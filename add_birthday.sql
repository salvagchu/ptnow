-- Adds an optional birthday field to employees (used for a future Dashboard
-- "Upcoming Birthdays" panel). Paste into Supabase SQL Editor and Run once.

alter table employees add column if not exists birthday date;
