-- =========================================
-- INDEX STRATEGY
-- Purpose: Reduce scan-heavy operations across core analytical queries.
-- Focus: Complaints, customers, resolutions, agents, product_tags.
-- Rationale: Queries repeatedly filter, group, and join on these fields.
-- =========================================


-- =========================================
-- COMPLAINTS TABLE
-- =========================================

-- Supports all customer-level joins and risk-scoring logic.
-- Prevents full scans during complaint volume lookups.
CREATE NONCLUSTERED INDEX idx_complaints_customer_id 
ON complaints(customer_id);

-- Enables efficient time-based filtering for trends, recency, and 30-day windows.
-- Required for volume_risk and time-series analysis.
CREATE NONCLUSTERED INDEX idx_complaints_date 
ON complaints(date);

-- Supports product-area trend analysis and theme frequency counts.
-- Used in weekly and monthly summaries.
CREATE NONCLUSTERED INDEX idx_complaints_product_area
ON complaints(product_area);

-- Supports channel-based segmentation and urgency scoring.
-- Reduces cost of channel distribution queries.
CREATE NONCLUSTERED INDEX idx_complaints_channel
ON complaints(channel);

-- Enables filtering for urgent cases inside operational dashboards.
-- Critical for performance when urgency is derived or updated.
CREATE NONCLUSTERED INDEX idx_complaints_urgency
ON complaints(urgency);

SELECT * FROM customer_risk
-- =========================================
-- CUSTOMERS TABLE
-- =========================================

-- Used for region-level segmentation and performance comparisons.
-- Reduces overhead on Power BI slicers based on region.
CREATE NONCLUSTERED INDEX idx_customers_region
ON customers(region);

-- Speeds up segment-based calculations for churn risk and complaint frequency.
CREATE NONCLUSTERED INDEX idx_customers_segment
ON customers(segment);



-- =========================================
-- RESOLUTIONS TABLE
-- =========================================

-- Primary join path between complaints and resolutions.
-- Prevents scans during resolution-rate and severity calculations.
CREATE NONCLUSTERED INDEX idx_resolutions_complaints
ON resolutions(complaint_id);

-- Required for agent-performance analytics and time-to-resolution measures.
CREATE NONCLUSTERED INDEX idx_resolutions_agent
ON resolutions(agent_id);

-- Enables window functions for operational trending over resolution dates.
-- Avoids repeated scans in period-based resolution summaries.
CREATE NONCLUSTERED INDEX idx_resolutions_date
ON resolutions(resolution_date);



-- =========================================
-- AGENTS TABLE
-- =========================================

-- Used in regional performance breakdowns and workforce evaluation.
CREATE NONCLUSTERED INDEX idx_agents_location
ON agents(location);



-- =========================================
-- PRODUCT_TAGS TABLE
-- =========================================

-- Composite index because both columns drive joins and tag-frequency queries.
-- Supports product-level theme detection and trending.
CREATE NONCLUSTERED INDEX idx_producttags_complaint_tag
ON p.product_tags(complaint_id, product_tag_id);
