-- Task 11A: local only until separately reviewed hosted deployment.
begin;
alter table public.institutions add column catalog_key text unique;
create table public.programmes (
 id uuid primary key default gen_random_uuid(),
 institution_id uuid not null references public.institutions(id),
 application_key text not null unique check(application_key ~ '^[a-z0-9-]{1,80}$'),
 name text not null check(char_length(btrim(name)) between 2 and 160),
 level text not null check(level in ('undergraduate','postgraduate')),
 active boolean not null default true,
 unique(id,institution_id), unique(institution_id,name)
);
alter table public.programmes enable row level security;
revoke all on public.programmes from public,anon,authenticated;
grant select on public.programmes to authenticated;
grant all on public.programmes to service_role;
create policy programme_catalog on public.programmes for select to authenticated
 using(active and private.account_allowed());
alter table public.profiles
 alter column department_id drop not null,
 alter column joining_year drop not null,
 alter column graduation_year drop not null,
 add column programme_id uuid,
 add column affiliation text not null default '' check(char_length(affiliation)<=120),
 add constraint profile_programme_institution foreign key(programme_id,institution_id) references public.programmes(id,institution_id),
 add constraint staff_no_degree_programme check(claimed_kind<>'staff' or (programme_id is null and joining_year is null and graduation_year is null));
create index profiles_programme_idx on public.profiles(programme_id,user_id);

create or replace function public.save_member_profile(p_input jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); status_value public.membership_status; previous public.profiles;
 selected_skills uuid[]; interests text[]; kind_value public.account_kind;
 institution_value uuid; department_value uuid; programme_value uuid;
 joining_value integer; graduation_value integer; degree_value text; is_msec boolean;
