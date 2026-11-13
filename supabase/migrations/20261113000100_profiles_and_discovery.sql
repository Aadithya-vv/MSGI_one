-- Task 04A: review before hosted deployment. Existing RPCs remain unchanged.
begin;
alter table public.profiles
  add column company text not null default '' check(char_length(company)<=120),
  add column professional_domain text not null default '' check(char_length(professional_domain)<=120),
  add column biography text not null default '' check(char_length(biography)<=1000),
  add column degree text not null default '' check(char_length(degree)<=120);
-- No new direct client UPDATE grants: validated RPC is the write boundary.
create table public.profile_drafts (
  user_id uuid primary key references auth.users(id) on delete cascade,
  content jsonb not null check(jsonb_typeof(content)='object' and octet_length(content::text)<=16000),
  updated_at timestamptz not null default now()
);
alter table public.profile_drafts enable row level security;
revoke all on public.profile_drafts from public,anon,authenticated;
grant select,insert,update,delete on public.profile_drafts to authenticated;
create policy own_allowed_draft on public.profile_drafts to authenticated
  using(user_id=auth.uid() and private.account_allowed())
  with check(user_id=auth.uid() and private.account_allowed());

create function public.save_member_profile(p_input jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); status_value public.membership_status; previous public.profiles;
  selected_skills uuid[]; interests text[];
begin
  if actor is null or not private.account_allowed() then raise insufficient_privilege; end if;
  if jsonb_typeof(p_input)<>'object' or octet_length(p_input::text)>16000 then raise check_violation; end if;
  if exists(select 1 from jsonb_object_keys(p_input) k where k not in
    ('display_name','kind','institution_id','department_id','joining_year','graduation_year','designation',
    'interests','skill_ids','city_id','directory_visible','map_opt_in','company','professional_domain','biography','degree','mentoring')) then
    raise check_violation using message='Unsupported profile field';
  end if;
  perform pg_advisory_xact_lock(hashtextextended(actor::text,0));
  select m.status into status_value from private.memberships m where m.user_id=actor for update;
  select p.* into previous from public.profiles p where p.user_id=actor;
  selected_skills:=array(select jsonb_array_elements_text(p_input->'skill_ids')::uuid);
  interests:=array(select jsonb_array_elements_text(p_input->'interests'));
  if cardinality(selected_skills) not between 1 and 20 or
    (select count(distinct s) from unnest(selected_skills) s)<>cardinality(selected_skills) or
    exists(select 1 from unnest(selected_skills) s where not exists(select 1 from public.skills sk where sk.id=s)) then raise check_violation; end if;
  if status_value is null or status_value='pending' then
    perform public.submit_onboarding(p_input->>'display_name',(p_input->>'kind')::public.account_kind,
      (p_input->>'institution_id')::uuid,(p_input->>'department_id')::uuid,
      (p_input->>'joining_year')::integer,(p_input->>'graduation_year')::integer,p_input->>'designation',
      interests,selected_skills,nullif(p_input->>'city_id','')::uuid,
      coalesce((p_input->>'directory_visible')::boolean,false),coalesce((p_input->>'map_opt_in')::boolean,false));
  elsif status_value='verified' then
    -- Verified education/identity claims require institutional review, not client edits.
    if previous.claimed_kind::text is distinct from p_input->>'kind' or
      previous.institution_id is distinct from (p_input->>'institution_id')::uuid or
      previous.department_id is distinct from (p_input->>'department_id')::uuid or
      previous.joining_year is distinct from (p_input->>'joining_year')::integer or
      previous.graduation_year is distinct from (p_input->>'graduation_year')::integer then raise insufficient_privilege; end if;
    update public.profiles set display_name=btrim(p_input->>'display_name'),designation=nullif(btrim(p_input->>'designation'),''),
      career_interests=interests,city_id=nullif(p_input->>'city_id','')::uuid,
      directory_visible=coalesce((p_input->>'directory_visible')::boolean,false),
      map_opt_in=coalesce((p_input->>'map_opt_in')::boolean,false) where user_id=actor;
    delete from public.profile_skills where profile_id=actor;
    insert into public.profile_skills(profile_id,skill_id) select actor,unnest(selected_skills);
  else raise insufficient_privilege;
  end if;
  update public.profiles set company=btrim(coalesce(p_input->>'company','')),
    professional_domain=btrim(coalesce(p_input->>'professional_domain','')),
    biography=btrim(coalesce(p_input->>'biography','')),degree=btrim(coalesce(p_input->>'degree','')) where user_id=actor;
  insert into public.mentorship_preferences(profile_id,available)
    values(actor,coalesce((p_input->>'mentoring')::boolean,false))
    on conflict(profile_id) do update set available=excluded.available;
  delete from public.profile_drafts where user_id=actor;
end; $$;

create function public.discover_alumni(
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
    join public.institutions i on i.id=p.institution_id join public.departments d on d.id=p.department_id
    left join public.cities c on c.id=p.city_id left join public.mentorship_preferences mp on mp.profile_id=p.user_id
  where m.status='verified' and m.verified_kind='alumni' and private.member_verified(p.user_id)
    and p.directory_visible and i.active and d.active
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
revoke all on function public.save_member_profile(jsonb),public.discover_alumni(text,uuid,uuid,integer,text,uuid,uuid,uuid,integer,uuid) from public,anon,authenticated;
grant execute on function public.save_member_profile(jsonb),public.discover_alumni(text,uuid,uuid,integer,text,uuid,uuid,uuid,integer,uuid) to authenticated;
notify pgrst,'reload schema';
commit;
