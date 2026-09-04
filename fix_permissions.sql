-- Run this once in Supabase SQL Editor to grant the missing table privileges
-- (RLS policies were already correct, but Postgres also requires a base GRANT
-- before RLS is even evaluated).

grant usage on schema public to authenticated;

grant select, insert, update, delete on public.employees to authenticated;
grant select, insert, update, delete on public.requests to authenticated;
grant select, insert, update, delete on public.settings to authenticated;
