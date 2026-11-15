-- Forward-only, LOCAL validation first. Never auto-provision administrators.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
set local standard_conforming_strings=on;
select set_config('msgi.executor_baseline', :'msgi_baseline_md5', true);
do $executor_lock$ begin
 if not pg_try_advisory_xact_lock(749312050001::bigint) then raise exception 'Concurrent administration deployment'; end if;
end $executor_lock$;
lock table "private"."account_roles","private"."memberships","private"."mentor_blocks","private"."verification_audit","public"."cities","public"."connections","public"."departments","public"."institutions","public"."mentor_goals","public"."mentorship_preferences","public"."opportunities","public"."opportunity_skills","public"."profile_drafts","public"."profile_skills","public"."profiles","public"."programmes","public"."reports","public"."skills",auth.users,supabase_migrations.schema_migrations in share row exclusive mode;
do $executor_guard$ begin
 if current_database()<>'postgres' or current_user<>'postgres' then raise exception 'Wrong database identity'; end if;
 if md5(((select jsonb_build_object('inventory',i.inventory - array['read_only','version','ssl','tls_version','active_ddl','waiting_locks'],
    'catalog',c.catalog_preflight - array['read_only','version'],
    'auth_fingerprint',(select md5(coalesce(string_agg(md5(row_to_json(u)::text),'' order by md5(row_to_json(u)::text)),'')) from auth.users u))
    from (-- Aggregate-only, read-only review. No user records, email addresses or secrets.
select jsonb_build_object(
 'read_only',current_setting('transaction_read_only'),
 'database',current_database(),'version',current_setting('server_version'),
 'ssl',(select ssl from pg_stat_ssl where pid=pg_backend_pid()),
 'tls_version',(select version from pg_stat_ssl where pid=pg_backend_pid()),
 'history',(select jsonb_agg(version order by version) from supabase_migrations.schema_migrations),
 'history_columns',(select jsonb_agg(jsonb_build_object('name',column_name,'type',data_type,'nullable',is_nullable,'default',column_default) order by ordinal_position) from information_schema.columns where table_schema='supabase_migrations' and table_name='schema_migrations'),
 'roles',jsonb_build_object('count',(select count(*) from private.account_roles),
 'without_profile',(select count(*) from private.account_roles r left join public.profiles p on p.user_id=r.user_id where p.user_id is null),
 'inactive_or_missing_institution',(select count(*) from private.account_roles r join public.profiles p on p.user_id=r.user_id left join public.institutions i on i.id=p.institution_id where i.id is null or not i.active)),
 'auth_users_count',(select count(*) from auth.users),
 'default_acls',(select jsonb_agg(jsonb_build_object('owner',pg_get_userbyid(d.defaclrole),'schema',n.nspname,'object_type',d.defaclobjtype,'acl',d.defaclacl) order by n.nspname,d.defaclobjtype) from pg_default_acl d left join pg_namespace n on n.oid=d.defaclnamespace where n.nspname in ('public','private')),
 'tables',(select jsonb_agg(jsonb_build_object('schema',s.nspname,'table',s.relname,'rows',((xpath('//row/count/text()',s.x))[1]::text)::bigint,
 'digest',(xpath('//row/digest/text()',s.x))[1]::text) order by s.nspname,s.relname)
 from (select n.nspname,c.relname,query_to_xml(format('select count(*) as count,md5(coalesce(string_agg(md5(row_to_json(v)::text),'''' order by md5(row_to_json(v)::text)),'''')) as digest from %I.%I v',n.nspname,c.relname),false,true,'') x
 from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind='r' and n.nspname in ('public','private'))s),
 'functions',(select jsonb_agg(jsonb_build_object('name',n.nspname||'.'||p.proname,'arguments',pg_get_function_identity_arguments(p.oid),'result',pg_get_function_result(p.oid),'body_hash',md5(p.prosrc),'security_definer',p.prosecdef,'config',p.proconfig,'acl',p.proacl) order by n.nspname,p.proname,pg_get_function_identity_arguments(p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private')),
 'tables_security',(select jsonb_agg(jsonb_build_object('schema',n.nspname,'name',c.relname,'owner',pg_get_userbyid(c.relowner),'rls',c.relrowsecurity,'acl',c.relacl) order by n.nspname,c.relname) from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind='r' and n.nspname in ('public','private')),
 'policies',(select jsonb_agg(to_jsonb(p) order by schemaname,tablename,policyname) from pg_policies p where schemaname in ('public','private')),
 'indexes',(select jsonb_agg(to_jsonb(i) order by schemaname,indexname) from pg_indexes i where schemaname in ('public','private')),
 'triggers',(select jsonb_agg(jsonb_build_object('table',t.tgrelid::regclass::text,'name',t.tgname,'definition',pg_get_triggerdef(t.oid)) order by t.tgrelid::regclass::text,t.tgname) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where not t.tgisinternal and n.nspname in ('public','private')),
 'constraints',(select jsonb_agg(jsonb_build_object('table',k.conrelid::regclass::text,'name',k.conname,'validated',k.convalidated,'definition',pg_get_constraintdef(k.oid)) order by n.nspname,k.conname) from pg_constraint k join pg_namespace n on n.oid=k.connamespace where n.nspname in ('public','private')),
 'active_ddl',(select count(*) from pg_stat_activity where pid<>pg_backend_pid() and state='active' and backend_type='client backend' and query ~* '^\s*(alter|create|drop|truncate|reindex)'),
 'waiting_locks',(select count(*) from pg_locks where not granted)
) as inventory) i cross join (select jsonb_build_object('read_only',current_setting('transaction_read_only'),'database',current_database(),'version',current_setting('server_version_num')::int/10000,'history',(select jsonb_agg(version order by version) from supabase_migrations.schema_migrations),'institutions_conflict',exists(select 1 from public.institutions s where not exists(select 1 from jsonb_to_recordset('[{"id":"a1100000-0000-4000-8000-000000000001","name":"Meenakshi Sundararajan Engineering College (MSEC)","catalog_key":"msec","active":true}]'::jsonb) as e(id uuid,name text,catalog_key text,active boolean) where s.id is not distinct from e.id and s.name is not distinct from e.name and s.catalog_key is not distinct from e.catalog_key and s.active is not distinct from e.active)),'departments_conflict',exists(select 1 from public.departments s where not exists(select 1 from jsonb_to_recordset('[{"id":"a1120000-0000-4000-8000-000000000001","institution_id":"a1100000-0000-4000-8000-000000000001","name":"Science and Humanities","active":true}]'::jsonb) as e(id uuid,institution_id uuid,name text,active boolean) where s.id is not distinct from e.id and s.institution_id is not distinct from e.institution_id and s.name is not distinct from e.name and s.active is not distinct from e.active)),'programmes_conflict',exists(select 1 from public.programmes s where not exists(select 1 from jsonb_to_recordset('[{"id":"a1110000-0000-4000-8000-000000000001","institution_id":"a1100000-0000-4000-8000-000000000001","application_key":"msec-ug-ai-ds","name":"B.Tech. Artificial Intelligence & Data Science","level":"undergraduate","active":true},{"id":"a1110000-0000-4000-8000-000000000002","institution_id":"a1100000-0000-4000-8000-000000000001","application_key":"msec-ug-ai-ml","name":"B.Tech. Artificial Intelligence & Machine Learning","level":"undergraduate","active":true},{"id":"a1110000-0000-4000-8000-000000000003","institution_id":"a1100000-0000-4000-8000-000000000001","application_key":"msec-ug-civil","name":"B.E. Civil Engineering","level":"undergraduate","active":true},{"id":"a1110000-0000-4000-8000-000000000004","institution_id":"a1100000-0000-4000-8000-000000000001","application_key":"msec-ug-cse","name":"B.E. Computer Science and Engineering","level":"undergraduate","active":true},{"id":"a1110000-0000-4000-8000-000000000005","institution_id":"a1100000-0000-4000-8000-000000000001","application_key":"msec-ug-cse-cybersecurity","name":"B.E. Computer Science & Engineering (Cybersecurity)","level":"undergraduate","active":true},{"id":"a1110000-0000-4000-8000-000000000006","institution_id":"a1100000-0000-4000-8000-000000000001","application_key":"msec-ug-eee","name":"B.E. Electrical and Electronics Engineering","level":"undergraduate","active":true},{"id":"a1110000-0000-4000-8000-000000000007","institution_id":"a1100000-0000-4000-8000-000000000001","application_key":"msec-ug-ece","name":"B.E. Electronics and Communication Engineering","level":"undergraduate","active":true},{"id":"a1110000-0000-4000-8000-000000000008","institution_id":"a1100000-0000-4000-8000-000000000001","application_key":"msec-ug-it","name":"B.Tech. Information Technology","level":"undergraduate","active":true},{"id":"a1110000-0000-4000-8000-000000000009","institution_id":"a1100000-0000-4000-8000-000000000001","application_key":"msec-ug-mechanical","name":"B.E. Mechanical Engineering","level":"undergraduate","active":true},{"id":"a1110000-0000-4000-8000-000000000010","institution_id":"a1100000-0000-4000-8000-000000000001","application_key":"msec-pg-cs","name":"M.E. Computer Science","level":"postgraduate","active":true},{"id":"a1110000-0000-4000-8000-000000000011","institution_id":"a1100000-0000-4000-8000-000000000001","application_key":"msec-pg-construction","name":"M.E. Construction Engineering and Management","level":"postgraduate","active":true},{"id":"a1110000-0000-4000-8000-000000000012","institution_id":"a1100000-0000-4000-8000-000000000001","application_key":"msec-pg-embedded","name":"M.E. Embedded Systems and Technologies","level":"postgraduate","active":true},{"id":"a1110000-0000-4000-8000-000000000013","institution_id":"a1100000-0000-4000-8000-000000000001","application_key":"msec-pg-energy","name":"M.E. Energy Engineering","level":"postgraduate","active":true}]'::jsonb) as e(id uuid,institution_id uuid,application_key text,name text,level text,active boolean) where s.id is not distinct from e.id and s.institution_id is not distinct from e.institution_id and s.application_key is not distinct from e.application_key and s.name is not distinct from e.name and s.level is not distinct from e.level and s.active is not distinct from e.active)),'skills_conflict',exists(select 1 from public.skills s where not exists(select 1 from jsonb_to_recordset('[{"name":"C"},{"name":"C++"},{"name":"Python"},{"name":"Java"},{"name":"Git"},{"name":"SQL"},{"name":"Flutter"},{"name":"Software Testing"},{"name":"Machine Learning"},{"name":"Data Analysis"},{"name":"Statistics"},{"name":"Data Visualization"},{"name":"Computer Networks"},{"name":"Cybersecurity"},{"name":"Linux"},{"name":"Cloud Computing"},{"name":"Embedded Systems"},{"name":"Microcontrollers"},{"name":"Digital Electronics"},{"name":"PCB Design"},{"name":"Circuit Analysis"},{"name":"Control Systems"},{"name":"Power Systems"},{"name":"Renewable Energy"},{"name":"Structural Analysis"},{"name":"Surveying"},{"name":"Construction Planning"},{"name":"Building Information Modeling"},{"name":"Computer-Aided Design"},{"name":"Engineering Drawing"},{"name":"Manufacturing Processes"},{"name":"Thermodynamics"},{"name":"Communication"},{"name":"Teamwork"},{"name":"Problem Solving"},{"name":"Project Management"}]'::jsonb) as e(name text) where s.name is not distinct from e.name)),'institutions_count',(select count(*) from public.institutions),'departments_count',(select count(*) from public.departments),'programmes_count',(select count(*) from public.programmes),'skills_count',(select count(*) from public.skills),'rls_tables',(select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('institutions','departments','programmes','skills') and c.relrowsecurity)) as catalog_preflight) c))::text) is distinct from current_setting('msgi.executor_baseline') then raise exception 'Deployment baseline changed'; end if;
end $executor_guard$;


create table private.administration_audit (
 id uuid primary key default gen_random_uuid(), actor_id uuid not null references auth.users(id),
 subject_id uuid references auth.users(id), report_id uuid references public.reports(id),
 action text not null, category text not null, note text not null check(char_length(note) between 1 and 1000),
 before_state jsonb not null, after_state jsonb not null,
 request_id uuid not null, request_hash text not null, created_at timestamptz not null default clock_timestamp(),
 unique(actor_id,request_id)
);
create index administration_audit_subject_idx on private.administration_audit(subject_id,created_at desc,id);
create table private.membership_requests (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id),
 kind text not null check(kind in ('appeal','correction')), status text not null default 'open' check(status in ('open','closed')),
 created_at timestamptz not null default clock_timestamp(), resolved_at timestamptz
);
create unique index membership_request_open_idx on private.membership_requests(user_id) where status='open';
alter table private.administration_audit enable row level security;
alter table private.membership_requests enable row level security;
revoke all on private.administration_audit,private.membership_requests from public,anon,authenticated,service_role;

-- Also closes the previous banned/deleted-Auth-account consistency gap.
create or replace function private.member_verified(subject uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.memberships m join auth.users u on u.id=m.user_id
 where m.user_id=subject and m.status='verified' and u.email_confirmed_at is not null
 and u.deleted_at is null and (u.banned_until is null or u.banned_until<=now())); $$;
-- Bind protected authority to its approved institution, not a mutable profile.
alter table private.account_roles add column institution_id uuid references public.institutions(id);
update private.account_roles r set institution_id=p.institution_id from public.profiles p where p.user_id=r.user_id;
alter table private.account_roles alter column institution_id set not null;
create function private.bind_administrator_institution() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.institution_id is null then select p.institution_id into new.institution_id from public.profiles p where p.user_id=new.user_id; end if;
 if new.institution_id is null then raise check_violation; end if;
 return new;
end; $$;
revoke all on function private.bind_administrator_institution() from public,anon,authenticated;
create trigger bind_administrator_scope before insert on private.account_roles for each row execute function private.bind_administrator_institution();
create or replace function private.is_admin() returns boolean
language sql stable security definer set search_path='' as $$
 select private.is_verified() and exists(select 1 from private.account_roles r join public.profiles p on p.user_id=r.user_id and p.institution_id=r.institution_id join public.institutions i on i.id=r.institution_id and i.active where r.user_id=auth.uid() and r.role='administrator');
$$;

create function private.admin_scope(subject uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select private.is_admin() and exists(select 1 from public.profiles a join public.profiles s
 on s.institution_id=a.institution_id where a.user_id=auth.uid() and s.user_id=subject); $$;
revoke all on function private.admin_scope(uuid) from public,anon,authenticated;
grant execute on function private.admin_scope(uuid) to authenticated;

create function public.administration_context() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_admin() then raise insufficient_privilege; end if;
 return jsonb_build_object('institution_id',(select p.institution_id from public.profiles p where p.user_id=auth.uid()),
 'pending',(select count(*) from private.memberships m where m.status='pending' and private.admin_scope(m.user_id)),
 'requests',(select count(*) from private.membership_requests r where r.status='open' and private.admin_scope(r.user_id)),
 'reports',(select count(*) from public.reports r where r.status='open' and private.admin_scope(coalesce(r.target_profile_id,(select o.author_id from public.opportunities o where o.id=r.target_opportunity_id)))));
end; $$;

create function public.administration_members(p_status text default 'pending',p_kind text default null,p_offset integer default 0,p_limit integer default 30)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not private.is_admin() then raise insufficient_privilege; end if;
 if p_status not in ('pending','verified','rejected','suspended') or p_status is null or
 (p_kind is not null and p_kind not in ('student','alumni','staff')) or p_offset is null or p_offset not between 0 and 10000 or p_limit is null or p_limit not between 1 and 50 then raise check_violation; end if;
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into result from (
 select p.user_id,p.display_name,p.claimed_kind::text,p.institution_id,p.department_id,
 p.joining_year,p.graduation_year,i.name institution,d.name department,pr.name programme,p.affiliation,
 p.designation,p.company,p.professional_domain,m.status::text,m.updated_at revision,
 (select r.kind from private.membership_requests r where r.user_id=p.user_id and r.status='open') request_kind
 from public.profiles p join private.memberships m on m.user_id=p.user_id
 join public.institutions i on i.id=p.institution_id left join public.departments d on d.id=p.department_id
 left join public.programmes pr on pr.id=p.programme_id
 where m.status::text=p_status and (p_kind is null or p.claimed_kind::text=p_kind) and private.admin_scope(p.user_id)
 order by p.created_at,p.user_id offset p_offset limit p_limit) x;
 return result;
end; $$;

create function public.decide_institutional_membership(p_user uuid,p_action text,p_kind public.account_kind,p_category text,p_note text,p_revision timestamptz,p_request uuid)
returns void language plpgsql security definer set search_path='' as $$
declare old private.memberships%rowtype; new_status public.membership_status; fingerprint text; previous private.administration_audit%rowtype;
begin
 if not private.admin_scope(p_user) or p_user=auth.uid() then raise insufficient_privilege; end if;
 if p_action is null or p_action not in ('approve','reject','suspend','reinstate','correction') or p_category is null or
 p_category not in ('record_checked','details_mismatch','evidence_unavailable','policy_violation','appeal_review','duplicate_account') or
 p_note is null or char_length(btrim(p_note)) not between 1 and 1000 or p_request is null or p_revision is null then raise check_violation; end if;
 fingerprint:=md5(jsonb_build_array(p_user,p_action,p_kind,p_category,btrim(p_note),p_revision)::text);
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_request::text,0));
 select a.* into previous from private.administration_audit a where a.actor_id=auth.uid() and a.request_id=p_request;
 if found then if previous.request_hash<>fingerprint then raise check_violation; end if; return; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,0));
 select m.* into strict old from private.memberships m where m.user_id=p_user for update;
 if old.updated_at<>p_revision then raise serialization_failure using message='Review changed; refresh before deciding'; end if;
 new_status:=case p_action when 'approve' then 'verified' when 'reject' then 'rejected' when 'suspend' then 'suspended' when 'reinstate' then 'verified' else 'pending' end;
 if not ((p_action in ('approve','reject') and old.status='pending') or (p_action='suspend' and old.status in ('pending','verified')) or
 (p_action='reinstate' and old.status='suspended') or (p_action='correction' and old.status in ('rejected','verified'))) then raise check_violation; end if;
 if (new_status='verified')<>(p_kind is not null) then raise check_violation; end if;
 if new_status='verified' and not exists(select 1 from public.profiles p join auth.users u on u.id=p.user_id
 join public.institutions i on i.id=p.institution_id and i.active
 left join public.departments d on d.id=p.department_id left join public.programmes pr on pr.id=p.programme_id
 where p.user_id=p_user and u.email_confirmed_at is not null and u.deleted_at is null
 and (u.banned_until is null or u.banned_until<=now()) and (p.department_id is null or d.active)
 and (p.programme_id is null or pr.active)) then raise check_violation; end if;
 update private.memberships set status=new_status,verified_kind=p_kind,updated_at=clock_timestamp() where user_id=p_user;
 insert into private.verification_audit(subject_id,actor_id,previous_status,new_status,verified_kind,reason)
 values(p_user,auth.uid(),old.status,new_status,p_kind,left(p_category||': '||btrim(p_note),1000));
 insert into private.administration_audit(actor_id,subject_id,action,category,note,before_state,after_state,request_id,request_hash)
 values(auth.uid(),p_user,p_action,p_category,btrim(p_note),jsonb_build_object('status',old.status,'kind',old.verified_kind,'claims',(select jsonb_build_object('kind',p.claimed_kind,'institution_id',p.institution_id,'department_id',p.department_id,'programme_id',p.programme_id,'joining_year',p.joining_year,'graduation_year',p.graduation_year,'affiliation',p.affiliation) from public.profiles p where p.user_id=p_user)),jsonb_build_object('status',new_status,'kind',p_kind),p_request,fingerprint);
 update private.membership_requests set status='closed',resolved_at=clock_timestamp() where user_id=p_user and status='open';
