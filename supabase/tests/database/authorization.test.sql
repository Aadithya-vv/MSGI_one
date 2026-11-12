-- Synthetic fixtures only. Run with `supabase test db` on an isolated local stack.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

insert into public.institutions(id,name) values('10000000-0000-4000-8000-000000000001','Test institution');
insert into public.departments(id,institution_id,name) values
 ('10000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000001','Test department');
insert into public.skills(id,name) values('10000000-0000-4000-8000-000000000003','Test skill');
insert into public.cities(id,name,country_code) values('10000000-0000-4000-8000-000000000004','Test city','IN');
insert into auth.users(id,email,email_confirmed_at) select
 ('00000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,
 'fixture'||n||'@example.invalid',now() from generate_series(1,7) n;
update auth.users set raw_user_meta_data='{"role":"administrator","verified":true}'::jsonb
  where id='00000000-0000-4000-8000-000000000001';
insert into public.profiles(user_id,display_name,claimed_kind,institution_id,department_id,
 joining_year,graduation_year,career_interests,city_id,directory_visible,map_opt_in)
select id,'Fixture '||right(id::text,1),'alumni','10000000-0000-4000-8000-000000000001',
 '10000000-0000-4000-8000-000000000002',2020,2024,array['Technology'],
 '10000000-0000-4000-8000-000000000004',right(id::text,1)<>'7',right(id::text,1) not in ('3','7')
 from auth.users where email like 'fixture%@example.invalid' and right(id::text,1)<>'6';
insert into private.memberships(user_id,status,verified_kind)
select user_id,case right(user_id::text,1) when '1' then 'pending' when '4' then 'suspended' else 'verified' end::public.membership_status,
 case when right(user_id::text,1) in ('1','4') then null when right(user_id::text,1)='7' then 'student' else 'alumni' end::public.account_kind
 from public.profiles;
insert into private.account_roles(user_id,role) values('00000000-0000-4000-8000-000000000005','administrator');

select ok((select count(*)=13 and bool_and(c.relrowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace
 where (n.nspname='public' and c.relname in ('institutions','departments','skills','cities','profiles',
 'profile_skills','mentorship_preferences','connections','opportunities','reports'))
 or (n.nspname='private' and c.relname in ('memberships','account_roles','verification_audit'))), 'All thirteen tables have RLS');
select hasnt_column('public','profiles','email','Discoverable profile storage has no email');
select hasnt_column('public','profiles','latitude','No precise GPS coordinates stored');
select ok(not has_table_privilege('authenticated','private.account_roles','INSERT'), 'No client role provisioning grant');
select ok(not has_table_privilege('authenticated','private.memberships','UPDATE'), 'No client membership update grant');
select ok(not has_table_privilege('authenticated','public.connections','INSERT'), 'Connections can only be created through checked RPC');
select ok(not has_function_privilege('authenticated','private.member_verified(uuid)','EXECUTE'), 'Cannot probe another private membership through a helper');
select ok(not has_table_privilege('service_role','private.verification_audit','UPDATE'), 'Audit is append-only for non-owner server role');
select ok(not has_function_privilege('anon','public.my_membership()','EXECUTE'), 'Anonymous membership RPC denied');
select ok(not has_function_privilege('anon','public.directory_profiles(text,integer)','EXECUTE'), 'Anonymous directory RPC denied');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok($$update private.memberships set status='verified',verified_kind='alumni'$$,'42501',null,'New user cannot self-verify');
select throws_ok($$insert into private.account_roles values(auth.uid(),'administrator',now())$$,'42501',null,'New user cannot assign admin');
select throws_ok($$select public.review_membership(auth.uid(),'verified','alumni','self approval')$$,'42501',null,'Admin RPC rejects ordinary user');
select throws_ok($$select * from public.directory_profiles()$$,'42501',null,'Pending user cannot browse directory');
select throws_ok($$insert into public.opportunities(title,description,kind,status) values('Test title','Long enough test description','job','published')$$,'42501',null,'Pending user cannot publish');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000006","role":"authenticated"}',true);
select is((select profile_complete from public.my_membership()),false,'Authenticated user without profile is incomplete');
select throws_ok($$select public.submit_onboarding('Fixture 6','student','10000000-0000-4000-8000-000000000001',
 '10000000-0000-4000-8000-000000000002',2024,2028,null,array['Technology'],array['ffffffff-ffff-4fff-8fff-ffffffffffff']::uuid[])$$,
 '23514',null,'Invalid skill rejected transactionally');
select is((select count(*) from public.profiles),0::bigint,'Failed onboarding leaves no own profile');
select lives_ok($$select public.submit_onboarding('Fixture 6','student','10000000-0000-4000-8000-000000000001',
 '10000000-0000-4000-8000-000000000002',2024,2028,null,array['Technology'],array['10000000-0000-4000-8000-000000000003']::uuid[])$$,
 'Valid onboarding succeeds without privileged arguments');
select is((select status from public.my_membership()),'pending','Onboarding always results in pending membership');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select throws_ok($$select * from private.memberships$$,'42501',null,'Verified member cannot read private membership table');
select throws_ok($$select email from auth.users$$,'42501',null,'Verified member cannot read auth emails');
select is((select count(*) from public.profiles),1::bigint,'Base profiles expose only caller data');
select results_eq($$update public.profiles set display_name='Forged name' where user_id='00000000-0000-4000-8000-000000000003' returning user_id$$,
 $$select null::uuid where false$$,'Cannot alter another profile');
select throws_ok($$update public.profiles set claimed_kind='student' where user_id=auth.uid()$$,'42501',null,'Verified institutional claims are not editable columns');
select throws_ok($$insert into public.connections(sender_id,recipient_id) values('00000000-0000-4000-8000-000000000003',auth.uid())$$,
 '42501',null,'Forged sender rejected');
select throws_ok($$select public.send_connection(auth.uid())$$,'23514',null,'Self-connections rejected');
select lives_ok($$select public.send_connection('00000000-0000-4000-8000-000000000003')$$,'Verified caller can request connection');
select throws_ok($$select public.send_connection('00000000-0000-4000-8000-000000000003')$$,'23505',null,'Duplicate relationship rejected');
select throws_ok($$select public.transition_connection((select id from public.connections limit 1),'accepted')$$,
 '42501',null,'Sender cannot accept their own request');
select is((select count(*) from public.map_profiles() where user_id='00000000-0000-4000-8000-000000000003'),0::bigint,'Map excludes non-opted-in member');
select is((select count(*) from public.map_profiles() where user_id=auth.uid()),1::bigint,'Map includes opted-in verified visible caller');
select throws_ok($$update public.profiles set directory_visible=false,map_opt_in=true where user_id=auth.uid()$$,'23514',null,'Map consent cannot override disabled directory visibility');
select is((select count(*) from public.map_profiles() where user_id='00000000-0000-4000-8000-000000000007'),0::bigint,'Directory-hidden profiles also excluded from map');
select is((select count(*) from public.directory_profiles() where user_id='00000000-0000-4000-8000-000000000004'),0::bigint,'Directory excludes suspended profiles');
select throws_ok($$insert into public.opportunities(author_id,title,description,kind) values('00000000-0000-4000-8000-000000000003','Test title','Long enough test description','job')$$,
 '42501',null,'Cannot forge opportunity author');
select lives_ok($$insert into public.opportunities(title,description,kind,status) values('Test title','Long enough test description','job','published')$$,'Verified alumnus can publish own listing');
select lives_ok($$insert into public.reports(target_profile_id,reason,details) values('00000000-0000-4000-8000-000000000003','other','Test moderation report contents')$$,'Verified member can submit own report');
select throws_ok($$update public.reports set status='resolved'$$,'42501',null,'Reporter cannot moderate their own report');
select throws_ok($$select * from public.verification_history(auth.uid())$$,'42501',null,'Audit history is administrator-only');
select throws_ok($$select * from public.pending_memberships()$$,'42501',null,'Pending verification queue is administrator-only');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select throws_ok($$select public.send_connection('00000000-0000-4000-8000-000000000002')$$,'23505',null,'Reverse-direction duplicate rejected');
select lives_ok($$select public.transition_connection((select id from public.connections limit 1),'accepted')$$,'Only recipient can accept incoming request');
select results_eq($$update public.opportunities set title='Forged opportunity' returning id$$,$$select null::uuid where false$$,'Another author cannot edit listing');
select throws_ok($$select public.moderate_report(gen_random_uuid(),'resolved')$$,'42501',null,'Ordinary members cannot moderate reports');
select is((select count(*) from public.reports),0::bigint,'Reported user cannot read another member report');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000007","role":"authenticated"}',true);
select throws_ok($$insert into public.opportunities(title,description,kind) values('Test title','Long enough test description','job')$$,
 '42501',null,'Verified students cannot publish alumni-only opportunities');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select throws_ok($$select * from public.directory_profiles()$$,'42501',null,'Suspended user cannot browse');
select throws_ok($$select public.send_connection('00000000-0000-4000-8000-000000000002')$$,'42501',null,'Suspended user cannot connect');
select throws_ok($$insert into public.opportunities(title,description,kind) values('Test title','Long enough test description','job')$$,'42501',null,'Suspended user cannot publish');
select is((select count(*) from public.institutions),0::bigint,'Suspended account loses catalog access');
select is((select count(*) from public.opportunities),0::bigint,'Suspended account cannot read community listings');
reset role;
update auth.users set email_confirmed_at=null where id='00000000-0000-4000-8000-000000000007';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000007","role":"authenticated"}',true);
select throws_ok($$select * from public.directory_profiles()$$,'42501',null,'Even verified membership requires confirmed account email');
select throws_ok($$select * from public.my_membership()$$,'42501',null,'Unconfirmed verification cannot grant verified client routing state');

select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000005","role":"authenticated"}',true);
select is((select count(*) from public.pending_memberships() where user_id='00000000-0000-4000-8000-000000000001'),1::bigint,'Administrator can inspect pending professional claims before review');
select throws_ok($$select public.review_membership('00000000-0000-4000-8000-000000000007','verified','student','Review unconfirmed account')$$,'23514',null,'Administrator cannot approve unconfirmed email');
select throws_ok($$select public.review_membership('00000000-0000-4000-8000-000000000001','verified','student','')$$,'23514',null,'Review without valid audit reason rolls back');
select is((select count(*) from public.directory_profiles() where user_id='00000000-0000-4000-8000-000000000001'),0::bigint,'Failed review does not leak verified access');
select lives_ok($$select public.moderate_report((select id from public.reports where details='Test moderation report contents' limit 1),'resolved')$$,'Trusted administrator can moderate a report');
select is((select status from public.reports where details='Test moderation report contents'),'resolved','Moderation updates report state');
select lives_ok($$select public.review_membership('00000000-0000-4000-8000-000000000001','verified','student','Institutional evidence reviewed')$$,'Trusted administrator can approve');
select is((select count(*) from public.verification_history('00000000-0000-4000-8000-000000000001')),1::bigint,'Approval creates audit record');
select throws_ok($$select public.review_membership(auth.uid(),'verified','alumni','Self approval')$$,'42501',null,'Admin cannot review their own membership');
select lives_ok($$select public.review_membership('00000000-0000-4000-8000-000000000002','suspended',null,'Moderation decision')$$,'Admin can suspend existing verified account');
select set_config('request.jwt.claims','{"sub":"00000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select throws_ok($$select * from public.directory_profiles()$$,'42501',null,'Existing JWT cannot bypass newly suspended membership');

reset role;
set local role anon;
select set_config('request.jwt.claims','{"role":"anon"}',true);
select throws_ok($$select * from private.memberships$$,'42501',null,'Anonymous private membership read denied');
select throws_ok($$select * from public.my_membership()$$,'42501',null,'Anonymous membership RPC denied at ACL');
select throws_ok($$select * from public.directory_profiles()$$,'42501',null,'Anonymous directory denied at ACL');
select throws_ok($$select * from public.pending_memberships()$$,'42501',null,'Anonymous verification queue denied at ACL');
reset role;
select * from finish();
rollback;
