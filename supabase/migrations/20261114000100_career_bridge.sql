-- Task 07. Local-first; hosted deployment requires separate approval.
begin;
alter table public.opportunities add column professional_domain text not null default '' check(char_length(professional_domain)<=120),
 add column organization text not null default '' check(char_length(organization)<=160),
 add column remote boolean not null default false,
 add column referral boolean not null default false check(not referral or kind in ('job','internship')),
 add column audience text not null default 'community' check(audience in ('community','institution','department')),
 add column institution_id uuid references public.institutions(id),
 add column department_id uuid,
 add column archived_at timestamptz,
 add constraint opportunity_department_scope foreign key(department_id,institution_id) references public.departments(id,institution_id),
 add constraint opportunity_audience_scope check((audience='community' and institution_id is null and department_id is null) or
 (audience='institution' and institution_id is not null and department_id is null) or
 (audience='department' and institution_id is not null and department_id is not null));
create index career_recent_idx on public.opportunities(created_at desc,id desc) where archived_at is null;
create index career_scope_idx on public.opportunities(institution_id,department_id,status);
create table public.opportunity_skills(
 opportunity_id uuid not null references public.opportunities(id) on delete cascade,
 skill_id uuid not null references public.skills(id), primary key(opportunity_id,skill_id)
);
create index career_required_skill_idx on public.opportunity_skills(skill_id,opportunity_id);
alter table public.opportunity_skills enable row level security;
revoke all on public.opportunity_skills from public,anon,authenticated;
grant select on public.opportunity_skills to authenticated;

create function private.safe_career_url(link text) returns boolean language sql immutable set search_path='' as $$
 select link is null or (char_length(link)<=2048 and
 link ~ '^https://([A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}([/?#][^[:space:]]*)?$'
 and link !~ '[[:space:][:cntrl:]]' and position(chr(92) in link)=0 and lower(link) !~ '%0[ad]'
 and lower(substring(link from '^https://([^/?#]+)')) !~ '(^|\.)(localhost|local|internal|test|invalid)$');
$$;
-- Legacy rows are not rewritten. New/changed rows must satisfy the stronger URL rule.
alter table public.opportunities add constraint career_safe_external_url check(private.safe_career_url(external_url)) not valid;
create function private.career_visible(subject uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select private.is_verified() and exists(select 1 from public.opportunities o
 join public.profiles author on author.user_id=o.author_id
 join public.institutions i on i.id=author.institution_id and i.active
 join public.departments d on d.id=author.department_id and d.active
 join public.profiles viewer on viewer.user_id=auth.uid()
 where o.id=subject and (o.author_id=auth.uid() or (o.status='published' and o.archived_at is null and private.member_verified(o.author_id)
 and (o.audience='community' or (o.institution_id=viewer.institution_id and (o.audience='institution' or o.department_id=viewer.department_id))))));
$$;
create policy career_visibility_guard on public.opportunities as restrictive for select to authenticated using(private.career_visible(id));
create policy career_skills_read on public.opportunity_skills for select to authenticated using(private.career_visible(opportunity_id));
revoke all on function private.safe_career_url(text),private.career_visible(uuid) from public,anon,authenticated;
grant execute on function private.safe_career_url(text),private.career_visible(uuid) to authenticated;

create function public.career_can_publish() returns boolean
language sql stable security definer set search_path='' as $$ select private.can_publish() and exists(
 select 1 from public.profiles p join public.institutions i on i.id=p.institution_id and i.active
 join public.departments d on d.id=p.department_id and d.active where p.user_id=auth.uid()); $$;

create function public.save_career_opportunity(p_id uuid,p_input jsonb,p_expected timestamptz default null) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); existing public.opportunities; profile public.profiles; skills uuid[]; scope text;
begin
 if not public.career_can_publish() then raise insufficient_privilege; end if;
 if p_id is null or p_input is null or jsonb_typeof(p_input)<>'object' then raise check_violation; end if;
 if exists(select 1 from jsonb_object_keys(p_input) k where k not in ('title','description','kind','location_text','external_url','status','professional_domain','organization','remote','referral','audience','skill_ids')) then raise check_violation; end if;
 if jsonb_typeof(p_input->'skill_ids') is distinct from 'array' then raise check_violation; end if;
 if jsonb_array_length(p_input->'skill_ids')>30 then raise check_violation; end if;
 if exists(select 1 from jsonb_array_elements(p_input->'skill_ids') v where jsonb_typeof(v)<>'string') or
 exists(select 1 from (values('remote'),('referral')) f(k) where jsonb_typeof(p_input->f.k) is distinct from 'boolean') or
 exists(select 1 from (values('title'),('description'),('kind'),('status'),('audience'),('professional_domain'),('organization'),('location_text'),('external_url')) f(k) where jsonb_typeof(p_input->f.k) is distinct from 'string') then raise check_violation; end if;
 scope:=p_input->>'audience';
 if scope not in ('community','institution','department') or p_input->>'status' not in ('draft','published','closed') or not private.safe_career_url(nullif(btrim(p_input->>'external_url'),'')) then raise check_violation; end if;
 select coalesce(array_agg(distinct v::uuid),'{}') into skills from jsonb_array_elements_text(p_input->'skill_ids') v;
 if exists(select 1 from unnest(skills) sk(id) where not exists(select 1 from public.skills s where s.id=sk.id)) then raise check_violation; end if;
 select p.* into strict profile from public.profiles p where p.user_id=actor;
 perform pg_advisory_xact_lock(hashtextextended(p_id::text,0));
 select o.* into existing from public.opportunities o where o.id=p_id for update;
 if found then
  if existing.author_id<>actor then raise insufficient_privilege; end if;
  if existing.archived_at is not null then raise check_violation; end if;
  if p_expected is null then return existing.id; end if; -- retry of the same create, never overwrite
  if existing.updated_at<>p_expected then raise serialization_failure using message='Post changed; reload before editing'; end if;
 elsif p_expected is not null then raise no_data_found; end if;
 insert into public.opportunities(id,author_id,title,description,kind,location_text,external_url,status,professional_domain,organization,remote,referral,audience,institution_id,department_id)
 values(p_id,actor,btrim(p_input->>'title'),btrim(p_input->>'description'),(p_input->>'kind')::public.opportunity_kind,btrim(p_input->>'location_text'),
 nullif(btrim(p_input->>'external_url'),''),p_input->>'status',btrim(p_input->>'professional_domain'),btrim(p_input->>'organization'),(p_input->>'remote')::boolean,(p_input->>'referral')::boolean,
 scope,case when scope<>'community' then profile.institution_id end,case when scope='department' then profile.department_id end)
 on conflict(id) do update set title=excluded.title,description=excluded.description,kind=excluded.kind,location_text=excluded.location_text,external_url=excluded.external_url,
 status=excluded.status,professional_domain=excluded.professional_domain,organization=excluded.organization,remote=excluded.remote,referral=excluded.referral,audience=excluded.audience,
 institution_id=excluded.institution_id,department_id=excluded.department_id;
 delete from public.opportunity_skills s where s.opportunity_id=p_id;
 insert into public.opportunity_skills select p_id,id from unnest(skills) id;
 return p_id;
