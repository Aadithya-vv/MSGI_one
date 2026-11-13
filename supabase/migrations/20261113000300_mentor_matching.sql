-- Task 06: local validation first; separate approval required for hosted deployment.
begin;
create table public.mentor_goals (
 user_id uuid primary key references public.profiles(user_id) on delete cascade,
 career_interests text[] not null default '{}', target_domains text[] not null default '{}',
 existing_skill_ids uuid[] not null default '{}', learning_skill_ids uuid[] not null default '{}',
 objectives text[] not null default '{}', updated_at timestamptz not null default now(),
 check(cardinality(career_interests)=0 or private.valid_text_list(career_interests,10,80)),
 check(cardinality(target_domains)=0 or private.valid_text_list(target_domains,10,120)),
 check(cardinality(objectives)=0 or private.valid_text_list(objectives,10,120)),
 check(cardinality(existing_skill_ids)<=30 and cardinality(learning_skill_ids)<=30)
);
alter table public.mentor_goals enable row level security;
revoke all on public.mentor_goals from public,anon,authenticated;
grant select on public.mentor_goals to authenticated;
create policy own_mentor_goals on public.mentor_goals for select to authenticated
 using(user_id=auth.uid() and private.is_verified());
-- Mentorship-scoped blocks: neither participant is recommended to the other.
create table private.mentor_blocks (
 blocker uuid not null references public.profiles(user_id) on delete cascade,
 blocked uuid not null references public.profiles(user_id) on delete cascade,
 primary key(blocker,blocked), check(blocker<>blocked)
);
create index mentor_blocks_reverse_idx on private.mentor_blocks(blocked,blocker);
alter table private.mentor_blocks enable row level security;
revoke all on private.mentor_blocks from public,anon,authenticated;
create index available_mentors_idx on public.mentorship_preferences(profile_id) where available;

create function public.my_mentor_goals() returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not private.is_verified() then raise insufficient_privilege; end if;
 select to_jsonb(g)-'user_id'-'updated_at' into result from public.mentor_goals g where g.user_id=auth.uid();
 if result is null then
 select jsonb_build_object('career_interests',p.career_interests,'target_domains',
 case when nullif(btrim(p.professional_domain),'') is null then '{}'::text[] else array[p.professional_domain] end,
 'existing_skill_ids',array(select ps.skill_id from public.profile_skills ps where ps.profile_id=p.user_id order by ps.skill_id),
 'learning_skill_ids','{}'::uuid[],'objectives','{}'::text[]) into result from public.profiles p where p.user_id=auth.uid();
 end if;
 return result||jsonb_build_object('skill_names',coalesce((select jsonb_object_agg(s.id::text,s.name) from public.skills s
 where s.id in (select v::uuid from jsonb_array_elements_text((result->'existing_skill_ids')||(result->'learning_skill_ids')) v)),'{}'::jsonb));
end; $$;
create function public.save_mentor_goals(p_input jsonb) returns void
language plpgsql security definer set search_path='' as $$
declare interests text[]; domains text[]; existing_ids uuid[]; learning_ids uuid[]; aims text[];
begin
 if not private.is_verified() then raise insufficient_privilege; end if;
 if p_input is null or jsonb_typeof(p_input)<>'object' or
 exists(select 1 from jsonb_object_keys(p_input) k where k not in ('career_interests','target_domains','existing_skill_ids','learning_skill_ids','objectives')) or
 exists(select 1 from (values('career_interests'),('target_domains'),('existing_skill_ids'),('learning_skill_ids'),('objectives')) f(k)
 where jsonb_typeof(p_input->f.k) is distinct from 'array' or jsonb_array_length(p_input->f.k)>30) then raise check_violation; end if;
 if exists(select 1 from jsonb_each(p_input) e cross join lateral jsonb_array_elements(e.value) v where jsonb_typeof(v)<>'string') then raise check_violation; end if;
 select coalesce(array_agg(distinct btrim(v)), '{}') into interests from jsonb_array_elements_text(p_input->'career_interests') v;
 select coalesce(array_agg(distinct btrim(v)), '{}') into domains from jsonb_array_elements_text(p_input->'target_domains') v;
 select coalesce(array_agg(distinct v::uuid), '{}') into existing_ids from jsonb_array_elements_text(p_input->'existing_skill_ids') v;
 select coalesce(array_agg(distinct v::uuid), '{}') into learning_ids from jsonb_array_elements_text(p_input->'learning_skill_ids') v;
 select coalesce(array_agg(distinct btrim(v)), '{}') into aims from jsonb_array_elements_text(p_input->'objectives') v;
 if exists(select 1 from unnest(existing_ids||learning_ids) ids(skill_id) where not exists(select 1 from public.skills s where s.id=ids.skill_id)) then raise check_violation; end if;
 insert into public.mentor_goals(user_id,career_interests,target_domains,existing_skill_ids,learning_skill_ids,objectives)
 values(auth.uid(),interests,domains,existing_ids,learning_ids,aims)
 on conflict(user_id) do update set career_interests=excluded.career_interests,target_domains=excluded.target_domains,
 existing_skill_ids=excluded.existing_skill_ids,learning_skill_ids=excluded.learning_skill_ids,objectives=excluded.objectives,updated_at=now();
end; $$;
create function public.set_mentor_block(p_peer uuid,p_block boolean) returns void
language plpgsql security definer set search_path='' as $$
begin
 if not private.is_verified() then raise insufficient_privilege; end if;
 if p_peer is null or p_peer=auth.uid() or p_block is null then raise check_violation; end if;
 if p_block then
  if not exists(select 1 from public.profiles p join private.memberships m on m.user_id=p.user_id
    where p.user_id=p_peer and private.member_verified(p.user_id) and p.directory_visible and m.verified_kind='alumni') then raise insufficient_privilege; end if;
  insert into private.mentor_blocks values(auth.uid(),p_peer) on conflict do nothing;
 else delete from private.mentor_blocks b where b.blocker=auth.uid() and b.blocked=p_peer; end if;
end; $$;

create function public.recommend_mentors(p_domain text default '',p_unconnected boolean default false,
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
  join public.departments d on d.id=p.department_id and d.active
  left join public.connections c on c.user_low=least(auth.uid(),p.user_id) and c.user_high=greatest(auth.uid(),p.user_id)
  where mp.available and m.status='verified' and m.verified_kind='alumni' and private.member_verified(p.user_id)
   and p.directory_visible and p.user_id<>auth.uid()
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
revoke all on function public.my_mentor_goals(),public.save_mentor_goals(jsonb),public.set_mentor_block(uuid,boolean),public.recommend_mentors(text,boolean,text,numeric,uuid,integer) from public,anon,authenticated;
grant execute on function public.my_mentor_goals(),public.save_mentor_goals(jsonb),public.set_mentor_block(uuid,boolean),public.recommend_mentors(text,boolean,text,numeric,uuid,integer) to authenticated;
notify pgrst,'reload schema';
commit;
