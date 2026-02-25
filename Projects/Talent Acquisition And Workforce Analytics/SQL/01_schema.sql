/* =========================================================
   Project: TARI (Talent Acquisition & Retention Intelligence)
   Stack: SQL Server (Docker) + VS Code + Python + Tableau
   File: 01_schema.sql
   Author: Colin Suarez
   ========================================================= */

-- 1) Create DB (safe to re-run)
DROP TABLE IF EXISTS TARI
BEGIN
    CREATE DATABASE TARI;
END
GO

USE TARI;
GO

-- 2) Create analytics schema
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'pa')
BEGIN
    EXEC('CREATE SCHEMA pa');
END
GO

/* =========================
   3) Dimension tables
   ========================= */

-- Recruiters
DROP TABLE IF EXISTS pa.recruiters;
GO
CREATE TABLE pa.recruiters (
    recruiter_id       INT IDENTITY(1,1) PRIMARY KEY,
    recruiter_name     VARCHAR(100) NOT NULL,
    recruiter_team     VARCHAR(100) NULL,
    location           VARCHAR(100) NULL,
    active_flag        BIT NOT NULL DEFAULT(1),
    created_at         DATETIME2(0) NOT NULL DEFAULT(SYSDATETIME())
);
GO

-- Hiring managers (modeled as a separate dimension to keep TA clean)
DROP TABLE IF EXISTS pa.hiring_managers;
GO
CREATE TABLE pa.hiring_managers (
    hiring_manager_id  INT IDENTITY(1,1) PRIMARY KEY,
    manager_name       VARCHAR(100) NOT NULL,
    department         VARCHAR(100) NOT NULL,
    location           VARCHAR(100) NULL,
    created_at         DATETIME2(0) NOT NULL DEFAULT(SYSDATETIME())
);
GO

/* =========================
   4) Talent Acquisition core
   ========================= */

-- Job requisitions (one row per req)
DROP TABLE IF EXISTS pa.job_requisitions;
GO
CREATE TABLE pa.job_requisitions (
    req_id             INT IDENTITY(1000,1) PRIMARY KEY,
    department         VARCHAR(100) NOT NULL,
    role_family        VARCHAR(100) NOT NULL,   -- e.g., Data, Eng, Support, Sales
    job_title          VARCHAR(150) NOT NULL,
    job_level          VARCHAR(20)  NOT NULL,   -- e.g., L3/L4/L5
    location           VARCHAR(100) NOT NULL,
    recruiter_id       INT NOT NULL,
    hiring_manager_id  INT NOT NULL,
    headcount_needed   INT NOT NULL DEFAULT(1),
    posted_date        DATE NOT NULL,
    closed_date        DATE NULL,               -- when req closed
    req_status         VARCHAR(30) NOT NULL DEFAULT('Open'), -- Open/Closed/OnHold/Cancelled
    created_at         DATETIME2(0) NOT NULL DEFAULT(SYSDATETIME()),

    CONSTRAINT FK_jobreq_recruiter
        FOREIGN KEY (recruiter_id) REFERENCES pa.recruiters(recruiter_id),

    CONSTRAINT FK_jobreq_hiring_manager
        FOREIGN KEY (hiring_manager_id) REFERENCES pa.hiring_managers(hiring_manager_id),

    CONSTRAINT CK_jobreq_status
        CHECK (req_status IN ('Open','Closed','OnHold','Cancelled')),

    CONSTRAINT CK_jobreq_headcount
        CHECK (headcount_needed >= 1)
);
GO

-- Candidates (one row per candidate per req application)
DROP TABLE IF EXISTS pa.candidates;
GO
CREATE TABLE pa.candidates (
    candidate_id       BIGINT IDENTITY(1,1) PRIMARY KEY,
    req_id             INT NOT NULL,
    applied_date       DATE NOT NULL,
    source_channel     VARCHAR(50) NOT NULL,    -- LinkedIn/Referral/Indeed/Campus/Agency/etc
    years_experience   DECIMAL(4,1) NULL,
    location           VARCHAR(100) NULL,

    -- Demographics (for fairness monitoring; allow Unknown)
    gender             VARCHAR(30) NOT NULL DEFAULT('Unknown'),
    ethnicity          VARCHAR(50) NOT NULL DEFAULT('Unknown'),

    created_at         DATETIME2(0) NOT NULL DEFAULT(SYSDATETIME()),

    CONSTRAINT FK_candidates_req
        FOREIGN KEY (req_id) REFERENCES pa.job_requisitions(req_id),

    CONSTRAINT CK_candidates_source
        CHECK (source_channel IN ('LinkedIn','Referral','Indeed','Campus','Agency','Internal','Other')),

    CONSTRAINT CK_candidates_gender
        CHECK (gender IN ('Male','Female','Non-binary','Prefer not to say','Unknown')),

    CONSTRAINT CK_candidates_ethnicity
        CHECK (ethnicity IN ('Asian','Black','Hispanic','White','Two or more','Other','Prefer not to say','Unknown'))
);
GO

