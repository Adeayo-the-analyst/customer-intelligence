-- ========================================================================
-- AGENT & OPERATIONAL PERFORMANCE ANALYSIS
-- ========================================================================
-- Purpose: Evaluate human efficiency, specialization, and process design
-- Key Questions: What differentiates top-performing agents from bottom performers?
-- Author: Adeayo Adewale
-- Last Modified: 2025
-- ========================================================================

-- ========================================================================
-- SECTION 1: AGENT RESOLUTION TIME ANALYSIS
-- ========================================================================
-- Purpose: Identify fastest and slowest agents by resolution time
-- Use Case: Performance benchmarking, training needs identification

SELECT
   agent_name,
   AVG(resolution_time) AS avg_res_time,
   MIN(resolution_time) AS min_res_time,
   MAX(resolution_time) AS max_res_time,
   STDEV(resolution_time) AS std_dev_res_time,
   VAR(resolution_time) AS var_res_time
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
   AND resolution_status = 'Closed'
   AND signup_date<= GETDATE()
   AND agent_name IS NOT NULL
   AND agent_name <> ''
GROUP BY agent_name
ORDER BY avg_res_time ASC;

-- ========================================================================
-- SECTION 2: AGENT WORKLOAD AND RESOLUTION RATES
-- ========================================================================
-- Purpose: Analyze complaint handling capacity and resolution effectiveness

WITH agent_performance AS (
   -- Aggregate agent metrics
   SELECT
       agent_name,
       skillset,
       COUNT(*) AS total_complaints_handled,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS resolved_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS open_complaints
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND agent_name IS NOT NULL
       AND agent_name <> ''
       AND signup_date <= GETDATE()
   GROUP BY agent_name,skillset
)
SELECT
   agent_name,
   skillset,
   total_complaints_handled,
   open_complaints,
   resolved_complaints,
   -- Calculate percentage metrics
   CONCAT(ROUND(100.0 * open_complaints/total_complaints_handled, 2), '%') AS unresolved_rate,   
   CONCAT(ROUND(100.0 * resolved_complaints/total_complaints_handled,2),'%') AS resolution_rate,
   CONCAT(ROUND(100.0 * open_complaints/total_complaints_handled, 2),'%') AS complaint_backlog
FROM agent_performance
ORDER BY resolution_rate, complaint_backlog DESC;

-- ========================================================================
-- SECTION 3: AGENT PERFORMANCE SCORE
-- ========================================================================
-- Purpose: Create composite performance metric (resolution_rate / avg_res_time)
-- Higher score = better performance (high resolution rate, low resolution time)

WITH agent_performance AS (
   -- Calculate base metrics
   SELECT
       agent_name,
       COUNT(*) AS total_complaints,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS closed_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS opened_complaints,
       AVG(resolution_time) AS avg_res_time
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND agent_name <> ''
       AND agent_name IS NOT NULL
   GROUP BY agent_name
),
performance AS (
   -- Calculate performance score
   SELECT
       agent_name,
       total_complaints,
       closed_complaints,
       opened_complaints,
       avg_res_time,
       CONCAT(ROUND(100.0 * closed_complaints/total_complaints, 2), '%') AS resolution_rate,
       -- Performance score: resolution rate divided by average resolution time
       ROUND(100.0 * closed_complaints/total_complaints, 2) / avg_res_time AS performance_score
   FROM agent_performance
)
SELECT
   agent_name,
   total_complaints,
   closed_complaints,
   opened_complaints,
   avg_res_time,
   resolution_rate,
   performance_score,
   -- Rank agents by performance
   RANK() OVER(ORDER BY resolution_rate DESC, avg_res_time ASC) AS performance_rank
FROM performance
ORDER BY performance_rank;

-- ========================================================================
-- SECTION 4: SKILLSET PERFORMANCE COMPARISON
-- ========================================================================
-- Purpose: Identify which skillsets perform best overall

WITH efficiency AS (
   -- Aggregate by skillset
   SELECT
       skillset,
       COUNT(DISTINCT agent_name) AS total_agents,
       COUNT(*) AS total_complaints,
       AVG(resolution_time) AS avg_res_time,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS closed_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS opened_complaints 
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND agent_name IS NOT NULL
       AND agent_name <> ''
       AND signup_date <= GETDATE()
   GROUP BY skillset
),
skillset_performance AS (
   -- Calculate skillset metrics
   SELECT
       skillset,
       total_complaints,
       total_agents,
       opened_complaints,
       closed_complaints,
       avg_res_time,
       CONCAT(ROUND(100.0 * opened_complaints/total_complaints,2),'%') AS complaint_backlog,
       CONCAT(ROUND(100.0 * closed_complaints/total_complaints, 2),'%') AS resolution_rate
   FROM efficiency
)
SELECT
   skillset,
   total_agents,
   total_complaints,
   opened_complaints,
   closed_complaints,
   avg_res_time,
   resolution_rate,
   complaint_backlog
FROM skillset_performance
ORDER BY resolution_rate DESC;

