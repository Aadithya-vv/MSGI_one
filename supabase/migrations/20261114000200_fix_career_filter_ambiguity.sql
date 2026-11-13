-- Forward-only correction: qualify PL/pgSQL filters; preserve all authorization.
begin;
create or replace function public.career_opportunities(p_filters jsonb default '{}',p_after jsonb default null,p_limit integer default 21,p_id uuid default null)
returns setof jsonb language plpgsql stable security definer set search_path='' as $$
<<filter_values>>
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
 where private.career_visible(o.id) and (p_id is null or o.id=p_id) and (not filter_values.mine or o.author_id=auth.uid())
 and (p_id is not null or filter_values.mine or o.archived_at is null) and (p_id is not null or filter_values.state='all' or o.status=filter_values.state)
 and (filter_values.kind='all' or o.kind::text=filter_values.kind) and (not filter_values.remote_only or o.remote)
 and (filter_values.scope_filter='all' or o.audience=filter_values.scope_filter)
 and (not coalesce((p_filters->>'referral')::boolean,false) or o.referral)
 and (btrim(filter_values.search)='' or position(lower(btrim(filter_values.search)) in lower(o.title||' '||o.description))>0)
 and (btrim(filter_values.domain_filter)='' or position(lower(btrim(filter_values.domain_filter)) in lower(o.professional_domain))>0)
 and (btrim(filter_values.place)='' or position(lower(btrim(filter_values.place)) in lower(coalesce(o.location_text,'')))>0)
 and (filter_values.skill is null or exists(select 1 from public.opportunity_skills os where os.opportunity_id=o.id and os.skill_id=filter_values.skill))
 ), ranked as (select c.*,case when filter_values.ordering='relevance' and cardinality(c.skill_ids)>0 then round(100.0*c.shared_count/cardinality(c.skill_ids))::int else 0 end rank from candidates c)
 select jsonb_build_object('id',r.id,'author_id',r.author_id,'title',r.title,'description',r.description,'kind',r.kind,'location_text',r.location_text,
 'external_url',case when private.safe_career_url(r.external_url) then r.external_url end,'status',r.status,'professional_domain',r.professional_domain,'organization',r.organization,
 'remote',r.remote,'referral',r.referral,'audience',r.audience,'archived',r.archived_at is not null,'created_at',r.created_at,'updated_at',r.updated_at,'rank',r.rank,
 'author_name',r.author_name,'author_available',r.author_available,'required_skills',r.required_skills,'skill_ids',r.skill_ids,'shared_count',r.shared_count)
 from ranked r where p_after is null or (r.rank,r.created_at,r.id)<((p_after->>'rank')::int,(p_after->>'created_at')::timestamptz,(p_after->>'id')::uuid)
 order by r.rank desc,r.created_at desc,r.id desc limit p_limit;
end; $$;

notify pgrst,'reload schema';
commit;
