-- ========================================================================
-- CUSTOMER INTELLIGENCE VIEWS & RISK MODEL
-- ========================================================================
-- Purpose: Create analytical views and multi-factor risk scoring model
-- Components:
--   1. Customer Intelligence View (Fact Table)
--   2. Customer Risk Score Model (Churn Prediction)
--   3. Weekly/Monthly Complaint Summary Procedure
-- Author: Adeayo Adewale
-- Last Modified: 2025
-- ========================================================================

/**************************************************************************************************
-- SECTION 1: CUSTOMER INTELLIGENCE VIEW DEVELOPMENT
-- PURPOSE: Iterative development of sentiment analysis and keyword matching
-- This section documents the evolution of the query logic
**************************************************************************************************/

-- ========================================================================
-- ITERATION 1: CROSS JOIN APPROACH (Initial Attempt)
-- ========================================================================
-- Purpose: Match each complaint to all keywords using pattern matching
-- Issue: Generated duplicates due to cartesian product
-- Learning: Simple CROSS JOIN creates row explosion

SELECT
    c.customer_id,
    c.complaint_id,
    c.complaint_text,
    -- Aggregate matched keywords into comma-separated list
    STRING_AGG(k.keyword, ', ') AS matched_keywords,
    -- Calculate average sentiment across all matched keywords
    AVG(ROUND(k.sentiment_score, 2)) AS sentiment_score,
    k.category
FROM complaints c
CROSS JOIN sentiment_keywords k
WHERE c.complaint_text LIKE '%' + k.keyword + '%'
GROUP BY c.customer_id, c.complaint_id;
-- Result: Too many duplicates, inaccurate aggregation

-- ========================================================================
-- ITERATION 2: DISTINCT CTE APPROACH
-- ========================================================================
-- Purpose: Use CTE with DISTINCT to reduce duplicate keyword matches
-- Improvement: Reduces row count but still has aggregation issues

WITH matched_keywords AS (
    -- Get unique keyword matches per complaint
    SELECT DISTINCT
        c.complaint_id,
        c.complaint_text,
        k.keyword,
        ROUND(k.sentiment_score, 2) AS sentiment_score
    FROM complaints c
    CROSS JOIN sentiment_keywords k
    WHERE c.complaint_text LIKE '%' + k.keyword + '%'
)
SELECT
    complaint_text,
    -- Aggregate unique keywords
    STRING_AGG(CAST(keyword AS NVARCHAR(max)), ', ') AS matched_keywords,
    -- Average sentiment score
    AVG(sentiment_score) AS sentiment_score
FROM matched_keywords
GROUP BY complaint_text;
-- Result: Better, but still not optimal for nested aggregation

-- ========================================================================
-- ITERATION 3: SUBQUERY AGGREGATION APPROACH
-- ========================================================================
-- Purpose: Use nested subquery with DISTINCT for keyword aggregation
-- Issue: Complex nesting makes query hard to maintain and optimize

SELECT
    c.complaint_id,
    c.complaint_text,
    -- Correlated subquery to get keywords for each complaint
    (
        SELECT STRING_AGG(k.keyword, ', ')
        FROM (
            SELECT DISTINCT k.keyword
            FROM sentiment_keywords k
            WHERE c.complaint_text LIKE '%' + k.keyword + '%'
        ) AS distinct_keywords
    ) AS keywords
FROM complaints c
CROSS JOIN sentiment_keywords k
WHERE c.complaint_text LIKE '%' + k.keyword + '%'
GROUP BY c.complaint_id, c.complaint_text
ORDER BY c.complaint_id;
-- Result: Overly complex, performance concerns with correlated subquery

-- ========================================================================
-- ITERATION 4: CROSS APPLY APPROACH (Breakthrough)
-- ========================================================================
-- Purpose: Use CROSS APPLY with DISTINCT to efficiently match keywords
-- Improvement: Eliminates row explosion while maintaining accuracy
-- This became the foundation for the final solution

SELECT
    c.complaint_id,
    c.complaint_text,
    -- Aggregate matched keywords
    STRING_AGG(k.keyword, ', ') AS keywords,
    -- Average sentiment score across matched keywords
    ROUND(AVG(k.sentiment_score), 2) AS sentiment_score,
    -- Get primary sentiment category
    MAX(k.category) AS category