-- ========================================================================
-- SECTION 5: AGENT SPECIALIZATION ANALYSIS
-- ========================================================================
-- Purpose: Determine if agents are being distributed to their skillsets
-- Shows which product areas each agent works on

WITH distinct_products AS (
   -- Get unique agent-product combinations
   SELECT
       DISTINCT agent_name, product_area,
       skillset
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND agent_name <> ''
       AND signup_date <= GETDATE()
       AND agent_name IS NOT NULL
),
products_served AS (
   -- Count products served per agent
   SELECT
       agent_name,
       skillset,
       COUNT(DISTINCT product_area) AS product_served,
       STRING_AGG(product_area, ', ') AS areas_served
   FROM distinct_products
   GROUP BY agent_name, skillset
)
SELECT *
FROM products_served;

-- Query continuation: Agent focus analysis
WITH agent_focus AS (
   -- Identify primary product area for each agent
   SELECT
       agent_name,
       skillset,
       product_area,
       COUNT(*) AS total_cases,
       ROW_NUMBER () OVER(PARTITION BY agent_name
       ORDER BY COUNT(*) DESC) AS rn
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND agent_name IS NOT NULL
       AND agent_name <> ''
       AND signup_date <= GETDATE()
   GROUP BY agent_name, skillset, product_area
)
SELECT * FROM agent_focus;

-- ========================================================================
-- SECTION 6: SKILLSET RESOLUTION TIME STATISTICS
-- ========================================================================
-- Purpose: Statistical analysis of resolution times by skillset

SELECT
   skillset,
   AVG(resolution_time) AS avg_res_time,
   MIN(resolution_time) AS min_res_time,
   MAX(resolution_time) AS max_res_time,
   STDEV(resolution_time) AS std_dev_res_time,
   VAR(resolution_time) AS var_res_time
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
   AND signup_date <= GETDATE()
   AND agent_name <> ''
   AND agent_name IS NOT NULL
GROUP BY skillset;

-- ========================================================================
-- SECTION 7: AGENT ABOVE-AVERAGE PERFORMANCE TRACKING
-- ========================================================================
-- Purpose: Count how many times each agent exceeded their personal average

WITH agent_avg AS (
   -- Calculate agent-specific averages
   SELECT
       agent_name,
       skillset,
       AVG(resolution_time) AS avg_res_time
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND resolution_status = 'Closed'
       AND agent_name IS NOT NULL
       AND agent_name <> ''
       AND signup_date <= GETDATE()
   GROUP BY agent_name, skillset
)
SELECT
   c.agent_name,
   COUNT(*) AS total_complaints,
   -- Count times agent went above their personal average
   SUM(CASE WHEN resolution_time > avg_res_time AND resolution_status = 'Closed' THEN 1 ELSE 0 END) AS above_average_resolutions
FROM customer_intelligence c
INNER JOIN agent_avg a ON c.agent_name = a.agent_name
AND c.skillset = a.skillset
WHERE c.complaint_date <= GETDATE()
GROUP BY c.agent_name;

-- Query: Skillset complaint volume
SELECT 
   skillset,
   COUNT(*) AS total_complaints
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
GROUP BY skillset;

-- ========================================================================
-- SECTION 8: AGENT ANOMALY DETECTION
-- ========================================================================
-- Purpose: Identify agents with unusual resolution time patterns

