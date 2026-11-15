-- OWNER-ONLY operation. Never a migration, seed, public RPC or Flutter action.
-- Use a reviewed dedicated owner transaction. Set these transaction-local values:
-- msgi.role_approved=yes; msgi.role_subject=<UUID>; msgi.role_operator=<UUID>;
-- msgi.role_action=grant|revoke; msgi.role_reason=<independent approval reference>.
-- The operator UUID is an existing consented human account, not a caller-supplied
-- client authority. Database-owner execution + separate institutional approval
-- are mandatory. No passwords, Auth metadata changes or automatic provisioning.
do $$
declare
 subject uuid:=nullif(current_setting('msgi.role_subject',true),'')::uuid;
 operator uuid:=nullif(current_setting('msgi.role_operator',true),'')::uuid;
 action text:=current_setting('msgi.role_action',true);
 reason_text text:=btrim(current_setting('msgi.role_reason',true));
 existed boolean;
begin
 perform pg_catalog.set_config('search_path','',true);
 if current_setting('msgi.role_approved',true) is distinct from 'yes' or subject is null or operator is null or subject=operator or
 action is null or action not in ('grant','revoke') or reason_text is null or char_length(reason_text) not between 10 and 1000 then raise check_violation; end if;
 perform pg_advisory_xact_lock(hashtextextended('msgi.initial.administrator',0));
 perform pg_advisory_xact_lock(hashtextextended(subject::text,0));
 if not exists(select 1 from auth.users u where u.id=operator and u.email_confirmed_at is not null and u.deleted_at is null and (u.banned_until is null or u.banned_until<=now())) then raise check_violation; end if;
 select exists(select 1 from private.account_roles r where r.user_id=subject and r.role='administrator') into existed;
 if action='grant' then
  if not private.member_verified(subject) then raise check_violation using message='Independently verify membership before role grant'; end if;
  if existed and not exists(select 1 from private.account_roles r join public.profiles p on p.user_id=r.user_id and p.institution_id=r.institution_id where r.user_id=subject) then raise check_violation using message='Existing role scope differs; review revocation and new grant separately'; end if;
  if existed then return; end if;
  insert into private.account_roles(user_id,role) values(subject,'administrator');
 else
  if not existed then return; end if;
  if exists(select 1 from private.account_roles r join public.profiles p on p.user_id=r.user_id and p.institution_id=r.institution_id where r.user_id=subject and private.member_verified(subject)) and
     not exists(select 1 from private.account_roles r join public.profiles p on p.user_id=r.user_id and p.institution_id=r.institution_id join private.account_roles s on s.user_id=subject and s.institution_id=r.institution_id where r.user_id<>subject and r.role='administrator' and private.member_verified(r.user_id)) then raise check_violation using message='Do not revoke the last active institution administrator'; end if;
  delete from private.account_roles where user_id=subject and role='administrator';
 end if;
 insert into private.administration_audit(actor_id,subject_id,action,category,note,before_state,after_state,request_id,request_hash)
 values(operator,subject,'owner_role_'||action,'independent_owner_approval',reason_text,jsonb_build_object('administrator',existed),jsonb_build_object('administrator',action='grant'),gen_random_uuid(),'owner-only');
end; $$;