end; $$;

create function public.transition_career_opportunity(p_id uuid,p_action text) returns void
language plpgsql security definer set search_path='' as $$
declare post public.opportunities;
begin
 if not public.career_can_publish() then raise insufficient_privilege; end if;
 if p_action is null or p_action not in ('close','archive') then raise check_violation; end if;
 select o.* into strict post from public.opportunities o where o.id=p_id for update;
 if post.author_id<>auth.uid() then raise insufficient_privilege; end if;
 if p_action='archive' then
  if post.archived_at is null then update public.opportunities set status='closed',archived_at=now() where id=p_id; end if;
 elsif post.status<>'closed' and post.archived_at is null then update public.opportunities set status='closed' where id=p_id; end if;
end; $$;

create function public.career_opportunities(p_filters jsonb default '{}',p_after jsonb default null,p_limit integer default 21,p_id uuid default null)
returns setof jsonb language plpgsql stable security definer set search_path='' as $$
declare mine boolean; kind text; state text; ordering text; remote_only boolean; search text; domain_filter text; place text; skill uuid; scope_filter text;
begin
 if not private.is_verified() then raise insufficient_privilege; end if;
 if p_filters is null or jsonb_typeof(p_filters)<>'object' or p_limit is null or p_limit not between 1 and 51 then raise check_violation; end if;
 if exists(select 1 from jsonb_object_keys(p_filters) k where k not in ('mine','kind','status','sort','remote','search','domain','location','skill','scope','referral')) then raise check_violation; end if;
 mine:=coalesce((p_filters->>'mine')::boolean,false); kind:=coalesce(p_filters->>'kind','all'); state:=coalesce(p_filters->>'status','published');
 ordering:=coalesce(p_filters->>'sort','recent'); remote_only:=coalesce((p_filters->>'remote')::boolean,false);
 search:=coalesce(p_filters->>'search','');domain_filter:=coalesce(p_filters->>'domain','');place:=coalesce(p_filters->>'location','');skill:=(p_filters->>'skill')::uuid;scope_filter:=coalesce(p_filters->>'scope','all');
 if kind not in ('all','job','internship','collaboration') or state not in ('all','published','closed','draft') or ordering not in ('recent','relevance')
 or scope_filter not in ('all','community','institution','department') or char_length(search)>100 or char_length(domain_filter)>120 or char_length(place)>160 then raise check_violation; end if;
 if p_after is not null and (jsonb_typeof(p_after)<>'object' or not (p_after ?& array['rank','created_at','id'])) then raise check_violation; end if;
 return query with candidates as (
 select o.*,case when author.directory_visible and private.member_verified(author.user_id) and m.verified_kind='alumni' then author.display_name end author_name,
 coalesce(author.directory_visible and private.member_verified(author.user_id) and m.verified_kind='alumni',false) author_available,
 array(select s.name from public.opportunity_skills os join public.skills s on s.id=os.skill_id where os.opportunity_id=o.id order by s.name,s.id) required_skills,
 array(select os.skill_id from public.opportunity_skills os where os.opportunity_id=o.id order by os.skill_id) skill_ids,
 (select count(*)::int from public.opportunity_skills os join public.profile_skills ps on ps.skill_id=os.skill_id and ps.profile_id=auth.uid() where os.opportunity_id=o.id) shared_count
 from public.opportunities o join public.profiles author on author.user_id=o.author_id join private.memberships m on m.user_id=o.author_id
 where private.career_visible(o.id) and (p_id is null or o.id=p_id) and (not mine or o.author_id=auth.uid())
 and (p_id is not null or mine or o.archived_at is null) and (p_id is not null or state='all' or o.status=state)
 and (kind='all' or o.kind::text=kind) and (not remote_only or o.remote)
 and (scope_filter='all' or o.audience=scope_filter)
 and (not coalesce((p_filters->>'referral')::boolean,false) or o.referral)
 and (btrim(search)='' or position(lower(btrim(search)) in lower(o.title||' '||o.description))>0)
 and (btrim(domain_filter)='' or position(lower(btrim(domain_filter)) in lower(o.professional_domain))>0)
 and (btrim(place)='' or position(lower(btrim(place)) in lower(coalesce(o.location_text,'')))>0)
 and (skill is null or exists(select 1 from public.opportunity_skills os where os.opportunity_id=o.id and os.skill_id=skill))
 ), ranked as (select c.*,case when ordering='relevance' and cardinality(c.skill_ids)>0 then round(100.0*c.shared_count/cardinality(c.skill_ids))::int else 0 end rank from candidates c)
 select jsonb_build_object('id',r.id,'author_id',r.author_id,'title',r.title,'description',r.description,'kind',r.kind,'location_text',r.location_text,
 'external_url',case when private.safe_career_url(r.external_url) then r.external_url end,'status',r.status,'professional_domain',r.professional_domain,'organization',r.organization,
 'remote',r.remote,'referral',r.referral,'audience',r.audience,'archived',r.archived_at is not null,'created_at',r.created_at,'updated_at',r.updated_at,'rank',r.rank,
 'author_name',r.author_name,'author_available',r.author_available,'required_skills',r.required_skills,'skill_ids',r.skill_ids,'shared_count',r.shared_count)
 from ranked r where p_after is null or (r.rank,r.created_at,r.id)<((p_after->>'rank')::int,(p_after->>'created_at')::timestamptz,(p_after->>'id')::uuid)
 order by r.rank desc,r.created_at desc,r.id desc limit p_limit;
