-- Adds "Management" and "All" as selectable Clinic options for employees.
-- Paste into Supabase SQL Editor and Run once.

update settings
set clinics = clinics || array(
  select x from unnest(array['Management','All']) as x
  where x <> all(clinics)
)
where id = 1;