end; $$;

-- Legacy clients remain supported but cannot skip live authority/scope or state rules.
create or replace function public.review_membership(p_user_id uuid,p_status public.membership_status,p_verified_kind public.account_kind,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare revision timestamptz;
begin
 if not private.admin_scope(p_user_id) then raise insufficient_privilege; end if;
 select m.updated_at into strict revision from private.memberships m where m.user_id=p_user_id;
 perform public.decide_institutional_membership(p_user_id,case p_status when 'verified' then 'approve' when 'rejected' then 'reject' when 'suspended' then 'suspend' else null end,p_verified_kind,'record_checked',p_reason,revision,gen_random_uuid());
end; $$;

create function public.request_membership_review(p_kind text) returns void
language plpgsql security definer set search_path='' as $$
declare state public.membership_status;
begin
 if auth.uid() is null or not exists(select 1 from auth.users u where u.id=auth.uid() and u.email_confirmed_at is not null and u.deleted_at is null and (u.banned_until is null or u.banned_until<=now())) then raise insufficient_privilege; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 select m.status into strict state from private.memberships m where m.user_id=auth.uid();
 if p_kind is null or not ((p_kind='appeal' and state in ('rejected','suspended')) or (p_kind='correction' and state='verified')) then raise check_violation; end if;
 if exists(select 1 from private.membership_requests r where r.user_id=auth.uid() and r.status='open') then return; end if;
 if (select count(*) from private.membership_requests r where r.user_id=auth.uid() and r.created_at>now()-interval '30 days')>=3 then raise check_violation using message='Review request limit reached'; end if;
 insert into private.membership_requests(user_id,kind) values(auth.uid(),p_kind);
end; $$;

create function public.own_review_status() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise insufficient_privilege; end if;
 return jsonb_build_object('category',(select a.category from private.administration_audit a where a.subject_id=auth.uid() order by a.created_at desc,a.id desc limit 1),
 'request_open',exists(select 1 from private.membership_requests r where r.user_id=auth.uid() and r.status='open'));
end; $$;

create function public.administration_history(p_user uuid,p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.admin_scope(p_user) then raise insufficient_privilege; end if;
 if p_offset is null or p_offset not between 0 and 10000 then raise check_violation; end if;
 return (select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from (select a.id,a.actor_id,a.action,a.category,a.note,a.before_state,a.after_state,a.created_at from private.administration_audit a where a.subject_id=p_user order by a.created_at desc,a.id desc offset p_offset limit 30)x);
end; $$;

create function public.administration_reports(p_status text default 'open',p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_admin() then raise insufficient_privilege; end if;
 if p_status is null or p_status not in ('open','resolved','dismissed') or p_offset is null or p_offset not between 0 and 10000 then raise check_violation; end if;
 return (select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from (select r.id,r.target_profile_id,r.target_opportunity_id,r.reason,r.details,r.status,r.updated_at revision,r.moderated_by,r.created_at,
 (select count(*) from public.reports s where coalesce(s.target_profile_id,(select o.author_id from public.opportunities o where o.id=s.target_opportunity_id))=coalesce(r.target_profile_id,(select o.author_id from public.opportunities o where o.id=r.target_opportunity_id))) prior_reports
 from public.reports r where r.status=p_status and private.admin_scope(coalesce(r.target_profile_id,(select o.author_id from public.opportunities o where o.id=r.target_opportunity_id))) order by r.created_at,r.id offset p_offset limit 30)x);
end; $$;

create function public.decide_institutional_report(p_report uuid,p_status text,p_note text,p_revision timestamptz,p_request uuid) returns void
language plpgsql security definer set search_path='' as $$
declare old public.reports%rowtype; subject uuid; fingerprint text; previous private.administration_audit%rowtype;
begin
 if not private.is_admin() then raise insufficient_privilege; end if;
 select coalesce(r.target_profile_id,o.author_id) into subject from public.reports r left join public.opportunities o on o.id=r.target_opportunity_id where r.id=p_report;
 if not private.admin_scope(subject) or subject=auth.uid() then raise insufficient_privilege; end if;
 if p_status is null or p_status not in ('resolved','dismissed','archive') or p_note is null or char_length(btrim(p_note)) not between 1 and 1000 or p_revision is null or p_request is null then raise check_violation; end if;
 fingerprint:=md5(jsonb_build_array(p_report,p_status,btrim(p_note),p_revision)::text);
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_request::text,0));
 select a.* into previous from private.administration_audit a where a.actor_id=auth.uid() and a.request_id=p_request;
 if found then if previous.request_hash<>fingerprint then raise check_violation; end if; return; end if;
 select r.* into strict old from public.reports r where r.id=p_report for update;
 if old.updated_at<>p_revision then raise serialization_failure; end if;
 if old.status<>'open' then raise check_violation; end if;
 if p_status='archive' then
 if old.target_opportunity_id is null then raise check_violation; end if;
 perform 1 from public.opportunities o where o.id=old.target_opportunity_id for update;
 update public.opportunities set archived_at=clock_timestamp(),status='closed' where id=old.target_opportunity_id;
 end if;
 update public.reports set status=case when p_status='archive' then 'resolved' else p_status end,moderated_by=auth.uid(),updated_at=clock_timestamp() where id=p_report;
 insert into private.administration_audit(actor_id,subject_id,report_id,action,category,note,before_state,after_state,request_id,request_hash)
 values(auth.uid(),subject,p_report,case when p_status='archive' then 'archive_opportunity_report' else 'moderate_report' end,old.reason,btrim(p_note),jsonb_build_object('status',old.status),jsonb_build_object('status',case when p_status='archive' then 'resolved' else p_status end,'opportunity_archived',p_status='archive'),p_request,fingerprint);
end; $$;
create or replace function public.moderate_report(p_id uuid,p_status text) returns void
language plpgsql security definer set search_path='' as $$
declare revision timestamptz;
begin
 if not private.is_admin() then raise insufficient_privilege; end if;
 select r.updated_at into strict revision from public.reports r where r.id=p_id;
 perform public.decide_institutional_report(p_id,p_status,'Legacy moderation decision; review under institutional policy',revision,gen_random_uuid());
end; $$;

-- Limit legacy projections too, rather than leaving a parallel global read path.
create or replace function public.pending_memberships(p_limit integer default 30)
returns table(user_id uuid,display_name text,claimed_kind text,institution_id uuid,department_id uuid,joining_year integer,graduation_year integer)
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_admin() then raise insufficient_privilege; end if;
 if p_limit is null or p_limit not between 1 and 100 then raise check_violation; end if;
 return query select p.user_id,p.display_name,p.claimed_kind::text,p.institution_id,p.department_id,p.joining_year::integer,p.graduation_year::integer from public.profiles p join private.memberships m on m.user_id=p.user_id where m.status='pending' and private.admin_scope(p.user_id) order by p.created_at,p.user_id limit p_limit;
end; $$;
create or replace function public.pending_memberships_v2(p_limit integer default 30)
returns table(user_id uuid,display_name text,claimed_kind text,institution_id uuid,department_id uuid,joining_year integer,graduation_year integer,programme_id uuid,programme text,institution text,department text,affiliation text)
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_admin() then raise insufficient_privilege; end if;
 if p_limit is null or p_limit not between 1 and 100 then raise check_violation; end if;
 return query select p.user_id,p.display_name,p.claimed_kind::text,p.institution_id,p.department_id,p.joining_year::integer,p.graduation_year::integer,p.programme_id,pr.name,i.name,d.name,p.affiliation
 from public.profiles p join private.memberships m on m.user_id=p.user_id join public.institutions i on i.id=p.institution_id left join public.departments d on d.id=p.department_id left join public.programmes pr on pr.id=p.programme_id
 where m.status='pending' and private.admin_scope(p.user_id) order by p.created_at,p.user_id limit p_limit;
end; $$;
create or replace function public.verification_history(p_user_id uuid)
returns table(id uuid,actor_id uuid,previous_status text,new_status text,verified_kind text,reason text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.admin_scope(p_user_id) then raise insufficient_privilege; end if;
 return query select a.id,a.actor_id,a.previous_status::text,a.new_status::text,a.verified_kind::text,a.reason,a.created_at from private.verification_audit a where a.subject_id=p_user_id order by a.created_at,a.id;
end; $$;
drop policy reporter_read on public.reports;
create policy reporter_read on public.reports for select to authenticated using
 ((reporter_id=auth.uid() and private.is_verified()) or private.admin_scope(coalesce(target_profile_id,(select o.author_id from public.opportunities o where o.id=target_opportunity_id))));

revoke all on function public.administration_context(),public.administration_members(text,text,integer,integer),public.decide_institutional_membership(uuid,text,public.account_kind,text,text,timestamptz,uuid),public.request_membership_review(text),public.own_review_status(),public.administration_history(uuid,integer),public.administration_reports(text,integer),public.decide_institutional_report(uuid,text,text,timestamptz,uuid) from public,anon,authenticated,service_role;
grant execute on function public.administration_context(),public.administration_members(text,text,integer,integer),public.decide_institutional_membership(uuid,text,public.account_kind,text,text,timestamptz,uuid),public.request_membership_review(text),public.own_review_status(),public.administration_history(uuid,integer),public.administration_reports(text,integer),public.decide_institutional_report(uuid,text,text,timestamptz,uuid) to authenticated;
alter table public.reports drop constraint reports_reason_check;
alter table public.reports add constraint reports_reason_check check(reason in ('harassment','impersonation','inappropriate','other','fraud','spam','privacy'));
create index memberships_status_review_idx on private.memberships(status,user_id);
create or replace function public.report_career_opportunity(p_id uuid,p_reason text,p_details text) returns uuid
language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not private.career_visible(p_id) or not exists(select 1 from public.opportunities o where o.id=p_id and o.status='published' and o.author_id<>auth.uid()) then raise insufficient_privilege; end if;
 if p_reason is null or p_reason not in ('harassment','impersonation','inappropriate','other','fraud','spam','privacy') or p_details is null or char_length(p_details)>2000 or char_length(btrim(p_details))<10 then raise check_violation; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_id::text,0));
 select r.id into result from public.reports r where r.reporter_id=auth.uid() and r.target_opportunity_id=p_id and r.status='open' order by r.created_at limit 1;
 if result is not null then return result; end if;
 insert into public.reports(reporter_id,target_opportunity_id,reason,details) values(auth.uid(),p_id,p_reason,btrim(p_details)) returning id into result;
 return result;