end; $$;

create function public.report_career_opportunity(p_id uuid,p_reason text,p_details text) returns uuid
language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not private.career_visible(p_id) or not exists(select 1 from public.opportunities o where o.id=p_id and o.status='published' and o.author_id<>auth.uid()) then raise insufficient_privilege; end if;
 if p_reason is null or p_reason not in ('harassment','impersonation','inappropriate','other') or p_details is null or char_length(p_details)>2000 or char_length(btrim(p_details))<10 then raise check_violation; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_id::text,0));
 select r.id into result from public.reports r where r.reporter_id=auth.uid() and r.target_opportunity_id=p_id and r.status='open' order by r.created_at limit 1;
 if result is not null then return result; end if;
 insert into public.reports(reporter_id,target_opportunity_id,reason,details) values(auth.uid(),p_id,p_reason,btrim(p_details)) returning id into result;
 return result;
end; $$;
revoke all on function public.career_can_publish(),public.save_career_opportunity(uuid,jsonb,timestamptz),public.transition_career_opportunity(uuid,text),public.career_opportunities(jsonb,jsonb,integer,uuid),public.report_career_opportunity(uuid,text,text) from public,anon,authenticated;
grant execute on function public.career_can_publish(),public.save_career_opportunity(uuid,jsonb,timestamptz),public.transition_career_opportunity(uuid,text),public.career_opportunities(jsonb,jsonb,integer,uuid),public.report_career_opportunity(uuid,text,text) to authenticated;
notify pgrst,'reload schema';
commit;
