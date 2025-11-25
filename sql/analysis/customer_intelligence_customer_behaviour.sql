-- ========================================================================
-- CUSTOMER BEHAVIOUR ANALYSIS
-- ========================================================================
-- Purpose: Understand customer complaint patterns, segmentation, and trends
-- Goal: Identify at-risk customers and optimize customer experience
-- Author: Adeayo Adewale
-- Last Modified: 2025
-- ========================================================================

-- ========================================================================
-- SECTION 1: IGNORED COMPLAINTS ANALYSIS
-- ========================================================================
-- Purpose: Identify customers with complaints not assigned to agents
-- Critical: These represent potential customer churn risks

-- Query 1.1: Count customers with ignored complaints
SELECT
   COUNT(DISTINCT customer_id) AS customers_with_ignored_complaints
FROM customer_intelligence
WHERE signup_date <= GETDATE()
   AND complaint_date <= GETDATE()
   AND (agent_name IS NULL OR agent_name = '');

-- Query 1.2: Profile customers with multiple ignored complaints
SELECT
   DISTINCT customer_id AS customers_with_ignored_complaints,
   COUNT(complaint_id) AS total_complaints,
   COUNT(DISTINCT product_area) AS product_areas_problems
FROM customer_intelligence
WHERE signup_date <= GETDATE()
   AND complaint_date <= GETDATE()
   AND (agent_name IS NULL OR agent_name = '')
GROUP BY customer_id
HAVING COUNT(complaint_id) > 1;

-- Query 1.3: Total customer base
SELECT COUNT(DISTINCT customer_id) AS total_customers
FROM customers
WHERE signup_date <= GETDATE();

-- ========================================================================
-- SECTION 2: COMPLAINT TREND ANALYSIS
-- ========================================================================
-- Purpose: Identify whether complaint volume is stabilizing or accelerating
-- Method: 3-month rolling average

WITH monthly_complaints AS (
   -- Aggregate complaints by month
   SELECT
       CONCAT(DATEPART(YEAR, complaint_date),'-', DATENAME(MONTH, complaint_date)) AS complaint_month,
       DATEPART(YEAR, complaint_date) AS complaint_year,
       DATEPART(MONTH, complaint_date) AS complaint_month_num,
       COUNT(*) AS total_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
   AND signup_date <= GETDATE()
   GROUP BY 
   CONCAT(DATEPART(YEAR, complaint_date), '-', DATENAME(MONTH, complaint_date)),
   DATEPART(YEAR, complaint_date), DATEPART(MONTH, complaint_date)
)
SELECT
   complaint_month,
   total_complaints,
   -- Calculate 3-month rolling average
   ROUND(
       AVG(total_complaints) OVER (
           ORDER BY complaint_year, complaint_month_num 
           ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
       ), 2
   ) AS rolling_3_month_avg
FROM monthly_complaints
ORDER BY complaint_year, complaint_month_num;

-- ========================================================================
-- SECTION 3: CUSTOMER SEGMENTATION
-- ========================================================================

-- Query 3.1: Customers by segment
SELECT
   segment,
   COUNT(DISTINCT customer_id) AS total_customers
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
   AND signup_date <= GETDATE()
GROUP BY segment;

-- Query 3.2: Customers by region
SELECT
   region,
   COUNT(DISTINCT customer_id) AS total_customers,
   COUNT(complaint_id) AS total_complaints
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
   AND signup_date <= GETDATE()
GROUP BY region;

-- ========================================================================
-- SECTION 4: COMPLAINT FREQUENCY CATEGORIZATION
-- ========================================================================
-- Purpose: Segment customers by how often they complain
-- Categories: 1-time, Occasional, Frequent, Persistent, Chronic

WITH complaints AS (
   -- Count complaints per customer
   SELECT
       customer_id,
       segment,
       COUNT(complaint_id) AS customer_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY customer_id, segment
)
SELECT
   -- Categorize by complaint frequency
   CASE
       WHEN customer_complaints >= 11 THEN 'Chronic Complainers'
       WHEN customer_complaints BETWEEN 7 AND 10 THEN 'Persistent Complainers'
       WHEN customer_complaints BETWEEN 4 AND 6 THEN 'Frequent Complainers'
       WHEN customer_complaints BETWEEN 2 AND 3 THEN 'Occasional Complainers'
       ELSE '1-Time Complainers'
   END AS complaint_category,
   segment,
   COUNT(customer_id) AS total_customers
