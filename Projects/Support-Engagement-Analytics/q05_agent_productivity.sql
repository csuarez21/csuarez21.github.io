USE SupportEngagement;

-- q05_agent_productivity.sql
-- Analysis: Agent Productivity & Responsiveness
--
-- Purpose:
--   Evaluate agent performance by measuring ticket engagement,
--   reply volume, and responsiveness based on first-response ownership.
--
-- Metrics:
--   - agent_id
--   - tickets_touched (distinct tickets with >= 1 AgentReply)
--   - total_agent_replies (count of AgentReply events)
--   - avg_first_response_minutes (average FRT for tickets where agent replied first)
--   - median_first_response_minutes (optional)
--   - p90_first_response_minutes (optional)
--
-- Definitions:
--   - A ticket is "touched" if the agent has at least one AgentReply event.
--   - First-response ownership is assigned to the agent who sent
--     the earliest AgentReply for a ticket.
--   - First Response Time (FRT) = minutes from ticket created_at
--     to the first AgentReply event.
--
-- Assumptions:
--   - Only AgentReply events are considered for productivity metrics.
--   - Tickets without agent replies are excluded from FRT calculations.
--   - Division by zero is handled safely where applicable.
--
-- Notes:
--   - Uses window functions to determine first-response ownership.
--   - Output grain is one row per agent.

WITH agent_tickets AS
(
SELECT  t.agent_id
        , s.ticket_id
        , s.created_at
        , s.resolved_at
        , t.event_time AS first_reply_time
        , DATEDIFF(MINUTE, s.created_at, t.event_time) AS frt_minutes
        , ROW_NUMBER()OVER(PARTITION BY t.Ticket_id ORDER BY t.event_time) AS RN
FROM    dbo.SupportTickets s  
JOIN    dbo.TicketEvents t 
    ON  s.ticket_id = t.ticket_id
 WHERE t.event_type = 'AgentReply'   
    AND t.agent_id IS NOT NULL
)

SELECT agent_id
        ,COUNT(DISTINCT ticket_id) AS tickets_touched
        ,COUNT(*) AS total_agent_replies
        ,AVG(CASE
            WHEN RN = 1 THEN frt_minutes
            ELSE NULL
            END) AS avg_first_response_minutes
FROM agent_tickets
GROUP BY agent_id
ORDER BY agent_id



