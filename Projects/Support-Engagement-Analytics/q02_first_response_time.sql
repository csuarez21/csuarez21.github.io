USE SupportEngagement;

-- q02_first_response_time.sql
-- Analysis: First Response Time (FRT)
--
-- Purpose:
--   Measure operational responsiveness by calculating the time
--   between ticket creation and the first agent reply.
--
-- Metrics:
--   - ticket_id
--   - created_at
--   - first_agent_reply_time
--   - first_response_minutes (Created -> first AgentReply)
--
-- Assumptions:
--   - First response is defined as the earliest 'AgentReply' event per ticket
--   - Tickets without an agent reply return NULL for FRT
--   - Time difference is measured in minutes using DATEDIFF
--
-- Notes:
--   - Uses event log data (TicketEvents) to determine first reply
--   - Ensures one row per ticket


WITH agent_reply 
AS (
    SELECT ticket_id, MIN(event_time) AS first_agent_reply_time
    FROM dbo.TicketEvents
    WHERE event_type = 'AgentReply'
    GROUP BY ticket_id
)

SELECT c.ticket_id, c.created_at, a.first_agent_reply_time, DATEDIFF(MINUTE, c.created_at, a.first_agent_reply_time) AS first_response_minutes
FROM dbo.SupportTickets c
LEFT JOIN agent_reply a
    ON c.ticket_id = a.ticket_id
 ORDER BY c.ticket_id   