WITH agent_anomalies AS(
   -- Calculate agent baselines
   SELECT
       agent_name,
       skillset,
       AVG(resolution_time) AS avg_res_time,
       VAR(resolution_time) AS var_res_time,
       STDEV(resolution_time) AS std_res_time
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND agent_name <> ''
       AND agent_name IS NOT NULL
       AND signup_date <= GETDATE()
   GROUP BY agent_name, skillset
)
SELECT
   c.agent_name,
   a.skillset,
   COUNT(c.complaint_id) AS total_complaints,
   ROUND(a.avg_res_time, 2) AS avg_res_time,
   ROUND(a.var_res_time, 2) AS var_res_time,
   ROUND(a.std_res_time, 2) AS std_res_time,
   -- Count performance relative to personal average
   SUM(CASE WHEN c.resolution_time <= a.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions,
   SUM(CASE WHEN c.resolution_time > a.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions
FROM customer_intelligence c
INNER JOIN agent_anomalies a ON c.agent_name = a.agent_name
   AND a.skillset = c.skillset
WHERE c.complaint_date <= GETDATE()
   AND c.agent_name IS NOT NULL
   AND c.agent_name <> ''
   AND c.signup_date <= GETDATE()
GROUP BY c.agent_name, a.skillset, a.avg_res_time, a.var_res_time, a.std_res_time;

-- ========================================================================
-- SECTION 9: SKILLSET ANOMALY DETECTION
-- ========================================================================
-- Purpose: Identify skillsets with unusual resolution patterns

WITH skillset_anomaly AS (
   -- Calculate skillset baselines
   SELECT
       skillset,
       AVG(resolution_time) AS avg_res_time
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND agent_name <> ''
       AND agent_name IS NOT NULL
   GROUP BY skillset
)
SELECT
   c.skillset,
   COUNT(c.complaint_id) AS total_complaints,
   s.avg_res_time,
   -- Count performance relative to skillset average
   SUM(CASE WHEN c.resolution_time > s.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
   SUM(CASE WHEN c.resolution_time <= s.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions_nr
FROM customer_intelligence c
INNER JOIN skillset_anomaly s ON c.skillset = s.skillset
WHERE c.complaint_date <= GETDATE()
   AND c.agent_name IS NOT NULL
   AND c.agent_name <> ''
   AND c.signup_date <= GETDATE()
GROUP BY c.skillset, s.avg_res_time;

-- ========================================================================
-- SECTION 10: SKILLSET-PRODUCT ALIGNMENT ANALYSIS (AGENTS)
-- ========================================================================
-- Purpose: Analyze how agents perform when skillset matches/mismatches product area

WITH skill_map AS (
   -- Define skillset-to-product mappings
   SELECT 'Billing Specialist' AS skillset, 'Billing' AS product_area UNION ALL
   SELECT 'Export Specialist', 'Export' UNION ALL
   SELECT 'Integration Expert', 'Integrations' UNION ALL
   SELECT 'Mobile App Support', 'Mobile App' UNION ALL
   SELECT 'Notification Specialist', 'Notifications' UNION ALL
   SELECT 'Performance Analyst', 'Performance'
),
classified AS (
   -- Classify each complaint as matched or mismatched
   SELECT
       c.agent_name,
       c.skillset,
       c.product_area,
       CASE
           WHEN m.product_area IS NOT NULL THEN 'Matched'
           ELSE 'Mismatched'
       END AS alignment_status,
       c.complaint_id,
       c.resolution_status,
       c.resolution_time
   FROM customer_intelligence c
   LEFT JOIN skill_map m
       ON c.skillset = m.skillset AND c.product_area = m.product_area
       WHERE c.complaint_date <= GETDATE()
           AND c.agent_name IS NOT NULL
           AND c.signup_date <= GETDATE()
           AND c.agent_name <> ''
),
stats AS (
   -- Aggregate by agent and alignment
   SELECT
       agent_name,
       skillset,
       product_area,
       alignment_status,
       COUNT(*) AS total_complaints,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS closed_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS opened_complaints,
       AVG(resolution_time) AS avg_res_time,
       STDEV(resolution_time) AS std_res_time,
       VAR(resolution_time) AS var_res_time
   FROM classified
   GROUP BY agent_name, skillset, product_area, alignment_status
)
SELECT
   agent_name,
   skillset,
   product_area,
   alignment_status,
   total_complaints,
   closed_complaints,
   opened_complaints,
   CONCAT(ROUND(100.0 * opened_complaints/total_complaints, 2), '%') AS complaint_backlog,
   CONCAT(ROUND(100.0 * closed_complaints/total_complaints, 2), '%') AS resolution_rate,
   avg_res_time,
   std_res_time,
   var_res_time
FROM stats;

-- ========================================================================
-- SECTION 11: SKILLSET-PRODUCT ALIGNMENT ANALYSIS (SKILLSETS)
-- ========================================================================
-- Purpose: Aggregate alignment analysis at skillset level

WITH skill_map AS (
   -- Define skillset-to-product mappings
   SELECT 'Billing Specialist' AS skillset, 'Billing' AS product_area UNION ALL
   SELECT 'Export Specialist', 'Export' UNION ALL
   SELECT 'Integration Expert', 'Integrations' UNION ALL
   SELECT 'Mobile App Support', 'Mobile App' UNION ALL
   SELECT 'Notification Specialist', 'Notifications' UNION ALL
   SELECT 'Performance Analyst', 'Performance'
),
classified AS (
   -- Classify complaints
   SELECT
       c.agent_name,
       c.skillset,
       c.product_area,
       CASE
           WHEN m.product_area IS NOT NULL THEN 'Matched'
           ELSE 'Mismatched'
       END AS alignment_status,
       c.complaint_id,
       c.resolution_status,
       c.resolution_time
   FROM customer_intelligence c
   LEFT JOIN skill_map m
       ON c.skillset = m.skillset AND c.product_area = m.product_area
       WHERE c.complaint_date <= GETDATE()
           AND c.agent_name IS NOT NULL
           AND c.signup_date <= GETDATE()
           AND c.agent_name <> ''
),
stats AS (
   -- Aggregate by skillset and alignment
   SELECT
       COUNT(DISTINCT agent_name) AS total_agents,
       skillset,
       product_area,
       alignment_status,
       COUNT(*) AS total_complaints,
       SUM(CASE WHEN resolution_status = 'Closed' THEN 1 ELSE 0 END) AS closed_complaints,
       SUM(CASE WHEN resolution_status = 'Open' THEN 1 ELSE 0 END) AS opened_complaints,
       AVG(resolution_time) AS avg_res_time,
       STDEV(resolution_time) AS std_res_time,
       VAR(resolution_time) AS var_res_time
   FROM classified
   GROUP BY skillset, product_area, alignment_status
)
SELECT
   skillset,
   total_agents,
   product_area,
   alignment_status,
   total_complaints,
   closed_complaints,
   opened_complaints,
   CONCAT(ROUND(100.0 * opened_complaints/total_complaints, 2), '%') AS complaint_backlog,
   CONCAT(ROUND(100.0 * closed_complaints/total_complaints, 2), '%') AS resolution_rate,
   avg_res_time,
   std_res_time,
   var_res_time
FROM stats
GROUP BY skillset, product_area, alignment_status, total_complaints,
closed_complaints, opened_complaints, avg_res_time, std_res_time, var_res_time;

-- ========================================================================
-- SECTION 12: PERFORMANCE CONSISTENCY INDEX (PCI)
-- ========================================================================
-- Purpose: Create consistency metric (within_average_resolutions / total_complaints)
-- Higher PCI = more consistent performance

WITH resolutions AS (
   -- Calculate agent averages
   SELECT
       agent_name,
       AVG(resolution_time) AS average_res_time
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND agent_name <> ''
       AND agent_name IS NOT NULL
       AND signup_date <= GETDATE()
   GROUP BY agent_name
),
complaints AS (
   -- Compare each complaint to agent average
   SELECT
       c.agent_name,
       c.skillset,
       COUNT(c.complaint_id) AS total_complaints,
       r.average_res_time,
       SUM(CASE WHEN c.resolution_time > r.average_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN c.resolution_time <= r.average_res_time THEN 1 ELSE 0 END) AS within_average_resolutions 
   FROM customer_intelligence c
   INNER JOIN resolutions r 
       ON c.agent_name = r.agent_name
   WHERE c.complaint_date <= GETDATE()
       AND c.agent_name IS NOT NULL
       AND c.agent_name <> ''
       AND c.signup_date <= GETDATE()
   GROUP BY c.agent_name, c.skillset, r.average_res_time
),
pci_formula AS (
   -- Calculate PCI
   SELECT
       agent_name,
       skillset,
       total_complaints,
       average_res_time,
       within_average_resolutions,
       above_average_resolutions,
       ROUND(1.0 * within_average_resolutions/total_complaints, 2) AS pci_index
   FROM complaints
)
SELECT
   agent_name,
   skillset,
   total_complaints,
   average_res_time,
   within_average_resolutions,
   above_average_resolutions,
   pci_index,
   -- Categorize performance
   CASE
       WHEN pci_index >= 0.6 THEN 'Consistent Performer'
       WHEN pci_index BETWEEN 0.5 AND 0.59 THEN 'Average Performer'
       WHEN pci_index <= 0.49 THEN 'Overloaded Performer'
   END AS performance_flag
FROM pci_formula
ORDER BY pci_index DESC;

-- Query: Single-complaint customers
SELECT DISTINCT customer_id,
   COUNT(complaint_id) AS total_complaints
FROM customer_intelligence
WHERE signup_date <= GETDATE()
   AND complaint_date <= GETDATE()
GROUP BY customer_id
HAVING COUNT(complaint_id) = 1;

-- Query: Product areas per agent
SELECT
   agent_name,
   COUNT(DISTINCT product_area) AS product_areas_worked_in
FROM customer_intelligence
WHERE signup_date <= GETDATE()
   AND complaint_date <= GETDATE()
   AND agent_name IS NOT NULL
   AND agent_name <> ''
GROUP BY agent_name;

-- Query: Max resolution time analysis
WITH max AS (
   SELECT
       agent_name,
       VAR(resolution_time) AS var_res_time,
       STDEV(resolution_time) AS std_dev_res_time
   FROM customer_intelligence
   WHERE agent_name <> ''
       AND agent_name IS NOT NULL
       AND complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       GROUP BY agent_name
   HAVING AVG(resolution_time) <=5
)
SELECT
   ci.agent_name,
   m.max_res_time,
   m.std_dev_res_time,
   m.var_res_time,
   SUM(CASE WHEN ci.resolution_time = m.max_res_time THEN 1 ELSE 0 END) AS resolutions_in_max_time
FROM customer_intelligence ci
INNER JOIN max m ON
   ci.agent_name = m.agent_name
WHERE ci.complaint_date <= GETDATE()
   AND ci.agent_name <> ''
   AND ci.agent_name IS NOT NULL
   AND ci.signup_date <= GETDATE()
GROUP BY ci.agent_name, m.max_res_time, m.std_dev_res_time, m.var_res_time;

-- ========================================================================
-- SECTION 13: OUTLIER DETECTION WITH SKILLSET COMPARISON
-- ========================================================================
-- Purpose: Identify agents who are statistical outliers within their skillset

WITH resolutions AS (
   SELECT
       agent_name,
       AVG(resolution_time) AS avg_res_time,
       STDEV(resolution_time) AS std_dev_res_time
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND agent_name IS NOT NULL
       AND agent_name <> ''
       AND signup_date <= GETDATE()
   GROUP BY agent_name
),
complaints AS(
   SELECT
       c.agent_name,
       c.skillset,
       COUNT(c.complaint_id) AS total_complaints,
       r.avg_res_time,
       r.std_dev_res_time,
       SUM(CASE WHEN c.resolution_time > r.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN c.resolution_time <= r.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions
   FROM customer_intelligence c
   INNER JOIN resolutions r
       ON c.agent_name = r.agent_name
   WHERE c.complaint_date <= GETDATE()
       AND c.agent_name IS NOT NULL
       AND c.agent_name <> ''
       AND c.signup_date <= GETDATE()
   GROUP BY c.agent_name, c.skillset, r.avg_res_time, r.std_dev_res_time
),
pci_formula AS (
   SELECT
       agent_name,
       skillset,
       total_complaints,
       avg_res_time,
       std_dev_res_time,
       within_average_resolutions,
       above_average_resolutions,
       ROUND(1.0 * within_average_resolutions/total_complaints, 2) AS pci_index
   FROM complaints
),
skillset_stats AS (
   -- Calculate skillset-level statistics
   SELECT
       skillset,
       AVG(std_dev_res_time) AS mean_std_res_time,
       STDEV(std_dev_res_time) AS std_std_res_time,
       AVG(within_average_resolutions) AS mean_within_avg_res,
       STDEV(within_average_resolutions) AS std_within_avg_res,
       AVG(pci_index) AS mean_pci,
       STDEV(pci_index) AS std_pci
   FROM pci_formula
   GROUP BY skillset
)
SELECT
   p.agent_name,
   p.skillset,
   p.total_complaints,
   p.avg_res_time,
   p.std_dev_res_time,
   p.within_average_resolutions,
   p.above_average_resolutions,
   p.pci_index,
   -- Performance classification
   CASE
       WHEN p.pci_index >= 0.6 THEN 'Consistent Performer'
       WHEN p.pci_index BETWEEN 0.5 AND 0.59 THEN 'Average Performer'
       ELSE 'Overloaded Performer'
   END AS performance_flag,
   -- Outlier detection (2 standard deviations)
   CASE
       WHEN p.std_dev_res_time > s.mean_std_res_time + 2 * s.std_std_res_time THEN 'High Variability'
       WHEN p.within_average_resolutions > s.mean_within_avg_res + 2 * s.std_within_avg_res THEN 'Overperforming'
       ELSE 'Normal'
   END AS outlier_flag
FROM pci_formula p
INNER JOIN skillset_stats s 
   ON p.skillset = s.skillset
ORDER BY p.pci_index DESC;

-- ========================================================================
-- SECTION 14: COACHING NEEDS IDENTIFICATION (AGENTS)
-- ========================================================================
-- Purpose: Identify which agents need coaching based on PCI
-- PCI < 0.49 = High coaching priority
-- PCI 0.50-0.59 = Medium priority
-- PCI >= 0.60 = Low priority

WITH stats AS (
   SELECT
       agent_name,
       skillset,
       AVG(resolution_time) AS avg_res_time
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND agent_name <> ''
       AND agent_name IS NOT NULL
   GROUP BY agent_name, skillset
),
complaints AS (
   SELECT
       c.agent_name,
       c.skillset,
       s.avg_res_time,
       COUNT(c.complaint_id) AS total_complaints,
       SUM(CASE WHEN c.resolution_time > s.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN c.resolution_time <= s.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions
   FROM customer_intelligence c
   INNER JOIN stats s
       ON c.agent_name = s.agent_name
       AND c.skillset = s.skillset
   WHERE c.complaint_date <= GETDATE()
       AND c.agent_name IS NOT NULL
       AND c.agent_name <> ''
       AND c.signup_date <= GETDATE()
   GROUP BY c.agent_name, c.skillset, s.avg_res_time
),
pci AS (
   SELECT
       agent_name,
       skillset,
       avg_res_time,
       total_complaints,
       within_average_resolutions,
       above_average_resolutions,
       ROUND(1.0 * within_average_resolutions/total_complaints, 2) AS pci_index
   FROM complaints
)
SELECT
   agent_name,
   skillset,
   avg_res_time,
   total_complaints,
   within_average_resolutions,
   above_average_resolutions,
   pci_index,
   -- Coaching priority assignment
   CASE
       WHEN pci_index >= 0.60 THEN 'Consistent Performer - Low Coaching Priority'
       WHEN pci_index BETWEEN 0.50 AND 0.59 THEN 'Average Performer - Medium Coaching Priority'
       ELSE 'Low Performer - High Coaching Priority'
   END AS coaching_status 
FROM pci;

-- ========================================================================
-- SECTION 15: COACHING NEEDS IDENTIFICATION (SKILLSETS)
-- ========================================================================
-- Purpose: Identify skillset-level coaching needs

WITH skillsets AS (
   SELECT
       skillset,
       AVG(resolution_time) AS avg_res_time
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND agent_name <> ''
       AND agent_name IS NOT NULL
       AND signup_date <= GETDATE()
   GROUP BY skillset
),
complaints AS (
   SELECT 
       c.skillset,
       s.avg_res_time,
       COUNT(c.complaint_id) AS total_complaints,
       COUNT(DISTINCT c.agent_id) AS total_agents,
       SUM(CASE WHEN c.resolution_time > s.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN c.resolution_time < s.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions
   FROM customer_intelligence c
   INNER JOIN skillsets s 
       ON c.skillset = s.skillset
   WHERE c.complaint_date <= GETDATE()
       AND c.signup_date <= GETDATE()
       AND c.agent_name <> ''
       AND c.agent_name IS NOT NULL
   GROUP BY c.skillset, s.avg_res_time
)
SELECT
    skillset,
   avg_res_time,
   total_complaints,
   total_agents,
   above_average_resolutions,
   within_average_resolutions,
   ROUND(1.0 * within_average_resolutions/total_complaints, 2) AS pci_index
FROM complaints;

-- ========================================================================
-- SECTION 16: REPEAT INTENSITY ANALYSIS (AGENTS)
-- ========================================================================
-- Purpose: Measure how many unique customers vs total complaints each agent handles
-- Lower repeat_ratio = more repeat customers (potential quality issue)

SELECT
   agent_name,
   COUNT(*) AS total_complaints,
   COUNT(DISTINCT customer_id) AS unique_customers,
   ROUND(1.0 * COUNT(DISTINCT customer_id)/COUNT(*),2) AS repeat_ratio
FROM customer_intelligence
WHERE complaint_date <= GETDATE()
   AND agent_name IS NOT NULL
   AND agent_name <> ''
   AND signup_date <= GETDATE()
GROUP BY agent_name 
ORDER BY repeat_ratio;

-- ========================================================================
-- SECTION 17: COMPREHENSIVE AGENT ANALYSIS WITH PCI AND REPEAT RATIO
-- ========================================================================
-- Purpose: Combine PCI with repeat ratio for holistic agent evaluation

WITH stats AS (
   SELECT
       agent_name,
       AVG(resolution_time) AS avg_res_time
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND agent_name IS NOT NULL
       AND agent_name <> ''
   GROUP BY agent_name
),
repeat_analysis AS (
   -- Calculate repeat customer metrics
   SELECT
       agent_name,
       skillset,
       COUNT(complaint_id) AS total_complaints,
       COUNT(DISTINCT customer_id) AS unique_customers,
       ROUND(1.0 * COUNT(DISTINCT customer_id)/COUNT(complaint_id), 2) AS repeat_ratio
   FROM customer_intelligence 
   WHERE complaint_date <= GETDATE()
       AND signup_date <= GETDATE()
       AND agent_name IS NOT NULL
       AND agent_name <> ''
   GROUP BY agent_name, skillset
),
pci AS (
   -- Calculate PCI components
   SELECT
       ci.agent_name,
       ci.skillset,
       s.avg_res_time,
       SUM(CASE WHEN ci.resolution_time > s.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time < s.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions
   FROM customer_intelligence ci
   INNER JOIN stats s 
       ON ci.agent_name = s.agent_name
   WHERE ci.complaint_date <= GETDATE()
       AND ci.agent_name IS NOT NULL
       AND ci.agent_name <> ''
       AND ci.signup_date <= GETDATE()
   GROUP BY ci.agent_name, ci.skillset, s.avg_res_time
),
pci_calc AS (
   -- Combine all metrics
   SELECT
       p.agent_name,
       p.skillset,
       p.avg_res_time,
       r.total_complaints,
       r.unique_customers,
       r.repeat_ratio,
       p.above_average_resolutions,
       p.within_average_resolutions,
       ROUND(1.0 * p.within_average_resolutions/r.total_complaints, 2) AS pci_index
   FROM pci p 
   INNER JOIN repeat_analysis r 
       ON p.agent_name = r.agent_name
)
SELECT
   agent_name,
   skillset,
   avg_res_time,
   total_complaints,
   unique_customers,
   repeat_ratio,
   above_average_resolutions,
   within_average_resolutions,
   pci_index,
   -- Repeat intensity classification
   CASE 
       WHEN repeat_ratio >= 0.99 THEN 'Low Repeat Intensity'
       WHEN repeat_ratio BETWEEN 0.97 AND 0.989 THEN 'Moderate Repeat Intensity'
       ELSE 'High Repeat Intensity'
   END AS repeat_intensity,
   -- Coaching status
   CASE
       WHEN pci_index >= 0.60 THEN 'Consistent Performer - Low Coaching Priority'
       WHEN pci_index BETWEEN 0.50 AND 0.59 THEN 'Average Performer - Medium Coaching Priority'
       ELSE 'Low Performer - High Coaching Priority'
   END AS coaching_status
FROM pci_calc;

-- ========================================================================
-- SECTION 18: SKILLSET-LEVEL PCI AND REPEAT RATIO
-- ========================================================================
-- Purpose: Aggregate PCI and repeat metrics at skillset level

WITH stats AS (
   SELECT
       agent_name,
       AVG(resolution_time) AS avg_res_time
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
       AND agent_name IS NOT NULL
       AND agent_name <> ''
       AND signup_date <= GETDATE()
   GROUP BY agent_name
),
repeat_analysis AS (
   SELECT
       agent_name,
       skillset,
       COUNT(complaint_id) AS total_complaints,
       COUNT(DISTINCT customer_id) AS unique_customers,
       ROUND(1.0 * COUNT(DISTINCT customer_id)/COUNT(complaint_id), 2) AS repeat_ratio
   FROM customer_intelligence 
   WHERE complaint_date <= GETDATE()
   GROUP BY agent_name, skillset
),
pci AS (
   SELECT
       ci.agent_name,
       ci.skillset,
       s.avg_res_time,
       SUM(CASE WHEN ci.resolution_time > s.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time < s.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions
   FROM customer_intelligence ci
   INNER JOIN stats s 
       ON ci.agent_name = s.agent_name
   WHERE ci.complaint_date <= GETDATE()
       AND ci.agent_name <> ''
       AND ci.agent_name IS NOT NULL
       AND ci.signup_date <= GETDATE()
   GROUP BY ci.agent_name, ci.skillset, s.avg_res_time
),
pci_calc AS (
   SELECT
       p.agent_name,
       p.skillset,
       p.avg_res_time,
       r.total_complaints,
       r.unique_customers,
       r.repeat_ratio,
       p.above_average_resolutions,
       p.within_average_resolutions,
       ROUND(1.0 * p.within_average_resolutions/r.total_complaints, 2) AS pci_index
   FROM pci p 
   INNER JOIN repeat_analysis r 
       ON p.agent_name = r.agent_name
)
SELECT
   skillset,
   ROUND(AVG(avg_res_time),2) AS avg_res_time,
   SUM(total_complaints) AS total_complaints,
   SUM(unique_customers) AS unique_customers,
   ROUND(AVG(repeat_ratio),2) AS avg_repeat_ratio,
   ROUND(AVG(pci_index),2) AS avg_pci_index
FROM pci_calc
GROUP BY skillset
ORDER BY avg_repeat_ratio;

-- ========================================================================
-- SECTION 19: URGENCY-ADJUSTED PERFORMANCE ANALYSIS (AGENTS)
-- ========================================================================
-- Purpose: Evaluate agent performance considering urgency of cases handled
-- Maps urgency levels to scores: High=3, Medium=2, Low=1

WITH stats AS (
   SELECT
       agent_name,
       AVG(resolution_time) AS avg_res_time
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
   AND agent_name IS NOT NULL
       AND agent_name <> ''
       AND signup_date <= GETDATE()
   GROUP BY agent_name
),
repeat_analysis AS (
   SELECT
       agent_name,
       skillset,
       COUNT(complaint_id) AS total_complaints,
       COUNT(DISTINCT customer_id) AS unique_customers,
       ROUND(1.0 * COUNT(DISTINCT customer_id)/COUNT(complaint_id), 2) AS repeat_ratio
   FROM customer_intelligence 
   WHERE complaint_date <= GETDATE()
       AND agent_name IS NOT NULL
       AND agent_name <> ''
       AND signup_date <= GETDATE()
   GROUP BY agent_name, skillset
),
pci AS (
   SELECT
       ci.agent_name,
       ci.skillset,
       s.avg_res_time,
       SUM(CASE WHEN ci.resolution_time > s.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time < s.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions
   FROM customer_intelligence ci
   INNER JOIN stats s 
       ON ci.agent_name = s.agent_name
   WHERE ci.complaint_date <= GETDATE()
       AND ci.agent_name IS NOT NULL
       AND ci.agent_name <> ''
       AND ci.signup_date<= GETDATE()
   GROUP BY ci.agent_name, ci.skillset, s.avg_res_time
),
pci_calc AS (
   SELECT
       p.agent_name,
       p.skillset,
       p.avg_res_time,
       r.total_complaints,
       r.unique_customers,
       r.repeat_ratio,
       p.above_average_resolutions,
       p.within_average_resolutions,
       ROUND(1.0 * p.within_average_resolutions/r.total_complaints, 2) AS pci_index
   FROM pci p 
   INNER JOIN repeat_analysis r 
       ON p.agent_name = r.agent_name
),
urgency_map AS (
   -- Map urgency levels to numeric scores
   SELECT 'High' AS urgency, 3 AS urgency_score
   UNION ALL SELECT 'Medium', 2
   UNION ALL SELECT 'Low', 1
),
agent_urgency AS (
   -- Calculate average urgency score per agent
   SELECT
       c.agent_name,
       c.skillset,
       AVG(u.urgency_score * 1.0) AS avg_urgency_score
   FROM customer_intelligence c
   INNER JOIN urgency_map u
       ON c.urgency = u.urgency
   WHERE c.complaint_date <=GETDATE()
   GROUP BY c.agent_name, skillset
)
SELECT
   p.agent_name,
   p.skillset,
   p.pci_index,
   a.avg_urgency_score,
   -- Performance classification considering urgency
   CASE
       WHEN p.pci_index >= 0.6 AND a.avg_urgency_score >= 2.5 THEN 'Top Performer - High Urgency'
       WHEN p.pci_index >= 0.6 AND a.avg_urgency_score < 2.5 THEN 'Top Performer - Low Urgency'
       WHEN p.pci_index < 0.49 AND a.avg_urgency_score >= 2.5 THEN 'Needs coaching - High urgency (overloaded)'
       WHEN p.pci_index < 0.49 AND a.avg_urgency_score < 2.5 THEN 'Needs coaching - Low urgency (skill gap)'
       ELSE 'Mid-tier Performer'
   END AS performance_type
FROM pci_calc p
INNER JOIN agent_urgency a
   ON p.agent_name = a.agent_name
ORDER BY a.avg_urgency_score DESC, p.pci_index DESC;

-- ========================================================================
-- SECTION 20: URGENCY-ADJUSTED PERFORMANCE ANALYSIS (SKILLSETS)
-- ========================================================================
-- Purpose: Aggregate urgency analysis at skillset level

WITH stats AS (
   SELECT
       agent_name,
       AVG(resolution_time) AS avg_res_time
   FROM customer_intelligence
   WHERE complaint_date <= GETDATE()
   GROUP BY agent_name
),
repeat_analysis AS (
   SELECT
       agent_name,
       skillset,
       COUNT(complaint_id) AS total_complaints,
       COUNT(DISTINCT customer_id) AS unique_customers,
       ROUND(1.0 * COUNT(DISTINCT customer_id)/COUNT(complaint_id), 2) AS repeat_ratio
   FROM customer_intelligence 
   WHERE complaint_date <= GETDATE()
   GROUP BY agent_name, skillset
),
pci AS (
   SELECT
       ci.agent_name,
       ci.skillset,
       s.avg_res_time,
       SUM(CASE WHEN ci.resolution_time > s.avg_res_time THEN 1 ELSE 0 END) AS above_average_resolutions,
       SUM(CASE WHEN ci.resolution_time < s.avg_res_time THEN 1 ELSE 0 END) AS within_average_resolutions
   FROM customer_intelligence ci
   INNER JOIN stats s 
       ON ci.agent_name = s.agent_name
   WHERE ci.complaint_date <= GETDATE()
   GROUP BY ci.agent_name, ci.skillset, s.avg_res_time
),
pci_calc AS (
   SELECT
       p.agent_name,
       p.skillset,
       p.avg_res_time,
       r.total_complaints,
       r.unique_customers,
       r.repeat_ratio,
       p.above_average_resolutions,
       p.within_average_resolutions,
       ROUND(1.0 * p.within_average_resolutions/r.total_complaints, 2) AS pci_index
   FROM pci p 
   INNER JOIN repeat_analysis r 
       ON p.agent_name = r.agent_name
),
urgency_map AS (
   SELECT 'High' AS urgency, 3 AS urgency_score
   UNION ALL SELECT 'Medium', 2
   UNION ALL SELECT 'Low', 1
),
agent_urgency AS (
   SELECT
       c.agent_name,
       c.skillset,
       AVG(u.urgency_score * 1.0) AS avg_urgency_score
   FROM customer_intelligence c
   INNER JOIN urgency_map u
       ON c.urgency = u.urgency
   WHERE c.complaint_date <=GETDATE()
   GROUP BY c.agent_name, skillset
)
SELECT
   p.skillset,
   ROUND(AVG(p.pci_index),2) AS avg_pci_index,
   ROUND(AVG(a.avg_urgency_score),2) AS avg_urgency_score
FROM pci_calc p
INNER JOIN agent_urgency a
   ON p.agent_name = a.agent_name
GROUP BY p.skillset;

-- ========================================================================
-- SECTION 21: UNASSIGNED COMPLAINTS ANALYSIS
-- ========================================================================
-- Purpose: Identify scale of complaints not assigned to agents
-- Critical metric for workload distribution issues

WITH responsibility AS (
   -- Calculate assignment metrics
   SELECT
       SUM(CASE WHEN agent_name IS NOT NULL AND agent_name <> '' THEN 1 ELSE 0 END) AS complaints_assigned_to_agents,
       SUM(CASE WHEN agent_name IS NULL or agent_name = '' THEN 1 ELSE 0 END) AS unworked_complaints,
       COUNT(complaint_id) AS total_complaints,
       CONCAT(ROUND(100.0 *  SUM(CASE WHEN agent_name IS NULL or agent_name = '' THEN 1 ELSE 0 END)/COUNT(complaint_id), 2), '%') AS active_complaints_without_agents_pct
   FROM customer_intelligence
   WHERE signup_date <= GETDATE()
       AND complaint_date <= GETDATE()
)
SELECT
   COUNT(DISTINCT ci.customer_id) AS customers_with_ignored_complaints,
   r.total_complaints,
   r.complaints_assigned_to_agents,
   r.unworked_complaints,
   r.active_complaints_without_agents_pct
FROM customer_intelligence ci
CROSS JOIN responsibility r
WHERE ci.signup_date <= GETDATE()
   AND ci.complaint_date <= GETDATE()
GROUP BY 
   r.total_complaints, r.complaints_assigned_to_agents, r.unworked_complaints, r.active_complaints_without_agents_pct;

-- ========================================================================
-- END OF AGENT & OPERATIONAL PERFORMANCE ANALYSIS
-- ========================================================================