FROM complaints
GROUP BY 
   CASE
       WHEN customer_complaints >= 11 THEN 'Chronic Complainers'
       WHEN customer_complaints BETWEEN 7 AND 10 THEN 'Persistent Complainers'
       WHEN customer_complaints BETWEEN 4 AND 6 THEN 'Frequent Complainers'
       WHEN customer_complaints BETWEEN 2 AND 3 THEN 'Occasional Complainers'
       ELSE '1-Time Complainers'
   END,
   segment;

-- ========================================================================
-- SECTION 5: PARETO ANALYSIS - 80/20 RULE FOR CUSTOMERS
-- ========================================================================
-- Purpose: Identify which customers account for most complaints
-- Question: What proportion of customers drive 80% of complaints?

WITH total AS (
   -- Get total complaint count
   SELECT 
       COUNT(*) AS all_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
   AND signup_date <= GETDATE()
),
customer_totals AS (
   -- Count complaints per customer
   SELECT
       c.customer_id,
       COUNT(*) AS customer_complaints
   FROM customer_intelligence c
   WHERE c.complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY c.customer_id
), 
pareto AS (
   -- Calculate Pareto metrics
   SELECT 
       ct.customer_id,
       ct.customer_complaints,
       CAST(ct.customer_complaints * 100.0 / t.all_complaints AS DECIMAL(10,2))
        AS percent_of_total,
       -- Calculate cumulative percentage
       SUM(ct.customer_complaints) OVER (ORDER BY ct.customer_complaints DESC
       ROWS UNBOUNDED PRECEDING) * 100.0 / t.all_complaints AS cumulative_percent,
       RANK() OVER(ORDER BY ct.customer_complaints DESC) AS complaints_ranking
   FROM customer_totals ct
   CROSS JOIN total t
), 
count AS (
   -- Label top contributors
   SELECT
       customer_id,
       customer_complaints,
       percent_of_total,
       ROUND(cumulative_percent, 2) AS cumulative_percent,
       complaints_ranking,
       CASE
           WHEN cumulative_percent <= 80 THEN 'Top 20% Customers'
           ELSE 'Bottom 80% Customers'
       END AS pareto_group
   FROM pareto
)
SELECT
   pareto_group,
   COUNT(customer_id) AS total_customers
FROM count
GROUP BY pareto_group;

-- ========================================================================
-- SECTION 6: REPEAT COMPLAINT ANALYSIS
-- ========================================================================

-- Query 6.1: Count customers with repeat complaints
SELECT
   customer_id,
   COUNT(*) AS customers_with_repeat_complaints
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
AND signup_date <= GETDATE()
GROUP BY customer_id
HAVING COUNT(*) > 1;

-- Query 6.2: Frequency distribution of repeat complaints
WITH repeat_complaints AS (
   SELECT
       customer_id,
       COUNT(complaint_id) AS repeat_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
   GROUP BY customer_id
   HAVING COUNT(complaint_id) > 1
)
SELECT
   -- Categorize repeat frequency
   CASE
       WHEN repeat_complaints = 2 THEN 'Low Frequency'
       WHEN repeat_complaints BETWEEN 3 AND 5 THEN 'Medium Frequency'
       WHEN repeat_complaints BETWEEN 6 AND 10 THEN 'High Frequency'
       ELSE 'Very High Frequency'
   END AS complaint_frequency,
   COUNT(customer_id) AS customers_with_repeat_complaints
FROM repeat_complaints
GROUP BY  CASE
       WHEN repeat_complaints = 2 THEN 'Low Frequency'
       WHEN repeat_complaints BETWEEN 3 AND 5 THEN 'Medium Frequency'
       WHEN repeat_complaints BETWEEN 6 AND 10 THEN 'High Frequency'
       ELSE 'Very High Frequency'
   END;

-- ========================================================================
-- SECTION 7: REPEAT COMPLAINTS BY PRODUCT AREA
-- ========================================================================
-- Purpose: Identify which product areas generate most repeat complaints

WITH repeat_complaints_product AS (
   SELECT
       product_area,
       customer_id,
       COUNT(complaint_id) AS repeat_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY product_area, customer_id
   HAVING COUNT(complaint_id) > 1
)
SELECT
   product_area,
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
-- SECTION 8: REPEAT COMPLAINTS BY REGION
-- ========================================================================
-- Purpose: Identify geographic patterns in repeat complaints

