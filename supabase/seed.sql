-- Official reference catalogs only. NO approved records are available yet.
-- Approval/source requirements: docs/hosted-deployment-plan.md.
-- Never add users, memberships, roles, personal data or sample profiles here.
-- Replace empty relations only after faculty approval. Run as a trusted owner.
begin;
with approved_institutions(name) as (
  select unnest(array[]::text[])
)
insert into public.institutions(name)
select name from approved_institutions
on conflict (lower(name)) do nothing;

-- Supply approved (institution_name, name) rows here after review.
-- Validate every department maps to exactly one institution BEFORE execution:
-- an unmatched name would otherwise be omitted by this join.
with approved_departments(institution_name, name) as (
  select null::text, null::text where false
)
insert into public.departments(institution_id, name)
select institution.id, department.name
from approved_departments as department
join public.institutions as institution
  on lower(institution.name) = lower(department.institution_name)
on conflict (institution_id, name) do nothing;
-- Reruns preserve existing IDs, names, active flags and timestamps.
commit;
