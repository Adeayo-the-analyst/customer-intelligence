-- ========================================================================
-- STRATEGIC & PREDICTIVE INSIGHTS ANALYSIS
-- ========================================================================
-- Purpose: Transform analytics into actionable decisions
-- Goal: Identify top issues and predict impact of interventions
-- Author: Adeayo Adewale
-- Last Modified: 2025
-- ========================================================================

-- ========================================================================
-- STRATEGIC RECOMMENDATIONS SUMMARY
-- ========================================================================
-- Based on analysis, top 3 interventions to reduce complaints:
-- 1. Fix top 3 product areas: Billings, Integrations, and Performance
-- 2. Increase resolution rate from 64% to 80%
-- 3. Reallocate staffing/escalation: more agents on high-volume areas, 
--    faster escalation for Premium users
-- ========================================================================

-- ========================================================================
-- SECTION 1: CURRENT STATE - TOP PROBLEM AREAS (DETAILED)
-- ========================================================================
-- Purpose: Establish baseline for Billing, Integrations, Performance
-- Shows complaint types, volumes, and resolution rates

WITH info AS (
   -- Aggregate by product area and complaint text
   SELECT
       product_area,
       complaint_text,
       COUNT(complaint_id) AS total_complaints,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   AND product_area IN ('Billing', 'Performance', 'Integrations')
   GROUP BY product_area, complaint_text
)
SELECT
   product_area,
   complaint_text,
   total_complaints,
   resolved_complaints,
   unresolved_complaints,
   CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate,
   CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS unresolved_rate
FROM info
ORDER BY total_complaints DESC;

-- ========================================================================
-- SECTION 2: CURRENT STATE - AGGREGATED METRICS
-- ========================================================================
-- Purpose: High-level current state metrics for top 3 product areas

WITH info AS (
   SELECT
       product_area,
       COUNT(complaint_id) AS total_complaints,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   AND product_area IN ('Billing', 'Integrations', 'Performance')
   GROUP BY product_area
),
calc AS (
   SELECT
       product_area,
       total_complaints,
       resolved_complaints,
       unresolved_complaints,
       ROUND(100.0 * resolved_complaints/total_complaints, 2) AS resolution_rate,
       ROUND(100.0 * unresolved_complaints/total_complaints, 2) AS unresolved_rate
   FROM info
)
SELECT *
FROM calc;

-- ========================================================================
-- SECTION 3: INTERVENTION SIMULATION - AFTER STATE
-- ========================================================================
-- Purpose: Simulate impact if complaints drop 40% and resolutions reach 80%
-- Scenario: What if we fix core issues?

WITH info AS (
   -- Current state
   SELECT
       product_area,
       COUNT(complaint_id) AS total_complaints,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   AND product_area IN ('Billing', 'Integrations', 'Performance')
   GROUP BY product_area
),
calc AS (
   SELECT
       product_area,
       total_complaints,
       resolved_complaints,
       unresolved_complaints,
       ROUND(100.0 * resolved_complaints/total_complaints, 2) AS resolution_rate,
       ROUND(100.0 * unresolved_complaints/total_complaints, 2) AS unresolved_rate
   FROM info
),
intervention AS (
   -- Simulate 40% complaint reduction
   SELECT
       product_area,
       ROUND(total_complaints * (1 - 0.4), 0) AS new_total_complaints,
       resolved_complaints,
       unresolved_complaints,
       resolution_rate,
       unresolved_rate
   FROM calc
),
resolutions AS (
   -- Apply 80% resolution rate to new complaint volume
   SELECT
       product_area,
       new_total_complaints,
       ROUND(new_total_complaints * 0.8, 0) AS new_resolved_complaints,
       ROUND(new_total_complaints * 0.2, 0) AS new_unresolved_complaints    
   FROM intervention
)
SELECT
   product_area,
   new_total_complaints,
   new_resolved_complaints,
   new_unresolved_complaints,
   CONCAT(ROUND(100.0 * new_unresolved_complaints/new_total_complaints,2),'%') AS new_unresolved_rate,
   CONCAT(ROUND(100.0 * new_resolved_complaints/new_total_complaints, 2), '%') AS new_resolution_rate
FROM resolutions;

-- ========================================================================
-- SECTION 4: BEFORE/AFTER COMPARISON
-- ========================================================================
-- Purpose: Side-by-side comparison of current vs projected state

WITH info AS (
   SELECT
       product_area,
       COUNT(DISTINCT agent_name) AS present_agents,
       COUNT(complaint_id) AS total_complaints,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
   AND product_area IN ('Billing', 'Integrations', 'Performance')
   GROUP BY product_area
),
calc AS (
   SELECT
       product_area,
       present_agents,
       total_complaints,
       resolved_complaints,
       unresolved_complaints,
       ROUND(100.0 * resolved_complaints/total_complaints, 2) AS resolution_rate,
       ROUND(100.0 * unresolved_complaints/total_complaints, 2) AS unresolved_rate
   FROM info
),
intervention AS (
   -- Store current state and calculate new totals
   SELECT
       product_area,
       ROUND(total_complaints * (1 - 0.4), 0) AS new_total_complaints,
       total_complaints AS current_total_complaints,
       resolved_complaints AS current_resolved_complaints,
       unresolved_complaints AS current_unresolved_complaints,
       resolution_rate AS current_resolution_rate,
       unresolved_rate AS current_unresolved_rate
   FROM calc
),
resolutions AS (
   -- Calculate projected resolutions
   SELECT
       product_area,
       current_total_complaints,
       current_resolved_complaints,
       current_unresolved_complaints,
       current_resolution_rate,
       current_unresolved_rate,
       new_total_complaints,
       ROUND(new_total_complaints * 0.8, 0) AS new_resolved_complaints,
       ROUND(new_total_complaints * 0.2, 0) AS new_unresolved_complaints    
   FROM intervention
)
SELECT
   product_area,
   current_total_complaints,
   current_resolved_complaints,
   current_unresolved_complaints,
   current_resolution_rate,
   current_unresolved_rate,
   new_total_complaints,
   new_resolved_complaints,
   new_unresolved_complaints,
   CONCAT(ROUND(100.0 * new_unresolved_complaints/new_total_complaints,2),'%') AS new_unresolved_rate,
   CONCAT(ROUND(100.0 * new_resolved_complaints/new_total_complaints, 2), '%') AS new_resolution_rate
FROM resolutions;

-- ========================================================================
-- SECTION 5: AGENT STAFFING ANALYSIS
-- ========================================================================
-- Purpose: Analyze current agent distribution and efficiency
-- Metrics: Cases per agent, resolution efficiency, workload balance

