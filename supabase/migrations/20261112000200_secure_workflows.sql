begin;
-- No auth.users trigger: signup cannot fail because profile/catalog setup failed.
-- One RPC transaction creates profile, skills, pending membership and audit entry.
create function public.submit_onboarding(
  p_display_name text, p_kind public.account_kind, p_institution uuid, p_department uuid,
  p_joining_year integer, p_graduation_year integer, p_designation text,
  p_interests text[], p_skills uuid[], p_city uuid default null,
  p_directory_visible boolean default false, p_map_opt_in boolean default false
) returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); current_status public.membership_status;
begin
  if actor is null or not private.account_allowed() then raise insufficient_privilege using message='Account cannot onboard'; end if;
  perform pg_advisory_xact_lock(hashtextextended(actor::text, 0));
  select status into current_status from private.memberships where user_id = actor for update;
  if current_status is not null and current_status <> 'pending' then
    raise insufficient_privilege using message='Membership claim cannot be changed';
  end if;
  if not exists (select 1 from public.institutions where id=p_institution and active) or
     not exists (select 1 from public.departments where id=p_department and institution_id=p_institution and active) then
    raise check_violation using message='Invalid institution or department';
  end if;
  if p_joining_year > extract(year from current_date) or
     p_graduation_year > extract(year from current_date)+8 or
     (p_kind='alumni' and p_graduation_year > extract(year from current_date)) then
    raise check_violation using message='Invalid batch years';
  end if;
  if p_skills is null or cardinality(p_skills) not between 1 and 20 or
     exists(select 1 from unnest(p_skills) s where s is null or not exists(select 1 from public.skills where id=s)) or
     (select count(distinct s) from unnest(p_skills) s) <> cardinality(p_skills) then
    raise check_violation using message='Select distinct catalog skills';
  end if;
  insert into public.profiles(user_id,display_name,claimed_kind,institution_id,department_id,
    joining_year,graduation_year,designation,career_interests,city_id,directory_visible,map_opt_in)
  values(actor,btrim(p_display_name),p_kind,p_institution,p_department,p_joining_year,p_graduation_year,
    nullif(btrim(p_designation),''),p_interests,p_city,p_directory_visible,p_map_opt_in)
  on conflict(user_id) do update set display_name=excluded.display_name,claimed_kind=excluded.claimed_kind,
    institution_id=excluded.institution_id,department_id=excluded.department_id,
    joining_year=excluded.joining_year,graduation_year=excluded.graduation_year,designation=excluded.designation,
    career_interests=excluded.career_interests,city_id=excluded.city_id,
    directory_visible=excluded.directory_visible,map_opt_in=excluded.map_opt_in;
  delete from public.profile_skills where profile_id=actor;
  insert into public.profile_skills(profile_id,skill_id) select actor,unnest(p_skills);
  insert into private.memberships(user_id) values(actor) on conflict(user_id) do nothing;
  if current_status is null then
    insert into private.verification_audit(subject_id,actor_id,new_status,reason)
      values(actor,actor,'pending','Profile submitted for institutional review');
  end if;
end; $$;

