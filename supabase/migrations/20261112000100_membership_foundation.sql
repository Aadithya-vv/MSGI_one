-- PostgreSQL 15+ / Supabase. Apply only to an isolated test project first.
begin;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated, service_role;
revoke create on schema public from public, anon, authenticated;

create type public.account_kind as enum ('student', 'alumni');
create type public.membership_status as enum ('pending', 'verified', 'rejected', 'suspended');
create type public.connection_status as enum ('pending', 'accepted', 'rejected', 'cancelled');
create type public.opportunity_kind as enum ('job', 'internship', 'collaboration');

create table public.institutions (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) <= 160 and char_length(btrim(name)) >= 2),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create unique index institutions_name_idx on public.institutions (lower(name));
create table public.departments (
  id uuid primary key default gen_random_uuid(),
  institution_id uuid not null references public.institutions(id),
  name text not null check (char_length(name) <= 160 and char_length(btrim(name)) >= 2),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (id, institution_id), unique (institution_id, name)
);
create table public.skills (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) <= 80 and char_length(btrim(name)) >= 1),
  created_at timestamptz not null default now()
);
create unique index skills_name_idx on public.skills (lower(name));
create table public.cities (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) <= 100 and char_length(btrim(name)) >= 1),
  country_code text not null check (country_code ~ '^[A-Z]{2}$'),
  created_at timestamptz not null default now(),
  unique(name, country_code)
);

create function private.valid_text_list(items text[], max_items integer, max_length integer)
returns boolean language sql immutable set search_path = '' as $$
  select items is not null and cardinality(items) between 1 and max_items
    and not exists (select 1 from unnest(items) item
      where item is null or char_length(item) > max_length or char_length(btrim(item)) < 1);
$$;

-- No email, phone, address, precise coordinates, verification flag or admin role.
create table public.profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null check (char_length(display_name) <= 80 and char_length(btrim(display_name)) >= 2),
  claimed_kind public.account_kind not null,
  institution_id uuid not null references public.institutions(id),
  department_id uuid not null,
  joining_year smallint not null check (joining_year between 1950 and 2200),
  graduation_year smallint not null check (graduation_year between joining_year and 2200),
  designation text check (char_length(designation) <= 120),
  career_interests text[] not null check (private.valid_text_list(career_interests, 10, 80)),
  city_id uuid references public.cities(id),
  directory_visible boolean not null default false,
  map_opt_in boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  foreign key (department_id, institution_id) references public.departments(id, institution_id),
  check (not map_opt_in or (city_id is not null and directory_visible))
);
create index profiles_department_idx on public.profiles(department_id);
create index profiles_city_idx on public.profiles(city_id) where map_opt_in;
create index profiles_search_idx on public.profiles using gin
  (to_tsvector('simple', display_name || ' ' || coalesce(designation, '')));