begin
 if actor is null or not private.account_allowed() or not exists(
   select 1 from auth.users u where u.id=actor and u.email_confirmed_at is not null
   and u.deleted_at is null and (u.banned_until is null or u.banned_until<=now())) then raise insufficient_privilege; end if;
 if p_input is null or jsonb_typeof(p_input)<>'object' or octet_length(p_input::text)>16000 then raise check_violation; end if;
 if exists(select 1 from jsonb_object_keys(p_input) k where k not in
 ('display_name','kind','institution_id','department_id','programme_id','affiliation','joining_year','graduation_year',
 'designation','interests','skill_ids','city_id','directory_visible','map_opt_in','company','professional_domain','biography','degree','mentoring')) then
 raise check_violation using message='Unsupported profile field'; end if;
 kind_value:=(p_input->>'kind')::public.account_kind;
 institution_value:=(p_input->>'institution_id')::uuid;
 department_value:=nullif(p_input->>'department_id','')::uuid;
 programme_value:=nullif(p_input->>'programme_id','')::uuid;
 joining_value:=nullif(p_input->>'joining_year','')::integer;
 graduation_value:=nullif(p_input->>'graduation_year','')::integer;
 if kind_value is null or not exists(select 1 from public.institutions i where i.id=institution_value and i.active) then raise check_violation; end if;
 select i.catalog_key='msec' into is_msec from public.institutions i where i.id=institution_value;
 if department_value is not null and not exists(select 1 from public.departments d where d.id=department_value and d.institution_id=institution_value and d.active) then raise check_violation; end if;
 if programme_value is not null then
   select pr.name into degree_value from public.programmes pr where pr.id=programme_value and pr.institution_id=institution_value and pr.active;
   if not found then raise check_violation using message='Invalid programme'; end if;
 else degree_value:=btrim(coalesce(p_input->>'degree','')); end if;
 if kind_value='staff' then
   if programme_value is not null or joining_value is not null or graduation_value is not null or
     nullif(btrim(p_input->>'designation'),'') is null or
     (department_value is null and nullif(btrim(p_input->>'affiliation'),'') is null) then raise check_violation using message='Staff designation and affiliation required'; end if;
   degree_value:='';
 else
   if (coalesce(is_msec,false) and programme_value is null) or (programme_value is null and department_value is null) then raise check_violation using message='Select a degree programme'; end if;
   if graduation_value is null or graduation_value<1950 or graduation_value>extract(year from current_date)+8 or
      (kind_value='alumni' and graduation_value>extract(year from current_date)) or
      (kind_value='student' and joining_value is null) or
      (joining_value is not null and (joining_value<1950 or joining_value>extract(year from current_date) or graduation_value<joining_value)) then raise check_violation using message='Invalid academic years'; end if;
 end if;
 selected_skills:=array(select jsonb_array_elements_text(p_input->'skill_ids')::uuid);
 interests:=array(select jsonb_array_elements_text(p_input->'interests'));
 if cardinality(selected_skills)>20 or (kind_value<>'staff' and cardinality(selected_skills)<1) or
   (select count(distinct s) from unnest(selected_skills) s)<>cardinality(selected_skills) or
   exists(select 1 from unnest(selected_skills) s where not exists(select 1 from public.skills sk where sk.id=s)) or
   not private.valid_text_list(interests,10,80) then raise check_violation; end if;
 perform pg_advisory_xact_lock(hashtextextended(actor::text,0));
 select m.status into status_value from private.memberships m where m.user_id=actor for update;
 select p.* into previous from public.profiles p where p.user_id=actor;
 if status_value='verified' and (previous.claimed_kind is distinct from kind_value or previous.institution_id is distinct from institution_value or
   previous.department_id is distinct from department_value or previous.programme_id is distinct from programme_value or
   previous.joining_year is distinct from joining_value or previous.graduation_year is distinct from graduation_value or
   previous.affiliation is distinct from btrim(coalesce(p_input->>'affiliation',''))) then raise insufficient_privilege using message='Reviewed affiliation is immutable'; end if;
 if status_value is not null and status_value not in ('pending','verified') then raise insufficient_privilege; end if;
 insert into public.profiles(user_id,display_name,claimed_kind,institution_id,department_id,programme_id,affiliation,joining_year,graduation_year,
 designation,career_interests,city_id,directory_visible,map_opt_in,company,professional_domain,biography,degree)
 values(actor,btrim(p_input->>'display_name'),kind_value,institution_value,department_value,programme_value,btrim(coalesce(p_input->>'affiliation','')),joining_value,graduation_value,
 nullif(btrim(p_input->>'designation'),''),interests,nullif(p_input->>'city_id','')::uuid,coalesce((p_input->>'directory_visible')::boolean,false),
 coalesce((p_input->>'map_opt_in')::boolean,false),btrim(coalesce(p_input->>'company','')),btrim(coalesce(p_input->>'professional_domain','')),btrim(coalesce(p_input->>'biography','')),degree_value)
 on conflict(user_id) do update set display_name=excluded.display_name,claimed_kind=excluded.claimed_kind,institution_id=excluded.institution_id,
 department_id=excluded.department_id,programme_id=excluded.programme_id,affiliation=excluded.affiliation,joining_year=excluded.joining_year,graduation_year=excluded.graduation_year,
 designation=excluded.designation,career_interests=excluded.career_interests,city_id=excluded.city_id,directory_visible=excluded.directory_visible,map_opt_in=excluded.map_opt_in,
 company=excluded.company,professional_domain=excluded.professional_domain,biography=excluded.biography,degree=excluded.degree;
 delete from public.profile_skills ps where ps.profile_id=actor;
 insert into public.profile_skills(profile_id,skill_id) select actor,unnest(selected_skills);
 insert into private.memberships(user_id) values(actor) on conflict(user_id) do nothing;
 if status_value is null then insert into private.verification_audit(subject_id,actor_id,new_status,reason)
 values(actor,actor,'pending','Profile submitted for institutional review'); end if;
 insert into public.mentorship_preferences(profile_id,available) values(actor,kind_value='alumni' and coalesce((p_input->>'mentoring')::boolean,false))
 on conflict(profile_id) do update set available=excluded.available;
 delete from public.profile_drafts pd where pd.user_id=actor;
end; $$;

-- Legacy signature retained; delegates to the same validation/write boundary.
create or replace function public.submit_onboarding(
 p_display_name text,p_kind public.account_kind,p_institution uuid,p_department uuid,
 p_joining_year integer,p_graduation_year integer,p_designation text,p_interests text[],p_skills uuid[],
 p_city uuid default null,p_directory_visible boolean default false,p_map_opt_in boolean default false
) returns void language sql security definer set search_path='' as $$
 select public.save_member_profile(jsonb_build_object('display_name',p_display_name,'kind',p_kind,
 'institution_id',p_institution,'department_id',p_department,'joining_year',p_joining_year,'graduation_year',p_graduation_year,
 'designation',p_designation,'interests',p_interests,'skill_ids',p_skills,'city_id',p_city,'directory_visible',p_directory_visible,'map_opt_in',p_map_opt_in));
$$;
-- Keep existing RPC ACLs; explicit revocation also covers fresh deployments.
revoke all on function public.save_member_profile(jsonb) from public,anon;
grant execute on function public.save_member_profile(jsonb) to authenticated;

