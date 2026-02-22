USE SupportEngagement;

-- q04_backlog_by_day.sql
-- Analysis: Backlog Trend (End-of-Day Open Tickets)
--
-- Purpose:
--   Measure operational workload over time by calculating
--   the number of tickets open at the end of each day.
--
-- Metrics:
--   - as_of_date
--   - open_tickets_end_of_day
--
-- Definitions:
--   A ticket is considered open on date d if:
--     - created_at (date) <= d
--     - AND (resolved_at is NULL OR resolved_at (date) > d)
--
-- Assumptions:
--   - Date comparisons use CAST(datetime AS DATE)
--   - End-of-day logic is based on calendar date boundaries
--   - Includes dates with zero open tickets
--
-- Notes:
--   - Uses a date spine to generate continuous reporting dates
--   - Output grain is one row per day

DECLARE @Start DATE = (SELECT MIN(CAST(created_at AS DATE)) FROM dbo.SupportTickets)
DECLARE @End DATE = (SELECT MAX(CAST(COALESCE(resolved_at, created_at) AS DATE)) FROM dbo.SupportTickets)
DECLARE @DaysBetween INT = DATEDIFF(Day, @Start, @end); -- Use this to find exact number of days between to use in the maxrecursion


WITH DateSpan AS
(
    SELECT @Start AS as_of_date
    UNION ALL
    SELECT DATEADD(day, 1, as_of_date)
    FROM DateSpan 
    WHERE as_of_date < @End
)
,convertdate AS
(
    SELECT *
            , CAST(created_at AS DATE) AS created_at_modified
            , CAST(resolved_at AS DATE) AS resolved_at_modified
    FROM dbo.SupportTickets 
)

SELECT  d.as_of_date
        , SUM(CASE
                WHEN st.created_at_modified <= d.as_of_date 
                    AND (st.resolved_at IS NULL 
                        OR st.resolved_at_modified > d.as_of_date) THEN 1
                ELSE 0
                END) 
         AS open_tickets_end_of_day
FROM    DateSpan d  
LEFT JOIN convertdate st
    ON d.as_of_date >= st.created_at_modified
GROUP BY d.as_of_date
ORDER BY d.as_of_date
OPTION (MAXRECURSION 32767)
