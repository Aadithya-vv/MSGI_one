-- Forward-only, LOCAL validation first. Never auto-provision administrators.
begin;
set local lock_timeout='5s';
set local statement_timeout='60s';
set local standard_conforming_strings=on;

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
