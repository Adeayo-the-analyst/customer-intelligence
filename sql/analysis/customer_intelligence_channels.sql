-- ========================================================================
-- CHANNEL & CONTACT BEHAVIOUR ANALYSIS
-- ========================================================================
-- Purpose: Understand how customers communicate and escalate issues
-- Goal: Optimize channel strategy and customer journey
-- Author: Adeayo Adewale
-- Last Modified: 2025
-- ========================================================================

-- ========================================================================
-- SECTION 1: CHANNEL PERFORMANCE METRICS
-- ========================================================================
-- Purpose: Compare resolution times and rates across communication channels
-- Use Case: Identify most/least effective channels

WITH channels AS (
   -- Aggregate metrics by channel
   SELECT
       channel,
       AVG(resolution_time) AS average_res_time,
       STDEV(resolution_time) AS std_dev_res_time,
       COUNT(DISTINCT agent_name) AS total_agents,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time,
       COUNT(complaint_id) AS total_complaints,
       SUM(CASE WHEN agent_name IS NULL OR agent_name = '' THEN 1 ELSE 0 END) AS complaints_not_assigned_to_agents,
       SUM(CASE WHEN agent_name IS NOT NULL AND agent_name <> '' THEN 1 ELSE 0 END) AS complaints_assigned_to_agents,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY channel
),
totals AS (
   -- Calculate percentage metrics
   SELECT
       channel,
       total_agents,
       max_res_time,
       average_res_time,
       std_dev_res_time,
       total_complaints,
       resolved_complaints,
       unresolved_complaints,
       CONCAT(ROUND(100.0 * complaints_not_assigned_to_agents/total_complaints, 2), '%') AS unassigned_complaint_pct,
       CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate
   FROM channels
)
SELECT * FROM totals;

-- ========================================================================
-- SECTION 2: CHANNEL PERFORMANCE BY URGENCY
-- ========================================================================
-- Purpose: Analyze how channels handle different urgency levels
-- Insight: Which channels are best for high-urgency issues?

WITH channels AS (
   -- Aggregate by channel and urgency
   SELECT
       channel,
       urgency,
       AVG(resolution_time) AS average_res_time,
       STDEV(resolution_time) AS std_dev_res_time,
       MAX(resolution_time) AS max_res_time,
       MIN(resolution_time) AS min_res_time,
       VAR(resolution_time) AS var_res_time,
       COUNT(complaint_id) AS total_complaints,
       SUM(CASE WHEN agent_name IS NOT NULL AND agent_name <> '' THEN 1 ELSE 0 END) AS complaints_assigned_to_agents,
       SUM(CASE WHEN agent_name IS NULL OR agent_name = '' THEN 1 ELSE 0 END) AS complaints_not_assigned_to_agents,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY channel, urgency
),
totals AS (
   SELECT
       channel,
       urgency,
       average_res_time,
       std_dev_res_time,
       min_res_time,
       max_res_time,
       var_res_time,
       total_complaints,
       complaints_assigned_to_agents,
       complaints_not_assigned_to_agents,
       resolved_complaints,
       unresolved_complaints,
       CONCAT(ROUND(100.0 * complaints_not_assigned_to_agents/total_complaints, 2), '%') AS unassigned_complaint_pct,
       CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate
   FROM channels
)
SELECT * FROM totals;

-- ========================================================================
-- SECTION 3: CHANNEL PERFORMANCE BY PRODUCT AREA
-- ========================================================================
-- Purpose: Identify which channels work best for specific product issues

WITH channels AS (
   SELECT
       channel,
       product_area,
       AVG(resolution_time) AS average_res_time,
       STDEV(resolution_time) AS std_dev_res_time,
       MAX(resolution_time) AS max_res_time,
       MIN(resolution_time) AS min_res_time,
       VAR(resolution_time) AS var_res_time,
       SUM(CASE WHEN agent_name IS NOT NULL AND agent_name <> '' THEN 1 ELSE 0 END) AS complaints_assigned_to_agents,
       SUM(CASE WHEN agent_name IS NULL OR agent_name = '' THEN 1 ELSE 0 END) AS complaints_not_assigned_to_agents,
       COUNT(complaint_id) AS total_complaints,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY channel, product_area
),
totals AS (
   SELECT
       channel,
       product_area,
       average_res_time,
       std_dev_res_time,
       min_res_time,
       max_res_time,
       var_res_time,
       total_complaints,
       complaints_assigned_to_agents,
       complaints_not_assigned_to_agents,
       resolved_complaints,
       unresolved_complaints,
       CONCAT(ROUND(100.0 * complaints_not_assigned_to_agents/total_complaints, 2), '%') AS complaints_not_assigned_to_agents_pct,
       CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate
   FROM channels
)
SELECT * FROM totals;