end; $$;

create function private.audit_academic_correction() returns trigger
language plpgsql security definer set search_path='' as $$
declare before_claim jsonb; after_claim jsonb;
begin
 if auth.uid() is distinct from new.user_id or not exists(select 1 from private.memberships m where m.user_id=new.user_id and m.status='pending') or
 not exists(select 1 from private.administration_audit a where a.subject_id=new.user_id and a.action='correction') then return new; end if;
 before_claim:=jsonb_build_object('kind',old.claimed_kind,'institution_id',old.institution_id,'department_id',old.department_id,'programme_id',old.programme_id,'joining_year',old.joining_year,'graduation_year',old.graduation_year,'affiliation',old.affiliation);
 after_claim:=jsonb_build_object('kind',new.claimed_kind,'institution_id',new.institution_id,'department_id',new.department_id,'programme_id',new.programme_id,'joining_year',new.joining_year,'graduation_year',new.graduation_year,'affiliation',new.affiliation);
 if before_claim is distinct from after_claim then
 insert into private.administration_audit(actor_id,subject_id,action,category,note,before_state,after_state,request_id,request_hash)
 values(auth.uid(),new.user_id,'claim_correction','member_updated_claim','Own academic claims changed during an authorized pending correction',before_claim,after_claim,gen_random_uuid(),'owned-profile-correction');
 end if;
 return new;
