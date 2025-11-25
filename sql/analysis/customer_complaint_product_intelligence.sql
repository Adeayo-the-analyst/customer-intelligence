-- ========================================================================
-- PRODUCT & ISSUE INTELLIGENCE ANALYSIS
-- ========================================================================
-- Purpose: Expose recurring product weaknesses and systemic friction points
-- Author: Adeayo Adewale
-- Last Modified: 2025
-- ========================================================================

-- ========================================================================
-- SECTION 1: BASIC COMPLAINT METRICS
-- ========================================================================
-- Purpose: Get high-level complaint counts by product area
-- Use Case: Executive dashboard, product prioritization

-- Query 1.1: Total complaints by product area (closed only)
SELECT
    product_area,
    COUNT(DISTINCT complaint_id) as total_complaints
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
AND signup_date <= GETDATE()
AND resolution_status = 'Closed'
GROUP BY product_area;

-- Query 1.2: Overall complaint volume metrics
-- Returns: Total unique customers and total complaints across all areas
SELECT
    COUNT(DISTINCT customer_id) AS unique_customers,
    COUNT(complaint_id) AS total_complaints
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
AND signup_date <= GETDATE()

-- ========================================================================
-- SECTION 2: PRODUCT PERFORMANCE ANALYSIS
-- ========================================================================
-- Purpose: Comprehensive product area performance metrics
-- Metrics: Resolution rates, agent assignment, complaint volume

WITH product_performance AS (
    -- Aggregate complaint metrics by product area
    SELECT
        product_area,
        COUNT(*) AS total_complaints,
        -- Resolution status breakdown
        SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
        SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints,
        -- Agent assignment breakdown
        SUM(CASE WHEN agent_name IS NULL OR agent_name = '' THEN 1 ELSE 0 END) AS complaints_without_agents,
        SUM(CASE WHEN agent_name IS NOT NULL AND agent_name <> '' THEN 1 ELSE 0 END) AS complaints_assigned_to_agents
    FROM customer_intelligence
    WHERE complaint_date <= GETDATE()
    AND signup_date <= GETDATE()
    GROUP BY product_area
)
SELECT 
    product_area,
    total_complaints,
    resolved_complaints,
    unresolved_complaints,
    complaints_without_agents,
    complaints_assigned_to_agents,
    -- Calculate percentage metrics
    CONCAT(ROUND(100.0 * complaints_assigned_to_agents/total_complaints, 2), '%') AS complaints_handled_by_agents_pct,
    CONCAT(ROUND(100.0 * complaints_without_agents/total_complaints, 2), '%') AS complaints_without_agents_pct,
    CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS unresolved_rate,
    CONCAT(ROUND((resolved_complaints * 100.0)/total_complaints, 2), '%') AS resolution_rate
FROM product_performance;

-- ========================================================================
-- SECTION 3: TREND ANALYSIS - YEARLY
-- ========================================================================
-- Purpose: Identify recurring issues and trends over years
-- Question: What have been the recurring issues over the years?

SELECT
    DATEPART(YEAR, complaint_date) AS complaint_year,
    product_area,
    COUNT(*) AS total_complaints,
    -- Breakdown by resolution status
    SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
    SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints,
    -- Agent assignment metrics
    SUM(CASE WHEN agent_name IS NULL OR agent_name = '' THEN 1 ELSE 0 END) AS complaints_without_agents,
    SUM(CASE WHEN agent_name IS NOT NULL AND agent_name <> '' THEN 1 ELSE 0 END) AS complaints_assigned_to_agents
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
AND signup_date <= GETDATE()
GROUP BY 
    DATEPART(YEAR, complaint_date), product_area
ORDER BY complaint_year;

-- ========================================================================
-- SECTION 4: MONTH-OVER-MONTH ANALYSIS
-- ========================================================================
-- Purpose: Detect complaint spikes and seasonality patterns
-- Includes: MoM % change, baseline averages, median calculations

