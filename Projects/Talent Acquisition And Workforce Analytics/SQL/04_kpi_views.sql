USE TARI;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'pa_bi')
    EXEC('CREATE SCHEMA pa_bi');
GO

/*
--------------------------------------------------------------------------------
KPI View 1: Recruiting Funnel Conversion
View Name: pa_bi.v_kpi_funnel_conversion
Grain: department x job_level x source_channel
--------------------------------------------------------------------------------

Business Purpose
--------------------------------------------------------------------------------
This view measures candidate progression through the recruiting funnel.
It quantifies how effectively candidates move from application to hire
and highlights conversion bottlenecks across departments and sourcing channels.

This KPI supports:
- Recruiting performance evaluation
- Source effectiveness analysis
- Funnel drop-off identification
- Hiring process optimization

Metric Definitions
--------------------------------------------------------------------------------
applied_candidates
    Candidates who reached the Applied stage.

screen_candidates
    Candidates who reached RecruiterScreen.

hmreview_candidates
    Candidates who reached Hiring Manager Review.

onsite_candidates
    Candidates who reached Onsite.

offer_candidates
    Candidates who successfully reached Offer stage (outcome = 'Pass').

start_candidates
    Candidates who successfully reached Start stage (outcome = 'Pass').

offer_rate
    offer_candidates / applied_candidates

start_rate
    start_candidates / applied_candidates

onsite_to_offer_rate
    offer_candidates / onsite_candidates

Design Notes
--------------------------------------------------------------------------------
- Stage flags are derived using MAX(CASE...) to prevent double counting.
- Aggregation is performed at candidate grain before computing conversion rates.
- Safe division (NULLIF) prevents divide-by-zero errors.
- Raw decimal precision is preserved for Tableau formatting.

This view serves as the foundational recruiting effectiveness metric layer.
--------------------------------------------------------------------------------
*/
CREATE OR ALTER VIEW pa_bi.v_kpi_funnel_conversion AS
WITH candidates_counts
AS
(
SELECT candidate_id
        ,department
        ,job_level
        ,source_channel
        ,MAX(CASE WHEN stage_name = 'Applied' THEN 1 ELSE 0 END) AS applied_count
        ,MAX(CASE WHEN stage_name = 'RecruiterScreen' THEN 1 ELSE 0 END) AS screen_count
        ,MAX(CASE WHEN stage_name = 'HMReview' THEN 1 ELSE 0 END) AS hmreview_count
        ,MAX(CASE WHEN stage_name = 'Onsite' THEN 1 ELSE 0 END) AS onsite_count    
        ,MAX(CASE WHEN stage_name = 'Offer' AND outcome = 'Pass' THEN 1 ELSE 0 END) AS offer_count   
        ,MAX(CASE WHEN stage_name = 'Start' AND outcome = 'Pass' THEN 1 ELSE 0 END) AS start_count                                         
FROM pa_bi.v_candidate_funnel
GROUP BY candidate_id, department, job_level, source_channel
)

SELECT  Department
        ,job_level
        ,source_channel
        ,SUM(applied_count) AS applied_candidates
        ,SUM(screen_count) AS screen_candidates
        ,SUM(HMReview_count) AS hmreview_candidates
        ,SUM(onsite_count) AS onsite_candidates
        ,SUM(offer_count) AS offer_candidates
        ,SUM(Start_count) AS start_candidates
        ,SUM(offer_count) * 1.0 / NULLIF(SUM(applied_count), 0)  AS offer_rate
        ,SUM(start_count) * 1.0 / NULLIF(SUM(applied_count), 0) AS start_rate
        ,SUM(offer_count) * 1.0 / NULLIF(SUM(onsite_count), 0)AS onsite_to_offer_rate
FROM    candidates_counts
GROUP BY department, job_level, source_channel

GO

