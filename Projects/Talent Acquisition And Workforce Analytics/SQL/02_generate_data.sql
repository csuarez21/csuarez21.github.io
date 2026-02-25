
USE TARI;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

/****************************************************************************************
TARI – Medium Hiring Funnel Seed Script

DESCRIPTION
This script generates a medium-sized, memory-safe hiring dataset for the TARI database.
It is designed to run safely inside a Docker SQL Server environment while producing
realistic funnel drop-offs and downstream HR analytics data.

DATA GENERATED
- 6 Recruiters
- 8 Hiring Managers
- 25 Job Requisitions (Closed)
- 12 Candidates per Requisition (~300 total)
- Structured Stage Events with guaranteed drop-offs
- 2 Offers per Requisition (1 Accepted, 1 Declined)
- 1 Employee per Requisition (Accepted Offer)
- Engagement Surveys (2 per employee)
- Performance Reviews (1 per employee)
- Promotions (L3 → L4, L4 → L5 only; constraint-safe)

FUNNEL STRUCTURE (Per Requisition)
Applied:          12
Recruiter Screen: 8
HM Review:        5
Onsite:           3
Offer:            2
Background:       1
Start:            1

DESIGN GOALS
- Deterministic data generation (reproducible results)
- Guaranteed conversion drop-offs
- Respect table constraints (including CK_promo_level_change)
- Avoid large memory grants
- Safe for Docker SQL Server (uses MAXDOP 1 on heavy inserts)

USAGE
1. Ensure database TARI exists.
2. Run entire script in one execution.
3. Script deletes existing data in pa.* tables before regenerating.

****************************************************************************************/

-- CLEAN TABLES (FK-safe order)
DELETE FROM pa.promotions;
DELETE FROM pa.engagement_surveys;
DELETE FROM pa.performance_reviews;
DELETE FROM pa.employees;
DELETE FROM pa.offers;
DELETE FROM pa.candidate_stage_events;
DELETE FROM pa.candidates;
DELETE FROM pa.job_requisitions;
DELETE FROM pa.hiring_managers;
DELETE FROM pa.recruiters;