-- Preserve old RPC signatures/projections and privacy checks for legacy clients.
create or replace function public.directory_profiles(p_search text default '', p_limit integer default 30)
returns table(user_id uuid,display_name text,kind text,institution text,department text,designation text,skills text[])
language plpgsql stable security definer set search_path = '' as $$
begin
  if not private.is_verified() then raise insufficient_privilege using message='Verified membership required'; end if;
  if p_limit is null or p_limit not between 1 and 100 or char_length(p_search)>100 then raise check_violation; end if;
  return query select p.user_id,p.display_name,m.verified_kind::text,i.name,d.name,p.designation,
    coalesce((select array_agg(s.name order by s.name) from public.profile_skills ps
      join public.skills s on s.id=ps.skill_id where ps.profile_id=p.user_id),'{}'::text[])
    from public.profiles p join private.memberships m on m.user_id=p.user_id
    join public.institutions i on i.id=p.institution_id left join public.departments d on d.id=p.department_id
    where m.status='verified' and private.member_verified(p.user_id) and p.directory_visible and i.active and (p.department_id is null or d.active)
      and (coalesce(btrim(p_search),'')='' or to_tsvector('simple',p.display_name||' '||coalesce(p.designation,''))
        @@ plainto_tsquery('simple',p_search)) order by p.display_name,p.user_id limit p_limit;
end; $$;

create or replace function public.discover_alumni(
  p_search text default '', p_institution uuid default null,p_department uuid default null,
  p_year integer default null,p_profession text default '',p_skill uuid default null,p_city uuid default null,
  p_after uuid default null,p_limit integer default 20,p_user uuid default null
) returns table(user_id uuid,display_name text,institution text,department text,graduation_year integer,
  designation text,company text,professional_domain text,biography text,degree text,skills text[],
  city text,country_code text,mentoring boolean)
language plpgsql stable security definer set search_path='' as $$
begin
  if not private.is_verified() then raise insufficient_privilege using message='Verified membership required'; end if;
  if p_limit is null or p_limit not between 1 and 50 or p_search is null or char_length(p_search)>100 or
    p_profession is null or char_length(p_profession)>120 then raise check_violation; end if;
  return query select p.user_id,p.display_name,i.name,d.name,p.graduation_year::integer,p.designation,
    p.company,p.professional_domain,p.biography,p.degree,
    coalesce((select array_agg(s.name order by s.name) from public.profile_skills ps join public.skills s on s.id=ps.skill_id where ps.profile_id=p.user_id),'{}'::text[]),
    case when p.map_opt_in then c.name end,case when p.map_opt_in then c.country_code end,coalesce(mp.available,false)
  from public.profiles p join private.memberships m on m.user_id=p.user_id
    join public.institutions i on i.id=p.institution_id left join public.departments d on d.id=p.department_id
    left join public.cities c on c.id=p.city_id left join public.mentorship_preferences mp on mp.profile_id=p.user_id
  where m.status='verified' and m.verified_kind='alumni' and private.member_verified(p.user_id)
    and p.directory_visible and i.active and (p.department_id is null or d.active)
    and (p_user is null or p.user_id=p_user) and (p_after is null or p.user_id>p_after)
    and (p_institution is null or p.institution_id=p_institution)
    and (p_department is null or p.department_id=p_department) and (p_year is null or p.graduation_year=p_year)
    and (btrim(p_search)='' or position(lower(btrim(p_search)) in lower(p.display_name))>0)
    and (btrim(p_profession)='' or position(lower(btrim(p_profession)) in lower(coalesce(p.designation,'')||' '||p.company||' '||p.professional_domain))>0)
    and (p_skill is null or exists(select 1 from public.profile_skills ps where ps.profile_id=p.user_id and ps.skill_id=p_skill))
    -- Hidden location must not be inferred through a filter.
    and (p_city is null or (p.map_opt_in and p.city_id=p_city))
  order by p.user_id limit p_limit;
end; $$;

create or replace function public.discover_alumni_v2(
  p_search text default '', p_institution uuid default null,p_department uuid default null,
  p_year integer default null,p_profession text default '',p_skill uuid default null,p_city uuid default null,
  p_after uuid default null,p_limit integer default 20,p_user uuid default null,p_programme uuid default null
) returns table(user_id uuid,display_name text,institution text,department text,graduation_year integer,
  designation text,company text,professional_domain text,biography text,degree text,skills text[],
  city text,country_code text,mentoring boolean,programme_id uuid,programme text)
