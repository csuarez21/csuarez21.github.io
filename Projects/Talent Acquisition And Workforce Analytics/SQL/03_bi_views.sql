USE TARI;
GO

------------------------------------------------------------
-- 0) BI Schema
------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'pa_bi')
    EXEC('CREATE SCHEMA pa_bi');
GO

------------------------------------------------------------
-- 1) Candidate Funnel (grain = candidate x stage)
------------------------------------------------------------
CREATE OR ALTER VIEW pa_bi.v_candidate_funnel AS
SELECT
    c.candidate_id,
    c.req_id,
    r.department,
    r.role_family,
    r.job_title,
    r.job_level,
    r.location,
    c.source_channel,
    c.gender,
    c.ethnicity,
    c.applied_date,
    e.stage_name,
    e.stage_entered_at,
    e.stage_exited_at,
    e.outcome,
    e.outcome_reason,
    DATEDIFF(DAY, e.stage_entered_at, e.stage_exited_at) AS stage_days
FROM pa.candidates c
JOIN pa.job_requisitions r
    ON r.req_id = c.req_id
JOIN pa.candidate_stage_events e
    ON e.candidate_id = c.candidate_id;
GO

------------------------------------------------------------
-- 2) Requisition Summary (grain = req_id)
------------------------------------------------------------
CREATE OR ALTER VIEW pa_bi.v_requisition_summary AS
WITH hires AS (
    SELECT
        req_id_hired_from AS req_id,
        COUNT(*) AS hires
    FROM pa.employees
    GROUP BY req_id_hired_from
)
SELECT
    r.req_id,
    r.department,
    r.role_family,
    r.job_title,
    r.job_level,
    r.location,
    r.recruiter_id,
    r.hiring_manager_id,
    r.headcount_needed,
    r.posted_date,
    r.closed_date,
    r.req_status,
    CASE
        WHEN r.closed_date IS NOT NULL
        THEN DATEDIFF(DAY, r.posted_date, r.closed_date)
    END AS time_to_fill_days,
    COALESCE(h.hires, 0) AS hires
FROM pa.job_requisitions r
LEFT JOIN hires h
    ON h.req_id = r.req_id;
GO

------------------------------------------------------------
-- 3) Offer Summary (grain = offer)
------------------------------------------------------------
CREATE OR ALTER VIEW pa_bi.v_offer_summary AS
SELECT
    o.offer_id,
    o.candidate_id,
    o.req_id,
    r.department,
    r.job_title,
    r.job_level,
    c.source_channel,
    o.offer_extended_date,
    o.offer_accepted_date,
    o.offer_status,
    o.base_salary_offer,
    o.equity_offer_usd,
    o.start_date_planned,
    CASE WHEN o.offer_status = 'Accepted' THEN 1 ELSE 0 END AS is_accepted
FROM pa.offers o
JOIN pa.candidates c
    ON c.candidate_id = o.candidate_id
JOIN pa.job_requisitions r
    ON r.req_id = o.req_id;
GO

------------------------------------------------------------
-- 4) Workforce Summary (grain = employee)
------------------------------------------------------------
CREATE OR ALTER VIEW pa_bi.v_workforce_summary AS
SELECT
    e.employee_id,
    e.req_id_hired_from,
    e.hire_date,
    e.termination_date,
    e.department,
    e.role_family,
    e.job_title,
    e.job_level,
    e.location,
    e.base_salary,
    e.gender,
    e.ethnicity,
    CASE WHEN e.termination_date IS NULL THEN 1 ELSE 0 END AS is_active,
    DATEDIFF(DAY, e.hire_date, COALESCE(e.termination_date, GETDATE())) AS tenure_days
FROM pa.employees e;
GO

------------------------------------------------------------
-- 5) Headcount Trend (monthly grain)
------------------------------------------------------------
CREATE OR ALTER VIEW pa_bi.v_headcount_monthly AS
WITH months AS (
    SELECT DISTINCT
        DATEFROMPARTS(YEAR(hire_date), MONTH(hire_date), 1) AS month_start
    FROM pa.employees
)
SELECT
    m.month_start,
    COUNT(e.employee_id) AS headcount
FROM months m
LEFT JOIN pa.employees e
    ON e.hire_date <= EOMONTH(m.month_start)
   AND (e.termination_date IS NULL OR e.termination_date > EOMONTH(m.month_start))
GROUP BY m.month_start;
GO

------------------------------------------------------------
-- 6) Quality of Hire (performance + engagement proxy)
------------------------------------------------------------
CREATE OR ALTER VIEW pa_bi.v_quality_of_hire AS
WITH perf AS (
    SELECT
        employee_id,
        AVG(performance_rating) AS avg_performance
    FROM pa.performance_reviews
    GROUP BY employee_id
),
eng AS (
    SELECT
        employee_id,
        AVG(engagement_score) AS avg_engagement
    FROM pa.engagement_surveys
    GROUP BY employee_id
),
promo AS (
    SELECT DISTINCT employee_id
    FROM pa.promotions
)
SELECT
    e.employee_id,
    e.department,
    e.job_level,
    e.hire_date,
    p.avg_performance,
    en.avg_engagement,
    CASE WHEN pr.employee_id IS NOT NULL THEN 1 ELSE 0 END AS promoted_flag
FROM pa.employees e
LEFT JOIN perf p ON p.employee_id = e.employee_id
LEFT JOIN eng en ON en.employee_id = e.employee_id
LEFT JOIN promo pr ON pr.employee_id = e.employee_id;
GO


SELECT COUNT(*) FROM pa_bi.v_candidate_funnel;
SELECT COUNT(*) FROM pa_bi.v_requisition_summary;
SELECT COUNT(*) FROM pa_bi.v_offer_summary;
SELECT COUNT(*) FROM pa_bi.v_workforce_summary;