FROM complaints c
CROSS APPLY (
    -- CROSS APPLY ensures each complaint only joins matching keywords
    -- DISTINCT prevents duplicate keywords from affecting sentiment calculation
    SELECT DISTINCT k.keyword, k.sentiment_score, k.category
    FROM sentiment_keywords k
    WHERE c.complaint_text LIKE '%' + k.keyword + '%'
) k
GROUP BY c.complaint_id, c.complaint_text
ORDER BY c.complaint_id;
-- Result: Clean, efficient, accurate - selected for production

-- ========================================================================
-- ITERATION 5: SIMPLIFIED KEYWORDS-ONLY TEST
-- ========================================================================
-- Purpose: Validate keyword matching logic without sentiment complexity
-- Use Case: Testing and debugging

SELECT 
    c.complaint_id,
    c.complaint_text,
    -- Just aggregate keywords to verify matching works
    STRING_AGG(k.keyword, ', ') AS keywords
FROM complaints c
CROSS APPLY (
    SELECT DISTINCT k.keyword
    FROM sentiment_keywords k
    WHERE c.complaint_text LIKE '%' + k.keyword + '%'
) k
GROUP BY c.complaint_id, c.complaint_text
ORDER BY c.complaint_id;

-- ========================================================================
-- DATA QUALITY: FIX TYPOS IN SOURCE DATA
-- ========================================================================
-- Purpose: Standardize complaint text for consistent keyword matching
-- Issue: "biling" appears in source data instead of "billing"
-- Impact: Affects sentiment analysis and keyword matching accuracy

UPDATE complaints
SET complaint_text = REPLACE(complaint_text, 'biling', 'billing')
WHERE complaint_text LIKE '%biling%';

-- ========================================================================
-- DATA QUALITY: CHECK FOR NULL CUSTOMER IDs
-- ========================================================================
-- Purpose: Identify data quality issues before creating view

SELECT
    COUNT(*) AS null_complaints
FROM complaints
WHERE customer_id IS NULL;

/**************************************************************************************************
-- SECTION 2: PRODUCTION VIEW - CUSTOMER INTELLIGENCE
-- PURPOSE: Create single source of truth for all customer complaint analytics
-- This view serves as the primary fact table for Power BI reporting
**************************************************************************************************/

-- ===================================================================================
-- VIEW: customer_intelligence
-- ===================================================================================
-- Description: Comprehensive customer complaint intelligence with sentiment analysis
-- Inputs: customers, complaints, resolutions, agents, product_tags, sentiment_keywords
-- Outputs: Enriched fact table with sentiment scores, resolution metrics, agent data
-- Usage: Power BI reports, dashboards, analytical queries
-- Refresh: Real-time (view queries underlying tables)

CREATE VIEW customer_intelligence AS
WITH 
    -- ===================================================================================
    -- CTE 1: SENTIMENT ANALYSIS ENGINE
    -- ===================================================================================
    -- Purpose: Extract keywords and compute sentiment scores using NLP simulation
    -- Method: Pattern matching against pre-defined sentiment keyword dictionary
    -- Output: Sentiment score (-1 to +1), category (Positive/Neutral/Negative), keywords
    
    sentiment AS (
        SELECT 
            c.complaint_id,
            c.complaint_text,
            -- Aggregate all matched keywords for reporting and analysis
            STRING_AGG(k.keyword, ', ') AS matched_keywords, 
            -- Compute average sentiment score across all matched keywords
            -- Score ranges: -1 (very negative) to +1 (very positive)
            ROUND(AVG(k.sentiment_score), 2) AS sentiment_score, 
            -- Assign primary sentiment category
            -- MAX prioritizes negative sentiment if mixed signals present
            MAX(k.category) AS sentiment_category 
        FROM complaints c
        CROSS APPLY (
            -- Use CROSS APPLY for efficient keyword matching
            -- DISTINCT prevents duplicate keywords from skewing sentiment average
            SELECT DISTINCT sk.keyword, sk.sentiment_score, sk.category 
            FROM sentiment_keywords sk
            WHERE c.complaint_text LIKE '%' + sk.keyword + '%'
        ) k
        GROUP BY c.complaint_id, c.complaint_text
    ),

    -- ===================================================================================
    -- CTE 2: PRODUCT TAGS AGGREGATION
    -- ===================================================================================
    -- Purpose: Consolidate multiple product tags per complaint into single field
    -- Use Case: Power BI visualization, drill-through analysis
    -- Example: "Bug, Performance Issue, UI Problem"
    
    product_tags_agg AS (
        SELECT
            complaint_id,
            -- Combine all tags into comma-separated string
            STRING_AGG(product_tag, ', ') AS detailed_issue_tags
        FROM product_tags
        GROUP BY complaint_id
    )