end; $$;
revoke all on function private.audit_academic_correction() from public,anon,authenticated;
create trigger academic_correction_audit after update on public.profiles for each row execute function private.audit_academic_correction();

notify pgrst,'reload schema';
insert into supabase_migrations.schema_migrations(version,name,statements) values('20261115000100','institutional_operations',array[$msgi_reviewed_migration_source$-- Forward-only, LOCAL validation first. Never auto-provision administrators.
begin;
create table private.administration_audit (
 id uuid primary key default gen_random_uuid(), actor_id uuid not null references auth.users(id),
 subject_id uuid references auth.users(id), report_id uuid references public.reports(id),
 action text not null, category text not null, note text not null check(char_length(note) between 1 and 1000),
 before_state jsonb not null, after_state jsonb not null,
 request_id uuid not null, request_hash text not null, created_at timestamptz not null default clock_timestamp(),
 unique(actor_id,request_id)
);
create index administration_audit_subject_idx on private.administration_audit(subject_id,created_at desc,id);
create table private.membership_requests (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id),
 kind text not null check(kind in ('appeal','correction')), status text not null default 'open' check(status in ('open','closed')),
 created_at timestamptz not null default clock_timestamp(), resolved_at timestamptz
);
create unique index membership_request_open_idx on private.membership_requests(user_id) where status='open';
alter table private.administration_audit enable row level security;
alter table private.membership_requests enable row level security;
revoke all on private.administration_audit,private.membership_requests from public,anon,authenticated,service_role;

-- Also closes the previous banned/deleted-Auth-account consistency gap.
create or replace function private.member_verified(subject uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.memberships m join auth.users u on u.id=m.user_id
 where m.user_id=subject and m.status='verified' and u.email_confirmed_at is not null
 and u.deleted_at is null and (u.banned_until is null or u.banned_until<=now())); $$;
-- Bind protected authority to its approved institution, not a mutable profile.
alter table private.account_roles add column institution_id uuid references public.institutions(id);
update private.account_roles r set institution_id=p.institution_id from public.profiles p where p.user_id=r.user_id;
alter table private.account_roles alter column institution_id set not null;
create function private.bind_administrator_institution() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.institution_id is null then select p.institution_id into new.institution_id from public.profiles p where p.user_id=new.user_id; end if;
 if new.institution_id is null then raise check_violation; end if;
 return new;
end; $$;
revoke all on function private.bind_administrator_institution() from public,anon,authenticated;
create trigger bind_administrator_scope before insert on private.account_roles for each row execute function private.bind_administrator_institution();
create or replace function private.is_admin() returns boolean
language sql stable security definer set search_path='' as $$
 select private.is_verified() and exists(select 1 from private.account_roles r join public.profiles p on p.user_id=r.user_id and p.institution_id=r.institution_id join public.institutions i on i.id=r.institution_id and i.active where r.user_id=auth.uid() and r.role='administrator');
$$;

create function private.admin_scope(subject uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select private.is_admin() and exists(select 1 from public.profiles a join public.profiles s
 on s.institution_id=a.institution_id where a.user_id=auth.uid() and s.user_id=subject); $$;
revoke all on function private.admin_scope(uuid) from public,anon,authenticated;
grant execute on function private.admin_scope(uuid) to authenticated;

create function public.administration_context() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_admin() then raise insufficient_privilege; end if;
 return jsonb_build_object('institution_id',(select p.institution_id from public.profiles p where p.user_id=auth.uid()),
 'pending',(select count(*) from private.memberships m where m.status='pending' and private.admin_scope(m.user_id)),
 'requests',(select count(*) from private.membership_requests r where r.status='open' and private.admin_scope(r.user_id)),
 'reports',(select count(*) from public.reports r where r.status='open' and private.admin_scope(coalesce(r.target_profile_id,(select o.author_id from public.opportunities o where o.id=r.target_opportunity_id)))));
end; $$;

create function public.administration_members(p_status text default 'pending',p_kind text default null,p_offset integer default 0,p_limit integer default 30)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not private.is_admin() then raise insufficient_privilege; end if;
 if p_status not in ('pending','verified','rejected','suspended') or p_status is null or
 (p_kind is not null and p_kind not in ('student','alumni','staff')) or p_offset is null or p_offset not between 0 and 10000 or p_limit is null or p_limit not between 1 and 50 then raise check_violation; end if;
 select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) into result from (
 select p.user_id,p.display_name,p.claimed_kind::text,p.institution_id,p.department_id,
 p.joining_year,p.graduation_year,i.name institution,d.name department,pr.name programme,p.affiliation,
 p.designation,p.company,p.professional_domain,m.status::text,m.updated_at revision,
 (select r.kind from private.membership_requests r where r.user_id=p.user_id and r.status='open') request_kind
 from public.profiles p join private.memberships m on m.user_id=p.user_id
 join public.institutions i on i.id=p.institution_id left join public.departments d on d.id=p.department_id
 left join public.programmes pr on pr.id=p.programme_id
 where m.status::text=p_status and (p_kind is null or p.claimed_kind::text=p_kind) and private.admin_scope(p.user_id)
 order by p.created_at,p.user_id offset p_offset limit p_limit) x;
 return result;
end; $$;

create function public.decide_institutional_membership(p_user uuid,p_action text,p_kind public.account_kind,p_category text,p_note text,p_revision timestamptz,p_request uuid)
returns void language plpgsql security definer set search_path='' as $$
declare old private.memberships%rowtype; new_status public.membership_status; fingerprint text; previous private.administration_audit%rowtype;
begin
 if not private.admin_scope(p_user) or p_user=auth.uid() then raise insufficient_privilege; end if;
 if p_action is null or p_action not in ('approve','reject','suspend','reinstate','correction') or p_category is null or
 p_category not in ('record_checked','details_mismatch','evidence_unavailable','policy_violation','appeal_review','duplicate_account') or
 p_note is null or char_length(btrim(p_note)) not between 1 and 1000 or p_request is null or p_revision is null then raise check_violation; end if;
 fingerprint:=md5(jsonb_build_array(p_user,p_action,p_kind,p_category,btrim(p_note),p_revision)::text);
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_request::text,0));
 select a.* into previous from private.administration_audit a where a.actor_id=auth.uid() and a.request_id=p_request;
 if found then if previous.request_hash<>fingerprint then raise check_violation; end if; return; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_user::text,0));
 select m.* into strict old from private.memberships m where m.user_id=p_user for update;
 if old.updated_at<>p_revision then raise serialization_failure using message='Review changed; refresh before deciding'; end if;
 new_status:=case p_action when 'approve' then 'verified' when 'reject' then 'rejected' when 'suspend' then 'suspended' when 'reinstate' then 'verified' else 'pending' end;
 if not ((p_action in ('approve','reject') and old.status='pending') or (p_action='suspend' and old.status in ('pending','verified')) or
 (p_action='reinstate' and old.status='suspended') or (p_action='correction' and old.status in ('rejected','verified'))) then raise check_violation; end if;
 if (new_status='verified')<>(p_kind is not null) then raise check_violation; end if;
 if new_status='verified' and not exists(select 1 from public.profiles p join auth.users u on u.id=p.user_id
 join public.institutions i on i.id=p.institution_id and i.active
 left join public.departments d on d.id=p.department_id left join public.programmes pr on pr.id=p.programme_id
 where p.user_id=p_user and u.email_confirmed_at is not null and u.deleted_at is null
 and (u.banned_until is null or u.banned_until<=now()) and (p.department_id is null or d.active)
 and (p.programme_id is null or pr.active)) then raise check_violation; end if;
 update private.memberships set status=new_status,verified_kind=p_kind,updated_at=clock_timestamp() where user_id=p_user;
 insert into private.verification_audit(subject_id,actor_id,previous_status,new_status,verified_kind,reason)
 values(p_user,auth.uid(),old.status,new_status,p_kind,left(p_category||': '||btrim(p_note),1000));
 insert into private.administration_audit(actor_id,subject_id,action,category,note,before_state,after_state,request_id,request_hash)
 values(auth.uid(),p_user,p_action,p_category,btrim(p_note),jsonb_build_object('status',old.status,'kind',old.verified_kind,'claims',(select jsonb_build_object('kind',p.claimed_kind,'institution_id',p.institution_id,'department_id',p.department_id,'programme_id',p.programme_id,'joining_year',p.joining_year,'graduation_year',p.graduation_year,'affiliation',p.affiliation) from public.profiles p where p.user_id=p_user)),jsonb_build_object('status',new_status,'kind',p_kind),p_request,fingerprint);
 update private.membership_requests set status='closed',resolved_at=clock_timestamp() where user_id=p_user and status='open';
