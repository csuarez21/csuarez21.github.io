# Talent Acquisition KPI Dashboard (TARI)

An end-to-end recruiting analytics project built using **SQL Server**
and **Tableau Public**.

This project simulates a hiring environment and analyzes funnel
conversion, stage velocity, offer/start rates, and time-to-fill
performance across departments, job levels, and source channels.

------------------------------------------------------------------------

## Project Overview

The goal of this project was to:

-   Simulate a realistic recruiting dataset
-   Model hiring lifecycle data in SQL
-   Create KPI views for business reporting
-   Build an executive-ready Tableau dashboard

The dataset includes:

-   Job requisitions\
-   Candidates\
-   Stage progression events\
-   Offers and starts\
-   Employee outcomes

All business metrics were calculated in SQL and visualized in Tableau.

------------------------------------------------------------------------

##  Key Business Questions Answered

-   What is the overall **offer rate** and **start rate**?
-   Where are candidates dropping off in the hiring funnel?
-   Which hiring stages take the longest?
-   How long does it take to fill roles?
-   How does performance vary by department, job level, and source
    channel?

------------------------------------------------------------------------

## KPIs Included

-   Offer Rate\
-   Start Rate\
-   Funnel Conversion by Stage\
-   Average Time in Stage\
-   Time to Fill\
-   Hiring Velocity by Stage

------------------------------------------------------------------------

## Tech Stack

**Database & Modeling** - SQL Server\
- T-SQL\
- KPI Views for metric aggregation

**Visualization** - Tableau Public\
- Interactive filters by Department, Job Level, and Source Channel

------------------------------------------------------------------------

## Project Structure

    TARI-Recruiting-Analytics
    │
    ├── sql/
    │   ├── 01_create_schema.sql
    │   ├── 02_generate_data.sql
    │   └── 03_kpi_views.sql
    │
    ├── data/curated
    │   ├── attrition.csv
    │   ├── funnel_conversion.csv
    │   ├── stage_speed.csv  
    │   └── time_to_fill.sql    
    |
    ├── tableau/
    │   └── TARI.twbx
    │
    └── README.md

------------------------------------------------------------------------

## Live Interactive Dashboard

🔗 Add your Tableau Public link here

------------------------------------------------------------------------

## Key Takeaways

-   Designed a structured recruiting data model
-   Implemented guaranteed stage drop-offs for realistic funnel behavior
-   Built SQL KPI views to separate business logic from visualization
-   Developed an executive-level interactive dashboard

------------------------------------------------------------------------

## Why This Project Matters

This project demonstrates the full analytics lifecycle:

1.  Data modeling\
2.  KPI definition\
3.  SQL-based metric calculation\
4.  BI dashboard development\
5.  Public deployment

It reflects practical business intelligence skills applicable to Data
Analyst, BI Analyst, and People Analytics roles.