language plpgsql stable security definer set search_path='' as $$
begin
  if not private.is_verified() then raise insufficient_privilege using message='Verified membership required'; end if;
  if p_limit is null or p_limit not between 1 and 50 or p_search is null or char_length(p_search)>100 or
    p_profession is null or char_length(p_profession)>120 then raise check_violation; end if;
  return query select p.user_id,p.display_name,i.name,d.name,p.graduation_year::integer,p.designation,
    p.company,p.professional_domain,p.biography,p.degree,
    coalesce((select array_agg(s.name order by s.name) from public.profile_skills ps join public.skills s on s.id=ps.skill_id where ps.profile_id=p.user_id),'{}'::text[]),
    case when p.map_opt_in then c.name end,case when p.map_opt_in then c.country_code end,coalesce(mp.available,false),p.programme_id,pr.name
  from public.profiles p join private.memberships m on m.user_id=p.user_id
    join public.institutions i on i.id=p.institution_id left join public.departments d on d.id=p.department_id
    left join public.programmes pr on pr.id=p.programme_id
    left join public.cities c on c.id=p.city_id left join public.mentorship_preferences mp on mp.profile_id=p.user_id
  where m.status='verified' and m.verified_kind='alumni' and private.member_verified(p.user_id)
    and p.directory_visible and i.active and (p.department_id is null or d.active)
    and (p_user is null or p.user_id=p_user) and (p_after is null or p.user_id>p_after)
    and (p_programme is null or p.programme_id=p_programme)
    and (p_institution is null or p.institution_id=p_institution)
    and (p_department is null or p.department_id=p_department) and (p_year is null or p.graduation_year=p_year)
    and (btrim(p_search)='' or position(lower(btrim(p_search)) in lower(p.display_name))>0)
    and (btrim(p_profession)='' or position(lower(btrim(p_profession)) in lower(coalesce(p.designation,'')||' '||p.company||' '||p.professional_domain))>0)
    and (p_skill is null or exists(select 1 from public.profile_skills ps where ps.profile_id=p.user_id and ps.skill_id=p_skill))
    -- Hidden location must not be inferred through a filter.
    and (p_city is null or (p.map_opt_in and p.city_id=p_city))
  order by p.user_id limit p_limit;
end; $$;
revoke all on function public.discover_alumni_v2(text,uuid,uuid,integer,text,uuid,uuid,uuid,integer,uuid,uuid) from public,anon,authenticated;
grant execute on function public.discover_alumni_v2(text,uuid,uuid,integer,text,uuid,uuid,uuid,integer,uuid,uuid) to authenticated;

create or replace function public.alumni_city_clusters(p_location text default '',p_domain text default '',p_after uuid default null,p_limit integer default 101)
returns table(city_id uuid,city text,country_code text,latitude numeric,longitude numeric,alumni_count bigint)
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_verified() then raise insufficient_privilege; end if;
 if p_location is null or p_domain is null or char_length(p_location)>100 or char_length(p_domain)>120 or p_limit is null or p_limit not between 1 and 201 then raise check_violation; end if;
 return query select c.id,c.name,c.country_code,c.centroid_latitude,c.centroid_longitude,count(*)
 from public.profiles p join private.memberships m on m.user_id=p.user_id
 join public.institutions i on i.id=p.institution_id and i.active
 left join public.departments d on d.id=p.department_id
 join public.cities c on c.id=p.city_id and c.centroid_latitude is not null
 where m.status='verified' and m.verified_kind='alumni' and private.member_verified(p.user_id)
 and (p.department_id is null or d.active) and p.directory_visible and p.map_opt_in
 and (p_after is null or c.id>p_after)
 and (btrim(p_location)='' or position(lower(btrim(p_location)) in lower(c.name||' '||c.country_code))>0)
 and (btrim(p_domain)='' or position(lower(btrim(p_domain)) in lower(p.professional_domain))>0)
 group by c.id order by c.id limit p_limit;
end; $$;