end; $$;

-- Legacy clients remain supported but cannot skip live authority/scope or state rules.
create or replace function public.review_membership(p_user_id uuid,p_status public.membership_status,p_verified_kind public.account_kind,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare revision timestamptz;
begin
 if not private.admin_scope(p_user_id) then raise insufficient_privilege; end if;
 select m.updated_at into strict revision from private.memberships m where m.user_id=p_user_id;
 perform public.decide_institutional_membership(p_user_id,case p_status when 'verified' then 'approve' when 'rejected' then 'reject' when 'suspended' then 'suspend' else null end,p_verified_kind,'record_checked',p_reason,revision,gen_random_uuid());
end; $$;

create function public.request_membership_review(p_kind text) returns void
language plpgsql security definer set search_path='' as $$
declare state public.membership_status;
begin
 if auth.uid() is null or not exists(select 1 from auth.users u where u.id=auth.uid() and u.email_confirmed_at is not null and u.deleted_at is null and (u.banned_until is null or u.banned_until<=now())) then raise insufficient_privilege; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 select m.status into strict state from private.memberships m where m.user_id=auth.uid();
 if p_kind is null or not ((p_kind='appeal' and state in ('rejected','suspended')) or (p_kind='correction' and state='verified')) then raise check_violation; end if;
 if exists(select 1 from private.membership_requests r where r.user_id=auth.uid() and r.status='open') then return; end if;
 if (select count(*) from private.membership_requests r where r.user_id=auth.uid() and r.created_at>now()-interval '30 days')>=3 then raise check_violation using message='Review request limit reached'; end if;
 insert into private.membership_requests(user_id,kind) values(auth.uid(),p_kind);
end; $$;

create function public.own_review_status() returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null then raise insufficient_privilege; end if;
 return jsonb_build_object('category',(select a.category from private.administration_audit a where a.subject_id=auth.uid() order by a.created_at desc,a.id desc limit 1),
 'request_open',exists(select 1 from private.membership_requests r where r.user_id=auth.uid() and r.status='open'));
end; $$;

create function public.administration_history(p_user uuid,p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.admin_scope(p_user) then raise insufficient_privilege; end if;
 if p_offset is null or p_offset not between 0 and 10000 then raise check_violation; end if;
 return (select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from (select a.id,a.actor_id,a.action,a.category,a.note,a.before_state,a.after_state,a.created_at from private.administration_audit a where a.subject_id=p_user order by a.created_at desc,a.id desc offset p_offset limit 30)x);
end; $$;

create function public.administration_reports(p_status text default 'open',p_offset integer default 0) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_admin() then raise insufficient_privilege; end if;
 if p_status is null or p_status not in ('open','resolved','dismissed') or p_offset is null or p_offset not between 0 and 10000 then raise check_violation; end if;
 return (select coalesce(jsonb_agg(to_jsonb(x)),'[]'::jsonb) from (select r.id,r.target_profile_id,r.target_opportunity_id,r.reason,r.details,r.status,r.updated_at revision,r.moderated_by,r.created_at,
 (select count(*) from public.reports s where coalesce(s.target_profile_id,(select o.author_id from public.opportunities o where o.id=s.target_opportunity_id))=coalesce(r.target_profile_id,(select o.author_id from public.opportunities o where o.id=r.target_opportunity_id))) prior_reports
 from public.reports r where r.status=p_status and private.admin_scope(coalesce(r.target_profile_id,(select o.author_id from public.opportunities o where o.id=r.target_opportunity_id))) order by r.created_at,r.id offset p_offset limit 30)x);
end; $$;

create function public.decide_institutional_report(p_report uuid,p_status text,p_note text,p_revision timestamptz,p_request uuid) returns void
language plpgsql security definer set search_path='' as $$
declare old public.reports%rowtype; subject uuid; fingerprint text; previous private.administration_audit%rowtype;
begin
 if not private.is_admin() then raise insufficient_privilege; end if;
 select coalesce(r.target_profile_id,o.author_id) into subject from public.reports r left join public.opportunities o on o.id=r.target_opportunity_id where r.id=p_report;
 if not private.admin_scope(subject) or subject=auth.uid() then raise insufficient_privilege; end if;
 if p_status is null or p_status not in ('resolved','dismissed','archive') or p_note is null or char_length(btrim(p_note)) not between 1 and 1000 or p_revision is null or p_request is null then raise check_violation; end if;
 fingerprint:=md5(jsonb_build_array(p_report,p_status,btrim(p_note),p_revision)::text);
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_request::text,0));
 select a.* into previous from private.administration_audit a where a.actor_id=auth.uid() and a.request_id=p_request;
 if found then if previous.request_hash<>fingerprint then raise check_violation; end if; return; end if;
 select r.* into strict old from public.reports r where r.id=p_report for update;
 if old.updated_at<>p_revision then raise serialization_failure; end if;
 if old.status<>'open' then raise check_violation; end if;
 if p_status='archive' then
 if old.target_opportunity_id is null then raise check_violation; end if;
 perform 1 from public.opportunities o where o.id=old.target_opportunity_id for update;
 update public.opportunities set archived_at=clock_timestamp(),status='closed' where id=old.target_opportunity_id;
 end if;
 update public.reports set status=case when p_status='archive' then 'resolved' else p_status end,moderated_by=auth.uid(),updated_at=clock_timestamp() where id=p_report;
 insert into private.administration_audit(actor_id,subject_id,report_id,action,category,note,before_state,after_state,request_id,request_hash)
 values(auth.uid(),subject,p_report,case when p_status='archive' then 'archive_opportunity_report' else 'moderate_report' end,old.reason,btrim(p_note),jsonb_build_object('status',old.status),jsonb_build_object('status',case when p_status='archive' then 'resolved' else p_status end,'opportunity_archived',p_status='archive'),p_request,fingerprint);
