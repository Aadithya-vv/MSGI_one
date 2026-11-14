-- Self-contained, rollback-only synthetic acceptance; no hosted execution.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
insert into public.institutions(id,name,catalog_key) values('b1100000-0000-4000-8000-000000000001','Synthetic MSEC test scope','msec') on conflict(catalog_key) do nothing;
insert into public.institutions(id,name) values('b1100000-0000-4000-8000-000000000002','Synthetic other institution');
insert into public.programmes(id,institution_id,application_key,name,level)
 select 'b1110000-0000-4000-8000-000000000001',i.id,'synthetic-test-programme','Synthetic test qualification','undergraduate'
 from public.institutions i where i.catalog_key='msec';
insert into public.programmes(id,institution_id,application_key,name,level)
 select 'b1110000-0000-4000-8000-000000000002',i.id,'synthetic-other-programme','Synthetic other qualification','postgraduate'
 from public.institutions i where i.catalog_key='msec';
insert into auth.users(id,email,email_confirmed_at) select
 ('b1130000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'task11a-sql-'||n||'@example.test',case when n<4 then now() end from generate_series(1,4)n;
create function pg_temp.input(kind text) returns jsonb language sql as $$
 select jsonb_build_object('display_name','Synthetic '||kind,'kind',kind,'institution_id',(select id from public.institutions where catalog_key='msec'),
 'department_id',null,'programme_id',case when kind='staff' then null else 'b1110000-0000-4000-8000-000000000001' end,
 'affiliation',case when kind='staff' then 'Academic support' else '' end,
 'joining_year',case when kind='student' then 2024 else null end,'graduation_year',case kind when 'student' then 2028 when 'alumni' then 2020 end,
 'designation','Synthetic professional','interests',jsonb_build_array('Engineering'),'skill_ids','[]'::jsonb,
 'directory_visible',true,'map_opt_in',false,'mentoring',kind='alumni');
$$;
insert into public.skills(id,name) values('b1140000-0000-4000-8000-000000000001','Synthetic onboarding skill');
create function pg_temp.member_input(kind text) returns jsonb language sql as $$
 select pg_temp.input(kind)||jsonb_build_object('skill_ids',jsonb_build_array('b1140000-0000-4000-8000-000000000001'));
$$;
select has_table('public','programmes','Normalized programme table exists');
select ok((select relrowsecurity from pg_class where oid='public.programmes'::regclass),'Programme RLS enabled');
select ok(not has_table_privilege('authenticated','public.programmes','INSERT'),'Clients cannot provision programmes');
select ok(not has_column_privilege('authenticated','public.profiles','programme_id','UPDATE'),'Reviewed academic edits require RPC');
select ok(not has_function_privilege('anon','public.discover_alumni_v2(text,uuid,uuid,integer,text,uuid,uuid,uuid,integer,uuid,uuid)','EXECUTE'),'Anonymous programme discovery denied');
select ok(not has_function_privilege('anon','public.pending_memberships_v2(integer)','EXECUTE'),'Anonymous academic review denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b1130000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.save_member_profile(pg_temp.member_input('student')||'{"programme_id":null}'::jsonb)$$,'23514',null,'MSEC student requires programme');
select throws_ok($$select public.save_member_profile(pg_temp.member_input('student')||'{"institution_id":"b1100000-0000-4000-8000-000000000002"}'::jsonb)$$,'23514',null,'Cross-institution programme denied');
select throws_ok($$select public.save_member_profile(pg_temp.member_input('student')||'{"role":"administrator"}'::jsonb)$$,'23514',null,'Profile role escalation field rejected');
select lives_ok($$select public.save_member_profile(pg_temp.member_input('student'))$$,'Student programme onboarding succeeds');
select is((select status from public.my_membership()),'pending','Student remains pending');
select is((select department_id from public.profiles where user_id=auth.uid()),null::uuid,'Programme creates no department claim');
select is((select degree from public.profiles where user_id=auth.uid()),'Synthetic test qualification','Canonical programme label stored');
select throws_ok($$select * from public.discover_alumni_v2()$$,'42501',null,'Pending programme student cannot discover');
select throws_ok($$select public.request_connection('b1130000-0000-4000-8000-000000000002')$$,'42501',null,'Pending connection denied');
select set_config('request.jwt.claims','{"sub":"b1130000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select lives_ok($$select public.save_member_profile(pg_temp.member_input('alumni'))$$,'Alumni onboarding permits unknown joining year');
select set_config('request.jwt.claims','{"sub":"b1130000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select lives_ok($$select public.save_member_profile(pg_temp.input('staff'))$$,'Staff affiliation onboarding needs no academic years or skills');
select is((select status from public.my_membership()),'pending','Staff claim remains pending');
select is((select count(*) from public.profiles),1::bigint,'Staff sees only own base profile');
select throws_ok($$select * from public.pending_memberships()$$,'42501',null,'Staff claim grants no reviewer authority');
select throws_ok($$select * from public.pending_memberships_v2()$$,'42501',null,'Staff claim grants no academic reviewer authority');
select throws_ok($$insert into private.account_roles(user_id,role) values(auth.uid(),'administrator')$$,'42501',null,'Staff cannot self-provision admin');
select throws_ok($$select public.save_member_profile(pg_temp.input('staff')||'{"joining_year":2024}'::jsonb)$$,'23514',null,'Staff cannot attach student academic years');
select set_config('request.jwt.claims','{"sub":"b1130000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select throws_ok($$select public.save_member_profile(pg_temp.member_input('student'))$$,'42501',null,'Unconfirmed account cannot create profile');
reset role;
update private.memberships m set status='verified',verified_kind=p.claimed_kind from public.profiles p
 where p.user_id=m.user_id and p.user_id in (select id from auth.users where email like 'task11a-sql-%@example.test');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"b1130000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select ok(private.is_verified(),'Independently verified Staff obtains member access');
select ok(not private.is_admin(),'Verified Staff is not an administrator');
select throws_ok($$select * from public.pending_memberships_v2()$$,'42501',null,'Verified Staff still cannot read reviewer-only academic claims');
select ok(not public.career_can_publish(),'Staff cannot publish without separate publishing authorization');
select throws_ok($$select public.save_member_profile(pg_temp.input('staff')||'{"affiliation":"Changed claim"}'::jsonb)$$,'42501',null,'Verified Staff affiliation changes require review');
select throws_ok($$update public.profiles set affiliation='Changed claim' where user_id=auth.uid()$$,'42501',null,'Direct staff affiliation edits lack grants');
select ok(exists(select 1 from public.discover_alumni_v2(p_programme:='b1110000-0000-4000-8000-000000000001') r where r.user_id='b1130000-0000-4000-8000-000000000002'),'Programme-only alumni discoverable to verified Staff');
select ok(exists(select 1 from public.recommend_mentors() r where r.user_id='b1130000-0000-4000-8000-000000000002'),'Programme-only mentor eligible without fabricated department');
select set_config('request.jwt.claims','{"sub":"b1130000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select ok(public.career_can_publish(),'Verified programme-only alumni may publish');
select throws_ok($$select public.save_member_profile(pg_temp.member_input('alumni')||'{"programme_id":"b1110000-0000-4000-8000-000000000002"}'::jsonb)$$,'42501',null,'Verified programme switch requires review');
select throws_ok($$select public.save_member_profile(pg_temp.member_input('alumni')||'{"programme_id":null}'::jsonb)$$,'23514',null,'Verified programme cannot be removed');
select lives_ok($$select public.save_member_profile(pg_temp.member_input('alumni')||'{"directory_visible":false}'::jsonb)$$,'Own privacy update retained');
select set_config('request.jwt.claims','{"sub":"b1130000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select ok(not exists(select 1 from public.discover_alumni_v2(p_user:='b1130000-0000-4000-8000-000000000002')),'Hidden programme alumni excluded');
reset role;
-- Explicit rollback-only reviewer fixture, never self-declared through a client.
insert into private.account_roles(user_id,role) values('b1130000-0000-4000-8000-000000000003','administrator');
update private.memberships set status='pending',verified_kind=null where user_id='b1130000-0000-4000-8000-000000000001';
set local role authenticated;
select ok(private.is_admin(),'Separate protected owner role is required for reviewer access');
select ok(exists(select 1 from public.pending_memberships_v2() r where r.user_id='b1130000-0000-4000-8000-000000000001' and r.programme='Synthetic test qualification' and r.department_id is null),'Authorized review sees programme-only claim without invented department');
reset role;
select * from finish();
rollback;