WITH region_repeat_complaints AS (
   SELECT
       region,
       customer_id,
       COUNT(complaint_id) AS repeat_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY region, customer_id
   HAVING COUNT(complaint_id) > 1
)
SELECT
   region,
   CASE
       WHEN repeat_complaints = 2 THEN 'Low Frequency'
       WHEN repeat_complaints BETWEEN 3 AND 5 THEN 'Medium Frequency'
       WHEN repeat_complaints BETWEEN 6 AND 10 THEN 'High Frequency'
       ELSE 'Very High Frequency'
   END AS complaint_frequency,
   COUNT(customer_id) AS repeat_complaints
FROM region_repeat_complaints
GROUP BY 
   region,
    CASE
       WHEN repeat_complaints = 2 THEN 'Low Frequency'
       WHEN repeat_complaints BETWEEN 3 AND 5 THEN 'Medium Frequency'
       WHEN repeat_complaints BETWEEN 6 AND 10 THEN 'High Frequency'
       ELSE 'Very High Frequency'
   END
ORDER BY repeat_complaints DESC;

-- ========================================================================
-- SECTION 9: PRODUCT AREA CROSS-COMPLAINT ANALYSIS
-- ========================================================================
-- Purpose: Analyze how many product areas customers complain about

WITH customers AS(
   SELECT
       customer_id,
       COUNT(DISTINCT product_area) AS num_product_area
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY customer_id
),
complaint_distribution AS (
   SELECT
       num_product_area,
       COUNT(customer_id) AS complaining_customers
   FROM customers
   GROUP BY num_product_area
)
SELECT 
   num_product_area,
   complaining_customers
FROM complaint_distribution
ORDER BY complaining_customers DESC;

-- ========================================================================
-- SECTION 10: SEGMENT CROSS-PRODUCT ANALYSIS
-- ========================================================================
-- Purpose: Which segments complain across multiple product areas?

WITH customers AS(
   SELECT
       customer_id,
       segment,
       COUNT(DISTINCT product_area) AS num_product_area
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY customer_id, segment
),
segment_distribution AS (
   SELECT
       segment,
       num_product_area,
       COUNT(customer_id) AS complaining_customers
   FROM customers
   GROUP BY segment, num_product_area
)
SELECT 
   segment,
   num_product_area,
   complaining_customers
FROM segment_distribution
ORDER BY complaining_customers DESC;

-- ========================================================================
-- SECTION 11: REGIONAL CROSS-PRODUCT ANALYSIS
-- ========================================================================
-- Purpose: Which regions have customers complaining across product areas?

