create table public.deals (
  id uuid primary key,
  tenant_id uuid not null,
  row_version bigint,
  calc_version integer
);

alter table public.tenants enable row level security;
alter table public.deals enable row level security;
-- 7.6: calc_version change protocol audit marker
