-- OWNER-ONLY reviewed initial-administrator operation. NOT a migration/seed/RPC.
-- This single DO statement is atomic. Requires explicit approved parameters.
-- No account creation, no Auth metadata roles, no public execute endpoint.
-- Set msgi.bootstrap_approved, msgi.bootstrap_user (UUID), msgi.bootstrap_kind,
-- msgi.bootstrap_approver and msgi.bootstrap_reason in the SAME owner session.
do $$
declare
 actor uuid := nullif(current_setting('msgi.bootstrap_user',true),'')::uuid;
 approved_kind public.account_kind := nullif(current_setting('msgi.bootstrap_kind',true),'')::public.account_kind;
 approver text := nullif(btrim(current_setting('msgi.bootstrap_approver',true)),'');
 reason_text text := nullif(btrim(current_setting('msgi.bootstrap_reason',true)),'');
 current_membership private.memberships%rowtype;
 profile_claim public.account_kind;
 audit_reason text;
 affected integer;
begin
 perform pg_catalog.set_config('search_path','',true);
 if current_setting('msgi.bootstrap_approved',true) is distinct from 'yes' or actor is null or approved_kind is null or approver is null or reason_text is null then
   raise exception 'Explicit initial administrator approval and complete parameters required';
 end if;
 audit_reason := 'INITIAL DEVELOPMENT ADMINISTRATOR; independently approved by '||approver||'; '||reason_text;
 if char_length(audit_reason)>1000 then raise exception 'Approval reason exceeds audit bound'; end if;
 perform pg_advisory_xact_lock(hashtextextended('msgi.initial.administrator',0));
 perform pg_advisory_xact_lock(hashtextextended(actor::text,0));
 perform 1 from auth.users u where u.id=actor and u.email_confirmed_at is not null and u.deleted_at is null and (u.banned_until is null or u.banned_until<=now()) for update;
 if not found then
   raise exception 'Candidate must be an existing confirmed, non-deleted, non-banned account';
 end if;
 select m.* into current_membership from private.memberships m where m.user_id=actor for update;
 if not found then raise exception 'Complete onboarding before administrator provisioning'; end if;
 if exists(select 1 from private.account_roles r where r.user_id=actor and r.role='administrator') then
   if current_membership.status='verified' and current_membership.verified_kind=approved_kind and
      exists(select 1 from private.verification_audit a where a.subject_id=actor and a.reason=audit_reason and a.new_status='verified') then
     raise notice 'Approved initial administrator already provisioned; no changes'; return;
   end if;
   raise exception 'Existing role does not match this audited operation; stop for review';
 end if;
 if exists(select 1 from private.account_roles where role='administrator') then raise exception 'Initial administrator already exists; use separately approved administration'; end if;
 if current_membership.status<>'pending' then raise exception 'Candidate must have pending membership'; end if;
 select p.claimed_kind into profile_claim from public.profiles p
   join public.institutions i on i.id=p.institution_id and i.active
   left join public.departments d on d.id=p.department_id and d.institution_id=p.institution_id
   left join public.programmes pr on pr.id=p.programme_id and pr.institution_id=p.institution_id
   where p.user_id=actor and (p.department_id is null or d.active)
     and (p.programme_id is null or pr.active)
     and (p.department_id is not null or p.programme_id is not null or (p.claimed_kind='staff' and nullif(btrim(p.affiliation),'') is not null))
   for update of p;
 if not found or profile_claim<>approved_kind or (profile_claim<>'staff' and not exists(select 1 from public.profile_skills ps where ps.profile_id=actor)) then raise exception 'Review complete profile, active catalogs and approved account kind first'; end if;
 update private.memberships set status='verified',verified_kind=approved_kind,updated_at=now() where user_id=actor and status='pending';
 get diagnostics affected=row_count;
 if affected<>1 then raise exception 'Unexpected membership update count'; end if;
 insert into private.account_roles(user_id,role) values(actor,'administrator');
 -- First-bootstrap subject is the database audit actor; the independent human
 -- authorizer is explicitly recorded in the private audit reason, not fabricated.
 insert into private.verification_audit(subject_id,actor_id,previous_status,new_status,verified_kind,reason)
 values(actor,actor,'pending','verified',approved_kind,audit_reason);
 insert into private.administration_audit(actor_id,subject_id,action,category,note,before_state,after_state,request_id,request_hash)
 values(actor,actor,'initial_administrator','independent_owner_approval',audit_reason,
 jsonb_build_object('administrator',false,'status','pending'),jsonb_build_object('administrator',true,'status','verified'),gen_random_uuid(),'owner-bootstrap');
end;
$$;