WITH spikes AS (
    -- Calculate monthly complaint volumes
    SELECT
        DATEPART(YEAR, complaint_date) AS complaint_year,
        DATEPART(MONTH, complaint_date) AS complaint_month_number,
        DATENAME(MONTH, complaint_date) AS complaint_month,
        product_area,
        COUNT(*) AS total_complaints
    FROM customer_intelligence
    WHERE complaint_date <= GETDATE()
        AND signup_date <= GETDATE()
    GROUP BY 
        product_area,
        DATEPART(YEAR, complaint_date),
        DATEPART(MONTH, complaint_date),
        DATENAME(MONTH, complaint_date)
),
baseline AS (
    -- Calculate average monthly complaints per product area
    SELECT
        product_area,
        AVG(total_complaints) AS average_monthly_complaints
    FROM spikes
    GROUP BY product_area
),
median_calc AS (
    -- Calculate median monthly complaints per product area
    SELECT DISTINCT
        product_area,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_complaints) OVER(PARTITION BY product_area) AS median_month_complaints
    FROM spikes
)
SELECT
    s.complaint_year,
    s.complaint_month,
    s.product_area,
    s.total_complaints,
    -- Previous month for comparison
    LAG(s.total_complaints) OVER (
        PARTITION BY s.product_area
        ORDER BY s.complaint_year, s.complaint_month_number
    ) AS prev_month_complaints,
    -- Calculate month-over-month percentage change
    CASE 
        WHEN LAG(s.total_complaints) OVER (
            PARTITION BY s.product_area
            ORDER BY s.complaint_year, s.complaint_month_number
        ) IS NULL THEN NULL
        ELSE CAST(
            (s.total_complaints - LAG(s.total_complaints) OVER (
                PARTITION BY s.product_area
                ORDER BY s.complaint_year, s.complaint_month_number
            )) * 100.0 / LAG(s.total_complaints) OVER (
                PARTITION BY s.product_area
                ORDER BY s.complaint_year, s.complaint_month_number
            ) AS DECIMAL(10,2)
        )
    END AS mom_pct_change,
    b.average_monthly_complaints,
    m.median_month_complaints
FROM spikes s
INNER JOIN baseline b
    ON b.product_area = s.product_area
INNER JOIN median_calc m ON s.product_area = m.product_area
ORDER BY s.product_area, s.complaint_year, s.complaint_month_number;

-- ========================================================================
-- SECTION 5: REGRESSION TO THE MEAN ANALYSIS
-- ========================================================================
-- Purpose: Identify outlier months (abnormally high/low) using statistical methods
-- Method: 2 standard deviations from mean

WITH spikes AS (
    -- Monthly complaint aggregation
    SELECT
        DATEPART(YEAR, complaint_date) AS complaint_year,
        DATEPART(MONTH, complaint_date) AS complaint_month_number,
        DATENAME(MONTH, complaint_date) AS complaint_month,
        product_area,
        COUNT(*) AS total_complaints
    FROM customer_intelligence
    WHERE complaint_date <= GETDATE()
    AND signup_date <= GETDATE()
    GROUP BY 
        product_area,
        DATEPART(YEAR, complaint_date),
        DATEPART(MONTH, complaint_date),
        DATENAME(MONTH, complaint_date)
),
baseline AS (
    -- Calculate statistical baseline per product area
    SELECT
        product_area,
        AVG(total_complaints) AS avg_complaints,
        STDEV(total_complaints) AS std_dev_complaints
    FROM spikes
    GROUP BY product_area
)
SELECT
    s.complaint_year,
    s.complaint_month_number,
    s.complaint_month,
    s.product_area,
    s.total_complaints,
    b.avg_complaints,
    b.std_dev_complaints,
    -- Flag outlier months using 2 standard deviations
    CASE
        WHEN s.total_complaints > b.avg_complaints + 2 * b.std_dev_complaints THEN 'High (likely regression down)'
        WHEN s.total_complaints < b.avg_complaints - 2 * b.std_dev_complaints THEN 'Low (likely regression up)'
        ELSE 'Near Average'
    END AS regression_flag