create or replace function public.map_city_members(p_city uuid,p_domain text default '',p_after uuid default null,p_limit integer default 21)
returns table(user_id uuid,display_name text,institution text,department text,graduation_year integer,designation text,company text,professional_domain text,skills text[])
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_verified() then raise insufficient_privilege; end if;
 if p_domain is null or char_length(p_domain)>120 or p_city is null or p_limit is null or p_limit not between 1 and 51 then raise check_violation; end if;
 return query select p.user_id,p.display_name,i.name,d.name,p.graduation_year::integer,p.designation,p.company,p.professional_domain,
 coalesce((select array_agg(s.name order by s.name) from public.profile_skills ps join public.skills s on s.id=ps.skill_id where ps.profile_id=p.user_id),'{}'::text[])
 from public.profiles p join private.memberships m on m.user_id=p.user_id
 join public.institutions i on i.id=p.institution_id and i.active
 left join public.departments d on d.id=p.department_id
 join public.cities c on c.id=p.city_id and c.centroid_latitude is not null
 where p.city_id=p_city and m.status='verified' and m.verified_kind='alumni' and private.member_verified(p.user_id)
 and (p.department_id is null or d.active) and p.directory_visible and p.map_opt_in and (p_after is null or p.user_id>p_after)
 and (btrim(p_domain)='' or position(lower(btrim(p_domain)) in lower(p.professional_domain))>0)
 order by p.user_id limit p_limit;
end; $$;

create or replace function public.network_connections(p_tab text default 'accepted',p_after uuid default null,p_limit integer default 21,p_peer uuid default null)
returns table(connection_id uuid,peer_id uuid,display_name text,company text,status text,incoming boolean,profile_available boolean,peer_eligible boolean)
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_verified() then raise insufficient_privilege; end if;
 if p_tab is null or p_tab not in ('incoming','outgoing','accepted','all') or p_limit is null or p_limit not between 1 and 51 then raise check_violation; end if;
 return query select c.id,p.user_id,
 case when private.member_verified(p.user_id) and p.directory_visible then p.display_name end,
 case when private.member_verified(p.user_id) and p.directory_visible then p.company end,
 c.status::text,c.recipient_id=auth.uid(),private.member_verified(p.user_id) and p.directory_visible and exists(select 1 from private.memberships pm join public.institutions pi on pi.id=p.institution_id and pi.active left join public.departments pd on pd.id=p.department_id where pm.user_id=p.user_id and (p.department_id is null or pd.active) and pm.verified_kind='alumni'),private.member_verified(p.user_id)
 from public.connections c join public.profiles p on p.user_id=case when c.sender_id=auth.uid() then c.recipient_id else c.sender_id end
 where auth.uid() in(c.sender_id,c.recipient_id) and (p_after is null or c.id>p_after) and (p_peer is null or p.user_id=p_peer)
 and (p_tab='all' or (p_tab='accepted' and c.status='accepted') or (p_tab='incoming' and c.status='pending' and c.recipient_id=auth.uid()) or (p_tab='outgoing' and c.status='pending' and c.sender_id=auth.uid()))
 order by c.id limit p_limit;
end; $$;

create or replace function public.recommend_mentors(p_domain text default '',p_unconnected boolean default false,
 p_sort text default 'relevance',p_after_rank numeric default null,p_after_id uuid default null,p_limit integer default 21)
returns table(user_id uuid,display_name text,institution text,designation text,company text,professional_domain text,
 score integer,evidence_count integer,shared_skills text[],matching_domains text[],shared_interests text[],
 connection_status text,incoming boolean,rank_value numeric)