create index profiles_interests_idx on public.profiles using gin(career_interests);
create table public.profile_skills (
  profile_id uuid not null references public.profiles(user_id) on delete cascade,
  skill_id uuid not null references public.skills(id),
  primary key (profile_id, skill_id)
);
create index profile_skills_skill_idx on public.profile_skills(skill_id);
create table public.mentorship_preferences (
  profile_id uuid primary key references public.profiles(user_id) on delete cascade,
  available boolean not null default false,
  interests text[] not null default '{}' check (cardinality(interests) = 0 or private.valid_text_list(interests,10,80)),
  updated_at timestamptz not null default now()
);
create table private.memberships (
  user_id uuid primary key references public.profiles(user_id) on delete cascade,
  status public.membership_status not null default 'pending',
  verified_kind public.account_kind,
  updated_at timestamptz not null default now(),
  check ((status = 'verified' and verified_kind is not null) or
         (status <> 'verified' and verified_kind is null))
);
create table private.account_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role = 'administrator'),
  created_at timestamptz not null default now()
);
create table private.verification_audit (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references auth.users(id),
  actor_id uuid not null references auth.users(id),
  previous_status public.membership_status,
  new_status public.membership_status not null,
  verified_kind public.account_kind,
  reason text not null check (char_length(reason) <= 1000 and char_length(btrim(reason)) >= 1),
  created_at timestamptz not null default now()
);
create index verification_audit_subject_idx on private.verification_audit(subject_id, created_at);
create table public.connections (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.profiles(user_id),
  recipient_id uuid not null references public.profiles(user_id),
  status public.connection_status not null default 'pending',
  user_low uuid generated always as (least(sender_id, recipient_id)) stored,
  user_high uuid generated always as (greatest(sender_id, recipient_id)) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (sender_id <> recipient_id), unique(user_low, user_high)
);
create index connections_recipient_idx on public.connections(recipient_id, status);
create index connections_sender_idx on public.connections(sender_id, status);
create table public.opportunities (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null default auth.uid() references public.profiles(user_id),
  title text not null check (char_length(title) <= 160 and char_length(btrim(title)) >= 3),
  description text not null check (char_length(description) <= 6000 and char_length(btrim(description)) >= 10),
  kind public.opportunity_kind not null,
  location_text text check (char_length(location_text) <= 160),
  external_url text check (external_url is null or
    (external_url ~ '^https://' and char_length(external_url) <= 2048)),
  status text not null default 'draft' check (status in ('draft', 'published', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index opportunities_author_idx on public.opportunities(author_id);
create index opportunities_published_idx on public.opportunities(created_at desc) where status = 'published';
create index opportunities_search_idx on public.opportunities using gin
  (to_tsvector('simple', title || ' ' || description));
create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null default auth.uid() references auth.users(id),
  target_profile_id uuid references public.profiles(user_id),
  target_opportunity_id uuid references public.opportunities(id),
  reason text not null check (reason in ('harassment','impersonation','inappropriate','other')),
  details text not null check (char_length(details) <= 2000 and char_length(btrim(details)) >= 10),
  status text not null default 'open' check (status in ('open','resolved','dismissed')),
  moderated_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (num_nonnulls(target_profile_id, target_opportunity_id) = 1)
);
create index reports_reporter_idx on public.reports(reporter_id);
create index reports_status_idx on public.reports(status, created_at);

-- Privileges are checked against current database state, never user metadata.
create function private.member_verified(subject uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from private.memberships m join auth.users u on u.id=m.user_id
    where m.user_id = subject and m.status = 'verified' and u.email_confirmed_at is not null);
$$;
create function private.is_verified() returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and private.member_verified(auth.uid());
$$;
create function private.account_allowed() returns boolean
language sql stable security definer set search_path = '' as $$
  select auth.uid() is not null and not exists
    (select 1 from private.memberships where user_id = auth.uid() and status in ('rejected','suspended'));
$$;
create function private.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select private.is_verified() and exists
    (select 1 from private.account_roles where user_id = auth.uid() and role = 'administrator');
$$;
create function private.can_publish() returns boolean
language sql stable security definer set search_path = '' as $$
  select private.is_verified() and (private.is_admin() or exists (select 1 from private.memberships
    where user_id = auth.uid() and status = 'verified' and verified_kind = 'alumni'));
$$;
create function private.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$ begin new.updated_at := now(); return new; end; $$;
create trigger profiles_updated before update on public.profiles
  for each row execute function private.touch_updated_at();
create trigger mentorship_updated before update on public.mentorship_preferences
  for each row execute function private.touch_updated_at();
create trigger opportunities_updated before update on public.opportunities
  for each row execute function private.touch_updated_at();
create trigger reports_updated before update on public.reports
  for each row execute function private.touch_updated_at();

-- Revoke implicit Supabase/default grants on every newly created relation/function.
revoke all on private.memberships,private.account_roles,private.verification_audit from public, anon, authenticated;
revoke all on function private.valid_text_list(text[],integer,integer),private.member_verified(uuid),
  private.is_verified(),private.account_allowed(),private.is_admin(),private.can_publish(),private.touch_updated_at()
  from public, anon, authenticated;
grant execute on function private.valid_text_list(text[],integer,integer),
  private.is_verified(), private.account_allowed(), private.is_admin(), private.can_publish()
  to authenticated;
revoke all on public.institutions, public.departments, public.skills, public.cities,
  public.profiles, public.profile_skills, public.mentorship_preferences,
  public.connections, public.opportunities, public.reports from public, anon, authenticated;
grant select on public.institutions, public.departments, public.skills, public.cities,
  public.profiles, public.profile_skills, public.mentorship_preferences,
  public.connections, public.opportunities, public.reports to authenticated;
grant update(display_name, designation, career_interests, city_id, directory_visible, map_opt_in)
  on public.profiles to authenticated;
grant insert(profile_id,available,interests), update(available,interests)
  on public.mentorship_preferences to authenticated;
grant delete on public.mentorship_preferences to authenticated;
grant insert(author_id,title,description,kind,location_text,external_url,status),
  update(title,description,kind,location_text,external_url,status)
  on public.opportunities to authenticated;
grant delete on public.opportunities to authenticated;
grant insert(reporter_id,target_profile_id,target_opportunity_id,reason,details)
  on public.reports to authenticated;
-- service_role is trusted server-side only; never a mobile client role/key.
grant all on private.memberships,private.account_roles to service_role;
revoke all on private.verification_audit from service_role;
grant select,insert on private.verification_audit to service_role;
grant execute on function private.valid_text_list(text[],integer,integer) to service_role;
grant all on public.institutions, public.departments, public.skills, public.cities,
  public.profiles, public.profile_skills, public.mentorship_preferences,
  public.connections, public.opportunities, public.reports to service_role;

alter table public.institutions enable row level security;
alter table public.departments enable row level security;
alter table public.skills enable row level security;
alter table public.cities enable row level security;
alter table public.profiles enable row level security;
alter table public.profile_skills enable row level security;
alter table public.mentorship_preferences enable row level security;
alter table public.connections enable row level security;
alter table public.opportunities enable row level security;
alter table public.reports enable row level security;
alter table private.memberships enable row level security;
alter table private.account_roles enable row level security;
alter table private.verification_audit enable row level security;
create policy institution_catalog on public.institutions for select to authenticated
  using (active and private.account_allowed());
create policy department_catalog on public.departments for select to authenticated
  using (active and private.account_allowed());
create policy skill_catalog on public.skills for select to authenticated using (private.account_allowed());
create policy city_catalog on public.cities for select to authenticated using (private.account_allowed());
create policy own_profile_read on public.profiles for select to authenticated using (user_id = auth.uid());
create policy own_profile_edit on public.profiles for update to authenticated
  using (user_id = auth.uid() and private.account_allowed())
  with check (user_id = auth.uid() and private.account_allowed());
create policy own_skills_read on public.profile_skills for select to authenticated using (profile_id = auth.uid());
create policy own_mentorship_read on public.mentorship_preferences for select to authenticated using (profile_id = auth.uid());
create policy own_mentorship_insert on public.mentorship_preferences for insert to authenticated
  with check (profile_id = auth.uid() and private.is_verified());
create policy own_mentorship_update on public.mentorship_preferences for update to authenticated
  using (profile_id = auth.uid() and private.is_verified())
  with check (profile_id = auth.uid() and private.is_verified());
create policy own_mentorship_delete on public.mentorship_preferences for delete to authenticated
  using (profile_id = auth.uid() and private.is_verified());
create policy participant_connections on public.connections for select to authenticated
  using (private.is_verified() and auth.uid() in (sender_id,recipient_id));
create policy visible_opportunities on public.opportunities for select to authenticated
  using (private.is_verified() and (status = 'published' or author_id = auth.uid()));
create policy author_opportunity_insert on public.opportunities for insert to authenticated
  with check (author_id = auth.uid() and private.can_publish());
create policy author_opportunity_update on public.opportunities for update to authenticated
  using (author_id = auth.uid() and private.can_publish())
  with check (author_id = auth.uid() and private.can_publish());
create policy author_opportunity_delete on public.opportunities for delete to authenticated
  using (author_id = auth.uid() and private.can_publish());
create policy reporter_read on public.reports for select to authenticated
  using ((reporter_id = auth.uid() and private.is_verified()) or private.is_admin());
create policy reporter_insert on public.reports for insert to authenticated
  with check (reporter_id = auth.uid() and private.is_verified());
commit;