-- Candidate stage events (FAANG-realistic; enables stage duration, funnel, adverse impact)
DROP TABLE IF EXISTS pa.candidate_stage_events;
GO
CREATE TABLE pa.candidate_stage_events (
    stage_event_id     BIGINT IDENTITY(1,1) PRIMARY KEY,
    candidate_id       BIGINT NOT NULL,
    req_id             INT NOT NULL,

    stage_name         VARCHAR(50) NOT NULL,    -- Applied/RecruiterScreen/HMReview/Onsite/Offer/Background/Start
    stage_entered_at   DATETIME2(0) NOT NULL,
    stage_exited_at    DATETIME2(0) NULL,

    outcome            VARCHAR(30) NOT NULL DEFAULT('InProgress'), -- Pass/Fail/Withdraw/InProgress
    outcome_reason     VARCHAR(100) NULL,

    created_at         DATETIME2(0) NOT NULL DEFAULT(SYSDATETIME()),

    CONSTRAINT FK_stage_candidate
        FOREIGN KEY (candidate_id) REFERENCES pa.candidates(candidate_id),

    CONSTRAINT FK_stage_req
        FOREIGN KEY (req_id) REFERENCES pa.job_requisitions(req_id),

    CONSTRAINT CK_stage_name
        CHECK (stage_name IN ('Applied','RecruiterScreen','HMReview','Onsite','Offer','Background','Start')),

    CONSTRAINT CK_stage_outcome
        CHECK (outcome IN ('Pass','Fail','Withdraw','InProgress')),

    CONSTRAINT CK_stage_time_order
        CHECK (stage_exited_at IS NULL OR stage_exited_at >= stage_entered_at)
);
GO

-- Offers (one row per offer event)
DROP TABLE IF EXISTS pa.offers;
GO
CREATE TABLE pa.offers (
    offer_id           BIGINT IDENTITY(1,1) PRIMARY KEY,
    candidate_id       BIGINT NOT NULL,
    req_id             INT NOT NULL,

    offer_extended_date  DATE NOT NULL,
    offer_accepted_date  DATE NULL,             -- null if declined/withdrawn
    offer_status         VARCHAR(20) NOT NULL DEFAULT('Extended'), -- Extended/Accepted/Declined/Withdrawn

    base_salary_offer    INT NULL,
    equity_offer_usd     INT NULL,
    start_date_planned   DATE NULL,

    created_at           DATETIME2(0) NOT NULL DEFAULT(SYSDATETIME()),

    CONSTRAINT FK_offers_candidate
        FOREIGN KEY (candidate_id) REFERENCES pa.candidates(candidate_id),

    CONSTRAINT FK_offers_req
        FOREIGN KEY (req_id) REFERENCES pa.job_requisitions(req_id),

    CONSTRAINT CK_offer_status
        CHECK (offer_status IN ('Extended','Accepted','Declined','Withdrawn')),

    CONSTRAINT CK_offer_accept_date
        CHECK (offer_accepted_date IS NULL OR offer_accepted_date >= offer_extended_date)
);
GO

/* =========================
   5) Workforce core
   ========================= */

