# Support & Engagement Analytics (SQL Server / T-SQL)

A personal analytics project that simulates a product with:
- Users and session activity (engagement)
- Customer support tickets (category, channel, priority, CSAT)
- Ticket event logs (created, agent reply, resolved) to compute operational KPIs

## What’s included
- `sql/00_create_db.sql`: creates the database
- `sql/01_schema.sql`: schema + indexes
- `sql/02_seed.sql`: mock data with edge cases (unresolved tickets, missing CSAT, users with no sessions)
- `prompts/questions.md`: practice prompts
- `solutions/`: my solutions (written by me)

## How to run
1. Run `sql/00_create_database.sql`
2. Run `sql/01_schema.sql`
3. Run `sql/02_seed.sql`
4. Solve prompts and save your queries in `solutions/`