language plpgsql stable security definer set search_path='' as $$
declare goals jsonb; wanted uuid[]; wanted_domains text[]; wanted_interests text[];
begin
 if not private.is_verified() then raise insufficient_privilege; end if;
 if p_domain is null or char_length(p_domain)>120 or p_unconnected is null or p_sort is null or p_sort not in ('relevance','skills','domain')
 or p_limit is null or p_limit not between 1 and 51 or (p_after_rank is null)<>(p_after_id is null) then raise check_violation; end if;
 goals:=public.my_mentor_goals();
 select coalesce(array_agg(distinct v::uuid),'{}') into wanted from jsonb_array_elements_text((goals->'existing_skill_ids')||(goals->'learning_skill_ids')) v;
 select coalesce(array_agg(distinct lower(btrim(v))),'{}') into wanted_domains from jsonb_array_elements_text(goals->'target_domains') v;
 select coalesce(array_agg(distinct lower(btrim(v))),'{}') into wanted_interests from jsonb_array_elements_text(goals->'career_interests') v;
 return query with eligible as (
  select p.*,i.name institution_name,c.status::text relationship,c.recipient_id=auth.uid() is_incoming,
    array(select ps.skill_id from public.profile_skills ps where ps.profile_id=p.user_id) skill_ids
  from public.mentorship_preferences mp join public.profiles p on p.user_id=mp.profile_id
  join private.memberships m on m.user_id=p.user_id
  join public.institutions i on i.id=p.institution_id and i.active
  left join public.departments d on d.id=p.department_id
  left join public.connections c on c.user_low=least(auth.uid(),p.user_id) and c.user_high=greatest(auth.uid(),p.user_id)
  where mp.available and m.status='verified' and m.verified_kind='alumni' and private.member_verified(p.user_id)
   and (p.department_id is null or d.active) and p.directory_visible and p.user_id<>auth.uid()
   and not exists(select 1 from private.mentor_blocks b where (b.blocker=auth.uid() and b.blocked=p.user_id) or (b.blocker=p.user_id and b.blocked=auth.uid()))
   and (btrim(p_domain)='' or position(lower(btrim(p_domain)) in lower(p.professional_domain))>0)
   and (not p_unconnected or c.id is null or c.status='cancelled')
 ), components as (
  select e.*,
   case when cardinality(wanted)>0 and cardinality(e.skill_ids)>0 then (select count(*)::numeric/cardinality(wanted) from unnest(wanted) w where w=any(e.skill_ids)) end sk,
   case when cardinality(wanted_domains)>0 and nullif(btrim(e.professional_domain),'') is not null then case when lower(btrim(e.professional_domain))=any(wanted_domains) then 1::numeric else 0::numeric end end dm,
   case when cardinality(wanted_interests)>0 and cardinality(e.career_interests)>0 then
    (select count(distinct lower(btrim(v)))::numeric/cardinality(wanted_interests) from unnest(e.career_interests) v where lower(btrim(v))=any(wanted_interests)) end intr
  from eligible e
 ), scored as (
  select q.*,(case when q.sk is null then 0 else 1 end+case when q.dm is null then 0 else 1 end+case when q.intr is null then 0 else 1 end) evidence,
   case when coalesce(q.sk,0)+coalesce(q.dm,0)+coalesce(q.intr,0)=0 then 0 else
    least(case when (q.sk is not null)::int+(q.dm is not null)::int+(q.intr is not null)::int=1 then 65
      when (q.sk is not null)::int+(q.dm is not null)::int+(q.intr is not null)::int=2 then 85 else 100 end,
     round(100*(.4*coalesce(q.sk,0)+.3*coalesce(q.dm,0)+.2+.1*coalesce(q.intr,0)) /
      (.2+case when q.sk is null then 0 else .4 end+case when q.dm is null then 0 else .3 end+case when q.intr is null then 0 else .1 end))::integer) end points
  from components q
 ), ranked as (
  select s.*,round(s.points+case p_sort when 'skills' then coalesce(s.sk,0)*1000 when 'domain' then coalesce(s.dm,0)*1000 else 0 end,6) ordering
  from scored s
 ) select r.user_id,r.display_name,r.institution_name,r.designation,r.company,r.professional_domain,r.points,r.evidence,
  array(select s.name from public.skills s where s.id=any(wanted) and s.id=any(r.skill_ids) order by lower(s.name),s.id),
  case when r.dm=1 then array[r.professional_domain] else '{}'::text[] end,
  array(select distinct btrim(v) from unnest(r.career_interests) v where lower(btrim(v))=any(wanted_interests) order by btrim(v)),
  r.relationship,coalesce(r.is_incoming,false),r.ordering
 from ranked r where p_after_id is null or r.ordering<p_after_rank or (r.ordering=p_after_rank and r.user_id>p_after_id)
 order by r.ordering desc,r.user_id limit p_limit;
end; $$;

create or replace function private.career_visible(subject uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select private.is_verified() and exists(select 1 from public.opportunities o
 join public.profiles author on author.user_id=o.author_id
 join public.institutions i on i.id=author.institution_id and i.active
 left join public.departments d on d.id=author.department_id
 join public.profiles viewer on viewer.user_id=auth.uid()
 where (author.department_id is null or d.active) and o.id=subject and (o.author_id=auth.uid() or (o.status='published' and o.archived_at is null and private.member_verified(o.author_id)
 and (o.audience='community' or (o.institution_id=viewer.institution_id and (o.audience='institution' or o.department_id=viewer.department_id))))));
$$;

create or replace function public.career_can_publish() returns boolean
language sql stable security definer set search_path='' as $$ select private.can_publish() and exists(
 select 1 from public.profiles p join public.institutions i on i.id=p.institution_id and i.active
 left join public.departments d on d.id=p.department_id where (p.department_id is null or d.active) and p.user_id=auth.uid()); $$;


notify pgrst,'reload schema';
commit;