-- Employees (one row per employee; includes req_id_hired_from to tie back to source/recruiter)
DROP TABLE IF EXISTS pa.employees;
GO
CREATE TABLE pa.employees (
    employee_id        BIGINT IDENTITY(1,1) PRIMARY KEY,
    req_id_hired_from  INT NULL,                -- nullable for legacy hires
    hire_date          DATE NOT NULL,
    termination_date   DATE NULL,

    department         VARCHAR(100) NOT NULL,
    role_family        VARCHAR(100) NOT NULL,
    job_title          VARCHAR(150) NOT NULL,
    job_level          VARCHAR(20)  NOT NULL,
    location           VARCHAR(100) NOT NULL,

    manager_employee_id BIGINT NULL,            -- self-referential manager relationship
    base_salary        INT NOT NULL,
    gender             VARCHAR(30) NOT NULL DEFAULT('Unknown'),
    ethnicity          VARCHAR(50) NOT NULL DEFAULT('Unknown'),

    created_at         DATETIME2(0) NOT NULL DEFAULT(SYSDATETIME()),

    CONSTRAINT FK_employees_req
        FOREIGN KEY (req_id_hired_from) REFERENCES pa.job_requisitions(req_id),

    CONSTRAINT FK_employees_manager
        FOREIGN KEY (manager_employee_id) REFERENCES pa.employees(employee_id),

    CONSTRAINT CK_emp_gender
        CHECK (gender IN ('Male','Female','Non-binary','Prefer not to say','Unknown')),

    CONSTRAINT CK_emp_ethnicity
        CHECK (ethnicity IN ('Asian','Black','Hispanic','White','Two or more','Other','Prefer not to say','Unknown')),

    CONSTRAINT CK_emp_termination_after_hire
        CHECK (termination_date IS NULL OR termination_date >= hire_date)
);
GO

-- Performance reviews (time series)
DROP TABLE IF EXISTS pa.performance_reviews;
GO
CREATE TABLE pa.performance_reviews (
    review_id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    employee_id        BIGINT NOT NULL,
    review_date        DATE NOT NULL,
    performance_rating DECIMAL(3,2) NOT NULL,   -- e.g., 1.0 - 5.0
    created_at         DATETIME2(0) NOT NULL DEFAULT(SYSDATETIME()),

    CONSTRAINT FK_perf_emp
        FOREIGN KEY (employee_id) REFERENCES pa.employees(employee_id),

    CONSTRAINT CK_perf_rating
        CHECK (performance_rating BETWEEN 1.0 AND 5.0)
);
GO

-- Engagement surveys (time series)
DROP TABLE IF EXISTS pa.engagement_surveys;
GO
CREATE TABLE pa.engagement_surveys (
    survey_id          BIGINT IDENTITY(1,1) PRIMARY KEY,
    employee_id        BIGINT NOT NULL,
    survey_date        DATE NOT NULL,
    engagement_score   DECIMAL(4,2) NOT NULL,   -- e.g., 0-100
    created_at         DATETIME2(0) NOT NULL DEFAULT(SYSDATETIME()),

    CONSTRAINT FK_eng_emp
        FOREIGN KEY (employee_id) REFERENCES pa.employees(employee_id),

    CONSTRAINT CK_eng_score
        CHECK (engagement_score BETWEEN 0 AND 100)
);
GO

-- Promotions (event table)
DROP TABLE IF EXISTS pa.promotions;
GO
CREATE TABLE pa.promotions (
    promotion_id       BIGINT IDENTITY(1,1) PRIMARY KEY,
    employee_id        BIGINT NOT NULL,
    promotion_date     DATE NOT NULL,
    old_level          VARCHAR(20) NOT NULL,
    new_level          VARCHAR(20) NOT NULL,
    created_at         DATETIME2(0) NOT NULL DEFAULT(SYSDATETIME()),

    CONSTRAINT FK_prom_emp
        FOREIGN KEY (employee_id) REFERENCES pa.employees(employee_id),

    CONSTRAINT CK_promo_level_change
        CHECK (old_level <> new_level)
);
GO

/* =========================
   6) Helpful Indexes
   ========================= */

-- Common join/filter indexes
CREATE INDEX IX_candidates_req ON pa.candidates(req_id);
CREATE INDEX IX_stage_candidate_req ON pa.candidate_stage_events(candidate_id, req_id);
CREATE INDEX IX_stage_stage_name ON pa.candidate_stage_events(stage_name);
CREATE INDEX IX_offers_req ON pa.offers(req_id);
CREATE INDEX IX_employees_req ON pa.employees(req_id_hired_from);
CREATE INDEX IX_employees_dept ON pa.employees(department);
GO