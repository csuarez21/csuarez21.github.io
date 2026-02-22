USE SupportEngagement;

-- q03_sla_compliance.sql
-- Analysis: SLA Compliance (Response & Resolution)
--
-- Purpose:
--   Evaluate operational performance by measuring whether tickets
--   meet defined response and resolution time service-level agreements (SLAs).
--
-- Metrics:
--   - category
--   - priority
--   - tickets_total
--   - tickets_with_agent_reply
--   - frt_sla_met
--   - frt_sla_met_pct
--   - tickets_resolved
--   - ttr_sla_met
--   - ttr_sla_met_pct
--
-- SLA Definitions:
--   First Response Time (FRT):
--     - P0, P1 <= 30 minutes
--     - P2 <= 60 minutes
--
--   Time to Resolution (TTR):
--     - P0 <= 24 hours (1440 minutes)
--     - P1, P2 <= 48 hours (2880 minutes)
--
-- Assumptions:
--   - FRT is calculated from ticket creation to first AgentReply
--   - TTR is calculated from created_at to resolved_at
--   - Tickets without agent replies are excluded from FRT SLA %
--   - Unresolved tickets are excluded from TTR SLA %
--   - Division by zero is handled safely
--
-- Notes:
--   - Output grain is one row per category and priority
--   - Uses conditional aggregation to calculate SLA metrics


WITH tickets_with_reply 
AS
(
SELECT ticket_id, MIN(event_time) AS FTR
FROM dbo.TicketEvents
WHERE event_type = 'AgentReply'
GROUP BY ticket_id
)     

SELECT  st.category
        ,st.priority
        ,COUNT(st.ticket_id) AS tickets_total
        ,COUNT(tr.ticket_id) AS tickets_with_agent_reply
        ,SUM(CASE
            WHEN DATEDIFF(MINUTE, st.created_at, tr.FTR) <= 30 AND st.priority IN ('P0','P1') 
                THEN 1
            WHEN DATEDIFF(MINUTE, st.created_at, tr.FTR) <= 60 AND st.priority = 'P2' 
                THEN 1
            ELSE 0 
            END) AS frt_sla_met
        ,CAST(SUM(CASE
            WHEN DATEDIFF(MINUTE, st.created_at, tr.FTR) <= 30 AND st.priority IN ('P0','P1') 
                THEN 1
            WHEN DATEDIFF(MINUTE, st.created_at, tr.FTR) <= 60 AND st.priority = 'P2' 
                THEN 1
            ELSE 0 
            END) * 100.0 / NULLIF(COUNT(tr.ticket_id),0) AS DECIMAL(18,2)) AS frt_sla_met_pct
        ,SUM(CASE WHEN st.resolved_at IS NOT NULL THEN 1 ELSE 0 END) AS tickets_resolved
        ,SUM(CASE
            WHEN DATEDIFF(MINUTE, st.created_at, st.resolved_at) <= 1440 AND st.priority = 'P0' AND st.resolved_at IS NOT NULL
                THEN 1
            WHEN DATEDIFF(MINUTE, st.created_at, st.resolved_at) <= 2880 AND st.priority IN ('P1','P2') AND st.resolved_at IS NOT NULL
                THEN 1
            ELSE 0
            END) AS ttr_sla_met
        ,CAST(SUM(CASE
            WHEN DATEDIFF(MINUTE, st.created_at, st.resolved_at) <= 1440 AND st.priority = 'P0' AND st.resolved_at IS NOT NULL
                THEN 1
            WHEN DATEDIFF(MINUTE, st.created_at, st.resolved_at) <= 2880 AND st.priority IN ('P1','P2') AND st.resolved_at IS NOT NULL
                THEN 1
            ELSE 0    
            END) * 100.0 / NULLIF(SUM(CASE WHEN st.resolved_at IS NOT NULL THEN 1 ELSE 0 END),0) AS DECIMAL(18,2)) AS ttr_sla_met_pct       
FROM    dbo.SupportTickets st
LEFT JOIN tickets_with_reply tr
    ON st.ticket_id = tr.ticket_id
 GROUP BY st.category, st.priority
 ORDER BY st.category, st.priority