-- SMALL TALLY
IF OBJECT_ID('tempdb..#N') IS NOT NULL DROP TABLE #N;
;WITH n AS
(
    SELECT TOP (5000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS n
    FROM sys.all_objects a
    CROSS JOIN sys.all_objects b
)
SELECT n INTO #N FROM n;
CREATE UNIQUE CLUSTERED INDEX IX_N ON #N(n);

-- RECRUITERS (6)
INSERT INTO pa.recruiters (recruiter_name, recruiter_team, location, active_flag)
VALUES
('Alex Kim','Tech','SF Bay Area',1),
('Jordan Lee','Tech','SF Bay Area',1),
('Taylor Nguyen','Tech','Seattle',1),
('Morgan Patel','GTM','NYC',1),
('Casey Rivera','GTM','Austin',1),
('Quinn Davis','G&A','Remote-US',1);

DECLARE @Recruiters TABLE (rn INT PRIMARY KEY, recruiter_id INT, recruiter_team VARCHAR(50), location VARCHAR(100));
INSERT INTO @Recruiters(rn, recruiter_id, recruiter_team, location)
SELECT ROW_NUMBER() OVER (ORDER BY recruiter_id), recruiter_id, recruiter_team, location
FROM pa.recruiters;

-- HIRING MANAGERS (8)
INSERT INTO pa.hiring_managers (manager_name, department, location)
VALUES
('Priya Shah','Engineering','SF Bay Area'),
('Chris Wong','Engineering','Seattle'),
('Leslie Parker','Data','NYC'),
('Omar Hassan','Data','NYC'),
('Dana Scott','Support','Austin'),
('Jules Turner','Support','Remote-US'),
('Pat Reed','Sales','NYC'),
('Elena Garcia','G&A','SF Bay Area');

DECLARE @HMs TABLE (rn INT PRIMARY KEY, hiring_manager_id INT, department VARCHAR(100), location VARCHAR(100));
INSERT INTO @HMs(rn, hiring_manager_id, department, location)
SELECT ROW_NUMBER() OVER (ORDER BY hiring_manager_id), hiring_manager_id, department, location
FROM pa.hiring_managers;

-- REQUISITIONS (25) captured with req_rn
DECLARE @Reqs TABLE
(
    req_rn INT PRIMARY KEY,
    req_id INT,
    department VARCHAR(100),
    role_family VARCHAR(100),
    job_title VARCHAR(200),
    job_level VARCHAR(10),
    location VARCHAR(100),
    recruiter_id INT,
    hiring_manager_id INT,
    posted_date DATE,
    closed_date DATE,
    req_status VARCHAR(30)
);

;WITH base AS
(
    SELECT TOP (25) n AS req_rn FROM #N ORDER BY n
),
picked AS
(
    SELECT
        b.req_rn,
        CASE WHEN b.req_rn % 5 = 1 THEN 'Engineering'
             WHEN b.req_rn % 5 = 2 THEN 'Data'
             WHEN b.req_rn % 5 = 3 THEN 'Support'
             WHEN b.req_rn % 5 = 4 THEN 'Sales'
             ELSE 'G&A' END AS department,
        CASE WHEN b.req_rn % 5 = 1 THEN 'Engineering'
             WHEN b.req_rn % 5 = 2 THEN 'Data'
             WHEN b.req_rn % 5 = 3 THEN 'Support'
             WHEN b.req_rn % 5 = 4 THEN 'Sales'
             ELSE 'G&A' END AS role_family,
        CASE WHEN b.req_rn % 5 = 1 THEN 'Software Engineer'
             WHEN b.req_rn % 5 = 2 THEN 'Data Analyst'
             WHEN b.req_rn % 5 = 3 THEN 'Support Ops Analyst'
             WHEN b.req_rn % 5 = 4 THEN 'Sales Ops Analyst'
             ELSE 'Finance Analyst' END AS job_title,
        CASE WHEN b.req_rn % 3 = 1 THEN 'L3'
             WHEN b.req_rn % 3 = 2 THEN 'L4'
             ELSE 'L5' END AS job_level,
        CASE WHEN b.req_rn % 4 = 1 THEN 'SF Bay Area'
             WHEN b.req_rn % 4 = 2 THEN 'NYC'
             WHEN b.req_rn % 4 = 3 THEN 'Austin'
             ELSE 'Remote-US' END AS location,
        (SELECT recruiter_id FROM @Recruiters WHERE rn = ((b.req_rn - 1) % 6) + 1) AS recruiter_id,
        (SELECT hiring_manager_id FROM @HMs WHERE rn = ((b.req_rn - 1) % 8) + 1) AS hiring_manager_id,
        DATEADD(DAY, (b.req_rn - 1) * 7, CAST('2025-01-01' AS DATE)) AS posted_date,
        DATEADD(DAY, 35 + (b.req_rn % 15), DATEADD(DAY, (b.req_rn - 1) * 7, CAST('2025-01-01' AS DATE))) AS closed_date
    FROM base b
)
MERGE pa.job_requisitions AS tgt
USING picked AS src
ON 1 = 0
WHEN NOT MATCHED THEN
    INSERT
    (
        department, role_family, job_title, job_level, location,
        recruiter_id, hiring_manager_id,
        headcount_needed, posted_date, closed_date, req_status
    )
    VALUES
    (
        src.department, src.role_family, src.job_title, src.job_level, src.location,
        src.recruiter_id, src.hiring_manager_id,
        1, src.posted_date, src.closed_date, 'Closed'
    )
OUTPUT
    src.req_rn,
    inserted.req_id,
    inserted.department,
    inserted.role_family,
    inserted.job_title,
    inserted.job_level,
    inserted.location,
    inserted.recruiter_id,
    inserted.hiring_manager_id,
    inserted.posted_date,
    inserted.closed_date,
    inserted.req_status
INTO @Reqs
(
    req_rn, req_id, department, role_family, job_title, job_level, location,
    recruiter_id, hiring_manager_id, posted_date, closed_date, req_status
)
OPTION (MAXDOP 1);

-- CANDIDATES (~300; 12 per req)
DECLARE @Candidates TABLE
(
    candidate_id BIGINT PRIMARY KEY,
    req_id INT,
    applied_date DATE,
    source_channel VARCHAR(50),
    gender VARCHAR(50),
    ethnicity VARCHAR(80),
    years_experience DECIMAL(4,1),
    location VARCHAR(100)
);

;WITH apps AS
(
    SELECT
        r.req_id,
        r.posted_date,
        r.location,
        r.job_level,
        n.n AS app_idx
    FROM @Reqs r
    JOIN #N n ON n.n <= 12
),
gen AS
(
    SELECT
        a.req_id,
        DATEADD(DAY, (a.app_idx - 1) % 21, a.posted_date) AS applied_date,
        CASE WHEN a.app_idx IN (1,6,11) THEN 'Referral'
             WHEN a.app_idx IN (2,7,12) THEN 'LinkedIn'
             WHEN a.app_idx IN (3,8) THEN 'Indeed'
             WHEN a.app_idx IN (4,9) THEN 'Agency'
             ELSE 'Other' END AS source_channel,
        CAST(CASE a.job_level WHEN 'L3' THEN 1.0 WHEN 'L4' THEN 4.0 ELSE 7.0 END
             + ((a.app_idx % 6) * 0.8) AS DECIMAL(4,1)) AS years_experience,
        a.location,
        CASE WHEN a.app_idx % 3 = 0 THEN 'Female' WHEN a.app_idx % 3 = 1 THEN 'Male' ELSE 'Non-binary' END AS gender,
        CASE WHEN a.app_idx % 5 = 0 THEN 'Asian'
             WHEN a.app_idx % 5 = 1 THEN 'White'
             WHEN a.app_idx % 5 = 2 THEN 'Hispanic'
             WHEN a.app_idx % 5 = 3 THEN 'Black'
             ELSE 'Two or more' END AS ethnicity
    FROM apps a
)
INSERT INTO pa.candidates
(req_id, applied_date, source_channel, years_experience, location, gender, ethnicity)
OUTPUT
    inserted.candidate_id,
    inserted.req_id,
    inserted.applied_date,
    inserted.source_channel,
    inserted.gender,
    inserted.ethnicity,
    inserted.years_experience,
    inserted.location
INTO @Candidates(candidate_id, req_id, applied_date, source_channel, gender, ethnicity, years_experience, location)
SELECT req_id, applied_date, source_channel, years_experience, location, gender, ethnicity
FROM gen
OPTION (MAXDOP 1);

-- STAGE EVENTS (guaranteed drop-offs per req)
IF OBJECT_ID('tempdb..#StageDefs') IS NOT NULL DROP TABLE #StageDefs;
CREATE TABLE #StageDefs(stage_order INT NOT NULL, stage_name VARCHAR(60) NOT NULL, enter_offset_days INT NOT NULL, dur_days INT NOT NULL);
INSERT INTO #StageDefs(stage_order, stage_name, enter_offset_days, dur_days) VALUES
(1,'Applied',0,1),
(2,'RecruiterScreen',2,1),
(3,'HMReview',5,2),
(4,'Onsite',10,2),
(5,'Offer',15,1),
(6,'Background',18,2),
(7,'Start',25,0);

;WITH ranked AS
(
    SELECT
        c.*,
        ROW_NUMBER() OVER (PARTITION BY c.req_id ORDER BY c.candidate_id) AS rn_in_req
    FROM @Candidates c
),
last_stage AS
(
    SELECT
        r.*,
        CASE
            WHEN r.rn_in_req <= 1 THEN 7      -- 1 start
            WHEN r.rn_in_req <= 2 THEN 5      -- 2 offers (offer stage reached)
            WHEN r.rn_in_req <= 3 THEN 4      -- 3 onsite
            WHEN r.rn_in_req <= 5 THEN 3      -- 5 HM review
            WHEN r.rn_in_req <= 8 THEN 2      -- 8 screen
            ELSE 1                            -- rest drop at applied
        END AS last_stage_order
    FROM ranked r
),
events AS
(
    SELECT
        l.candidate_id,
        l.req_id,
        s.stage_order,
        s.stage_name,
        DATEADD(DAY, s.enter_offset_days, CAST(l.applied_date AS DATETIME2(0))) AS entered_at,
        DATEADD(DAY, s.enter_offset_days + s.dur_days, CAST(l.applied_date AS DATETIME2(0))) AS exited_at,
        l.last_stage_order
    FROM last_stage l
    JOIN #StageDefs s ON s.stage_order <= l.last_stage_order
),
labeled AS
(
    SELECT
        e.candidate_id,
        e.req_id,
        e.stage_name,
        DATEADD(HOUR, 10, e.entered_at) AS stage_entered_at,
        DATEADD(HOUR, 17, e.exited_at) AS stage_exited_at,
        CASE
            WHEN e.stage_order < e.last_stage_order THEN 'Pass'
            WHEN e.stage_order = e.last_stage_order THEN CASE WHEN e.stage_name = 'Offer' THEN 'Pass' ELSE 'Fail' END
            ELSE 'Pass'
        END AS outcome,
        CASE
            WHEN e.stage_order = e.last_stage_order AND e.stage_name <> 'Offer'
            THEN CASE (e.candidate_id % 6)
                    WHEN 0 THEN 'Compensation mismatch'
                    WHEN 1 THEN 'Role fit'
                    WHEN 2 THEN 'Another offer'
                    WHEN 3 THEN 'Hiring manager decision'
                    WHEN 4 THEN 'Location constraint'
                    ELSE 'Interview performance'
                 END
            ELSE NULL
        END AS outcome_reason
    FROM events e
)
INSERT INTO pa.candidate_stage_events
(candidate_id, req_id, stage_name, stage_entered_at, stage_exited_at, outcome, outcome_reason)
SELECT candidate_id, req_id, stage_name, stage_entered_at, stage_exited_at, outcome, outcome_reason
FROM labeled
OPTION (MAXDOP 1);

-- OFFERS (Offer stage passers): offer_rank=1 accepted, offer_rank=2 declined
;WITH offer_stage AS
(
    SELECT DISTINCT
        e.candidate_id,
        e.req_id,
        CAST(e.stage_entered_at AS DATE) AS offer_extended_date
    FROM pa.candidate_stage_events e
    WHERE e.stage_name = 'Offer' AND e.outcome = 'Pass'
),
ranked_offer AS
(
    SELECT
        o.*,
        ROW_NUMBER() OVER (PARTITION BY o.req_id ORDER BY o.candidate_id) AS offer_rank
    FROM offer_stage o
)
INSERT INTO pa.offers
(candidate_id, req_id, offer_extended_date, offer_accepted_date, offer_status, base_salary_offer, equity_offer_usd, start_date_planned)
SELECT
    ro.candidate_id,
    ro.req_id,
    ro.offer_extended_date,
    CASE WHEN ro.offer_rank = 1 THEN DATEADD(DAY, 2, ro.offer_extended_date) ELSE NULL END AS offer_accepted_date,
    CASE WHEN ro.offer_rank = 1 THEN 'Accepted' ELSE 'Declined' END AS offer_status,
    140000 + (ro.req_id % 5) * 5000 AS base_salary_offer,
    40000 + (ro.req_id % 7) * 3000 AS equity_offer_usd,
    CASE WHEN ro.offer_rank = 1 THEN DATEADD(DAY, 30, ro.offer_extended_date) ELSE NULL END AS start_date_planned
FROM ranked_offer ro
OPTION (MAXDOP 1);

-- EMPLOYEES (Accepted only)
INSERT INTO pa.employees
(req_id_hired_from, hire_date, termination_date,
 department, role_family, job_title, job_level,
 location, manager_employee_id, base_salary, gender, ethnicity)
SELECT
    o.req_id,
    o.start_date_planned,
    NULL AS termination_date,
    r.department,
    r.role_family,
    r.job_title,
    r.job_level,
    r.location,
    NULL AS manager_employee_id,
    o.base_salary_offer,
    c.gender,
    c.ethnicity
FROM pa.offers o
JOIN pa.candidates c ON c.candidate_id = o.candidate_id
JOIN pa.job_requisitions r ON r.req_id = o.req_id
WHERE o.offer_status = 'Accepted'
OPTION (MAXDOP 1);

-- INSERT START STAGE EVENTS FOR HIRED CANDIDATES
INSERT INTO pa.candidate_stage_events
(
    candidate_id,
    req_id,
    stage_name,
    stage_entered_at,
    stage_exited_at,
    outcome,
    outcome_reason
)
SELECT
    o.candidate_id,
    o.req_id,
    'Start',
    DATEADD(HOUR, 9, CAST(o.start_date_planned AS DATETIME2(0))),
    DATEADD(HOUR, 17, CAST(o.start_date_planned AS DATETIME2(0))),
    'Pass',
    NULL
FROM pa.offers o
WHERE o.offer_status = 'Accepted';

-- LIGHT employee tables
INSERT INTO pa.engagement_surveys(employee_id, survey_date, engagement_score)
SELECT
    e.employee_id,
    DATEADD(DAY, v.n * 90, e.hire_date) AS survey_date,
    CAST(70 + (e.employee_id % 15) - (v.n * 2) AS DECIMAL(5,2)) AS engagement_score
FROM pa.employees e
JOIN (VALUES (1),(2)) v(n) ON 1=1;

INSERT INTO pa.performance_reviews(employee_id, review_date, performance_rating)
SELECT
    e.employee_id,
    DATEADD(DAY, 180, e.hire_date) AS review_date,
    CAST(3.2 + ((e.employee_id % 10) / 10.0) AS DECIMAL(3,2)) AS performance_rating
FROM pa.employees e;

INSERT INTO pa.promotions(employee_id, promotion_date, old_level, new_level)
SELECT
    e.employee_id,
    DATEADD(DAY, 365, e.hire_date) AS promotion_date,
    e.job_level AS old_level,
    CASE e.job_level WHEN 'L3' THEN 'L4' WHEN 'L4' THEN 'L5' END AS new_level
FROM pa.employees e
WHERE (e.employee_id % 5) = 0
  AND e.job_level IN ('L3','L4');

-- FINAL COUNTS
-- SELECT 'recruiters' t, COUNT(*) n FROM pa.recruiters UNION ALL
-- SELECT 'hiring_managers', COUNT(*) FROM pa.hiring_managers UNION ALL
-- SELECT 'job_requisitions', COUNT(*) FROM pa.job_requisitions UNION ALL
-- SELECT 'candidates', COUNT(*) FROM pa.candidates UNION ALL
-- SELECT 'candidate_stage_events', COUNT(*) FROM pa.candidate_stage_events UNION ALL
-- SELECT 'offers', COUNT(*) FROM pa.offers UNION ALL
-- SELECT 'employees', COUNT(*) FROM pa.employees UNION ALL
-- SELECT 'performance_reviews', COUNT(*) FROM pa.performance_reviews UNION ALL
-- SELECT 'engagement_surveys', COUNT(*) FROM pa.engagement_surveys UNION ALL
-- SELECT 'promotions', COUNT(*) FROM pa.promotions;

GO