FROM spikes s
INNER JOIN baseline b
    ON s.product_area = b.product_area
ORDER BY s.product_area, s.complaint_year, s.complaint_month_number;

-- ========================================================================
-- SECTION 6: PERSISTENT PROBLEM PATTERN ANALYSIS
-- ========================================================================
-- Purpose: Identify recurring complaint patterns in months with above-average volume
-- Method: Text normalization to group similar issues

WITH spikes AS (
    -- Monthly complaint aggregation
    SELECT
        DATEPART(YEAR, complaint_date) AS complaint_year,
        DATEPART(MONTH, complaint_date) AS complaint_month_number,
        DATENAME(MONTH, complaint_date) AS complaint_month,
        product_area,
        COUNT(*) AS total_complaints
    FROM customer_intelligence
    WHERE complaint_date <= GETDATE()
        AND signup_date <= GETDATE()
    GROUP BY 
        product_area,
        DATEPART(YEAR, complaint_date),
        DATEPART(MONTH, complaint_date),
        DATENAME(MONTH, complaint_date)
),
baseline AS (
    -- Calculate baseline statistics
    SELECT
        product_area,
        AVG(total_complaints) AS avg_complaints,
        STDEV(total_complaints) AS std_dev_complaints
    FROM spikes
    GROUP BY product_area
),
regression_flagged AS (
    -- Flag months with above-average complaints
    SELECT
        s.complaint_year,
        s.complaint_month_number,
        s.complaint_month,
        s.product_area,
        s.total_complaints,
        b.avg_complaints,
        b.std_dev_complaints,
        CASE
            WHEN s.total_complaints > b.avg_complaints + 2 * b.std_dev_complaints THEN 'High (likely regression down)'
            WHEN s.total_complaints < b.avg_complaints + 2 * b.std_dev_complaints THEN 'Low (likely regression up)'
            ELSE 'Near Average'
        END AS regression_flag
    FROM spikes s
    INNER JOIN baseline b
        ON s.product_area = b.product_area
),
persistent_complaints AS (
    -- Filter complaints from flagged months
    SELECT ci.*
    FROM customer_intelligence ci
    INNER JOIN regression_flagged rf
        ON ci.product_area = rf.product_area
        AND DATEPART(YEAR, ci.complaint_date) = rf.complaint_year
        AND DATEPART(MONTH, ci.complaint_date) = rf.complaint_month_number
    WHERE ci.complaint_date <= GETDATE()
    AND ci.signup_date <= GETDATE()
),
normalized AS (
    -- Normalize complaint text to detect patterns
    -- Replace all digits with [NUM] placeholder to group similar numeric variations
    SELECT
        product_area,
        LOWER(complaint_text) AS complaint_text_lower,
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(
                                    REPLACE(
                                        REPLACE(
                                            REPLACE(LOWER(complaint_text),'0','[NUM]'),'1','[NUM]'),'2','[NUM]'),'3','[NUM]'),'4','[NUM]'),'5','[NUM]'),'6','[NUM]'),'7','[NUM]'),'8','[NUM]'),'9','[NUM]')
                                            AS complaint_pattern
    FROM persistent_complaints
)
-- Count recurring patterns (appears more than once)
SELECT
    product_area,
    complaint_pattern,
    COUNT(*) AS occurrences
FROM normalized
GROUP BY product_area, complaint_pattern
HAVING COUNT(*) > 1
ORDER BY    
    product_area,
    occurrences DESC;

-- ========================================================================
-- SECTION 7: COMPLAINT LIFECYCLE ANALYSIS
-- ========================================================================
-- Purpose: Analyze time-to-resolution trends and identify bottlenecks
-- Metrics: Avg/min/max lifecycle days, month-over-month changes