create function public.my_membership()
returns table(status text, verified_kind text, profile_complete boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if auth.uid() is null then raise insufficient_privilege; end if;
  if exists(select 1 from private.memberships where user_id=auth.uid() and status='verified')
    and not private.is_verified() then raise insufficient_privilege using message='Confirmed email required'; end if;
  return query select m.status::text,m.verified_kind::text,p.user_id is not null
    from (select auth.uid() as id) caller
    left join public.profiles p on p.user_id=caller.id
    left join private.memberships m on m.user_id=caller.id;
end; $$;

create function public.review_membership(p_user_id uuid, p_status public.membership_status,
  p_verified_kind public.account_kind, p_reason text)
returns void language plpgsql security definer set search_path = '' as $$
declare old_status public.membership_status;
begin
  if not private.is_admin() then raise insufficient_privilege using message='Administrator required'; end if;
  -- Lock the same user key as onboarding so review cannot race a changed claim.
  perform pg_advisory_xact_lock(hashtextextended(p_user_id::text,0));
  select status into strict old_status from private.memberships where user_id=p_user_id for update;
  if p_user_id = auth.uid() then raise insufficient_privilege using message='Cannot review own membership'; end if;
  if (p_status='verified') <> (p_verified_kind is not null) then raise check_violation; end if;
  if p_status='verified' and not exists(select 1 from auth.users where id=p_user_id and email_confirmed_at is not null) then
    raise check_violation using message='Confirm account email before approval';
  end if;
  update private.memberships set status=p_status,verified_kind=p_verified_kind,updated_at=now() where user_id=p_user_id;
  insert into private.verification_audit(subject_id,actor_id,previous_status,new_status,verified_kind,reason)
    values(p_user_id,auth.uid(),old_status,p_status,p_verified_kind,p_reason);
end; $$;

-- Safe projection only. Base profiles are self-readable, never directory-readable.
create function public.directory_profiles(p_search text default '', p_limit integer default 30)
returns table(user_id uuid,display_name text,kind text,institution text,department text,designation text,skills text[])
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_verified() then raise insufficient_privilege using message='Verified membership required'; end if;
  if p_limit is null or p_limit not between 1 and 100 or char_length(p_search)>100 then raise check_violation; end if;
  return query select p.user_id,p.display_name,m.verified_kind::text,i.name,d.name,p.designation,
    coalesce((select array_agg(s.name order by s.name) from public.profile_skills ps
      join public.skills s on s.id=ps.skill_id where ps.profile_id=p.user_id),'{}'::text[])
    from public.profiles p join private.memberships m on m.user_id=p.user_id
    join public.institutions i on i.id=p.institution_id join public.departments d on d.id=p.department_id
    where m.status='verified' and private.member_verified(p.user_id) and p.directory_visible and i.active and d.active
      and (coalesce(btrim(p_search),'')='' or to_tsvector('simple',p.display_name||' '||coalesce(p.designation,''))
        @@ plainto_tsquery('simple',p_search)) order by p.display_name,p.user_id limit p_limit;
end; $$;

create function public.map_profiles(p_limit integer default 100)
returns table(user_id uuid,display_name text,city text,country_code text)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_verified() then raise insufficient_privilege; end if;
  if p_limit is null or p_limit not between 1 and 200 then raise check_violation; end if;
  return query select p.user_id,p.display_name,c.name,c.country_code
    from public.profiles p join private.memberships m on m.user_id=p.user_id
    join public.cities c on c.id=p.city_id
    where m.status='verified' and private.member_verified(p.user_id) and p.directory_visible and p.map_opt_in
      order by p.user_id limit p_limit;
end; $$;

create function public.send_connection(p_recipient uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare result uuid;
begin
  if not private.is_verified() or not private.member_verified(p_recipient) or
    not exists(select 1 from public.profiles where user_id=p_recipient and directory_visible) then
    raise insufficient_privilege;
  end if;
  insert into public.connections(sender_id,recipient_id) values(auth.uid(),p_recipient) returning id into result;
  return result;
end; $$;

create function public.transition_connection(p_id uuid,p_action text) returns void
language plpgsql security definer set search_path = '' as $$
declare relation public.connections;
begin
  if not private.is_verified() then raise insufficient_privilege; end if;
  select * into strict relation from public.connections where id=p_id for update;
  if relation.status <> 'pending' then raise check_violation; end if;
  if not private.member_verified(relation.sender_id) or not private.member_verified(relation.recipient_id) then raise insufficient_privilege; end if;
  if (p_action in ('accepted','rejected') and relation.recipient_id=auth.uid()) or
     (p_action='cancelled' and relation.sender_id=auth.uid()) then
    update public.connections set status=p_action::public.connection_status,updated_at=now() where id=p_id;
  else raise insufficient_privilege;
  end if;
end; $$;

create function public.moderate_report(p_id uuid,p_status text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_admin() then raise insufficient_privilege; end if;
  if p_status not in ('resolved','dismissed') then raise check_violation; end if;
  update public.reports set status=p_status,moderated_by=auth.uid(),updated_at=now() where id=p_id;
  if not found then raise no_data_found; end if;
end; $$;

create function public.verification_history(p_user_id uuid)
returns table(id uuid,actor_id uuid,previous_status text,new_status text,verified_kind text,reason text,created_at timestamptz)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_admin() then raise insufficient_privilege; end if;
  return query select a.id,a.actor_id,a.previous_status::text,a.new_status::text,a.verified_kind::text,a.reason,a.created_at
    from private.verification_audit a where a.subject_id=p_user_id order by a.created_at,a.id;
end; $$;

-- Explicit per-function ACLs, including PUBLIC (which otherwise grants execution).
create function public.pending_memberships(p_limit integer default 30)
returns table(user_id uuid,display_name text,claimed_kind text,institution_id uuid,
  department_id uuid,joining_year integer,graduation_year integer)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_admin() then raise insufficient_privilege; end if;
  if p_limit is null or p_limit not between 1 and 100 then raise check_violation; end if;
  return query select p.user_id,p.display_name,p.claimed_kind::text,p.institution_id,
    p.department_id,p.joining_year::integer,p.graduation_year::integer
    from public.profiles p join private.memberships m on m.user_id=p.user_id
    where m.status='pending' order by p.created_at,p.user_id limit p_limit;
end; $$;

revoke all on function public.submit_onboarding(text,public.account_kind,uuid,uuid,integer,integer,text,text[],uuid[],uuid,boolean,boolean),
  public.my_membership(),public.review_membership(uuid,public.membership_status,public.account_kind,text),
  public.directory_profiles(text,integer),public.map_profiles(integer),public.send_connection(uuid),
  public.transition_connection(uuid,text),public.moderate_report(uuid,text),public.verification_history(uuid),public.pending_memberships(integer)
  from public,anon,authenticated;
grant execute on function public.submit_onboarding(text,public.account_kind,uuid,uuid,integer,integer,text,text[],uuid[],uuid,boolean,boolean),
  public.my_membership(),public.review_membership(uuid,public.membership_status,public.account_kind,text),
  public.directory_profiles(text,integer),public.map_profiles(integer),public.send_connection(uuid),
  public.transition_connection(uuid,text),public.moderate_report(uuid,text),public.verification_history(uuid),public.pending_memberships(integer)
  to authenticated;
commit;
