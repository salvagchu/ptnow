-- Adds Clinic Licenses (facility licenses, permits, certificates) to the
-- Credentials & Compliance tab. Paste into Supabase SQL Editor and Run once.
-- PDFs reuse the existing private 'provider-documents' bucket (clinics/ folder).

create table if not exists clinic_licenses (
  id text primary key,
  clinic text not null,
  license_type text not null,
  license_number text,
  issuing_agency text,
  expiration_date date,
  document_path text,
  document_name text,
  created_at timestamptz not null default now()
);

alter table clinic_licenses enable row level security;

drop policy if exists "authenticated full access" on clinic_licenses;
create policy "authenticated full access" on clinic_licenses
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.clinic_licenses to authenticated;
grant select on public.clinic_licenses to service_role;

alter publication supabase_realtime add table clinic_licenses;