-- ========================================================================
-- SECTION 4: CHANNEL RESOLUTION BENCHMARKING
-- ========================================================================
-- Purpose: Identify fastest/slowest resolutions per channel

WITH channels AS (
   -- Calculate channel baselines
   SELECT
       channel,
       AVG(resolution_time) AS avg_res_time,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY channel
)
SELECT
   ci.channel,
   COUNT(ci.complaint_id) AS total_complaints,
   c.avg_res_time,
   c.min_res_time,
   c.max_res_time,
   -- Count performance relative to channel average
   SUM(CASE WHEN ci.resolution_time > c.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
   SUM(CASE WHEN ci.resolution_time <= c.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
   SUM(CASE WHEN ci.resolution_time = c.min_res_time THEN 1 ELSE 0 END) AS fastest_resolutions,
   SUM(CASE WHEN ci.resolution_time = c.max_res_time THEN 1 ELSE 0 END) AS slowest_resolutions
FROM customer_intelligence ci
INNER JOIN channels c
   ON ci.channel  = c.channel
WHERE ci.complaint_date <= GETDATE()
   AND ci.signup_date <= GETDATE()
   AND ci.agent_name IS NOT NULL
   AND ci.agent_name <> ''
GROUP BY ci.channel, c.avg_res_time, c.min_res_time, c.max_res_time;

-- ========================================================================
-- SECTION 5: HIGH URGENCY HANDLING BY CHANNEL
-- ========================================================================
-- Purpose: Evaluate how well each channel handles high-urgency complaints

WITH observations AS (
   SELECT
       channel,
       COUNT(complaint_id) AS total_complaints,
       SUM(CASE WHEN urgency = 'High' THEN 1 ELSE 0 END) AS high_urgency_complaints,
       SUM(CASE WHEN urgency = 'High' AND resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_high_urgency_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY channel
)
SELECT
   channel,
   total_complaints,
   high_urgency_complaints,
   resolved_high_urgency_complaints,
   CONCAT(ROUND(100.0 * high_urgency_complaints/total_complaints,2),'%') AS pct_high_urgency_complaints,
   CONCAT(ROUND(100.0 * resolved_high_urgency_complaints/total_complaints, 2), '%') AS pct_high_urgency_resolutions 
FROM observations;

-- ========================================================================
-- SECTION 6: CUSTOMER JOURNEY ANALYSIS - FULL
-- ========================================================================
-- Purpose: Map customer lifecycle and channel preferences
-- Segments: Tenure buckets + complaint frequency categories

WITH tenures AS (
   -- Calculate customer tenure and aggregate complaints
   SELECT
       customer_id,
       channel,
       DATEDIFF(MONTH, signup_date, GETDATE()) AS months_spent,
       COUNT(complaint_id) AS total_complaints,
       SUM(CASE WHEN agent_name IS NULL OR agent_name = '' THEN 1 ELSE 0 END) AS complaints_not_assigned_to_agents,
       SUM(CASE WHEN agent_name IS NOT NULL AND agent_name <> '' THEN 1 ELSE 0 END) AS complaints_assigned_to_agents,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY customer_id, channel, DATEDIFF(MONTH, signup_date, GETDATE())
),
categories AS (
   -- Categorize by tenure and complaint frequency
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
       channel,
       SUM(complaints_assigned_to_agents) AS complaints_assigned_to_agents,
       SUM(complaints_not_assigned_to_agents) AS complaints_not_assigned_to_agents,
       SUM(total_complaints) AS customer_complaints,
       COUNT(customer_id) AS total_customers,
       AVG(total_complaints) AS average_complaint_per_customer,
       STDEV(total_complaints) AS std_dev_complaints,
       SUM(resolved_complaints) AS total_resolved_complaints,
       SUM(unresolved_complaints) AS total_unresolved_complaints
   FROM tenures
   GROUP BY 
       channel,
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
   channel,
   age_bucket,
   complaint_category,
   total_customers,
   customer_complaints,
   complaints_assigned_to_agents,
   complaints_not_assigned_to_agents,
   total_resolved_complaints,
   total_unresolved_complaints,
   CONCAT(ROUND(100.0 * complaints_not_assigned_to_agents/customer_complaints, 2), '%') AS complaints_not_assigned_to_agents_pct,
   CONCAT(ROUND(100.0 * total_unresolved_complaints/customer_complaints, 2), '%') AS unresolved_rate,
   CONCAT(ROUND(100.0 * total_resolved_complaints/customer_complaints, 2), '%') AS resolution_rate
FROM categories;

-- ========================================================================
-- SECTION 7: CUSTOMER JOURNEY ANALYSIS - BY TENURE ONLY
-- ========================================================================
-- Purpose: Simplified view of channel preference by customer tenure

WITH tenures AS (
   SELECT
       customer_id,
       channel,
       DATEDIFF(MONTH, signup_date, GETDATE()) AS months_spent,
       COUNT(complaint_id) AS total_complaints,
       SUM(CASE WHEN agent_name IS NULL OR agent_name = '' THEN 1 ELSE 0 END) AS complaints_not_assigned_to_agents,
       SUM(CASE WHEN agent_name IS NOT NULL AND agent_name <> '' THEN 1 ELSE 0 END) AS complaints_assigned_to_agents,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   GROUP BY customer_id, channel, DATEDIFF(MONTH, signup_date, GETDATE())
),
categories AS (
   -- Group by tenure bucket only
   SELECT
       CASE
           WHEN months_spent BETWEEN 0 AND 1 THEN '0-1 Month: New Arrivals/ Onboarding Stage'
           WHEN months_spent BETWEEN 2 AND 3 THEN '2-3 Months: Early Activation Stage'
           WHEN months_spent BETWEEN 4 AND 6 THEN '4-6 Months: Primary Adoption Stage'
           WHEN months_spent BETWEEN 7 AND 12 THEN '7-12 Months: Established Users'
           WHEN months_spent BETWEEN 13 AND 24 THEN '13-24 Months: Long-term Customers'
           ELSE '24+ Months: Veterans'
       END AS age_bucket,
       channel,
       COUNT(customer_id) AS total_customers,
       SUM(total_complaints) AS total_complaints,
       SUM(complaints_assigned_to_agents) AS complaints_assigned_to_agents,
       SUM(complaints_not_assigned_to_agents) AS complaints_not_assigned_to_agents,
       AVG(total_complaints) AS average_complaint_per_customer,
       STDEV(total_complaints) AS std_dev_complaints,
       SUM(resolved_complaints) AS total_resolved_complaints,
       SUM(unresolved_complaints) AS total_unresolved_complaints
   FROM tenures
   GROUP BY 
       channel,
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
   channel,
   age_bucket,
   total_customers,
   total_complaints,
   total_resolved_complaints,
   total_unresolved_complaints,
   complaints_assigned_to_agents,
   complaints_not_assigned_to_agents,
   CONCAT(ROUND(100.0 * complaints_not_assigned_to_agents/total_complaints, 2), '%') AS complaints_not_assigned_to_agents_pct,
   CONCAT(ROUND(100.0 * total_resolved_complaints/total_complaints, 2), '%') AS resolution_rate,
   CONCAT(ROUND(100.0 * total_unresolved_complaints/total_complaints, 2), '%') AS unresolved_rate
FROM categories;

-- ========================================================================
-- SECTION 8: SEGMENT CHANNEL PREFERENCE
-- ========================================================================
-- Purpose: Identify which customer segments prefer which channels
-- Insight: Premium vs Standard customer communication patterns

SELECT
   segment,
   channel,
   COUNT(complaint_id) AS total_complaints,
   SUM(CASE WHEN agent_name IS NULL OR agent_name = '' THEN 1 ELSE 0 END) AS complaints_not_assigned_to_agents,
   SUM(CASE WHEN agent_name IS NOT NULL AND  agent_name <> '' THEN 1 ELSE 0 END) AS complaints_assigned_to_agents
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
   AND signup_date <= GETDATE()
GROUP BY segment, channel;

-- ========================================================================
-- END OF CHANNEL & CONTACT BEHAVIOUR ANALYSIS
-- ========================================================================
-- Summary: This analysis reveals:
-- 1. Channel effectiveness and efficiency
-- 2. Customer journey and lifecycle patterns
-- 3. Segment-specific channel preferences
-- 4. Urgency handling capabilities by channel
-- ========================================================================