WITH lifecycle AS (
    -- Calculate lifecycle days for each complaint
    SELECT
        complaint_id,
        product_area,
        DATEPART(YEAR, complaint_date) AS complaint_year,
        DATEPART(MONTH, complaint_date) AS complaint_month_num,
        DATENAME(MONTH, complaint_date) AS complaint_month,
        complaint_date,
        resolution_date,
        resolution_status,
        -- Calculate lifecycle days: for open complaints use complaint_age, for closed use date difference
        CASE
            WHEN resolution_status = 'Open' THEN complaint_age
            WHEN resolution_date >= complaint_date THEN DATEDIFF(DAY, complaint_date, resolution_date)
            ELSE NULL
        END AS lifecycle_days
    FROM customer_intelligence
    WHERE complaint_date <= GETDATE()
        AND signup_date <= GETDATE()
),
summary AS (
    -- Aggregate lifecycle metrics by product area and month
    SELECT  
        product_area,
        complaint_year,
        complaint_month_num,
        complaint_month,
        COUNT(*) AS total_complaints,
        SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS open_complaints,
        SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS closed_complaints,
        AVG(lifecycle_days) AS avg_lifecycle_days,
        MIN(lifecycle_days) AS min_lifecycle_days,
        MAX(lifecycle_days) AS max_lifecycle_days
    FROM lifecycle
    GROUP BY product_area, complaint_year, complaint_month_num, complaint_month
),
final AS (
    -- Add median calculation
    SELECT
        product_area,
        complaint_year,
        complaint_month_num,
        complaint_month,
        total_complaints,
        open_complaints,
        closed_complaints,
        avg_lifecycle_days,
        min_lifecycle_days,
        max_lifecycle_days,
        PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY s.avg_lifecycle_days)
            OVER(PARTITION BY s.product_area, complaint_year, complaint_month) AS median_lifecycle_days
    FROM summary s
)
SELECT 
  product_area,
  complaint_year,
  complaint_month,
  total_complaints,
  open_complaints,
  closed_complaints,
  avg_lifecycle_days,
  median_lifecycle_days,
  min_lifecycle_days,
  max_lifecycle_days,
  -- Compare to previous month
  LAG(avg_lifecycle_days) OVER(PARTITION BY product_area ORDER BY complaint_year, complaint_month_num) AS prev_avg_lifecycle,
  -- Calculate month-over-month change
  CASE
    WHEN lag(avg_lifecycle_days) OVER(PARTITION BY product_area ORDER BY complaint_year, complaint_month_num) IS NULL THEN NULL
    ELSE CAST(
        avg_lifecycle_days - LAG(avg_lifecycle_days) OVER(PARTITION BY product_area ORDER BY complaint_year, complaint_month_num)
    AS DECIMAL(10,2))
    END AS lifecycle_change_pct,
    -- Flag outlier months using statistical thresholds
    CASE
        WHEN avg_lifecycle_days > 
            AVG(avg_lifecycle_days) OVER(PARTITION BY product_area) +
            2 * STDEV(avg_lifecycle_days) OVER(PARTITION BY product_area)
            THEN 'Prolonged Lifecycle'
        WHEN avg_lifecycle_days < 
            AVG(avg_lifecycle_days) OVER(PARTITION BY product_area) -
            2 * STDEV(avg_lifecycle_days) OVER(PARTITION BY product_area)
            THEN 'Fast Resolution'
        ELSE 'Normal'
    END AS lifecycle_flag
FROM final
ORDER BY product_area, complaint_year, complaint_month_num;

-- ========================================================================
-- SECTION 8: CORRELATION ANALYSIS
-- ========================================================================
-- Purpose: Measure correlation between time and lifecycle days
-- Interpretation:
--   - Negative correlation: resolutions getting faster over time
--   - Positive correlation: resolutions getting slower over time
--   - Near zero: no clear trend