end; $$;
create or replace function public.moderate_report(p_id uuid,p_status text) returns void
language plpgsql security definer set search_path='' as $$
declare revision timestamptz;
begin
 if not private.is_admin() then raise insufficient_privilege; end if;
 select r.updated_at into strict revision from public.reports r where r.id=p_id;
 perform public.decide_institutional_report(p_id,p_status,'Legacy moderation decision; review under institutional policy',revision,gen_random_uuid());
end; $$;

-- Limit legacy projections too, rather than leaving a parallel global read path.
create or replace function public.pending_memberships(p_limit integer default 30)
returns table(user_id uuid,display_name text,claimed_kind text,institution_id uuid,department_id uuid,joining_year integer,graduation_year integer)
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_admin() then raise insufficient_privilege; end if;
 if p_limit is null or p_limit not between 1 and 100 then raise check_violation; end if;
 return query select p.user_id,p.display_name,p.claimed_kind::text,p.institution_id,p.department_id,p.joining_year::integer,p.graduation_year::integer from public.profiles p join private.memberships m on m.user_id=p.user_id where m.status='pending' and private.admin_scope(p.user_id) order by p.created_at,p.user_id limit p_limit;
end; $$;
create or replace function public.pending_memberships_v2(p_limit integer default 30)
returns table(user_id uuid,display_name text,claimed_kind text,institution_id uuid,department_id uuid,joining_year integer,graduation_year integer,programme_id uuid,programme text,institution text,department text,affiliation text)
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.is_admin() then raise insufficient_privilege; end if;
 if p_limit is null or p_limit not between 1 and 100 then raise check_violation; end if;
 return query select p.user_id,p.display_name,p.claimed_kind::text,p.institution_id,p.department_id,p.joining_year::integer,p.graduation_year::integer,p.programme_id,pr.name,i.name,d.name,p.affiliation
 from public.profiles p join private.memberships m on m.user_id=p.user_id join public.institutions i on i.id=p.institution_id left join public.departments d on d.id=p.department_id left join public.programmes pr on pr.id=p.programme_id
 where m.status='pending' and private.admin_scope(p.user_id) order by p.created_at,p.user_id limit p_limit;
