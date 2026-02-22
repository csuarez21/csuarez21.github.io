USE SupportEngagement;
GO

INSERT INTO dbo.Users (user_id, signup_date, country, platform, segment) VALUES
(101,'2024-06-01','USA','iOS','Free'),
(102,'2024-06-02','USA','Android','Free'),
(103,'2024-06-03','Canada','Desktop','Premium'),
(104,'2024-06-05','UK','Web','Plus'),
(105,'2024-06-07','Brazil','Android','Free'),
(106,'2024-06-08','USA','Console','Premium'),
(107,'2024-06-10','Germany','Web','Free'),      -- 0 sessions, has ticket
(108,'2024-06-12','Canada','iOS','Plus'),
(109,'2024-06-15','USA','Desktop','Premium'),
(110,'2024-06-18','Japan','iOS','Free'),        -- 0 sessions, no ticket
(111,'2024-06-20','USA','iOS','Plus'),
(112,'2024-06-21','UK','Console','Premium');
GO

-- Sessions (107 & 110 have 0 sessions)
INSERT INTO dbo.Sessions (user_id, session_start, session_minutes, product_area) VALUES
(101,'2024-06-20T09:10:00',35,'Browse'),
(101,'2024-06-21T18:05:00',55,'Social'),
(101,'2024-06-28T20:00:00',20,'Purchase'),

(102,'2024-06-20T10:00:00',15,'Browse'),
(102,'2024-06-22T10:30:00',25,'Purchase'),
(102,'2024-06-30T23:10:00',10,'Settings'),

(103,'2024-06-21T08:00:00',120,'Social'),
(103,'2024-06-23T09:30:00',60,'Social'),

(104,'2024-06-25T14:15:00',45,'Browse'),
(104,'2024-07-01T10:00:00',35,'Purchase'),

(105,'2024-06-20T07:00:00',90,'Purchase'),
(105,'2024-06-27T07:10:00',30,'Browse'),

(106,'2024-06-21T19:00:00',10,'Settings'),
(106,'2024-06-22T19:05:00',12,'Browse'),
(106,'2024-06-23T19:10:00',8,'Browse'),

(108,'2024-06-22T16:00:00',40,'Social'),
(108,'2024-06-29T16:30:00',25,'Browse'),

(109,'2024-06-29T21:00:00',75,'Purchase'),

(111,'2024-06-22T13:00:00',50,'Browse'),
(111,'2024-06-23T13:05:00',45,'Social'),
(112,'2024-06-23T09:00:00',20,'Browse');
GO

-- Support tickets (category/channel/priority variety + edge cases)
INSERT INTO dbo.SupportTickets (user_id, created_at, category, channel, priority, status, resolved_at, csat_score) VALUES
(101,'2024-06-21T19:00:00','Billing','Chat','P1','Resolved','2024-06-21T19:25:00',5),
(102,'2024-06-23T11:00:00','Technical','Email','P2','Resolved','2024-06-23T14:30:00',3),
(103,'2024-06-24T09:10:00','Safety','Web','P0','Resolved','2024-06-24T10:05:00',4),
(105,'2024-06-27T07:20:00','Account','InApp','P2','Open',NULL,NULL),                -- unresolved
(106,'2024-06-22T20:00:00','Billing','Chat','P1','Resolved','2024-06-22T20:08:00',5),
(107,'2024-06-26T12:00:00','Technical','Web','P1','Resolved','2024-06-26T15:00:00',2), -- 0 sessions
(109,'2024-06-30T10:00:00','Account','Email','P2','Resolved','2024-07-01T09:00:00',NULL),
(111,'2024-06-23T14:00:00','Billing','InApp','P2','Resolved','2024-06-23T14:40:00',4),
(112,'2024-06-23T09:30:00','Technical','Chat','P1','Resolved','2024-06-23T10:20:00',3),
(104,'2024-07-01T11:00:00','Safety','Web','P0','Pending',NULL,NULL),               -- unresolved
(108,'2024-06-29T17:00:00','Account','Chat','P2','Resolved','2024-06-29T17:50:00',1);
GO

-- Event log to compute FRT/touches
INSERT INTO dbo.TicketEvents (ticket_id, event_time, event_type, agent_id) VALUES
(1,'2024-06-21T19:00:00','Created',NULL),
(1,'2024-06-21T19:03:00','AgentReply',201),
(1,'2024-06-21T19:10:00','UserReply',NULL),
(1,'2024-06-21T19:25:00','Resolved',201),

(2,'2024-06-23T11:00:00','Created',NULL),
(2,'2024-06-23T11:50:00','AgentReply',202),
(2,'2024-06-23T13:15:00','AgentReply',203),
(2,'2024-06-23T14:30:00','Resolved',203),

(3,'2024-06-24T09:10:00','Created',NULL),
(3,'2024-06-24T09:22:00','AgentReply',204),
(3,'2024-06-24T10:05:00','Resolved',204),

(4,'2024-06-27T07:20:00','Created',NULL),
(4,'2024-06-27T08:40:00','AgentReply',205),

(5,'2024-06-22T20:00:00','Created',NULL),
(5,'2024-06-22T20:02:00','AgentReply',201),
(5,'2024-06-22T20:08:00','Resolved',201),

(6,'2024-06-26T12:00:00','Created',NULL),
(6,'2024-06-26T12:25:00','AgentReply',206),
(6,'2024-06-26T15:00:00','Resolved',206),

(7,'2024-06-30T10:00:00','Created',NULL),
(7,'2024-06-30T11:10:00','AgentReply',207),
(7,'2024-07-01T09:00:00','Resolved',207),

(8,'2024-06-23T14:00:00','Created',NULL),
(8,'2024-06-23T14:06:00','AgentReply',208),
(8,'2024-06-23T14:40:00','Resolved',208),

(9,'2024-06-23T09:30:00','Created',NULL),
(9,'2024-06-23T09:37:00','AgentReply',201),
(9,'2024-06-23T10:20:00','Resolved',201),

(10,'2024-07-01T11:00:00','Created',NULL),
(10,'2024-07-01T12:15:00','AgentReply',204),

(11,'2024-06-29T17:00:00','Created',NULL),
(11,'2024-06-29T17:18:00','AgentReply',209),
(11,'2024-06-29T17:50:00','Resolved',209);
GO