WITH lifecycle_summary AS (
    -- Calculate average lifecycle days by month
    SELECT
        product_area,
        DATEPART(YEAR, complaint_date) AS complaint_year,
        DATEPART(MONTH, complaint_date) AS complaint_month_num,
        DATENAME(MONTH, complaint_date) AS complaint_month,
        AVG(DATEDIFF(DAY, complaint_date, resolution_date)) AS avg_lifecycle_days
    FROM customer_intelligence
    WHERE resolution_status = 'Closed'
        AND signup_date <= GETDATE()
        AND complaint_date <= GETDATE()
    GROUP BY product_area, DATEPART(YEAR, complaint_date), DATEPART(MONTH, complaint_date), DATENAME(MONTH, complaint_date)
),
indexed AS (
    -- Create sequential month index for correlation calculation
    SELECT
        product_area,
        ROW_NUMBER () OVER(PARTITION BY product_area ORDER BY complaint_year, complaint_month_num) AS month_index,
        avg_lifecycle_days
    FROM lifecycle_summary
),
stats AS (
    -- Calculate correlation components
    SELECT
        product_area,
        COUNT(*) AS n,
        SUM(month_index) AS sum_x,
        SUM(avg_lifecycle_days) AS sum_y,
        SUM(month_index * avg_lifecycle_days) AS sum_xy,
        SUM(month_index * month_index) AS sum_x2,
        SUM(avg_lifecycle_days * avg_lifecycle_days) AS sum_y2
    FROM indexed
    GROUP BY product_area
)
-- Calculate Pearson correlation coefficient
SELECT
    product_area,
    CAST(
        (n * sum_xy - sum_x * sum_y)/
        (SQRT((n * sum_x2 - sum_x * sum_x) * (n * sum_y2 - sum_y * sum_y)))
        AS DECIMAL(10,4)
    ) AS correlation
FROM stats
ORDER BY correlation;

-- ========================================================================
-- SECTION 9: RESOLUTION TIME ANALYSIS
-- ========================================================================

-- Query 9.1: Average resolution time by product area
SELECT
    product_area,
    AVG(resolution_time) AS avg_res_time
FROM customer_intelligence
GROUP BY product_area;

-- Query 9.2: Quick response analysis (resolved in ≤1 day)
SELECT
    product_area,
    COUNT(*) AS quick_responses
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
    AND signup_date <= GETDATE()
    AND resolution_status = 'Closed' 
    AND resolution_time <= 1
GROUP BY product_area
ORDER BY quick_responses DESC;

-- Query 9.3: Longer than average resolutions
SELECT
    product_area,
    COUNT(*) AS longer_than_average_resolutions
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
    AND resolution_status = 'Closed'
    AND signup_date <= GETDATE()
    AND resolution_time >= (
        -- Calculate global average resolution time
        SELECT
            AVG(resolution_time)
        FROM customer_intelligence
        WHERE complaint_date <= GETDATE()
        AND signup_date <= GETDATE()
        AND resolution_status = 'Closed'
        )
GROUP By product_area
ORDER BY longer_than_average_resolutions DESC;

-- ========================================================================
-- SECTION 10: REGIONAL PRODUCT ANALYSIS
-- ========================================================================
-- Purpose: Identify which product problems appear in which regions

WITH product_region AS (
    -- Aggregate complaints by region and product area
    SELECT
        region,
        product_area,
        COUNT(*) AS total_complaints,
        SUM(CASE WHEN agent_name IS NULL OR agent_name = '' THEN 1 ELSE 0 END) AS complaints_not_assigned_to_agents,
        SUM(CASE WHEN agent_name IS NOT NULL AND agent_name <> '' THEN 1 ELSE 0 END) AS complaints_assigned_to_agents,
        SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints,
        SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints
    FROM customer_intelligence
    WHERE complaint_date <= GETDATE()
        AND signup_date <= GETDATE()
    GROUP BY region, product_area
)   
SELECT
    region,
    product_area,
    total_complaints,
    resolved_complaints,
    unresolved_complaints,
    complaints_assigned_to_agents,
    complaints_not_assigned_to_agents,
    -- Calculate percentage metrics
    CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS unresolved_rate,
    CONCAT(ROUND(100.0 * complaints_assigned_to_agents/total_complaints, 2), '%') AS complaints_assigned_to_agents_pct,
    CONCAT(ROUND(100.0 * complaints_not_assigned_to_agents/total_complaints, 2), '%') AS complaints_not_assigned_to_agents_pct,
    CONCAT(ROUND((resolved_complaints * 100.0)/total_complaints, 2), '%') AS resolution_rate