/*
--------------------------------------------------------------------------------
KPI View 2: Recruiting Stage Speed
View Name: pa_bi.v_kpi_stage_speed
Grain: department x job_level x source_channel x stage_name
--------------------------------------------------------------------------------

Business Purpose
--------------------------------------------------------------------------------
This view measures the duration candidates spend in each recruiting stage.
It identifies operational bottlenecks and highlights slow-moving segments.

This KPI supports:
- Process efficiency evaluation
- SLA monitoring by recruiting stage
- Bottleneck detection (p90 tail analysis)
- Source-level speed comparisons

Metric Definitions
--------------------------------------------------------------------------------
candidates_in_stage
    Distinct candidates who entered the stage.

avg_stage_days
    Average number of days spent in the stage.

median_stage_days
    50th percentile (p50) of stage duration.

p90_stage_days
    90th percentile of stage duration.

Design Notes
--------------------------------------------------------------------------------
- stage_days is precomputed in the BI layer.
- PERCENTILE_CONT is used for median and p90 calculations.
- Window functions are separated from grouped aggregates.
- DISTINCT is used to collapse repeated window outputs.
- Raw precision is preserved for visualization formatting.

This view enables granular stage-level operational diagnostics.
--------------------------------------------------------------------------------
*/
CREATE OR ALTER VIEW pa_bi.v_kpi_stage_speed AS
WITH candidate_data AS
(
SELECT  candidate_id
        ,department
        ,job_level
        ,source_channel
        ,stage_name
        ,stage_days
FROM    pa_bi.v_candidate_funnel
WHERE   stage_days IS NOT NULL
)
,stage_percentiles AS
(
    SELECT DISTINCT department
            ,job_level
            ,source_channel
            ,stage_name
            ,PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY stage_days)OVER(PARTITION BY department, job_level, source_channel, stage_name) AS median_stage_days
            ,PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY stage_days)OVER(PARTITION BY department, job_level, source_channel, stage_name) AS p90_stage_days
    FROM candidate_data
)
,stage_agg AS
(
    SELECT department
            ,job_level
            ,source_channel
            ,stage_name
            ,COUNT(DISTINCT candidate_id) AS candidates_in_stage
            ,avg(stage_days * 1.0) AS avg_stage_days
    FROM candidate_data
    GROUP BY department, job_level, source_channel, stage_name
)

SELECT p.department
        ,p.job_level
        ,p.source_channel
        ,p.stage_name
        ,a.candidates_in_stage
        ,a.avg_stage_days
        ,p.median_stage_days
        ,p.p90_stage_days    
FROM stage_percentiles p  
JOIN    stage_agg a
    ON p.department = a.department
        AND p.job_level = a.job_level
        AND p.source_channel = a.source_channel
        AND p.stage_name = a.stage_name

GO    

/*
--------------------------------------------------------------------------------
KPI View 3: Time to Fill
View Name: pa_bi.v_kpi_time_to_fill
Grain: department x job_level x location
--------------------------------------------------------------------------------

Business Purpose
--------------------------------------------------------------------------------
This view measures requisition closing speed across organizational segments.
It provides visibility into overall hiring velocity and tail delays.

This KPI supports:
- Workforce planning
- Capacity forecasting
- Hiring performance evaluation
- Executive reporting on fill efficiency

Metric Definitions
--------------------------------------------------------------------------------
reqs_closed
    Count of closed requisitions with valid time_to_fill_days.

avg_time_to_fill_days
    Average time from posted_date to closed_date.

median_time_to_fill_days
    50th percentile (p50) time to fill.

p90_time_to_fill_days
    90th percentile time to fill.

Design Notes
--------------------------------------------------------------------------------
- Only requisitions with req_status = 'Closed' are included.
- time_to_fill_days is precomputed in the BI layer.
- Percentiles are calculated using PERCENTILE_CONT.
- Window calculations are separated from aggregate calculations.
- Raw decimals are returned for Tableau formatting.

This view provides hiring speed benchmarking across departments and locations.
--------------------------------------------------------------------------------
*/
CREATE OR ALTER VIEW pa_bi.v_kpi_time_to_fill AS
WITH req_data AS
( 
SELECT req_id
        ,department
        ,job_level
        ,location
        ,time_to_fill_days
FROM pa_bi.v_requisition_summary
WHERE req_status = 'Closed'
    AND time_to_fill_days IS NOT NULL
)
, ttf_percentiles AS
(
SELECT DISTINCT department
        ,job_level
        ,location
        ,PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY time_to_fill_days)OVER(PARTITION BY department, job_level, location) AS median_time_to_fill_days
        ,PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY time_to_fill_days)OVER(PARTITION BY department, job_level, location) AS p90_time_to_fill_days