end; $$;
create or replace function public.verification_history(p_user_id uuid)
returns table(id uuid,actor_id uuid,previous_status text,new_status text,verified_kind text,reason text,created_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
begin
 if not private.admin_scope(p_user_id) then raise insufficient_privilege; end if;
 return query select a.id,a.actor_id,a.previous_status::text,a.new_status::text,a.verified_kind::text,a.reason,a.created_at from private.verification_audit a where a.subject_id=p_user_id order by a.created_at,a.id;
end; $$;
drop policy reporter_read on public.reports;
create policy reporter_read on public.reports for select to authenticated using
 ((reporter_id=auth.uid() and private.is_verified()) or private.admin_scope(coalesce(target_profile_id,(select o.author_id from public.opportunities o where o.id=target_opportunity_id))));

revoke all on function public.administration_context(),public.administration_members(text,text,integer,integer),public.decide_institutional_membership(uuid,text,public.account_kind,text,text,timestamptz,uuid),public.request_membership_review(text),public.own_review_status(),public.administration_history(uuid,integer),public.administration_reports(text,integer),public.decide_institutional_report(uuid,text,text,timestamptz,uuid) from public,anon,authenticated,service_role;
grant execute on function public.administration_context(),public.administration_members(text,text,integer,integer),public.decide_institutional_membership(uuid,text,public.account_kind,text,text,timestamptz,uuid),public.request_membership_review(text),public.own_review_status(),public.administration_history(uuid,integer),public.administration_reports(text,integer),public.decide_institutional_report(uuid,text,text,timestamptz,uuid) to authenticated;
alter table public.reports drop constraint reports_reason_check;
alter table public.reports add constraint reports_reason_check check(reason in ('harassment','impersonation','inappropriate','other','fraud','spam','privacy'));
create index memberships_status_review_idx on private.memberships(status,user_id);
create or replace function public.report_career_opportunity(p_id uuid,p_reason text,p_details text) returns uuid
language plpgsql security definer set search_path='' as $$
declare result uuid;
begin
 if not private.career_visible(p_id) or not exists(select 1 from public.opportunities o where o.id=p_id and o.status='published' and o.author_id<>auth.uid()) then raise insufficient_privilege; end if;
 if p_reason is null or p_reason not in ('harassment','impersonation','inappropriate','other','fraud','spam','privacy') or p_details is null or char_length(p_details)>2000 or char_length(btrim(p_details))<10 then raise check_violation; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_id::text,0));
 select r.id into result from public.reports r where r.reporter_id=auth.uid() and r.target_opportunity_id=p_id and r.status='open' order by r.created_at limit 1;
 if result is not null then return result; end if;
 insert into public.reports(reporter_id,target_opportunity_id,reason,details) values(auth.uid(),p_id,p_reason,btrim(p_details)) returning id into result;
 return result;