WITH res_time AS (
   -- Calculate staffing metrics by skillset and product area
   SELECT
       skillset,
       product_area,
       COUNT(DISTINCT agent_name) AS total_agents,
       COUNT(complaint_id) AS total_complaints,
       SUM(resolution_time) AS total_resolution_time,
       AVG(resolution_time) AS avg_res_time,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND agent_name IS NOT NULL
       AND agent_name <> ''
   GROUP BY skillset, product_area
),
totals AS (
   -- Calculate above/below average metrics
   SELECT
       c.skillset,
       c.product_area,
       r.total_agents,
       r.total_resolution_time,
       r.total_complaints,
       r.avg_res_time,
       r.unresolved_complaints,
       r.resolved_complaints,
       SUM(CASE WHEN c.resolution_time > r.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN c.resolution_time <= r.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions
   FROM customer_intelligence c
   INNER JOIN res_time r
       ON r.skillset = c.skillset
   WHERE c.complaint_date <= GETDATE()
       AND c.agent_name <> ''
       AND c.signup_date <= GETDATE()
       AND c.agent_name IS NOT NULL
   GROUP BY c.skillset, c.product_area, r.total_agents, r.total_resolution_time,
       r.avg_res_time, r.total_complaints, r.unresolved_complaints, r.resolved_complaints
)
SELECT
   skillset,
   product_area,
   total_agents,
   total_complaints,
   avg_res_time,
   total_resolution_time,
   unresolved_complaints,
   resolved_complaints,
   above_average_resolutions,
   within_average_resolutions,
   -- Calculate efficiency metrics
   ROUND(1.0 * total_complaints/total_agents,1) AS avg_complaints_per_agent_product_area,
   ROUND(1.0 * total_resolution_time/resolved_complaints, 1) AS avg_resolution_time_per_area,
   ROUND(1.0 * resolved_complaints/total_agents, 2) AS avg_resolved_cases_per_agent,
   ROUND(1.0 * unresolved_complaints/total_agents, 2) AS avg_unresolved_cases_per_agent,
   CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_efficiency_rate
FROM totals;

-- Query: Total cases by product area
SELECT
   product_area,
   COUNT(*) AS total_cases
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
GROUP BY product_area;

-- ========================================================================
-- SECTION 6: BILLING PROBLEM TYPE ANALYSIS
-- ========================================================================
-- Purpose: Deep dive into Billing complaints
-- Identifies most common problems and difficulty levels

WITH billings AS (
   -- Aggregate billing complaints by type
   SELECT
       product_area,
       complaint_text AS billing_problem_type,
       COUNT(DISTINCT agent_name) AS total_agents_involved,
       COUNT(complaint_id) AS total_complaints,
       AVG(resolution_time) AS avg_res_time,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time,
       COUNT(customer_id) AS total_customers,
       COUNT(DISTINCT customer_id) AS unique_customers,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND complaint_text IS NOT NULL
       AND agent_name IS NOT NULL
       AND agent_name <> ''
       AND product_area = 'Billing'
   GROUP BY product_area, complaint_text
),
complaints AS (
   -- Get total billing complaints for percentage calculations
   SELECT
       COUNT(complaint_id)  AS all_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND signup_date IS NOT NULL
       AND product_area = 'Billing'
)
SELECT
   billing_problem_type,
   total_agents_involved,
   total_customers,
   unique_customers,
   total_complaints,
   min_res_time,
   max_res_time,
   avg_res_time,
   all_complaints,
   CONCAT(ROUND(100.0 * total_complaints/all_complaints, 2), '%') AS complaint_pct,
   resolved_complaints,
   unresolved_complaints,
   CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate,
   CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS unresolved_rate
FROM billings
CROSS JOIN complaints;

-- ========================================================================
-- SECTION 7: PERFORMANCE PROBLEM TYPE ANALYSIS
-- ========================================================================
-- Purpose: Deep dive into Performance complaints

WITH performances AS (
   SELECT
       complaint_text AS performance_problem_type,
       COUNT(DISTINCT agent_name) AS total_agents_involved,
       COUNT(complaint_id) AS total_complaints,
       COUNT(customer_id) AS total_customers,
       COUNT(DISTINCT customer_id) AS unique_customers,
       AVG(resolution_time) AS avg_res_time,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND complaint_text IS NOT NULL
       AND agent_name IS NOT NULL
       AND agent_name <> ''
       AND product_area = 'Performance'
   GROUP BY complaint_text
),
complaints AS (
   SELECT
       COUNT(complaint_id)  AS all_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND signup_date IS NOT NULL
       AND product_area = 'Performance'
)
SELECT
   performance_problem_type,
   total_agents_involved,
   total_customers,
   unique_customers,
   total_complaints,
   min_res_time,
   max_res_time,
   avg_res_time,
   all_complaints,
   CONCAT(ROUND(100.0 * total_complaints/all_complaints, 2), '%') AS complaint_pct,
   resolved_complaints,
   unresolved_complaints,
   CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate,
   CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS unresolved_rate
FROM performances
CROSS JOIN complaints;

-- ========================================================================
-- SECTION 8: INTEGRATIONS PROBLEM TYPE ANALYSIS
-- ========================================================================
-- Purpose: Deep dive into Integrations complaints

WITH integrations AS (
   SELECT
       complaint_text AS integration_problem_type,
       COUNT(DISTINCT agent_name) AS total_agents_involved,
       COUNT(complaint_id) AS total_complaints,
       COUNT(customer_id) AS total_customers,
       AVG(resolution_time) AS avg_res_time,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time,
       COUNT(DISTINCT customer_id) AS unique_customers,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND complaint_text IS NOT NULL
       AND agent_name IS NOT NULL
       AND agent_name <> ''
       AND product_area = 'Integrations'
   GROUP BY complaint_text
),
complaints AS (
   SELECT
       COUNT(complaint_id)  AS all_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND signup_date IS NOT NULL
       AND product_area = 'Integrations'
)
SELECT
   integration_problem_type,
   total_agents_involved,
   total_customers,
   unique_customers,
   total_complaints,
   min_res_time,
   max_res_time,
   avg_res_time,
   all_complaints,
   CONCAT(ROUND(100.0 * total_complaints/all_complaints, 2), '%') AS complaint_pct,
   resolved_complaints,
   unresolved_complaints,
   CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate,
   CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS unresolved_rate
FROM integrations
CROSS JOIN complaints;

-- ========================================================================
-- SECTION 9: BILLING DIFFICULTY CLASSIFICATION
-- ========================================================================
-- Purpose: Classify billing problems by difficulty (Easy/Moderate/Hard)
-- Based on resolution rates: >80%=Easy, 60-80%=Moderate, <60%=Hard

WITH agents AS (
   -- Agent-level aggregation
   SELECT
       agent_name,
       complaint_text AS billing_problem_type,
       COUNT(complaint_id) AS total_complaints,
       AVG(resolution_time) AS avg_res_time,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time,
       COUNT(customer_id) AS total_customers,
       COUNT(DISTINCT customer_id) AS unique_customers,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE  0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND agent_name <> ''
       AND agent_name IS NOT NULL
       AND signup_date <= GETDATE()
       AND complaint_text IS NOT NULL
       AND product_area = 'Billing'
   GROUP BY agent_name, complaint_text
),
totals AS (
   SELECT
       agent_name,
       billing_problem_type,
       total_complaints,
       min_res_time,
       max_res_time,
       avg_res_time,
       total_customers,
       unique_customers,
       resolved_complaints,
       unresolved_complaints,
       ROUND(1.0 * resolved_complaints/total_complaints, 2) AS resolution_rate
   FROM agents
),
problems AS (
   -- Aggregate across all agents
   SELECT
       billing_problem_type,
       COUNT(DISTINCT agent_name) AS total_agents,
       SUM(total_complaints) AS total_complaints,
       SUM(unique_customers) AS unique_customers,
       MIN(min_res_time) AS min_res_time,
       MAX(max_res_time) AS max_res_time,
       -- Weighted average calculation
       SUM(CASE WHEN avg_res_time IS NOT NULL THEN avg_res_time * total_complaints ELSE 0 END)/
           SUM(CASE WHEN avg_res_time IS NOT NULL THEN total_complaints ELSE 0 END) AS avg_res_time,
       SUM(resolved_complaints) AS resolved_complaints,
       SUM(unresolved_complaints) AS unresolved_complaints,
       ROUND(1.0 *SUM(resolved_complaints)/ SUM(total_complaints), 2) AS resolution_rate
   FROM totals
   GROUP BY billing_problem_type
)
SELECT
   billing_problem_type,
   -- Difficulty classification based on resolution rate
   CASE
       WHEN resolution_rate > 0.8 THEN 'Easy'
       WHEN resolution_rate BETWEEN 0.6 AND 0.8 THEN 'Moderate'
       ELSE 'Hard'
   END AS difficulty,
   total_agents,
   total_complaints,
   unique_customers,
   min_res_time,
   max_res_time,
   avg_res_time
FROM problems;

-- ========================================================================
-- SECTION 10: PERFORMANCE DIFFICULTY CLASSIFICATION
-- ========================================================================
-- Purpose: Classify performance problems by difficulty

WITH agents AS (
   SELECT
       agent_name,
       complaint_text AS performance_problem_type,
       COUNT(complaint_id) AS total_complaints,
       AVG(resolution_time) AS avg_res_time,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time,
       COUNT(customer_id) AS total_customers,
       COUNT(DISTINCT customer_id) AS unique_customers,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE  0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND agent_name <> ''
       AND agent_name IS NOT NULL
       AND signup_date <= GETDATE()
       AND complaint_text IS NOT NULL
       AND product_area = 'Performance'
   GROUP BY agent_name, complaint_text
),
totals AS (
   SELECT
       agent_name,
       performance_problem_type,
       total_complaints,
       min_res_time,
       max_res_time,
       avg_res_time,
       total_customers,
       unique_customers,
       resolved_complaints,
       unresolved_complaints,
       ROUND(1.0 * resolved_complaints/total_complaints, 2) AS resolution_rate
   FROM agents
),
problems AS (
   SELECT
       performance_problem_type,
       COUNT(DISTINCT agent_name) AS total_agents,
       SUM(total_complaints) AS total_complaints,
       SUM(unique_customers) AS unique_customers,
       MIN(min_res_time) AS min_res_time,
       MAX(max_res_time) AS max_res_time,
       SUM(CASE WHEN avg_res_time IS NOT NULL THEN avg_res_time * total_complaints ELSE 0 END)/
           SUM(CASE WHEN avg_res_time IS NOT NULL THEN total_complaints ELSE 0 END) AS avg_res_time,
       SUM(resolved_complaints) AS resolved_complaints,
       SUM(unresolved_complaints) AS unresolved_complaints,
       ROUND(1.0 *SUM(resolved_complaints)/ SUM(total_complaints), 2) AS resolution_rate
   FROM totals
   GROUP BY performance_problem_type
)
SELECT
   performance_problem_type,
   CASE
       WHEN resolution_rate > 0.8 THEN 'Easy'
       WHEN resolution_rate BETWEEN 0.6 AND 0.8 THEN 'Moderate'
       ELSE 'Hard'
   END AS difficulty,
   total_agents,
   total_complaints,
   unique_customers,
   min_res_time,
   max_res_time,
   avg_res_time
FROM problems;

-- ========================================================================
-- SECTION 11: INTEGRATIONS DIFFICULTY CLASSIFICATION
-- ========================================================================
-- Purpose: Classify integration problems by difficulty

WITH agents AS (
   SELECT
       agent_name,
       complaint_text AS integrations_problem_type,
       COUNT(complaint_id) AS total_complaints,
       AVG(resolution_time) AS avg_res_time,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time,
       COUNT(customer_id) AS total_customers,
       COUNT(DISTINCT customer_id) AS unique_customers,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE  0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND agent_name <> ''
       AND agent_name IS NOT NULL
       AND signup_date <= GETDATE()
       AND complaint_text IS NOT NULL
       AND product_area = 'Integrations'
   GROUP BY agent_name, complaint_text
),
totals AS (
   SELECT
       agent_name,
       integrations_problem_type,
       total_complaints,
       min_res_time,
       max_res_time,
       avg_res_time,
       total_customers,
       unique_customers,
       resolved_complaints,
       unresolved_complaints,
       ROUND(1.0 * resolved_complaints/total_complaints, 2) AS resolution_rate
   FROM agents
),
problems AS (
   SELECT
       integrations_problem_type,
       COUNT(DISTINCT agent_name) AS total_agents,
       SUM(total_complaints) AS total_complaints,
       SUM(unique_customers) AS unique_customers,
       MIN(min_res_time) AS min_res_time,
       MAX(max_res_time) AS max_res_time,
       SUM(CASE WHEN avg_res_time IS NOT NULL THEN avg_res_time * total_complaints ELSE 0 END)/
           SUM(CASE WHEN avg_res_time IS NOT NULL THEN total_complaints ELSE 0 END) AS avg_res_time,
       SUM(resolved_complaints) AS resolved_complaints,
       SUM(unresolved_complaints) AS unresolved_complaints,
       ROUND(1.0 *SUM(resolved_complaints)/ SUM(total_complaints), 2) AS resolution_rate
   FROM totals
   GROUP BY integrations_problem_type
)
SELECT
   integrations_problem_type,
   CASE
       WHEN resolution_rate > 0.8 THEN 'Easy'
       WHEN resolution_rate BETWEEN 0.6 AND 0.8 THEN 'Moderate'
       ELSE 'Hard'
   END AS difficulty,
   total_agents,
   total_complaints,
   unique_customers,
   min_res_time,
   max_res_time,
   avg_res_time
FROM problems;

-- ========================================================================
-- SECTION 12: BILLING RESOLUTION PERFORMANCE BENCHMARKING
-- ========================================================================
-- Purpose: Identify fastest/slowest/average resolutions for billing issues

WITH resolutions AS (
   SELECT
       complaint_text AS billing_problem_type,
       AVG(resolution_time) AS avg_res_time,
       MIN(resolution_time) AS min_res_time,
       MAX(resolutioN_time) AS max_res_time
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND agent_name <> ''
       AND agent_name IS NOT NULL
       AND signup_date <= GETDATE()
       AND product_area = 'Billing'
       AND resolution_status = 'Closed'
       AND complaint_text IS NOT NULL
   GROUP BY complaint_text
),
problems AS (
   SELECT
       ci.complaint_text AS billning_problem_type,
       COUNT(ci.complaint_id) AS total_complaints,
       COUNT(ci.customer_id) AS total_customers,
       COUNT(DISTINCT ci.customer_id) AS unique_customers,
       COUNT(ci.customer_id) - COUNT(DISTINCT ci.customer_id) AS repeat_customers,
       r.avg_res_time,
       r.max_res_time,
       r.min_res_time,
       SUM(CASE WHEN ci.resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolutions,
       SUM(CASE WHEN ci.resolution_time > r.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time <= r.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
       SUM(CASE WHEN ci.resolution_time = r.max_res_time THEN 1 ELSE 0 END) AS slowest_resolutions,
       SUM(CASE WHEN ci.resolution_time = r.min_res_time THEN 1 ELSE 0 END) AS fastest_resolutions
   FROM customer_intelligence ci
   INNER JOIN resolutions r
       ON ci.complaint_text = r.billing_problem_type
   WHERE ci.product_area = 'Billing'
       AND ci.complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND ci.complaint_text IS NOT NULL
       AND ci.agent_name IS NOT NULL
       AND ci.agent_name <> ''
   GROUP BY ci.complaint_text, r.avg_res_time, r.min_res_time, r.max_res_time
)
SELECT * 
FROM problems;
-- SECTION 13: PERFORMANCE RESOLUTION PERFORMANCE BENCHMARKING
-- ========================================================================
-- Purpose: Identify fastest/slowest/average resolutions for performance issues

WITH resolutions AS (
   SELECT
       complaint_text AS performance_problem_type,
       AVG(resolution_time) AS avg_res_time,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND agent_name <> ''
       AND agent_name IS NOT NULL
       AND signup_date <= GETDATE()
       AND product_area = 'Performance'
       AND resolution_status = 'Closed'
       AND complaint_text IS NOT NULL
   GROUP BY complaint_text
),
problems AS (
   SELECT
       ci.complaint_text AS performance_problem_type,
       COUNT(ci.complaint_id) AS total_complaints,
       COUNT(ci.customer_id) AS total_customers,
       COUNT(DISTINCT ci.customer_id) AS unique_customers,
       COUNT(ci.customer_id) - COUNT(DISTINCT ci.customer_id) AS repeat_customers,
       r.avg_res_time,
       r.min_res_time,
       r.max_res_time,
       SUM(CASE WHEN ci.resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolutions,
       SUM(CASE WHEN ci.resolution_time > r.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time <= r.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
       SUM(CASE WHEN ci.resolution_time = r.max_res_time THEN 1 ELSE 0 END) AS slowest_resolutions,
       SUM(CASE WHEN ci.resolution_time = r.min_res_time THEN 1 ELSE 0 END) AS fastest_resolutions
   FROM customer_intelligence ci
   INNER JOIN resolutions r
       ON ci.complaint_text = r.performance_problem_type
   WHERE ci.product_area = 'Performance'
       AND ci.complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND ci.complaint_text IS NOT NULL
       AND ci.agent_name IS NOT NULL
       AND ci.agent_name <> ''
   GROUP BY ci.complaint_text, r.avg_res_time, r.min_res_time, r.max_res_time
)
SELECT * 
FROM problems;

-- ========================================================================
-- SECTION 14: INTEGRATIONS RESOLUTION PERFORMANCE BENCHMARKING
-- ========================================================================
-- Purpose: Identify fastest/slowest/average resolutions for integration issues

WITH resolutions AS (
   SELECT
       complaint_text AS integration_problem_type,
       AVG(resolution_time) AS avg_res_time,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND agent_name <> ''
       AND agent_name IS NOT NULL
       AND signup_date <= GETDATE()
       AND product_area = 'Integrations'
       AND resolution_status = 'Closed'
       AND complaint_text IS NOT NULL
   GROUP BY complaint_text
),
problems AS (
   SELECT
       ci.complaint_text AS integration_problem_type,
       COUNT(ci.complaint_id) AS total_complaints,
       COUNT(ci.customer_id) AS total_customers,
       COUNT(DISTINCT ci.customer_id) AS unique_customers,
       COUNT(ci.customer_id) - COUNT(DISTINCT ci.customer_id) AS repeat_customers,
       r.avg_res_time,
       r.min_res_time,
       r.max_res_time,
       SUM(CASE WHEN ci.resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolutions,
       SUM(CASE WHEN ci.resolution_time > r.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time <= r.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
       SUM(CASE WHEN ci.resolution_time = r.max_res_time THEN 1 ELSE 0 END) AS slowest_resolutions,
       SUM(CASE WHEN ci.resolution_time = r.min_res_time THEN 1 ELSE 0 END) AS fastest_resolutions
   FROM customer_intelligence ci
   LEFT JOIN resolutions r
       ON ci.complaint_text = r.integration_problem_type
   WHERE ci.product_area = 'Integrations'
       AND ci.complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND ci.complaint_text IS NOT NULL
       AND ci.agent_name IS NOT NULL
       AND ci.agent_name <> ''
   GROUP BY ci.complaint_text, r.avg_res_time, r.min_res_time, r.max_res_time
)
SELECT * 
FROM problems;

-- ========================================================================
-- SECTION 15: RESOLUTION METHOD EFFECTIVENESS - BILLING
-- ========================================================================
-- Purpose: Evaluate which resolution methods (notes) work best for billing
-- Question: Are agent methods effective?

WITH notes_stats AS (
   -- Calculate baseline metrics for each resolution method
   SELECT
       notes,
       AVG(resolution_time) AS avg_res_time,
       MAX(resolution_time) AS max_res_time,
       MIN(resolution_time) AS min_res_time
   FROM customer_intelligence
   WHERE signup_date <= GETDATE()
       AND complaint_date <= GETDATE()
       AND product_area = 'Billing'
       AND agent_name IS NOT NULL
       AND notes IS NOT NULL
       AND agent_name <> ''
   GROUP BY notes
),
calc AS (
   -- Aggregate by resolution method
   SELECT
       ci.notes,
       n.avg_res_time,
       n.max_res_time,
       n.min_res_time,
       COUNT(ci.complaint_id) AS total_complaints,
       COUNT(ci.customer_id) AS total_customers,
       COUNT(DISTINCT ci.customer_id) AS unique_customers,
       COUNT(ci.customer_id) - COUNT(DISTINCT ci.customer_id) AS repeat_customers,
       COUNT(DISTINCT agent_name) AS total_agents,
       SUM(CASE WHEN ci.resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN ci.resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints,
       SUM(CASE WHEN ci.resolution_time > n.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time <= n.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
       SUM(CASE WHEN ci.resolution_time = n.min_res_time THEN 1 ELSE 0 END) AS fastest_resolutions,
       SUM(CASE WHEN ci.resolution_time = n.max_res_time THEN 1 ELSE 0 END) AS slowest_resolutions
   FROM customer_intelligence ci
   LEFT JOIN notes_stats n
       ON ci.notes = n.notes
   WHERE ci.signup_date <= GETDATE()
       AND ci.complaint_date <= GETDATE()
       AND ci.product_area = 'Billing'
       AND ci.notes IS NOT NULL
       AND ci.agent_name IS NOT NULL
       AND ci.agent_name <> ''
   GROUP BY ci.notes, n.avg_res_time, n.max_res_time, n.min_res_time
)
SELECT
   notes,
   avg_res_time,
   min_res_time,
   max_res_time,
   total_agents,
   total_complaints,
   total_customers,
   unique_customers,
   repeat_customers,
   resolved_complaints, 
   unresolved_complaints,
   within_average_resolutions,
   above_average_resolutions,
   fastest_resolutions,
   slowest_resolutions,
   CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate
FROM calc
ORDER BY resolution_rate DESC;

-- ========================================================================
-- SECTION 16: RESOLUTION METHOD EFFECTIVENESS - PERFORMANCE
-- ========================================================================
-- Purpose: Evaluate which resolution methods work best for performance issues

WITH notes_stats AS (
   SELECT
       notes,
       AVG(resolution_time) AS avg_res_time,
       MAX(resolution_time) AS max_res_time,
       MIN(resolution_time) AS min_res_time
   FROM customer_intelligence
   WHERE signup_date <= GETDATE()
       AND complaint_date <= GETDATE()
       AND product_area = 'Performance'
       AND agent_name IS NOT NULL
       AND notes IS NOT NULL
       AND agent_name <> ''
   GROUP BY notes
),
calc AS (
   SELECT
       ci.notes,
       n.avg_res_time,
       n.max_res_time,
       n.min_res_time,
       COUNT(ci.complaint_id) AS total_complaints,
       COUNT(ci.customer_id) AS total_customers,
       COUNT(DISTINCT ci.customer_id) AS unique_customers,
       COUNT(ci.customer_id) - COUNT(DISTINCT ci.customer_id) AS repeat_customers,
       COUNT(DISTINCT agent_name) AS total_agents,
       SUM(CASE WHEN ci.resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN ci.resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints,
       SUM(CASE WHEN ci.resolution_time > n.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time <= n.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
       SUM(CASE WHEN ci.resolution_time = n.min_res_time THEN 1 ELSE 0 END) AS fastest_resolutions,
       SUM(CASE WHEN ci.resolution_time = n.max_res_time THEN 1 ELSE 0 END) AS slowest_resolutions
   FROM customer_intelligence ci
   LEFT JOIN notes_stats n
       ON ci.notes = n.notes
   WHERE ci.signup_date <= GETDATE()
       AND ci.complaint_date <= GETDATE()
       AND ci.product_area = 'Performance'
       AND ci.notes IS NOT NULL
       AND ci.agent_name IS NOT NULL
       AND ci.agent_name <> ''
   GROUP BY ci.notes, n.avg_res_time, n.max_res_time, n.min_res_time
)
SELECT
   notes,
   avg_res_time,
   min_res_time,
   max_res_time,
   total_agents,
   total_complaints,
   total_customers,
   unique_customers,
   repeat_customers,
   resolved_complaints, 
   unresolved_complaints,
   within_average_resolutions,
   above_average_resolutions,
   fastest_resolutions,
   slowest_resolutions,
   CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate
FROM calc
ORDER BY resolution_rate DESC;

-- ========================================================================
-- SECTION 17: RESOLUTION METHOD EFFECTIVENESS - INTEGRATIONS
-- ========================================================================
-- Purpose: Evaluate which resolution methods work best for integrations

WITH notes_stats AS (
   SELECT
       notes,
       AVG(resolution_time) AS avg_res_time,
       MAX(resolution_time) AS max_res_time,
       MIN(resolution_time) AS min_res_time
   FROM customer_intelligence
   WHERE signup_date <= GETDATE()
       AND complaint_date <= GETDATE()
       AND product_area = 'Integrations'
       AND agent_name IS NOT NULL
       AND notes IS NOT NULL
       AND agent_name <> ''
   GROUP BY notes
),
calc AS (
   SELECT
       ci.notes,
       n.avg_res_time,
       n.max_res_time,
       n.min_res_time,
       COUNT(ci.complaint_id) AS total_complaints,
       COUNT(ci.customer_id) AS total_customers,
       COUNT(DISTINCT ci.customer_id) AS unique_customers,
       COUNT(ci.customer_id) - COUNT(DISTINCT ci.customer_id) AS repeat_customers,
       COUNT(DISTINCT agent_name) AS total_agents,
       SUM(CASE WHEN ci.resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN ci.resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints,
       SUM(CASE WHEN ci.resolution_time > n.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time <= n.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
       SUM(CASE WHEN ci.resolution_time = n.min_res_time THEN 1 ELSE 0 END) AS fastest_resolutions,
       SUM(CASE WHEN ci.resolution_time = n.max_res_time THEN 1 ELSE 0 END) AS slowest_resolutions
   FROM customer_intelligence ci
   LEFT JOIN notes_stats n
       ON ci.notes = n.notes
   WHERE ci.signup_date <= GETDATE()
       AND ci.complaint_date <= GETDATE()
       AND ci.product_area = 'Integrations'
       AND ci.notes IS NOT NULL
       AND ci.agent_name IS NOT NULL
       AND ci.agent_name <> ''
   GROUP BY ci.notes, n.avg_res_time, n.max_res_time, n.min_res_time
)
SELECT
   notes,
   avg_res_time,
   min_res_time,
   max_res_time,
   total_agents,
   total_complaints,
   total_customers,
   unique_customers,
   repeat_customers,
   resolved_complaints, 
   unresolved_complaints,
   within_average_resolutions,
   above_average_resolutions,
   fastest_resolutions,
   slowest_resolutions,
   CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate
FROM calc
ORDER BY resolution_rate DESC;

-- ========================================================================
-- SECTION 18: CROSS-PRODUCT PROBLEM TYPE ANALYSIS
-- ========================================================================
-- Purpose: Identify problem types that span multiple product areas

WITH stats AS (
   -- Calculate baseline metrics per problem type
   SELECT
       complaint_text AS problem_type,
       COUNT(DISTINCT product_area) AS product_areas_affected,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time,
       AVG(resolution_time) AS avg_res_time
   FROM customer_intelligence
   WHERE signup_date <= GETDATE()
       AND complaint_date <= GETDATE()
       AND complaint_text IS NOT NULL
       AND agent_name IS NOT NULL
       AND agent_name <> ''
   GROUP BY complaint_text
),
problems AS (
   -- Aggregate problem metrics
   SELECT
       ci.complaint_text AS problem_type,
       s.product_areas_affected,
       COUNT(ci.complaint_id) AS total_complaints,
       COUNT(customer_id) AS total_customers,
       COUNT(DISTINCT customer_id) AS unique_customers,
       COUNT(customer_id) - COUNT(DISTINCT customer_id) AS repeat_customers,
       s.min_res_time,
       s.max_res_time,
       s.avg_res_time,
       COUNT(DISTINCT ci.agent_id) AS agents_involved,
       SUM(CASE WHEN ci.resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN ci.resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints,
       SUM(CASE WHEN ci.resolution_time > s.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time <= s.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.min_res_time THEN 1 ELSE 0 END) AS fastest_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.max_res_time THEN 1 ELSE 0 END) AS slowest_resolutions
   FROM customer_intelligence ci
   LEFT JOIN stats s 
       ON ci.complaint_text = s.problem_type
   WHERE ci.complaint_date <= GETDATE()
       AND ci.agent_name <> ''
       AND ci.complaint_text IS NOT NULL
       AND ci.agent_name IS NOT NULL
       AND ci.signup_date <= GETDATE()
   GROUP BY ci.complaint_text, s.avg_res_time, s.min_res_time, s.max_res_time, s.avg_res_time, s.product_areas_affected    
)
SELECT
   problem_type,
   product_areas_affected,
   max_res_time,
   min_res_time,
   avg_res_time,
   agents_involved,
   total_complaints,
   unique_customers,
   repeat_customers,
   total_complaints,
   resolved_complaints,
   unresolved_complaints,
   above_average_resolutions,
   within_average_resolutions,
   fastest_resolutions,
   slowest_resolutions,
   CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate,
   CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS resolution_gap_pct
FROM problems;

-- ========================================================================
-- SECTION 19: RESOLUTION NOTES EFFECTIVENESS ANALYSIS
-- ========================================================================
-- Purpose: Evaluate all resolution notes across product areas

WITH stats AS (
   -- Calculate baseline metrics for each note type
   SELECT
       notes,
       COUNT(DISTINCT product_area) AS product_areas_affected,
       MAX(resolution_time) AS max_res_time,
       MIN(resolution_time) AS min_res_time,
       AVG(resolution_time) AS avg_res_time
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND agent_name <> ''
       AND agent_name IS NOT NULL
       AND notes IS NOT NULL
   GROUP BY notes
),
complaints AS (
   -- Get total complaint count
   SELECT
       COUNT(complaint_id) AS all_customer_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
   AND signup_date <= GETDATE()
),
problems AS (
   -- Aggregate by note type
   SELECT
       ci.notes,
       s.product_areas_affected,
       s.max_res_time,
       s.min_res_time,
       s.avg_res_time,
       COUNT(DISTINCT agent_name) AS agents_involved,
       COUNT(ci.complaint_id) AS total_complaints,
       c.all_customer_complaints,
       COUNT(ci.customer_id) AS total_customers,
       COUNT(DISTINCT ci.customer_id) AS unique_customers,
       COUNT(ci.customer_id) - COUNT(DISTINCT ci.customer_id) AS repeat_customers,
       SUM(CASE WHEN ci.resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN ci.resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints,
       SUM(CASE WHEN ci.resolution_time > s.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time <= s.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.min_res_time THEN 1 ELSE 0 END) AS fastest_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.max_res_time THEN 1 ELSE 0 END) AS slowest_resolutions
   FROM customer_intelligence ci
   LEFT JOIN stats s
       ON ci.notes = s.notes
   CROSS JOIN complaints c
   WHERE ci.agent_name IS NOT NULL
       AND ci.agent_name <> ''
       AND ci.complaint_date <= GETDATE()
       AND ci.signup_date <= GETDATE()
       AND ci.notes IS NOT NULL
   GROUP BY ci.notes, c.all_customer_complaints, s.product_areas_affected, s.max_res_time, s.min_res_time, s.avg_res_time
)
SELECT
   notes,
   product_areas_affected,
   agents_involved,
   total_customers,
   unique_customers,
   repeat_customers,
   total_complaints,
   all_customer_complaints,
   min_res_time,
   max_res_time,
   avg_res_time,
   resolved_complaints,
   unresolved_complaints,
   within_average_resolutions,
   above_average_resolutions,
   fastest_resolutions,
   slowest_resolutions,
   CONCAT(ROUND(100.0 * total_complaints/all_customer_complaints, 2), '%') AS complaint_contribution_pct,
   CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate,
   CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS resolution_gap_pct
FROM problems
ORDER BY product_areas_affected DESC, resolution_gap_pct;

-- ========================================================================
-- SECTION 20: PARETO ANALYSIS - 80/20 RULE
-- ========================================================================
-- Purpose: Identify which problem types account for 80% of complaints
-- Use Case: Prioritize fixes based on impact

WITH stats AS (
   -- Calculate baseline metrics
   SELECT
       complaint_text AS problem_type,
       COUNT(DISTINCT product_area) AS product_areas_affected,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time,
       AVG(resolution_time) AS avg_res_time
   FROM customer_intelligence
   WHERE signup_date <= GETDATE()
       AND complaint_date <= GETDATE()
       AND complaint_text IS NOT NULL
       AND agent_name IS NOT NULL
       AND agent_name <> ''
   GROUP BY complaint_text
),
complaints AS (
   -- Get total complaints
   SELECT
       COUNT(complaint_id) AS all_customer_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
   AND signup_date <= GETDATE()
),
problems AS (
   -- Aggregate problem metrics
   SELECT
       ci.complaint_text AS problem_type,
       s.product_areas_affected,
       COUNT(ci.complaint_id) AS complaints,
       c.all_customer_complaints,
       COUNT(customer_id) AS total_customers,
       COUNT(DISTINCT customer_id) AS unique_customers,
       COUNT(ci.customer_id) - COUNT(DISTINCT customer_id) AS repeat_customers,
       s.avg_res_time,
       s.max_res_time,
       s.min_res_time,
       COUNT(DISTINCT ci.agent_name) AS agents_involved,
       SUM(CASE WHEN ci.resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN ci.resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints,
       SUM(CASE WHEN ci.resolution_time > s.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time <= s.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.min_res_time THEN 1 ELSE 0 END) AS fastest_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.max_res_time THEN 1 ELSE 0 END) AS slowest_resolutions
   FROM customer_intelligence ci
   LEFT JOIN stats s 
       ON ci.complaint_text = s.problem_type
   CROSS JOIN complaints c
   WHERE ci.complaint_date <= GETDATE()
       AND ci.complaint_text IS NOT NULL
       AND ci.agent_name IS NOT NULL
       AND ci.signup_date <= GETDATE()
       AND ci.agent_name <> ''
   GROUP BY ci.complaint_text, c.all_customer_complaints, s.product_areas_affected, s.avg_res_time, s.min_res_time, s.max_res_time
),
pareto AS (
   -- Calculate Pareto metrics
   SELECT
       problem_type,
       product_areas_affected,
       avg_res_time,
       min_res_time,
       max_res_time,
       complaints,
       all_customer_complaints,
       total_customers,
       unique_customers,
       repeat_customers,
       agents_involved,
       resolved_complaints,
       unresolved_complaints,
       within_average_resolutions,
       above_average_resolutions,
       fastest_resolutions,
       slowest_resolutions,
       ROUND(100.0 * complaints/all_customer_complaints, 2) AS complaint_contribution_pct,
       -- Calculate cumulative contribution
       SUM(100.0 * complaints/all_customer_complaints)
           OVER (ORDER BY complaints DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_contribution_pct
   FROM problems
)
SELECT
   problem_type,
   product_areas_affected,
   max_res_time,
   min_res_time,
   avg_res_time,
   agents_involved,
   complaints,
   all_customer_complaints,
   total_customers,
   unique_customers,
   repeat_customers,
   resolved_complaints,
   unresolved_complaints,
   within_average_resolutions,
   above_average_resolutions,
   fastest_resolutions,
   slowest_resolutions,
   CONCAT(ROUND(100.0 * unresolved_complaints/complaints, 2), '%') AS resolution_gap,
   CONCAT(ROUND(100.0 * resolved_complaints/complaints, 2), '%') AS resolution_rate,
   CONCAT(ROUND(complaint_contribution_pct, 2), '%') AS complaint_contribution_pct,
   CONCAT(ROUND(cumulative_contribution_pct, 2), '%') AS cumulative_contribution_pct
FROM pareto;

-- ========================================================================
-- SECTION 21: SPECIFIC ISSUE DEEP DIVES
-- ========================================================================
-- These queries analyze specific high-impact issues identified in analysis

-- Query: Find distinct complaint texts for specific issues
SELECT
   DISTINCT notes,
   complaint_text
FROM customer_intelligence
WHERE complaint_text LIKE '%Export%';

-- ========================================================================
-- SECTION 22: MOBILE APP ISSUES ANALYSIS
-- ========================================================================
-- Purpose: Deep dive into mobile app complaints

WITH stats AS (
   SELECT
       notes,
       complaint_text AS problem_type,
       AVG(resolution_time) AS avg_res_time,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time
   FROM customer_intelligence
   WHERE complaint_text LIKE '%Mobile%'
       AND notes IS NOT NULL
       AND complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND agent_name IS NOT NULL
       AND agent_name <> ''
   GROUP BY notes, complaint_text
),
problems AS (
   SELECT
       ci.notes,
       ci.complaint_text AS problem_type,
       s.max_res_time,
       s.min_res_time,
       s.avg_res_time,
       COUNT(ci.complaint_id) AS total_complaints,
       COUNT(ci.customer_id) AS total_customers,
       COUNT(DISTINCT ci.customer_id) AS unique_customers,
       COUNT(ci.complaint_id) - COUNT(DISTINCT ci.customer_id) AS repeat_customers,
       SUM(CASE WHEN ci.resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN ci.resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints,
       SUM(CASE WHEN ci.resolution_time > s.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time <= s.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.min_res_time THEN 1 ELSE 0 END) AS fastest_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.max_res_time THEN 1 ELSE 0 END) AS slowest_resolutions
   FROM customer_intelligence ci
   LEFT JOIN stats s 
       ON ci.notes = s.notes
       AND ci.complaint_text = s.problem_type
   WHERE ci.notes IS NOT NULL
       AND ci.agent_name IS NOT NULL
       AND ci.agent_name <> ''
       AND ci.complaint_date <= GETDATE()
       AND ci.signup_date <= GETDATE()
       AND ci.complaint_text LIKE '%Mobile%'
   GROUP BY ci.notes, ci.complaint_text, s.avg_res_time, s.max_res_time, s.min_res_time
),
observations AS (
   SELECT
       notes,
       problem_type,
       total_complaints,
       total_customers,
       unique_customers,
       repeat_customers,
       min_res_time,
       max_res_time,
       avg_res_time,
       resolved_complaints,
       unresolved_complaints,
       above_average_resolutions,
       within_average_resolutions,
       fastest_resolutions,
       slowest_resolutions,
       CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate,
       CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS resolution_gap_pct
   FROM problems
)
SELECT *
FROM observations;

-- ========================================================================
-- SECTION 23: EXPORT/CSV ISSUES ANALYSIS
-- ========================================================================
-- Purpose: Deep dive into export and CSV-related complaints

WITH stats AS (
   SELECT
       notes,
       complaint_text AS problem_type,
       AVG(resolution_time) AS avg_res_time,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time
   FROM customer_intelligence
   WHERE complaint_text LIKE '%CSV%'
       AND notes IS NOT NULL
       AND complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND agent_name IS NOT NULL
       AND agent_name <> ''
   GROUP BY notes, complaint_text
),
problems AS (
   SELECT
       ci.notes,
       ci.complaint_text AS problem_type,
       s.max_res_time,
       s.min_res_time,
       s.avg_res_time,
       COUNT(ci.complaint_id) AS total_complaints,
       COUNT(ci.customer_id) AS total_customers,
       COUNT(DISTINCT ci.customer_id) AS unique_customers,
       COUNT(ci.complaint_id) - COUNT(DISTINCT ci.customer_id) AS repeat_customers,
       SUM(CASE WHEN ci.resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN ci.resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints,
       SUM(CASE WHEN ci.resolution_time > s.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time <= s.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.min_res_time THEN 1 ELSE 0 END) AS fastest_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.max_res_time THEN 1 ELSE 0 END) AS slowest_resolutions
   FROM customer_intelligence ci
   LEFT JOIN stats s 
       ON ci.notes = s.notes
       AND ci.complaint_text = s.problem_type
   WHERE ci.notes IS NOT NULL
       AND ci.agent_name IS NOT NULL
       AND ci.agent_name <> ''
       AND ci.complaint_date <= GETDATE()
       AND ci.signup_date <= GETDATE()
       AND ci.complaint_text LIKE '%CSV%'
   GROUP BY ci.notes, ci.complaint_text, s.avg_res_time, s.max_res_time, s.min_res_time
),
observations AS (
   SELECT
       notes,
       problem_type,
       total_complaints,
       total_customers,
       unique_customers,
       repeat_customers,
       min_res_time,
       max_res_time,
       avg_res_time,
       resolved_complaints,
       unresolved_complaints,
       above_average_resolutions,
       within_average_resolutions,
       fastest_resolutions,
       slowest_resolutions,
       CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate,
       CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS resolution_gap_pct
   FROM problems
)
SELECT *
FROM observations;

-- ========================================================================
-- SECTION 24: NOTIFICATIONS ISSUES ANALYSIS
-- ========================================================================
-- Purpose: Deep dive into notification delay complaints

WITH stats AS (
   SELECT
       notes,
       complaint_text AS problem_type,
       AVG(resolution_time) AS avg_res_time,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time
   FROM customer_intelligence
   WHERE complaint_text LIKE '%Notifications%'
       AND notes IS NOT NULL
       AND complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND agent_name IS NOT NULL
       AND agent_name <> ''
   GROUP BY notes, complaint_text
),
problems AS (
   SELECT
       ci.notes,
       ci.complaint_text AS problem_type,
       s.max_res_time,
       s.min_res_time,
       s.avg_res_time,
       COUNT(ci.complaint_id) AS total_complaints,
       COUNT(ci.customer_id) AS total_customers,
       COUNT(DISTINCT ci.customer_id) AS unique_customers,
       COUNT(ci.complaint_id) - COUNT(DISTINCT ci.customer_id) AS repeat_customers,
       SUM(CASE WHEN ci.resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN ci.resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints,
       SUM(CASE WHEN ci.resolution_time > s.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time <= s.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.min_res_time THEN 1 ELSE 0 END) AS fastest_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.max_res_time THEN 1 ELSE 0 END) AS slowest_resolutions
   FROM customer_intelligence ci
   LEFT JOIN stats s 
       ON ci.notes = s.notes
       AND ci.complaint_text = s.problem_type
   WHERE ci.notes IS NOT NULL
       AND ci.agent_name IS NOT NULL
       AND ci.agent_name <> ''
       AND ci.complaint_date <= GETDATE()
       AND ci.signup_date <= GETDATE()
       AND ci.complaint_text LIKE '%Notifications%'
   GROUP BY ci.notes, ci.complaint_text, s.avg_res_time, s.max_res_time, s.min_res_time
),
observations AS (
   SELECT
       notes,
       problem_type,
       total_complaints,
       total_customers,
       unique_customers,
       repeat_customers,
       min_res_time,
       max_res_time,
       avg_res_time,
       resolved_complaints,
       unresolved_complaints,
       above_average_resolutions,
       within_average_resolutions,
       fastest_resolutions,
       slowest_resolutions,
       CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate,
       CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS resolution_gap_pct
   FROM problems
)
SELECT *
FROM observations;

-- ========================================================================
-- SECTION 25: PREMIUM FEATURE ACCESS ISSUES ANALYSIS
-- ========================================================================
-- Purpose: Deep dive into locked premium features complaints by segment

WITH stats AS (
   SELECT
       notes,
       complaint_text AS problem_type,
       segment,
       AVG(resolution_time) AS avg_res_time,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time
   FROM customer_intelligence
   WHERE complaint_text LIKE '%Premium%'
       AND notes IS NOT NULL
       AND complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND agent_name IS NOT NULL
       AND agent_name <> ''
   GROUP BY notes, complaint_text, segment
),
problems AS (
   SELECT
       ci.notes,
       ci.complaint_text AS problem_type,
       ci.segment,
       s.max_res_time,
       s.min_res_time,
       s.avg_res_time,
       COUNT(ci.complaint_id) AS total_complaints,
       COUNT(ci.customer_id) AS total_customers,
       COUNT(DISTINCT ci.customer_id) AS unique_customers,
       COUNT(ci.complaint_id) - COUNT(DISTINCT ci.customer_id) AS repeat_customers,
       SUM(CASE WHEN ci.resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN ci.resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints,
       SUM(CASE WHEN ci.resolution_time > s.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time <= s.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.min_res_time THEN 1 ELSE 0 END) AS fastest_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.max_res_time THEN 1 ELSE 0 END) AS slowest_resolutions
   FROM customer_intelligence ci
   LEFT JOIN stats s 
       ON ci.notes = s.notes
       AND ci.complaint_text = s.problem_type
       AND ci.segment = s.segment
   WHERE ci.notes IS NOT NULL
       AND ci.agent_name IS NOT NULL
       AND ci.agent_name <> ''
       AND ci.complaint_date <= GETDATE()
       AND ci.signup_date <= GETDATE()
       AND ci.complaint_text LIKE '%Premium%'
   GROUP BY ci.notes, ci.segment, ci.complaint_text, s.avg_res_time, s.max_res_time, s.min_res_time
),
observations AS (
   SELECT
       notes,
       segment,
       problem_type,
       total_complaints,
       total_customers,
       unique_customers,
       repeat_customers,
       min_res_time,
       max_res_time,
       avg_res_time,
       resolved_complaints,
       unresolved_complaints,
       above_average_resolutions,
       within_average_resolutions,
       fastest_resolutions,
       slowest_resolutions,
       CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate,
       CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS resolution_gap_pct
   FROM problems
)
SELECT *
FROM observations;

-- Query: Premium complaints by segment summary
SELECT
   notes,
   complaint_text AS problem_type,
   segment,
   COUNT(*) AS total_complaints,
   SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolutions
FROM customer_intelligence
WHERE signup_date <= GETDATE()
   AND complaint_date <= GETDATE()
   AND complaint_text LIKE '%Premium%'
   AND notes IS NOT NULL 
GROUP BY notes, complaint_text, segment;

-- ========================================================================
-- SECTION 26: BILLING PAGE CRASH ANALYSIS
-- ========================================================================
-- Purpose: Deep dive into billing page crash complaints

WITH stats AS (
   SELECT
       notes,
       complaint_text AS problem_type,
       AVG(resolution_time) AS avg_res_time,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time
   FROM customer_intelligence
   WHERE complaint_text LIKE '%Billing%'
       AND notes IS NOT NULL
       AND complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND agent_name IS NOT NULL
       AND agent_name <> ''
   GROUP BY notes, complaint_text
),
problems AS (
   SELECT
       ci.notes,
       ci.complaint_text AS problem_type,
       s.max_res_time,
       s.min_res_time,
       s.avg_res_time,
       COUNT(ci.complaint_id) AS total_complaints,
       COUNT(ci.customer_id) AS total_customers,
       COUNT(DISTINCT ci.customer_id) AS unique_customers,
       COUNT(ci.complaint_id) - COUNT(DISTINCT ci.customer_id) AS repeat_customers,
       SUM(CASE WHEN ci.resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN ci.resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints,
       SUM(CASE WHEN ci.resolution_time > s.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time <= s.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.min_res_time THEN 1 ELSE 0 END) AS fastest_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.max_res_time THEN 1 ELSE 0 END) AS slowest_resolutions
   FROM customer_intelligence ci
   LEFT JOIN stats s 
       ON ci.notes = s.notes
       AND ci.complaint_text = s.problem_type
   WHERE ci.notes IS NOT NULL
       AND ci.agent_name IS NOT NULL
       AND ci.agent_name <> ''
       AND ci.complaint_date <= GETDATE()
       AND ci.signup_date <= GETDATE()
       AND ci.complaint_text LIKE '%Billing%'
   GROUP BY ci.notes, ci.complaint_text, s.avg_res_time, s.max_res_time, s.min_res_time
),
observations AS (
   SELECT
       notes,
       problem_type,
       total_complaints,
       total_customers,
       unique_customers,
       repeat_customers,
       min_res_time,
       max_res_time,
       avg_res_time,
       resolved_complaints,
       unresolved_complaints,
       above_average_resolutions,
       within_average_resolutions,
       fastest_resolutions,
       slowest_resolutions,
       CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate,
       CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS resolution_gap_pct
   FROM problems
)
SELECT *
FROM observations;

-- ========================================================================
-- SECTION 27: DASHBOARD FREEZE ANALYSIS
-- ========================================================================
-- Purpose: Deep dive into dashboard freeze complaints

WITH stats AS (
   SELECT
       notes,
       complaint_text AS problem_type,
       AVG(resolution_time) AS avg_res_time,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time
   FROM customer_intelligence
   WHERE complaint_text LIKE '%Dashboard%'
       AND notes IS NOT NULL
       AND complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND agent_name IS NOT NULL
       AND agent_name <> ''
   GROUP BY notes, complaint_text
),
problems AS (
   SELECT
       ci.notes,
       ci.complaint_text AS problem_type,
       s.max_res_time,
       s.min_res_time,
       s.avg_res_time,
       COUNT(ci.complaint_id) AS total_complaints,
       COUNT(ci.customer_id) AS total_customers,
       COUNT(DISTINCT ci.customer_id) AS unique_customers,
       COUNT(ci.complaint_id) - COUNT(DISTINCT ci.customer_id) AS repeat_customers,
       SUM(CASE WHEN ci.resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN ci.resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints,
       SUM(CASE WHEN ci.resolution_time > s.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time <= s.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.min_res_time THEN 1 ELSE 0 END) AS fastest_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.max_res_time THEN 1 ELSE 0 END) AS slowest_resolutions
   FROM customer_intelligence ci
   LEFT JOIN stats s 
       ON ci.notes = s.notes
       AND ci.complaint_text = s.problem_type
   WHERE ci.notes IS NOT NULL
       AND ci.agent_name IS NOT NULL
       AND ci.agent_name <> ''
       AND ci.complaint_date <= GETDATE()
       AND ci.signup_date <= GETDATE()
       AND ci.complaint_text LIKE '%Dashboard%'
   GROUP BY ci.notes, ci.complaint_text, s.avg_res_time, s.max_res_time, s.min_res_time
),
observations AS (
   SELECT
       notes,
       problem_type,
       total_complaints,
       total_customers,
       unique_customers,
       repeat_customers,
       min_res_time,
       max_res_time,
       avg_res_time,
       resolved_complaints,
       unresolved_complaints,
       above_average_resolutions,
       within_average_resolutions,
       fastest_resolutions,
       slowest_resolutions,
       CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate,
       CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS resolution_gap_pct
   FROM problems
)
SELECT *
FROM observations;

-- ========================================================================
-- SECTION 28: SLOW UI PERFORMANCE ANALYSIS
-- ========================================================================
-- Purpose: Deep dive into UI slowness complaints

WITH stats AS (
   SELECT
       notes,
       complaint_text AS problem_type,
       AVG(resolution_time) AS avg_res_time,
       MIN(resolution_time) AS min_res_time,
       MAX(resolution_time) AS max_res_time
   FROM customer_intelligence
   WHERE complaint_text LIKE '%UI%'
       AND notes IS NOT NULL
       AND complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND agent_name IS NOT NULL
       AND agent_name <> ''
   GROUP BY notes, complaint_text
),
problems AS (
   SELECT
       ci.notes,
       ci.complaint_text AS problem_type,
       s.max_res_time,
       s.min_res_time,
       s.avg_res_time,
       COUNT(ci.complaint_id) AS total_complaints,
       COUNT(ci.customer_id) AS total_customers,
       COUNT(DISTINCT ci.customer_id) AS unique_customers,
       COUNT(ci.complaint_id) - COUNT(DISTINCT ci.customer_id) AS repeat_customers,
       SUM(CASE WHEN ci.resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN ci.resolution_status = 'Open' THEN 1 ELSE 0 END) AS unresolved_complaints,
       SUM(CASE WHEN ci.resolution_time > s.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time <= s.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.min_res_time THEN 1 ELSE 0 END) AS fastest_resolutions,
       SUM(CASE WHEN ci.resolution_time = s.max_res_time THEN 1 ELSE 0 END) AS slowest_resolutions
   FROM customer_intelligence ci
   LEFT JOIN stats s 
       ON ci.notes = s.notes
       AND ci.complaint_text = s.problem_type
   WHERE ci.notes IS NOT NULL
       AND ci.agent_name IS NOT NULL
       AND ci.agent_name <> ''
       AND ci.complaint_date <= GETDATE()
       AND ci.signup_date <= GETDATE()
       AND ci.complaint_text LIKE '%UI%'
   GROUP BY ci.notes, ci.complaint_text, s.avg_res_time, s.max_res_time, s.min_res_time
),
observations AS (
   SELECT
       notes,
       problem_type,
       total_complaints,
       total_customers,
       unique_customers,
       repeat_customers,
       min_res_time,
       max_res_time,
       avg_res_time,
       resolved_complaints,
       unresolved_complaints,
       above_average_resolutions,
       within_average_resolutions,
       fastest_resolutions,
       slowest_resolutions,
       CONCAT(ROUND(100.0 * resolved_complaints/total_complaints, 2), '%') AS resolution_rate,
       CONCAT(ROUND(100.0 * unresolved_complaints/total_complaints, 2), '%') AS resolution_gap_pct
   FROM problems
)
SELECT *
FROM observations;

-- ========================================================================
-- SECTION 29: RESOLUTION NOTES SUMMARY
-- ========================================================================
-- Purpose: Overall summary of resolution methods used

SELECT
   notes,
   COUNT(complaint_id) AS total_complaints
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
   AND signup_date <= GETDATE()
   AND notes IS NOT NULL
GROUP BY notes
ORDER BY total_complaints DESC;

-- ========================================================================
-- END OF STRATEGIC & PREDICTIVE INSIGHTS ANALYSIS
-- ========================================================================
-- Summary: This script provides 29 comprehensive analyses covering:
--   - Strategic recommendations baseline (Sections 1-4)
--   - Agent staffing and efficiency (Section 5)
--   - Deep dives into top 3 problem areas (Sections 6-8)
--   - Difficulty classification (Sections 9-11)
--   - Performance benchmarking (Sections 12-14)
--   - Resolution method effectiveness (Sections 15-17)
--   - Cross-product problem analysis (Section 18)
--   - Resolution notes effectiveness (Section 19)
--   - Pareto 80/20 analysis (Section 20)
--   - Specific issue exploration (Section 21)
--   - Targeted issue deep dives (Sections 22-28)
--   - Resolution notes summary (Section 29)
-- ========================================================================
