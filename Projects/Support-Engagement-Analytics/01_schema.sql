USE SupportEngagement;
GO

IF OBJECT_ID('dbo.TicketEvents','U') IS NOT NULL DROP TABLE dbo.TicketEvents;
IF OBJECT_ID('dbo.SupportTickets','U') IS NOT NULL DROP TABLE dbo.SupportTickets;
IF OBJECT_ID('dbo.Sessions','U') IS NOT NULL DROP TABLE dbo.Sessions;
IF OBJECT_ID('dbo.Users','U') IS NOT NULL DROP TABLE dbo.Users;
GO

CREATE TABLE dbo.Users (
  user_id INT PRIMARY KEY,
  signup_date DATE NOT NULL,
  country VARCHAR(50) NOT NULL,
  platform VARCHAR(20) NOT NULL,          -- Web, iOS, Android, Desktop, Console
  segment VARCHAR(20) NOT NULL            -- Free, Plus, Premium
);

CREATE TABLE dbo.Sessions (
  session_id INT IDENTITY(1,1) PRIMARY KEY,
  user_id INT NOT NULL,
  session_start DATETIME2 NOT NULL,
  session_minutes INT NOT NULL,
  product_area VARCHAR(30) NOT NULL,      -- Browse, Purchase, Social, Settings, Gameplay
  FOREIGN KEY (user_id) REFERENCES dbo.Users(user_id)
);

CREATE TABLE dbo.SupportTickets (
  ticket_id INT IDENTITY(1,1) PRIMARY KEY,
  user_id INT NOT NULL,
  created_at DATETIME2 NOT NULL,
  category VARCHAR(50) NOT NULL,          -- Billing, Technical, Safety, Account
  channel VARCHAR(20) NOT NULL,           -- Email, Chat, Web, InApp
  priority VARCHAR(10) NOT NULL,          -- P0, P1, P2
  status VARCHAR(20) NOT NULL,            -- Open, Pending, Resolved
  resolved_at DATETIME2 NULL,
  csat_score INT NULL,                    -- 1–5
  FOREIGN KEY (user_id) REFERENCES dbo.Users(user_id)
);

CREATE TABLE dbo.TicketEvents (
  ticket_event_id INT IDENTITY(1,1) PRIMARY KEY,
  ticket_id INT NOT NULL,
  event_time DATETIME2 NOT NULL,
  event_type VARCHAR(30) NOT NULL,        -- Created, AgentReply, UserReply, StatusChange, Resolved
  agent_id INT NULL,
  FOREIGN KEY (ticket_id) REFERENCES dbo.SupportTickets(ticket_id)
);
GO

-- Indexes (realistic)
CREATE INDEX IX_Sessions_user_time ON dbo.Sessions(user_id, session_start);
CREATE INDEX IX_Tickets_created ON dbo.SupportTickets(created_at) INCLUDE(category, channel, priority, status, resolved_at, csat_score, user_id);
CREATE INDEX IX_TicketEvents_ticket_time ON dbo.TicketEvents(ticket_id, event_time) INCLUDE(event_type, agent_id);
GO