-- ===================================================================================
-- MAIN SELECT: CONSTRUCT FACT TABLE
-- ===================================================================================
-- Purpose: Join all dimension and fact tables to create analytical dataset
-- Structure: One row per complaint with all related attributes

SELECT
    -- ============================================
    -- PRIMARY KEYS & IDENTIFIERS
    -- ============================================
    cc.complaint_id,
    c.customer_id,
    
    -- ============================================
    -- CUSTOMER ATTRIBUTES (Dimension)
    -- ============================================
    c.region,                -- Geographic location
    c.signup_date,           -- Customer acquisition date
    c.segment,               -- Customer tier (Premium, Standard, etc.)
    
    -- ============================================
    -- COMPLAINT ATTRIBUTES (Fact)
    -- ============================================
    CAST(cc.date AS DATE) AS complaint_date,  -- Complaint submission date
    cc.complaint_text,                         -- Full complaint description
    cc.channel,                                -- Communication channel (Email, Phone, Chat, etc.)
    cc.product_area,                           -- Primary product classification
    cc.urgency,                                -- Priority level (High, Medium, Low)

    -- ============================================
    -- SENTIMENT ANALYSIS (Derived)
    -- ============================================
    s.sentiment_score,        -- Numeric sentiment (-1 to +1)
    s.sentiment_category,     -- Categorical sentiment (Positive/Neutral/Negative)
    s.matched_keywords,       -- Keywords found in complaint text

    -- ============================================
    -- RESOLUTION ATTRIBUTES (Fact)
    -- ============================================
    r.resolution_type,        -- How complaint was resolved
    r.resolution_date,        -- When complaint was closed
    r.notes AS resolution_notes,  -- Agent's resolution notes

    -- ============================================
    -- PRODUCT TAGGING (Derived)
    -- ============================================
    p.detailed_issue_tags,    -- Aggregated product issue tags

    -- ============================================
    -- AGENT ATTRIBUTES (Dimension)
    -- ============================================
    a.agent_id,
    CONCAT(a.first_name, ' ', a.last_name) AS agent_name,  -- Full agent name
    a.skillset,               -- Agent specialization
    a.location AS agent_location,  -- Agent's work location

    -- ============================================
    -- DERIVED TIME METRICS (Calculated)
    -- ============================================
    
    -- Complaint age: Days since complaint was submitted
    -- Use Case: Identify aging open complaints
    DATEDIFF(DAY, cc.date, GETDATE()) AS complaint_age_days,
    
    -- Time to resolution: Days from complaint to resolution
    -- Data Quality Checks:
    --   - NULL if complaint still open
    --   - Use complaint_date if resolution_date precedes it (data error)
    --   - Otherwise use actual resolution_date
    DATEDIFF(DAY, cc.date, 
        CASE
            WHEN r.resolution_date IS NULL THEN NULL           -- Still open
            WHEN r.resolution_date < cc.date THEN cc.date      -- Data quality check
            ELSE r.resolution_date                             -- Valid resolution
        END
    ) AS resolution_time,

    -- ============================================
    -- RESOLUTION STATUS FLAG (Derived)
    -- ============================================
    -- Purpose: Categorical status for filtering and slicing in Power BI
    -- Values: Open, Pending, Closed
    CASE
        WHEN r.resolution_date IS NULL THEN 'Open'           -- No resolution date
        WHEN r.resolution_type = 'Pending' THEN 'Pending'    -- In progress
        ELSE 'Closed'                                         -- Resolved
    END AS resolution_status