WITH customers AS (
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
-- SECTION 12: DETAILED PARETO WITH CUMULATIVE METRICS
-- ========================================================================
-- Purpose: Detailed Pareto analysis with customer profiles

WITH customer_complaints AS (
   SELECT
       customer_id,
       COUNT(complaint_id) AS total_complaints,
       COUNT(DISTINCT product_area) AS distinct_product_areas
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
   GROUP BY customer_id
   HAVING COUNT(complaint_id) > 1
),
complaint_distribution AS (
   SELECT
       customer_id,
       total_complaints,
       distinct_product_areas,
       ROW_NUMBER () OVER(ORDER BY total_complaints DESC) AS rank_number
   FROM customer_complaints
),
pareto AS (
   SELECT
       *,
       SUM(total_complaints) OVER () AS grand_total_complaints,
       COUNT(*) OVER () AS total_customers,
       SUM(total_complaints) OVER (ORDER BY total_complaints DESC) AS cumulative_complaints, 
       ROW_NUMBER () OVER (ORDER BY total_complaints DESC) * 1.0 / COUNT(*) OVER () AS cumulative_customers_ratio
   FROM complaint_distribution
)
SELECT
   customer_id,
   total_complaints,
   distinct_product_areas,
   ROUND(cumulative_customers_ratio * 100.0, 2) AS cumulative_customers_pct,
   ROUND(cumulative_complaints * 100.0/grand_total_complaints, 2) AS cumulative_complaints_pct
FROM pareto
ORDER BY total_complaints DESC;

-- ========================================================================
-- SECTION 13: TENURE-BASED ANALYSIS
-- ========================================================================
-- Purpose: Analyze complaint patterns based on customer tenure

-- Query 13.1: Customer tenure calculation
SELECT
   customer_id,
   DATEDIFF(YEAR, signup_date, GETDATE()) AS years_spent,
   DATEDIFF(MONTH, signup_date, GETDATE()) AS months_spent,
   COUNT(complaint_id) AS total_complaints
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
AND signup_date <= GETDATE()
AND signup_date IS NOT NULL
GROUP BY customer_id, 
   DATEDIFF(YEAR, signup_date, GETDATE()),
   DATEDIFF(MONTH, signup_date, GETDATE())
ORDER BY months_spent DESC;

-- Query 13.2: Tenure bucket analysis
WITH tenures AS (
   SELECT
       customer_id,
       DATEDIFF(MONTH, signup_date, GETDATE()) AS months_spent,
       COUNT(complaint_id) AS total_complaints,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY customer_id, DATEDIFF(MONTH, signup_date, GETDATE())
),
categories AS (
   -- Categorize by tenure
   SELECT
       CASE
           WHEN months_spent BETWEEN 0 AND 1 THEN '0-1 Month: New Arrivals/ Onboarding Stage'
           WHEN months_spent BETWEEN 2 AND 3 THEN '2-3 Months: Early Activation Stage'
           WHEN months_spent BETWEEN 4 AND 6 THEN '4-6 Months: Primary Adoption Stage'
           WHEN months_spent BETWEEN 7 AND 12 THEN '7-12 Months: Established Users'
           WHEN months_spent BETWEEN 13 AND 24 THEN '13-24 Months: Long-term Customers'
           ELSE '24+ Months: Veterans'
       END AS age_bucket,
       COUNT(customer_id) AS total_customers,
       SUM(total_complaints) AS total_complaints,
       AVG(total_complaints) AS average_complaint_per_customer,
       STDEV(total_complaints) AS std_dev_complaints,
       SUM(resolved_complaints) AS total_resolved_complaints,
       SUM(unresolved_complaints) AS total_unresolved_complaints
   FROM tenures
   GROUP BY 
        CASE
           WHEN months_spent BETWEEN 0 AND 1 THEN '0-1 Month: New Arrivals/ Onboarding Stage'
           WHEN months_spent BETWEEN 2 AND 3 THEN '2-3 Months: Early Activation Stage'
           WHEN months_spent BETWEEN 4 AND 6 THEN '4-6 Months: Primary Adoption Stage'
           WHEN months_spent BETWEEN 7 AND 12 THEN '7-12 Months: Established Users'
           WHEN months_spent BETWEEN 13 AND 24 THEN '13-24 Months: Long-term Customers'
           ELSE '24+ Months: Veterans'
       END
)
SELECT
   age_bucket,
   total_customers,
   total_complaints,
   total_resolved_complaints,
   total_unresolved_complaints,
   CONCAT(ROUND(100.0 * total_resolved_complaints/total_complaints, 2), '%') AS resolution_rate,
   CONCAT(ROUND(100.0 * total_unresolved_complaints/total_complaints, 2), '%') AS unresolved_rate
FROM categories;

-- ========================================================================
-- SECTION 14: TENURE AND COMPLAINT CATEGORY MATRIX
-- ========================================================================
-- Purpose: Cross-tabulation of tenure and complaint frequency

WITH tenures AS (
   SELECT
       customer_id,
       DATEDIFF(MONTH, signup_date, GETDATE()) AS months_spent,
       COUNT(complaint_id) AS total_complaints,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY customer_id, DATEDIFF(MONTH, signup_date, GETDATE())
),
categories AS (
   -- Categorize by both tenure and complaint frequency
   SELECT
       CASE
           WHEN months_spent BETWEEN 0 AND 1 THEN '0-1 Month: New Arrivals/ Onboarding Stage'
           WHEN months_spent BETWEEN 2 AND 3 THEN '2-3 Months: Early Activation Stage'
           WHEN months_spent BETWEEN 4 AND 6 THEN '4-6 Months: Primary Adoption Stage'
           WHEN months_spent BETWEEN 7 AND 12 THEN '7-12 Months: Established Users'
           WHEN months_spent BETWEEN 13 AND 24 THEN '13-24 Months: Long-term Customers'
           ELSE '24+ Months: Veterans'
       END AS age_bucket,
       CASE
           WHEN total_complaints = 1 THEN '1-Time Complainers'
           WHEN total_complaints BETWEEN 2 AND 3 THEN 'Occasional Complainers'
           WHEN total_complaints BETWEEN 4 AND 6 THEN 'Frequent Complainers'
           WHEN total_complaints BETWEEN 7 AND 10 THEN 'Persistent Complainers'
           ELSE 'Chronic Complainers'
       END AS complaint_category,
       SUM(total_complaints) AS customer_complaints,
       COUNT(customer_id) AS total_customers,
       AVG(total_complaints) AS average_complaint_per_customer,
       STDEV(total_complaints) AS std_dev_complaints,
       SUM(resolved_complaints) AS total_resolved_complaints,
       SUM(unresolved_complaints) AS total_unresolved_complaints
   FROM tenures
   GROUP BY 
        CASE
           WHEN months_spent BETWEEN 0 AND 1 THEN '0-1 Month: New Arrivals/ Onboarding Stage'
           WHEN months_spent BETWEEN 2 AND 3 THEN '2-3 Months: Early Activation Stage'
           WHEN months_spent BETWEEN 4 AND 6 THEN '4-6 Months: Primary Adoption Stage'
           WHEN months_spent BETWEEN 7 AND 12 THEN '7-12 Months: Established Users'
           WHEN months_spent BETWEEN 13 AND 24 THEN '13-24 Months: Long-term Customers'
           ELSE '24+ Months: Veterans'
       END,
       CASE
           WHEN total_complaints = 1 THEN '1-Time Complainers'
           WHEN total_complaints BETWEEN 2 AND 3 THEN 'Occasional Complainers'
           WHEN total_complaints BETWEEN 4 AND 6 THEN 'Frequent Complainers'
           WHEN total_complaints BETWEEN 7 AND 10 THEN 'Persistent Complainers'
           ELSE 'Chronic Complainers'
       END
)
SELECT
   age_bucket,
   complaint_category,
   total_customers,
   customer_complaints,
   total_resolved_complaints,
   total_unresolved_complaints,
   CONCAT(ROUND(100.0 * total_unresolved_complaints/customer_complaints, 2), '%') AS unresolved_rate,
   CONCAT(ROUND(100.0 * total_resolved_complaints/customer_complaints, 2), '%') AS resolution_rate
FROM categories;

-- ========================================================================
-- SECTION 15: UNRESOLVED RATE BY COMPLAINT CATEGORY
-- ========================================================================
-- Purpose: Identify which complaint categories have worst resolution rates

WITH customers AS (
   SELECT
       customer_id,
       COUNT(complaint_id) AS total_complaints,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY customer_id
),
stats AS (
   SELECT
       customer_id,
       total_complaints,
       resolved_complaints,
       unresolved_complaints,
       CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate,
       CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS unresolved_rate
   FROM customers
),
categories AS (
   SELECT
       CASE
           WHEN total_complaints >= 11 THEN 'Chronic Complainer'
           WHEN total_complaints BETWEEN 7 AND 10 THEN 'Persistent Complainer'
           WHEN total_complaints BETWEEN 4 AND 6 THEN 'Frequent Complainers'
           WHEN total_complaints BETWEEN 2 AND 3 THEN 'Occasional Complainers'
           ELSE '1-time Complainers'
       END AS complaint_category,
       SUM(total_complaints) AS total_complaints,
       SUM(resolved_complaints) AS resolved_complaints,
       SUM(unresolved_complaints) AS unresolved_complaints,
       CONCAT(ROUND(100.0 * SUM(resolved_complaints)/SUM(total_complaints), 2), '%') AS resolution_rate,
       CONCAT(ROUND(100.0 * SUM(unresolved_complaints)/SUM(total_complaints), 2), '%') AS unresolved_rate        
   FROM stats
   GROUP BY 
       CASE
           WHEN total_complaints >= 11 THEN 'Chronic Complainer'
           WHEN total_complaints BETWEEN 7 AND 10 THEN 'Persistent Complainer'
           WHEN total_complaints BETWEEN 4 AND 6 THEN 'Frequent Complainers'
           WHEN total_complaints BETWEEN 2 AND 3 THEN 'Occasional Complainers'
           ELSE '1-time Complainers'
       END
)
SELECT *
FROM categories;

-- ========================================================================
-- SECTION 16: UNRESOLVED RATE BY SEGMENT
-- ========================================================================
-- Purpose: Compare resolution effectiveness across customer segments

WITH cases AS  (
   SELECT
       segment,
       COUNT(complaint_id) AS total_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY segment
)
SELECT
   segment,
   total_complaints,
   unresolved_complaints,
   CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS unresolved_rate
FROM cases;

-- ========================================================================
-- SECTION 17: UNRESOLVED RATE BY REGION
-- ========================================================================
-- Purpose: Identify regional service quality issues

WITH cases AS  (
   SELECT
       region,
       COUNT(complaint_id) AS total_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY region
)
SELECT
   region,
   total_complaints,
   unresolved_complaints,
   CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS unresolved_rate
FROM cases;

-- ========================================================================
-- SECTION 18: CUSTOMER COMPLAINT CATEGORY DISTRIBUTION
-- ========================================================================
-- Purpose: Understand overall customer base composition

WITH customers AS (
   SELECT
       customer_id,
       COUNT(*) AS customer_complaints,
       COUNT(DISTINCT product_area) AS distinct_product_area_defects
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY customer_id
),
segmentation AS (
   SELECT
       CASE
           WHEN customer_complaints >= 11 THEN 'Chronic Complainers'
           WHEN customer_complaints BETWEEN 7 AND 10 THEN 'Persistent Complainers'
           WHEN customer_complaints BETWEEN 4 AND 6 THEN 'Frequent Complainers'
           WHEN customer_complaints BETWEEN 2 AND 3 THEN 'Occasional Complainers'
           ELSE '1-Time Complainers'
       END AS complaint_category,
       COUNT(customer_id) AS total_customers,
       SUM(customer_complaints) AS customer_complaints,
       AVG(distinct_product_area_defects) AS avg_distinct_product_area_defects
   FROM customers
   GROUP BY
       CASE
           WHEN customer_complaints >= 11 THEN 'Chronic Complainers'
           WHEN customer_complaints BETWEEN 7 AND 10 THEN 'Persistent Complainers'
           WHEN customer_complaints BETWEEN 4 AND 6 THEN 'Frequent Complainers'
           WHEN customer_complaints BETWEEN 2 AND 3 THEN 'Occasional Complainers'
           ELSE '1-Time Complainers'
       END
),
total_customers AS (
   SELECT
       COUNT(DISTINCT customer_id) AS all_customers,
       COUNT(complaint_id) AS all_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
)
SELECT
   complaint_category,
   total_customers,
   customer_complaints,
   avg_distinct_product_area_defects,
   all_customers,
   all_complaints,
   CONCAT(ROUND(100.0 *total_customers/all_customers, 2 ), '%') AS pct_customers,
   CONCAT(ROUND(100.0 * customer_complaints/all_complaints, 2), '%') AS complaint_pct
FROM segmentation s
CROSS JOIN total_customers t
ORDER BY complaint_pct DESC;

-- ========================================================================
-- SECTION 19: CHRONIC COMPLAINERS BY SEGMENT
-- ========================================================================
-- Purpose: Identify which segments have most chronic complainers

WITH segmentations AS (
   SELECT
       customer_id,
       segment,
       COUNT(complaint_id) AS total_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY customer_id, segment
)
SELECT 
   segment,
   COUNT(*) AS total_chronic_complainers
FROM segmentations
WHERE total_complaints >= 11
GROUP BY segment;

-- ========================================================================
-- SECTION 20: COMPLAINT CATEGORY BY SEGMENT (DETAILED)
-- ========================================================================
-- Purpose: Full cross-tabulation of complaint categories and segments

WITH customers AS (
   SELECT
       customer_id,
       segment,
       COUNT(*) AS customer_complaints,
       COUNT(DISTINCT product_area) AS distinct_product_area_defects
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY customer_id, segment
),
segmentation AS (
   SELECT
       CASE
           WHEN customer_complaints >= 11 THEN 'Chronic Complainers'
           WHEN customer_complaints BETWEEN 7 AND 10 THEN 'Persistent Complainers'
           WHEN customer_complaints BETWEEN 4 AND 6 THEN 'Frequent Complainers'
           WHEN customer_complaints BETWEEN 2 AND 3 THEN 'Occasional Complainers'
           ELSE '1-Time Complainers'
       END AS complaint_category,
       segment,
       COUNT(customer_id) AS total_customers,
       SUM(customer_complaints) AS customer_complaints,
       AVG(distinct_product_area_defects) AS avg_distinct_product_area_defects
   FROM customers
   GROUP BY
       CASE
           WHEN customer_complaints >= 11 THEN 'Chronic Complainers'
           WHEN customer_complaints BETWEEN 7 AND 10 THEN 'Persistent Complainers'
           WHEN customer_complaints BETWEEN 4 AND 6 THEN 'Frequent Complainers'
           WHEN customer_complaints BETWEEN 2 AND 3 THEN 'Occasional Complainers'
           ELSE '1-Time Complainers'
       END, 
       segment
),
total_customers AS (
   SELECT
       COUNT(DISTINCT customer_id) AS all_customers,
       COUNT(complaint_id) AS all_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
)
SELECT
   complaint_category,
   segment, 
   total_customers,
   customer_complaints,
   avg_distinct_product_area_defects,
   all_customers,
   all_complaints,
   CONCAT(ROUND(100.0 * total_customers/all_customers, 2), '%') AS pct_customers,
   CONCAT(ROUND(100.0 * customer_complaints/all_complaints, 2), '%') AS complaint_pct
FROM segmentation s
CROSS JOIN total_customers t
ORDER BY complaint_pct DESC;

-- ========================================================================
-- SECTION 21: CHRONIC COMPLAINERS BY REGION
-- ========================================================================
-- Purpose: Geographic distribution of chronic complainers

WITH segmentations AS (
   SELECT
       customer_id,
       region,
       COUNT(complaint_id) AS total_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY customer_id, region
)
SELECT 
   region,
   COUNT(*) AS total_chronic_complainers
FROM segmentations
WHERE total_complaints >= 11
GROUP BY region
ORDER BY total_chronic_complainers DESC;

-- ========================================================================
-- SECTION 22: COMPLAINT CATEGORY BY REGION (DETAILED)
-- ========================================================================
-- Purpose: Full cross-tabulation of complaint categories and regions

WITH customers AS (
   SELECT
       customer_id,
       region,
       COUNT(*) AS customer_complaints,
       COUNT(DISTINCT product_area) AS distinct_product_area_defects
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY customer_id, region
),
segmentation AS (
   SELECT
       CASE
           WHEN customer_complaints >= 11 THEN 'Chronic Complainers'
           WHEN customer_complaints BETWEEN 7 AND 10 THEN 'Persistent Complainers'
           WHEN customer_complaints BETWEEN 4 AND 6 THEN 'Frequent Complainers'
           WHEN customer_complaints BETWEEN 2 AND 3 THEN 'Occasional Complainers'
           ELSE '1-Time Complainers'
       END AS complaint_category,
       region,
       COUNT(customer_id) AS total_customers,
       SUM(customer_complaints) AS customer_complaints,
       AVG(distinct_product_area_defects) AS avg_distinct_product_area_defects
   FROM customers
   GROUP BY
       CASE
           WHEN customer_complaints >= 11 THEN 'Chronic Complainers'
           WHEN customer_complaints BETWEEN 7 AND 10 THEN 'Persistent Complainers'
           WHEN customer_complaints BETWEEN 4 AND 6 THEN 'Frequent Complainers'
           WHEN customer_complaints BETWEEN 2 AND 3 THEN 'Occasional Complainers'
           ELSE '1-Time Complainers'
       END, 
       region
),
total_customers AS (
   SELECT
       COUNT(DISTINCT customer_id) AS all_customers,
       COUNT(complaint_id) AS all_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
)
SELECT
   complaint_category,
   region, 
   total_customers,
   customer_complaints,
   avg_distinct_product_area_defects,
   all_customers,
   all_complaints,
   CONCAT(ROUND(100.0 * total_customers/all_customers, 2), '%') AS pct_customers,
   CONCAT(ROUND(100.0 * customer_complaints/all_complaints, 2), '%') AS complaint_pct
FROM segmentation s
CROSS JOIN total_customers t
ORDER BY complaint_pct DESC;

-- ========================================================================
-- END OF CUSTOMER BEHAVIOUR ANALYSIS
-- ========================================================================
-- Summary: This script provides 22 comprehensive analyses covering:
--   - Ignored complaints identification (Section 1)
--   - Complaint trends over time (Section 2)
--   - Customer segmentation (Sections 3-4)
--   - Pareto analysis (Sections 5, 12)
--   - Repeat complaint patterns (Sections 6-8)
--   - Cross-product analysis (Sections 9-11)
--   - Tenure-based insights (Sections 13-14)
--   - Resolution rate analysis (Sections 15-17)
--   - Customer distribution (Sections 18-22)
-- ======================================================================