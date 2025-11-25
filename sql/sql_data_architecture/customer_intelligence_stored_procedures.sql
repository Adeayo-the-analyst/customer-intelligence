-- ============================================================
-- STORED PROCEDURE: WEEKLY OR MONTHLY COMPLAINT SUMMARY
-- ============================================================
-- Purpose: Generate complaint intelligence for the last N days.
-- Input:  @period accepts WEEKLY or MONTHLY and maps to 7 or 30 days.
-- Output: Complaint themes, urgency distribution, product-area counts,
--         and agent performance metrics.
-- Notes:  Each block isolates one analytical slice for auditability.

CREATE PROCEDURE sp_generate_complaint_summary 
    @period VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    -- Map period to day-window
    DECLARE @days INT;
    IF @period = 'WEEKLY'  SET @days = 7;
    ELSE IF @period = 'MONTHLY' SET @days = 30;
    ELSE SET @days = 7;

    -- Top complaint themes
    SELECT TOP 5 
        keywords AS complaint_theme,
        COUNT(*) AS total_complaints
    FROM customer_intelligence
    WHERE keywords IS NOT NULL
      AND complaint_date >= DATEADD(DAY, -@days, GETDATE())
    GROUP BY keywords;

    -- Complaints by urgency classification
    SELECT 
        urgency AS urgency_level,
        COUNT(*) AS total
    FROM customer_intelligence
    WHERE complaint_date >= DATEADD(DAY, -@days, GETDATE())
    GROUP BY urgency;

    -- Complaint distribution by product area
    SELECT 
        product_area,
        COUNT(*) AS total_complaints
    FROM customer_intelligence
    WHERE complaint_date >= DATEADD(DAY, -@days, GETDATE())
    GROUP BY product_area;

    -- Top agents ranked by mean resolution time
    SELECT TOP 5 
        agent_name,
        AVG(resolution_time) AS average_resolution_time
    FROM customer_intelligence
    WHERE resolution_time IS NOT NULL
      AND complaint_date >= DATEADD(DAY, -@days, GETDATE())
    GROUP BY agent_name;
END;

-- Execution example
EXEC sp_generate_complaint_summary @period = 'MONTHLY';