-- ============================================
-- TABLE JOINS
-- ============================================
FROM customers c
-- Customer to complaints (one-to-many)
LEFT JOIN complaints cc ON c.customer_id = cc.customer_id
-- Complaints to resolutions (one-to-one)
LEFT JOIN resolutions r ON cc.complaint_id = r.complaint_id
-- Resolutions to agents (many-to-one)
LEFT JOIN agents a ON a.agent_id = r.agent_id
-- Complaints to product tags (one-to-many, aggregated in CTE)
LEFT JOIN product_tags_agg p ON cc.complaint_id = p.complaint_id
-- Complaints to sentiment (one-to-one, computed in CTE)
LEFT JOIN sentiment s ON cc.complaint_id = s.complaint_id

-- ============================================
-- DATA QUALITY FILTER
-- ============================================
-- Exclude complaints with missing dates (data quality issue)
-- These should be cleaned in source system or ETL
WHERE cc.date IS NOT NULL;

/**************************************************************************************************
-- SECTION 3: CUSTOMER RISK SCORING MODEL
-- PURPOSE: Multi-factor churn prediction model
-- METHOD: Weighted scoring across 6 risk dimensions
**************************************************************************************************/

-- ===================================================================================
-- CUSTOMER RISK MODEL VIEW
-- ===================================================================================
-- Description: Transform customer_intelligence into churn risk scores
-- Factors: Volume, Severity, Recency, Frequency, Customer Value, Sentiment
-- Output: Normalized risk scores (0-1) with rankings for intervention prioritization
-- Use Case: Churn prevention, customer success outreach, retention campaigns

-- =========================================
-- CTE 1: RECENCY, FREQUENCY & VALUE ANALYSIS
-- =========================================
-- Purpose: Calculate time-based risk factors and customer value

recency_role AS (
    SELECT
        customer_id,

        -- RECENCY FACTOR: Exponential decay based on time since last complaint
        -- Formula: e^(-days_since_last_complaint / 30)
        -- Logic: Recent complaints are stronger churn signals than old ones
        -- Range: 0 (very old) to 1 (very recent)
        -- Example: 
        --   0 days ago = e^(0) = 1.0 (maximum risk)
        --   30 days ago = e^(-1) = 0.37 (moderate risk)
        --   90 days ago = e^(-3) = 0.05 (low risk)
        EXP(-DATEDIFF(DAY, MAX(complaint_date), GETDATE()) / 30.0) AS recency_factor,

        -- NEW CUSTOMER FLAG: Identifies recently acquired customers
        -- Logic: New customers churning is more critical than long-term churn
        -- Value: 1 if signup within last 30 days, else 0
        CASE WHEN signup_date >= DATEADD(DAY, -30, GETDATE()) THEN 1 ELSE 0 END AS is_new_customer,

        -- CUSTOMER VALUE: Weight by customer segment
        -- Logic: Premium customer churn has higher business impact
        -- Value: 2 for Premium, 1 for Standard
        CASE WHEN segment = 'Premium' THEN 2 ELSE 1 END AS customer_value,

        -- FREQUENCY: Average days between complaints
        -- Formula: (last_complaint_date - first_complaint_date) / complaint_count
        -- Logic: Lower number = more frequent complaints = higher risk
        -- Example: 
        --   10 days average = very frequent complainer (high risk)
        --   90 days average = occasional complainer (moderate risk)
        (DATEDIFF(DAY, MIN(complaint_date), MAX(complaint_date)) / COUNT(complaint_id)) AS frequency

    FROM customer_intelligence

    -- Group by customer and the derived factors
    GROUP BY customer_id, 
        CASE WHEN signup_date >= DATEADD(DAY, -30, GETDATE()) THEN 1 ELSE 0 END,
        CASE WHEN segment = 'Premium' THEN 2 ELSE 1 END
),

-- =========================================
-- CTE 2: COMPOSITE RISK SCORE CALCULATION
-- =========================================
-- Purpose: Combine all risk factors into single weighted score
-- Weights: Tuned based on business priorities and statistical correlation with churn