end; $$;

create function private.audit_academic_correction() returns trigger
language plpgsql security definer set search_path='' as $$
declare before_claim jsonb; after_claim jsonb;
begin
 if auth.uid() is distinct from new.user_id or not exists(select 1 from private.memberships m where m.user_id=new.user_id and m.status='pending') or
 not exists(select 1 from private.administration_audit a where a.subject_id=new.user_id and a.action='correction') then return new; end if;
 before_claim:=jsonb_build_object('kind',old.claimed_kind,'institution_id',old.institution_id,'department_id',old.department_id,'programme_id',old.programme_id,'joining_year',old.joining_year,'graduation_year',old.graduation_year,'affiliation',old.affiliation);
 after_claim:=jsonb_build_object('kind',new.claimed_kind,'institution_id',new.institution_id,'department_id',new.department_id,'programme_id',new.programme_id,'joining_year',new.joining_year,'graduation_year',new.graduation_year,'affiliation',new.affiliation);
 if before_claim is distinct from after_claim then
 insert into private.administration_audit(actor_id,subject_id,action,category,note,before_state,after_state,request_id,request_hash)
 values(auth.uid(),new.user_id,'claim_correction','member_updated_claim','Own academic claims changed during an authorized pending correction',before_claim,after_claim,gen_random_uuid(),'owned-profile-correction');
 end if;
 return new;
end; $$;
revoke all on function private.audit_academic_correction() from public,anon,authenticated;
create trigger academic_correction_audit after update on public.profiles for each row execute function private.audit_academic_correction();

notify pgrst,'reload schema';
commit;
$msgi_reviewed_migration_source$]);

commit;