FROM product_region;

-- ========================================================================
-- SECTION 11: RESOLUTION TIME STATISTICS BY PRODUCT AREA
-- ========================================================================
-- Purpose: Detailed statistical analysis of resolution times

SELECT
    product_area,
    AVG(resolution_time) AS avg_res_time,
    MIN(resolution_time) AS min_res_time,
    MAX(resolution_time) AS max_res_time,
    STDEV(resolution_time) AS std_dev_res_time,
    VAR(resolution_time) AS var_res_time
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
    AND signup_date <= GETDATE()
    AND resolution_status = 'Closed'
GROUP BY product_area
ORDER BY avg_res_time;

-- ========================================================================
-- SECTION 12: REPEAT COMPLAINT ANALYSIS
-- ========================================================================
-- Purpose: Identify product areas with most repeat complainers
-- Segments customers by complaint frequency

WITH repeat_complaints_product AS (
    -- Count complaints per customer per product area
    SELECT
        product_area,
        customer_id,
        COUNT(complaint_id) AS repeat_complaints
    FROM customer_intelligence
    WHERE complaint_date <= GETDATE()
        AND signup_date <= GETDATE()
    GROUP BY product_area, customer_id
    HAVING COUNT(complaint_id) > 1  -- Only customers with multiple complaints
)
SELECT
    product_area,
    -- Categorize complaint frequency
    CASE
        WHEN repeat_complaints = 2 THEN 'Low Frequency'
        WHEN repeat_complaints BETWEEN 3 AND 5 THEN 'Medium Frequency'
        WHEN repeat_complaints BETWEEN 6 AND 10 THEN 'High Frequency'
        ELSE 'Very High Frequency'
    END AS complaint_frequency,
    COUNT(customer_id) AS customers_with_repeat_complaints
FROM repeat_complaints_product
GROUP BY product_area, 
    CASE
        WHEN repeat_complaints = 2 THEN 'Low Frequency'
        WHEN repeat_complaints BETWEEN 3 AND 5 THEN 'Medium Frequency'
        WHEN repeat_complaints BETWEEN 6 AND 10 THEN 'High Frequency'
        ELSE 'Very High Frequency'
    END;

-- ========================================================================
-- SECTION 13: REGIONAL COMPLAINT DISTRIBUTION
-- ========================================================================
-- Purpose: Analyze how many product areas customers complain about by region

WITH customers AS (
    -- Count distinct product areas per customer per region
    SELECT
        customer_id,
        region,
        COUNT(DISTINCT product_area) AS num_product_area
    FROM customer_intelligence
    WHERE complaint_date <= GETDATE()
        AND signup_date <= GETDATE()
    GROUP BY customer_id, region
),
region_distribution AS (
    -- Aggregate by region and number of product areas
    SELECT
        region,
        num_product_area,
        COUNT(customer_id) AS complaining_customers
    FROM customers
    GROUP BY region, num_product_area
)
SELECT
    region,
    num_product_area,
    complaining_customers
FROM region_distribution
ORDER BY complaining_customers DESC;

-- ========================================================================
-- SECTION 14: PRODUCT AREA OVERLAP ANALYSIS
-- ========================================================================
-- Purpose: Identify which product areas customers complain about together

