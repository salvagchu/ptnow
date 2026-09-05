-- Adds the Credentials & Compliance (Providers) feature. Paste into Supabase
-- SQL Editor and Run once.

create table if not exists providers (
  id text primary key,
  employee_id text references employees(id) on delete set null,
  person_name text not null,
  occupation text not null,
  license_number text,
  expiration_date date,
  created_at timestamptz not null default now()
);

alter table providers enable row level security;

drop policy if exists "authenticated full access" on providers;
create policy "authenticated full access" on providers
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.providers to authenticated;

alter publication supabase_realtime add table providers;
