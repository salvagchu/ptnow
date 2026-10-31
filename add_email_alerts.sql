-- Daily email/SMS alerts: licenses expiring within 60 days and employee
-- birthdays within 10 days. Run AFTER deploying the "expiry-alerts" Edge
-- Function. Paste into Supabase SQL Editor, replace PASTE_CRON_SECRET_HERE
-- with the same CRON_SECRET you saved in Edge Function secrets, and Run once.

-- Remembers which alerts were already sent so each one goes out only once.
-- RLS on with no policies: only the Edge Function (service role) can use it.
create table if not exists alert_log (
  kind text not null,
  ref_id text not null,
  target_date date not null,
  sent_at timestamptz not null default now(),
  primary key (kind, ref_id, target_date)
);
alter table alert_log enable row level security;

-- The Edge Function runs as service_role, which this project doesn't grant
-- table access to by default.
grant usage on schema public to service_role;
grant select, insert on public.alert_log to service_role;
grant select on public.providers, public.clinic_licenses, public.employees to service_role;

create extension if not exists pg_cron;
create extension if not exists pg_net;

-- Every day at 12:00 UTC (8 AM Florida in summer, 7 AM in winter).
select cron.unschedule('ptn-expiry-alerts')
where exists (select 1 from cron.job where jobname = 'ptn-expiry-alerts');

select cron.schedule(
  'ptn-expiry-alerts',
  '0 12 * * *',
  $$
  select net.http_post(
    url := 'https://ospknbrfgvydwccmsjdb.supabase.co/functions/v1/expiry-alerts',
    headers := jsonb_build_object('Content-Type','application/json','x-cron-secret','PASTE_CRON_SECRET_HERE'),
    body := '{}'::jsonb
  );
  $$
);