WITH customers AS(
    -- Count product areas per customer
    SELECT
        customer_id,
        COUNT(DISTINCT product_area) AS num_product_area
    FROM customer_intelligence
    WHERE complaint_date <= GETDATE()
        AND signup_date <= GETDATE()
    GROUP BY customer_id
),
complaint_distribution AS (
    -- Join to get product area distribution
    SELECT
        c.num_product_area,
        COUNT(ci.customer_id) AS complaining_customers,
        ci.product_area
    FROM customer_intelligence ci 
    INNER JOIN customers c ON c.customer_id = ci.customer_id
    WHERE complaint_date <= GETDATE()
        AND signup_date <= GETDATE()
    GROUP BY c.num_product_area, ci.product_area
)
SELECT 
    num_product_area,
    product_area,
    complaining_customers
FROM complaint_distribution
ORDER BY complaining_customers DESC;

-- ========================================================================
-- SECTION 15: PRODUCT COMBINATION ANALYSIS
-- ========================================================================
-- Purpose: Identify which product complaints overlap for the same customers

WITH distinct_customer_products AS (
    -- Get unique customer-product pairs
    SELECT 
        DISTINCT customer_id, product_area
    FROM customer_intelligence
    WHERE complaint_date <= GETDATE()
        AND signup_date <= GETDATE()
),
customer_combinations AS (
    -- Create comma-separated list of product areas per customer
    SELECT
        customer_id,
        STRING_AGG(product_area, ', ') AS product_combinations
    FROM distinct_customer_products
    GROUP BY customer_id
),
combo_count AS (
    -- Count customers with each product combination
    SELECT
        product_combinations,
        COUNT(DISTINCT customer_id) AS num_customers
    FROM customer_combinations
    GROUP BY product_combinations
)
SELECT
    product_combinations,
    num_customers
FROM combo_count
ORDER BY num_customers DESC;

-- View all customer combinations
SELECT * FROM customer_combinations;

-- ========================================================================
-- SECTION 16: DAY-OF-WEEK ANALYSIS
-- ========================================================================
-- Purpose: Identify complaint patterns by day of week

-- Query 16.1: By product area
SELECT
    DATENAME(WEEKDAY, complaint_date) AS day_of_week,
    DATEPART(WEEKDAY, complaint_date) AS day_of_number,
    product_area,
    COUNT(customer_id) AS complaining_customers,
    COUNT(DISTINCT customer_id) AS repeating_complaining_customers,
    COUNT(customer_id) - COUNT(DISTINCT customer_id) AS repeats
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
    AND signup_date <= GETDATE()
GROUP BY product_area, DATENAME(WEEKDAY, complaint_date), DATEPART(WEEKDAY, complaint_date)
ORDER BY DATEPART(WEEKDAY, complaint_date);

-- Query 16.2: By region and product area
SELECT
    DATENAME(WEEKDAY, complaint_date) AS day_of_week,
    DATEPART(WEEKDAY, complaint_date) AS day_of_number,
    region,
    product_area,
    COUNT(customer_id) AS complaining_customers,
    COUNT(DISTINCT customer_id) AS repeating_complaining_customers,
    COUNT(customer_id) - COUNT(DISTINCT customer_id) AS repeats
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
    AND signup_date <= GETDATE()
GROUP BY region, product_area, DATENAME(WEEKDAY, complaint_date), DATEPART(WEEKDAY, complaint_date)
ORDER BY DATEPART(WEEKDAY, complaint_date);

-- ========================================================================
-- SECTION 17: AGENT SKILLSET DISTRIBUTION
-- ========================================================================
-- Purpose: Verify if all agents serve all product areas

SELECT
    product_area,
    skillset AS agents_skill,
    COUNT(DISTINCT agent_name) AS total_agents
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
    AND agent_name <> ''
    AND signup_date <= GETDATE()
    AND agent_name IS NOT NULL
GROUP BY product_area, skillset
ORDER BY total_agents DESC;

