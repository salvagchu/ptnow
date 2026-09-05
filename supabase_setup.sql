-- ============================================================
-- PTN Team Tracker — Supabase schema, security, and data migration
-- Paste this whole file into Supabase SQL Editor and click "Run" once.
-- ============================================================

create table if not exists employees (
  id text primary key,
  name text not null,
  clinic text not null,
  hire_date date not null,
  status text not null default 'Active',
  pto_exempt boolean not null default false,
  birthday date
);

create table if not exists requests (
  id text primary key,
  employee_id text references employees(id) on delete set null,
  employee_name text not null,
  first_day date not null,
  last_day date not null,
  hours numeric not null,
  status text not null default 'Pending',
  approved_by text,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists settings (
  id int primary key default 1,
  tier0_hours numeric not null default 0,
  tier1_hours numeric not null default 64,
  tier3_hours numeric not null default 104,
  anniversary_window_days int not null default 30,
  low_balance_threshold numeric not null default 24,
  clinics text[] not null default array['Orlando','Kissimmee','Altamonte Springs','Administration','Management','All','Other']
);

-- Row Level Security: only signed-in users (the manager + director accounts
-- you create under Authentication > Users) can read or write anything.
alter table employees enable row level security;
alter table requests enable row level security;
alter table settings enable row level security;

drop policy if exists "authenticated full access" on employees;
create policy "authenticated full access" on employees
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "authenticated full access" on requests;
create policy "authenticated full access" on requests
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "authenticated full access" on settings;
create policy "authenticated full access" on settings
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- Base table privileges: RLS above only narrows access that Postgres already
-- grants at this GRANT level, so signed-in users need these too.
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.employees to authenticated;
grant select, insert, update, delete on public.requests to authenticated;
grant select, insert, update, delete on public.settings to authenticated;

-- Realtime: broadcast changes to every connected client
alter publication supabase_realtime add table employees;
alter publication supabase_realtime add table requests;
alter publication supabase_realtime add table settings;

-- Seed data migrated from the clinic's original Excel tracker
insert into employees (id, name, clinic, hire_date, status) values
('marcelo-jaldin', 'Marcelo Jaldin', 'Orlando', '2022-07-11'::date, 'Active'),
('carolina-jaramillo', 'Carolina Jaramillo', 'Administration', '2022-12-26'::date, 'Active'),
('talondra-bryant', 'Talondra Bryant', 'Orlando', '2026-06-24'::date, 'Active'),
('troy-weiss', 'Troy Weiss', 'Orlando', '2025-10-12'::date, 'Active'),
('liliana-restrepo', 'Liliana Restrepo', 'Orlando', '2026-05-18'::date, 'Active'),
('valentina-tamara', 'Valentina Tamara', 'Orlando', '2026-03-16'::date, 'Inactive'),
('nicholas-paniati', 'Nicholas Paniati', 'Kissimmee', '2023-08-07'::date, 'Active'),
('maria-torrijano', 'Maria Torrijano', 'Kissimmee', '2023-07-18'::date, 'Active'),
('lissette-gonzalez', 'Lissette Gonzalez', 'Kissimmee', '2026-01-07'::date, 'Active'),
('myrnaris-cordero', 'Myrnaris Cordero', 'Kissimmee', '2025-12-25'::date, 'Active'),
('martha-rippy', 'Martha Rippy', 'Altamonte Springs', '2023-10-16'::date, 'Active'),
('manilia-plummer', 'Manilia Plummer', 'Altamonte Springs', '2023-07-12'::date, 'Active'),
('camila-diaz', 'Camila Diaz', 'Altamonte Springs', '2025-07-07'::date, 'Active')
on conflict (id) do nothing;

insert into requests (id, employee_id, employee_name, first_day, last_day, hours, status, approved_by, notes) values
('req-001', 'lissette-gonzalez', 'Lissette Gonzalez', '2027-02-18'::date, '2027-02-25'::date, 53.0, 'Approved', 'Diego Rojas', 'Vacation'),
('req-002', 'martha-rippy', 'Martha Rippy', '2026-09-21'::date, '2026-09-24'::date, 34.0, 'Approved', 'Diego Rojas', 'DPT Review/Test'),
('req-003', 'nicholas-paniati', 'Nicholas Paniati', '2026-09-17'::date, '2026-09-18'::date, 12.5, 'Approved- No PTO', 'Diego Rojas', 'Personal Day'),
('req-004', 'marcelo-jaldin', 'Marcelo Jaldin', '2026-09-17'::date, '2026-09-28'::date, 51.0, 'Approved', 'Diego Rojas', 'Vacation'),
('req-005', 'nicholas-paniati', 'Nicholas Paniati', '2026-09-14'::date, '2026-09-14'::date, 8.5, 'Approved- No PTO', 'Diego Rojas', 'Personal Day'),
('req-006', 'talondra-bryant', 'Talondra Bryant', '2026-09-10'::date, '2026-09-10'::date, 5.5, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-007', 'talondra-bryant', 'Talondra Bryant', '2026-09-08'::date, '2026-09-08'::date, 5.5, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-008', 'martha-rippy', 'Martha Rippy', '2026-08-31'::date, '2026-09-03'::date, 34.0, 'Approved', 'Diego Rojas', 'DPT Review'),
('req-009', 'manilia-plummer', 'Manilia Plummer', '2026-08-26'::date, '2026-08-27'::date, 17.0, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-010', 'liliana-restrepo', 'Liliana Restrepo', '2026-08-24'::date, '2026-08-25'::date, 18.0, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-011', 'troy-weiss', 'Troy Weiss', '2026-08-13'::date, '2026-08-17'::date, 17.0, 'Approved', 'Diego Rojas', 'Vacation (17 hrs borrowed from PTO)'),
('req-012', 'manilia-plummer', 'Manilia Plummer', '2026-08-12'::date, '2026-08-12'::date, 2.0, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-013', 'nicholas-paniati', 'Nicholas Paniati', '2026-08-06'::date, '2026-08-06'::date, 8.5, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-014', 'camila-diaz', 'Camila Diaz', '2026-08-03'::date, '2026-08-03'::date, 5.0, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-015', 'camila-diaz', 'Camila Diaz', '2026-07-31'::date, '2026-07-31'::date, 4.0, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-016', 'manilia-plummer', 'Manilia Plummer', '2026-07-30'::date, '2026-08-03'::date, 17.0, 'Approved', 'Diego Rojas', 'Vacation'),
('req-017', 'carolina-jaramillo', 'Carolina Jaramillo', '2026-07-24'::date, '2026-07-24'::date, 4.0, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-018', 'carolina-jaramillo', 'Carolina Jaramillo', '2026-07-17'::date, '2026-07-17'::date, 4.0, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-019', 'nicholas-paniati', 'Nicholas Paniati', '2026-07-16'::date, '2026-07-24'::date, 49.5, 'Approved', 'Diego Rojas', 'Vacation (26.5 hrs borrowed from PTO)'),
('req-020', 'manilia-plummer', 'Manilia Plummer', '2026-07-02'::date, '2026-07-02'::date, 8.5, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-021', 'nicholas-paniati', 'Nicholas Paniati', '2026-06-11'::date, '2026-06-11'::date, 8.5, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-022', 'manilia-plummer', 'Manilia Plummer', '2026-06-04'::date, '2026-06-04'::date, 8.5, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-023', 'carolina-jaramillo', 'Carolina Jaramillo', '2026-05-28'::date, '2026-06-01'::date, 22.0, 'Approved', 'Diego Rojas', 'Vacation'),
('req-024', 'marcelo-jaldin', 'Marcelo Jaldin', '2026-05-18'::date, '2026-05-18'::date, 8.5, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-025', 'troy-weiss', 'Troy Weiss', '2026-05-11'::date, '2026-05-11'::date, 8.5, 'Approved', 'Diego Rojas', 'Vacation'),
('req-026', 'camila-diaz', 'Camila Diaz', '2026-05-11'::date, '2026-05-11'::date, 9.0, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-027', 'valentina-tamara', 'Valentina Tamara', '2026-05-11'::date, '2026-05-11'::date, 8.5, 'Approved', 'Diego Rojas', 'Sick Leave'),
('req-028', 'camila-diaz', 'Camila Diaz', '2026-05-08'::date, '2026-05-08'::date, 4.0, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-029', 'troy-weiss', 'Troy Weiss', '2026-05-07'::date, '2026-05-08'::date, 12.0, 'Approved', 'Diego Rojas', 'Vacation'),
('req-030', 'valentina-tamara', 'Valentina Tamara', '2026-05-04'::date, '2026-05-05'::date, 17.0, 'Approved', 'Diego Rojas', 'Sick Leave'),
('req-031', 'manilia-plummer', 'Manilia Plummer', '2026-05-04'::date, '2026-05-05'::date, 17.0, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-032', 'valentina-tamara', 'Valentina Tamara', '2026-05-01'::date, '2026-05-01'::date, 3.5, 'Approved', 'Diego Rojas', 'Sick Leave'),
('req-033', 'marcelo-jaldin', 'Marcelo Jaldin', '2026-04-27'::date, '2026-05-01'::date, 37.5, 'Approved', 'Diego Rojas', 'Vacation'),
('req-034', 'nicholas-paniati', 'Nicholas Paniati', '2026-04-23'::date, '2026-04-24'::date, 12.0, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-035', 'manilia-plummer', 'Manilia Plummer', '2026-04-09'::date, '2026-04-09'::date, 8.5, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-036', 'lissette-gonzalez', 'Lissette Gonzalez', '2026-04-01'::date, '2026-04-01'::date, 4.0, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-037', 'manilia-plummer', 'Manilia Plummer', '2026-03-30'::date, '2026-04-02'::date, 34.0, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-038', 'valentina-tamara', 'Valentina Tamara', '2026-03-24'::date, '2026-03-25'::date, 17.0, 'Approved', 'Diego Rojas', 'Sick Leave'),
('req-039', 'maria-torrijano', 'Maria Torrijano', '2026-03-16'::date, '2026-03-20'::date, 40.0, 'Approved', 'Diego Rojas', 'Vacation'),
('req-040', 'lissette-gonzalez', 'Lissette Gonzalez', '2026-03-04'::date, '2026-03-07'::date, 26.0, 'Approved', 'Diego Rojas', 'Vacation'),
('req-041', 'manilia-plummer', 'Manilia Plummer', '2026-02-19'::date, '2026-02-19'::date, 8.5, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-042', 'nicholas-paniati', 'Nicholas Paniati', '2026-02-06'::date, '2026-02-07'::date, 12.0, 'Approved', 'Diego Rojas', 'Vacation'),
('req-043', 'marcelo-jaldin', 'Marcelo Jaldin', '2026-02-02'::date, '2026-02-02'::date, 8.5, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-044', 'manilia-plummer', 'Manilia Plummer', '2026-01-06'::date, '2026-01-06'::date, 8.5, 'Approved', 'Diego Rojas', 'Personal Day'),
('req-045', 'camila-diaz', 'Camila Diaz', '2026-01-05'::date, '2026-01-05'::date, 9.0, 'Approved', 'Diego Rojas', 'Personal Day')
on conflict (id) do nothing;

insert into settings (id, tier0_hours, tier1_hours, tier3_hours, anniversary_window_days, low_balance_threshold, clinics)
values (1, 0, 64, 104, 30, 24, array['Orlando','Kissimmee','Altamonte Springs','Administration','Other'])
on conflict (id) do nothing;