customer_risk_score AS (
    SELECT
        v.customer_id,
        s.signup_date,
        
        -- ============================================
        -- RISK COMPONENTS (Individual Factors)
        -- ============================================
        v.complaints_last_30_days,    -- Volume-based risk
        r.is_new_customer,             -- New customer flag (retention critical)
        r.customer_value,              -- Customer tier weighting
        ROUND(r.recency_factor, 2) AS recency_factor,  -- Time decay factor
        st.sentiment_score,            -- Sentiment analysis score
        COALESCE(st.sentiment, 'Negative') AS sentiment,  -- Sentiment category
        r.frequency,                   -- Complaint frequency metric
        s.severity_risk,               -- Urgency/unresolved combination
        s.segment,
        v.volume_risk,                 -- High volume flag

        -- ============================================
        -- COMPOSITE RISK SCORE (Weighted Sum)
        -- ============================================
        -- Formula: Weighted average of normalized risk factors
        -- Weights (totaling 100%):
        --   - Volume: 30% (high complaint volume = strong churn signal)
        --   - Severity: 30% (urgent/unresolved = immediate risk)
        --   - Recency: 20% (recent complaints = active dissatisfaction)
        --   - New Customer: 10% (early churn = onboarding failure)
        --   - Customer Value: 10% (premium customer priority)
        --   - Sentiment: 10% (negative sentiment = dissatisfaction indicator)
        --
        -- Range: 0 to ~3.5 (before normalization)
        -- Note: COALESCE handles NULL values by defaulting to 0
        
        COALESCE(
            ROUND(
                ((0.3 * v.volume_risk) +        -- 30% weight: Volume
                 (0.3 * severity_risk) +        -- 30% weight: Severity
                 (0.2 * recency_factor) +       -- 20% weight: Recency
                 (0.1 * is_new_customer) +      -- 10% weight: New customer
                 (0.1 * customer_value) +       -- 10% weight: Value
                 (0.1 * sentiment_score)), 2    -- 10% weight: Sentiment
            ), 0
        ) AS risk_score

    FROM volume_risk v
    LEFT JOIN severity s ON v.customer_id = s.customer_id
    LEFT JOIN recency_role r ON r.customer_id = v.customer_id
    LEFT JOIN sentiment st ON st.customer_id = v.customer_id
),

-- =========================================
-- CTE 3: NORMALIZATION & RANKING
-- =========================================
-- Purpose: Convert raw scores to 0-1 scale and add rankings
-- Use Case: Easier interpretation and comparison across customer base

ranked_score AS (
    SELECT
        customer_id,
        complaints_last_30_days,
        is_new_customer,
        segment,

        -- ============================================
        -- TENURE CATEGORIZATION
        -- ============================================
        -- Purpose: Segment customers by relationship length
        -- Use Case: Identify churn patterns by customer lifecycle stage
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

        -- ============================================
        -- NORMALIZED RISK SCORE (0 to 1 scale)
        -- ============================================
        -- Purpose: Min-Max normalization for easier interpretation
        -- Formula: (score - min) / (max - min)
        -- Benefits:
        --   - 0 = lowest risk customer in database
        --   - 1 = highest risk customer in database
        --   - Easy to set intervention thresholds (e.g., score > 0.8)
        -- 
        -- NULLIF prevents division by zero if all scores are identical
        CAST(
            ROUND(
                (risk_score - MIN(risk_score) OVER()) 
                / NULLIF(MAX(risk_score) OVER() - MIN(risk_score) OVER(), 0), 2
            ) AS DECIMAL(10,6)
        ) AS normalized_risk_score
    FROM customer_risk_score
)

-- ============================================
-- FINAL SELECT: OUTPUT RISK MODEL
-- ============================================
-- Returns all risk factors and normalized scores
-- Order by normalized_risk_score DESC to prioritize interventions
SELECT * FROM ranked_score;

/**************************************************************************************************
-- SECTION 4: OPERATIONAL STORED PROCEDURE
-- PURPOSE: Generate standardized complaint summaries for periodic reporting
**************************************************************************************************/