-- ========================================================================
-- SECTION 18: SKILLSET PERFORMANCE BY PRODUCT AREA
-- ========================================================================
-- Purpose: Analyze resolution time variance by skillset and product area

WITH res_stats AS (
    -- Calculate resolution time statistics
    SELECT
        skillset,
        product_area,
        AVG(resolution_time) AS avg_res_time,
        VAR(resolution_time) AS var_res_time,
        STDEV(resolution_time) AS std_res_time
    FROM customer_intelligence
    WHERE resolution_status = 'Closed'
        AND complaint_date <= GETDATE()
        AND signup_date <= GETDATE()
        AND agent_name IS NOT NULL
        AND agent_name <> ''        
    GROUP BY skillset, product_area
)
SELECT
    skillset,
    product_area,
    ROUND(avg_res_time, 2) AS average_res_time,
    ROUND(var_res_time, 2) AS var_res_time,
    ROUND(std_res_time, 2) AS std_res_time
FROM res_stats;

-- ========================================================================
-- SECTION 19: PRODUCT AREA ANOMALY DETECTION
-- ========================================================================
-- Purpose: Identify complaints with above/below average resolution times

WITH product_anomalies AS (
    -- Calculate product area baselines
    SELECT
        product_area,
        AVG(resolution_time) AS avg_res_time,
        STDEV(resolution_time) AS std_res_time,
        VAR(resolution_time) AS var_res_time
    FROM customer_intelligence
    WHERE complaint_date <= GETDATE()
        AND agent_name IS NOT NULL
        AND agent_name <> ''
        AND signup_date <= GETDATE()
    GROUP BY product_area
)
SELECT
    c.product_area,
    COUNT(c.complaint_id) AS total_complaints,
    p.avg_res_time,
    p.std_res_time,
    p.var_res_time,
    -- Count complaints above and below average
    SUM(CASE WHEN c.resolution_time > p.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
    SUM(CASE WHEN c.resolution_time <= p.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions_nr
FROM customer_intelligence c
INNER JOIN product_anomalies p ON c.product_area = p.product_area
WHERE c.complaint_date <= GETDATE()
        AND c.agent_name IS NOT NULL
        AND c.agent_name <> ''
        AND c.signup_date <= GETDATE()
GROUP BY c.product_area, p.avg_res_time, p.std_res_time, p.var_res_time;

-- ========================================================================
-- SECTION 20: UNRESOLVED RATE BY PRODUCT AREA
-- ========================================================================
-- Purpose: Calculate unresolved complaint rates

WITH cases AS  (
    SELECT
        product_area,
        COUNT(complaint_id) AS total_complaints,
        SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
    FROM customer_intelligence
    WHERE complaint_date <= GETDATE()
    GROUP BY product_area
)
SELECT
    product_area,
    total_complaints,
    unresolved_complaints,
    CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS unresolved_rate
FROM cases;

-- ========================================================================
-- SECTION 21: URGENCY LEVEL ANALYSIS
-- ========================================================================
-- Purpose: Analyze high urgency complaints by product area

WITH observations AS (
    SELECT
        product_area,
        COUNT(complaint_id) AS total_complaints,
        SUM(CASE WHEN urgency = 'High' THEN 1 ELSE 0 END) AS high_urgency_complaints,
        SUM(CASE WHEN urgency = 'High' AND resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_high_urgency_complaints
    FROM customer_intelligence
    WHERE complaint_date <= GETDATE()
    GROUP BY product_area
)
SELECT
    product_area,
    total_complaints,
    high_urgency_complaints,
    resolved_high_urgency_complaints,
    CONCAT(ROUND(100.0 * high_urgency_complaints/total_complaints,2),'%') AS pct_high_urgency_complaints,
    CONCAT(ROUND(100.0 * resolved_high_urgency_complaints/total_complaints, 2), '%') AS pct_high_urgency_resolutions 
FROM observations;

-- ========================================================================
-- END OF PRODUCT & ISSUE INTELLIGENCE ANALYSIS
-- ========================================================================