-- CUSTOMER RISK MODEL VIEW
-- Purpose: Transform customer_intelligence into a multi-factor risk model.
-- Inputs: complaint volume, severity, recency, sentiment, customer value.
-- Outputs: ranked and normalized customer risk scores for churn prediction
-- Notes: Each CTE isolates a single dimension of risk for clarity and auditability.
-- =========================================
-- Calculate recency, frequency, and customer value factors
-- =========================================
recency_role AS (
    SELECT
        customer_id,

        -- recency_factor: exponentially decays with time since last complaint.
        -- More recent complaints get a higher weight; older complaints reduce risk contribution.
        EXP(-DATEDIFF(DAY, MAX(complaint_date), GETDATE()) / 30.0) AS recency_factor,

        -- Flag new customers: 1 if signup within last 30 days, else 0
        CASE WHEN signup_date >= DATEADD(DAY, -30, GETDATE()) THEN 1 ELSE 0 END AS is_new_customer,

        -- Assign customer value: Premium customers weighted higher (2) than others (1)
        CASE WHEN segment = 'Premium' THEN 2 ELSE 1 END AS customer_value,

        -- frequency: average days between complaints
        -- Measures how often the customer complains; smaller number means more frequent complaints
        (DATEDIFF(DAY, MIN(complaint_date), MAX(complaint_date)) / COUNT(complaint_id)) AS frequency

    FROM customer_intelligence

    -- Group by customer and the derived factors used in calculations
    GROUP BY customer_id, 
        CASE WHEN signup_date >= DATEADD(DAY, -30, GETDATE()) THEN 1 ELSE 0 END,
        CASE WHEN segment = 'Premium' THEN 2 ELSE 1 END
),

-- =========================================
-- Combine risk components into a single customer risk score
-- =========================================
customer_risk_score AS (
    SELECT
        v.customer_id,
        s.signup_date,
        v.complaints_last_30_days, -- volume-based risk
        r.is_new_customer,          -- new customer flag
        r.customer_value,           -- premium or standard customer weighting
        ROUND(r.recency_factor, 2) AS recency_factor, -- recency contribution
        st.sentiment_score,         -- average sentiment score
        COALESCE(st.sentiment, 'Negative') AS sentiment, -- sentiment category
        r.frequency,                -- complaint frequency
        s.severity_risk,            -- severity contribution based on urgency / unresolved complaints
        s.segment,
        v.volume_risk,              -- volume-based risk flag

        -- Final composite risk score as weighted sum of multiple factors:
        -- volume (30%), severity (30%), recency (20%), new customer (10%), customer value (10%), sentiment (10%)
        COALESCE(
            ROUND(
                ((0.3 * v.volume_risk) + (0.3 * severity_risk) + 
                 (0.2 * recency_factor) + (0.1 * is_new_customer) + 
                 (0.1 * customer_value) + (0.1 * sentiment_score)), 2), 0
        ) AS risk_score

    FROM volume_risk v
    LEFT JOIN severity s ON v.customer_id = s.customer_id
    LEFT JOIN recency_role r ON r.customer_id = v.customer_id
    LEFT JOIN sentiment st ON st.customer_id = v.customer_id
),

-- =========================================
-- Rank and normalize customer risk scores for comparison
-- =========================================
ranked_score AS (
    SELECT
        customer_id,
        complaints_last_30_days,
        is_new_customer,
        segment,

        -- Tenure categories based on signup date
        CASE
            WHEN DATEDIFF(DAY, signup_date, GETDATE()) < 90 THEN '3 Months'
            WHEN DATEDIFF(DAY, signup_date, GETDATE()) BETWEEN 90 AND 180 THEN '3-6 Months'
            WHEN DATEDIFF(DAY, signup_date, GETDATE()) BETWEEN 181 AND 365 THEN '6-12 Months'
            WHEN DATEDIFF(DAY, signup_date, GETDATE()) BETWEEN 365 AND 730 THEN '1-2 Years'
            ELSE '2+ Years'
        END AS tenure,

        customer_value,
        recency_factor,
        frequency,
        sentiment,
        severity_risk,
        volume_risk,
        risk_score,

        -- Normalize risk score between 0 and 1 for easier comparison
        CAST(
            ROUND(
                (risk_score - MIN(risk_score) OVER()) 
                / NULLIF(MAX(risk_score) OVER() - MIN(risk_score) OVER(), 0), 2
            ) AS DECIMAL(10,6)
        ) AS normalized_risk_score
    FROM customer_risk_score
)