-- ============================================================
-- STORED PROCEDURE: sp_generate_complaint_summary
-- ============================================================
-- Description: Generate complaint intelligence for weekly or monthly periods
-- Parameters: @period VARCHAR(10) - Accepts 'WEEKLY' or 'MONTHLY'
-- Output: Four result sets covering themes, urgency, product areas, agent performance
-- Use Case: Executive reports, operational dashboards, team meetings
-- Schedule: Can be automated via SQL Server Agent jobs

CREATE PROCEDURE sp_generate_complaint_summary 
    @period VARCHAR(10)
AS
BEGIN
    -- Optimize performance by suppressing row count messages
    SET NOCOUNT ON;

    -- ============================================
    -- PARAMETER VALIDATION & MAPPING
    -- ============================================
    -- Purpose: Convert period string to day window
    -- Defaults to WEEKLY (7 days) if invalid input provided
    
    DECLARE @days INT;
    IF @period = 'WEEKLY'  SET @days = 7;
    ELSE IF @period = 'MONTHLY' SET @days = 30;
    ELSE SET @days = 7;  -- Default fallback

    -- ============================================
    -- RESULT SET 1: TOP COMPLAINT THEMES
    -- ============================================
    -- Purpose: Identify most common complaint topics/keywords
    -- Use Case: Product team priorities, engineering backlog
    -- Business Value: Focus fixes on highest-volume issues
    
    SELECT TOP 5 
        keywords AS complaint_theme,
        COUNT(*) AS total_complaints
    FROM customer_intelligence
    WHERE keywords IS NOT NULL
      AND complaint_date >= DATEADD(DAY, -@days, GETDATE())
    GROUP BY keywords
    ORDER BY total_complaints DESC;

    -- ============================================
    -- RESULT SET 2: URGENCY DISTRIBUTION
    -- ============================================
    -- Purpose: Show breakdown of complaint priorities
    -- Use Case: Resource allocation, SLA compliance monitoring
    -- Business Value: Ensure high-urgency cases receive priority
    
    SELECT 
        urgency AS urgency_level,
        COUNT(*) AS total
    FROM customer_intelligence
    WHERE complaint_date >= DATEADD(DAY, -@days, GETDATE())
    GROUP BY urgency
    ORDER BY 
        CASE urgency 
            WHEN 'High' THEN 1 
            WHEN 'Medium' THEN 2 
            WHEN 'Low' THEN 3 
        END;

    -- ============================================
    -- RESULT SET 3: PRODUCT AREA BREAKDOWN
    -- ============================================
    -- Purpose: Identify which product areas have most complaints
    -- Use Case: Product quality assessment, team performance
    -- Business Value: Target improvements to problematic areas
    
    SELECT 
        product_area,
        COUNT(*) AS total_complaints
    FROM customer_intelligence
    WHERE complaint_date >= DATEADD(DAY, -@days, GETDATE())
    GROUP BY product_area
    ORDER BY total_complaints DESC;

    -- ============================================
    -- RESULT SET 4: TOP PERFORMING AGENTS
    -- ============================================
    -- Purpose: Identify fastest-resolving agents
    -- Use Case: Performance reviews, best practice sharing
    -- Business Value: Recognize top performers, identify coaching needs
    
    SELECT TOP 5 
        agent_name,
        COUNT(*) AS cases_resolved,
        AVG(resolution_time) AS average_resolution_time,
        MIN(resolution_time) AS fastest_resolution,
        MAX(resolution_time) AS slowest_resolution
    FROM customer_intelligence
    WHERE resolution_time IS NOT NULL
      AND complaint_date >= DATEADD(DAY, -@days, GETDATE())
    GROUP BY agent_name
    ORDER BY average_resolution_time ASC;
END;
GO

-- ============================================
-- EXECUTION EXAMPLES
-- ============================================

-- Weekly summary (last 7 days)
EXEC sp_generate_complaint_summary @period = 'WEEKLY';

-- Monthly summary (last 30 days)
EXEC sp_generate_complaint_summary @period = 'MONTHLY';

-- ========================================================================
-- END OF VIEWS, RISK MODEL & STORED PROCEDURES
-- ========================================================================