FROM req_data
)
, ttf_agg AS
(
SELECT department
        ,job_level
        ,location
        ,COUNT(DISTINCT req_id) AS reqs_closed
        ,avg(time_to_fill_days * 1.0) AS avg_time_to_fill_days
FROM req_data
GROUP BY department, job_level, location
)

SELECT p.department
        ,p.job_level
        ,p.location
        ,a.reqs_closed
        ,a.avg_time_to_fill_days
        ,p.median_time_to_fill_days
        ,p.p90_time_to_fill_days
FROM ttf_percentiles p 
JOIN ttf_agg a
    ON p.department = a.department
        AND p.job_level = a.job_level
        AND p.location = a.location

GO 

/*
--------------------------------------------------------------------------------
KPI View 4: Attrition Metrics
View Name: pa_bi.v_kpi_attrition
Grain: department x job_level x location
--------------------------------------------------------------------------------

Business Purpose
--------------------------------------------------------------------------------
This view measures workforce turnover and early attrition risk.
It provides insight into retention health across organizational segments.

This KPI supports:
- Retention analysis
- Early tenure risk detection
- Workforce stability monitoring
- Recruiting backfill planning

Metric Definitions
--------------------------------------------------------------------------------
active_headcount
    Employees with termination_date IS NULL.

terminations
    Employees with termination_date IS NOT NULL.

attrition_rate
    terminations / total_employees.

early_attrition_90d
    Employees who terminated within 90 days of hire.

early_attrition_rate_90d
    early_attrition_90d / total_employees.

Design Notes
--------------------------------------------------------------------------------
- Metrics are calculated via conditional aggregation.
- Safe division (NULLIF) prevents divide-by-zero errors.
- Rates are returned as raw decimals for dashboard formatting.
- Grain aligns with recruiting KPIs to support cross-analysis.

This view enables retention diagnostics and supports future predictive modeling.
--------------------------------------------------------------------------------
*/
CREATE OR ALTER VIEW pa_bi.v_kpi_attrition AS
WITH employee_data AS
(
    SELECT employee_id
            ,department
            ,job_level
            ,location
            ,hire_date
            ,termination_date         
    FROM pa.employees
)
, employee_agg AS
(
    SELECT department
            ,job_level
            ,location
            ,SUM(CASE WHEN termination_date IS NULL THEN 1 ELSE 0 END) AS active_headcount
            ,SUM(CASE WHEN termination_date IS NOT NULL THEN 1 ELSE 0 END) AS terminations
            ,COUNT(*) AS total_employees
            ,SUM(CASE WHEN termination_date IS NOT NULL AND DATEDIFF(DAY, hire_date, termination_date) <= 90 THEN 1 ELSE 0 END) AS early_attrition_90d
    FROM employee_Data 
    GROUP BY department, job_level, location
)

SELECT department
        ,job_level
        ,location
        ,active_headcount
        ,terminations
        ,terminations * 1.0 / NULLIF(total_employees,0) AS attrition_rate
        ,early_attrition_90d
        ,early_attrition_90d * 1.0 / NULLIF(total_employees,0) AS early_attrition_rate_90d
FROM employee_agg

GO
