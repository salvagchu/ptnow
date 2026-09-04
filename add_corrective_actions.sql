-- Adds the Corrective Actions feature. Paste into Supabase SQL Editor and Run once.

create table if not exists corrective_actions (
  id text primary key,
  employee_id text references employees(id) on delete set null,
  employee_name text not null,
  date date not null,
  type text not null,
  reason text not null,
  description text,
  created_at timestamptz not null default now()
);

alter table corrective_actions enable row level security;

drop policy if exists "authenticated full access" on corrective_actions;
create policy "authenticated full access" on corrective_actions
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.corrective_actions to authenticated;

alter publication supabase_realtime add table corrective_actions;
