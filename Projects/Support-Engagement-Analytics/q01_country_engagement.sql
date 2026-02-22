
USE SupportEngagement;

-- q01_country_engagement.sql
-- Analysis: Country Engagement Summary
--
-- Purpose:
--   Measure user engagement at the country level by aggregating
--   user activity and session behavior.
--
-- Metrics:
--   - country
--   - total_users
--   - active_users (users with >= 1 session)
--   - total_sessions
--   - total_session_minutes
--   - avg_minutes_per_active_user
--
-- Assumptions:
--   - Active user is defined as a user with at least one session
--   - Countries with zero sessions are included in the output
--   - Division by zero is handled safely
--
-- Notes:
--   - LEFT JOIN ensures all users are included
--   - Aggregation grain is one row per country

SELECT u.country
    ,COUNT(DISTINCT u.USER_ID) AS total_users
    ,COUNT(DISTINCT s.USER_ID) AS active_users
    ,COUNT(s.Session_id) AS total_sessions
    ,COALESCE(SUM(s.session_minutes),0) AS total_session_minutes
    ,CAST(COALESCE(SUM(s.session_minutes), 0) * 1.0 / NULLIF(COUNT(DISTINCT s.user_id),0) AS DECIMAL(18,2)) AS avg_minutes_per_active_user
FROM dbo.Users u 
LEFT JOIN dbo.Sessions s
    ON u.user_id = s.user_id
GROUP BY u.country
ORDER BY total_session_minutes DESC;


