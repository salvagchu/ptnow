-- Adds the "PTO Exempt" flag to employees, and creates Diego Rojas and
-- Bruno Mancini as employees who appear in the roster but are excluded
-- from all PTO tracking/totals. Paste into Supabase SQL Editor and Run once.

alter table employees add column if not exists pto_exempt boolean not null default false;

insert into employees (id, name, clinic, hire_date, status, pto_exempt) values
('diego-rojas', 'Diego Rojas', 'Administration', current_date, 'Active', true),
('bruno-mancini', 'Bruno Mancini', 'Administration', current_date, 'Active', true)
on conflict (id) do nothing;

-- The hire_date above is a placeholder (today's date) since it wasn't provided.
-- Edit each of these two employees from the Employees tab afterward and set
-- their real hire date and clinic if you'd like those to be accurate.
