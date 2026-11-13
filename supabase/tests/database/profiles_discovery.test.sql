-- Isolated local, transactional synthetic security tests. No credentials.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
insert into public.institutions(id,name) values('50000000-0000-4000-8000-000000000001','Security fixture institute');
insert into public.departments(id,institution_id,name) values('51000000-0000-4000-8000-000000000001','50000000-0000-4000-8000-000000000001','Security fixture department');
insert into public.skills(id,name) values('52000000-0000-4000-8000-000000000001','Security fixture skill');
insert into public.cities(id,name,country_code) values('53000000-0000-4000-8000-000000000001','Security fixture city','IN');
insert into auth.users(id,email,email_confirmed_at)
select ('54000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'profile-fixture-'||n||'@example.invalid',now() from generate_series(1,26)n;
create function pg_temp.input(kind text default 'alumni') returns jsonb language sql as $$
 select jsonb_build_object('display_name','Synthetic professional','kind',kind,'institution_id','50000000-0000-4000-8000-000000000001',
 'department_id','51000000-0000-4000-8000-000000000001','joining_year',2018,'graduation_year',2022,'designation','Engineer','company','Synthetic company',
 'professional_domain','Software','biography','Synthetic biography','degree','Synthetic degree','mentoring',true,
 'interests',jsonb_build_array('Research'),'skill_ids',jsonb_build_array('52000000-0000-4000-8000-000000000001'),
 'city_id','53000000-0000-4000-8000-000000000001','directory_visible',true,'map_opt_in',true);
$$;
select ok((select relrowsecurity from pg_class where oid='public.profile_drafts'::regclass),'Draft RLS enabled');
select ok(not has_function_privilege('anon','public.save_member_profile(jsonb)','execute'),'Anonymous save denied');
select ok(not has_function_privilege('anon','public.discover_alumni(text,uuid,uuid,integer,text,uuid,uuid,uuid,integer,uuid)','execute'),'Anonymous discovery denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"54000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select lives_ok($$insert into public.profile_drafts(user_id,content) values(auth.uid(),'{"display_name":"Partial progress"}')$$,'Incomplete own draft saves');
select is((select count(*) from public.profile_drafts),1::bigint,'Own draft readable');
select throws_ok($$insert into public.profile_drafts(user_id,content) values('54000000-0000-4000-8000-000000000002','{}')$$,'42501',null,'Other-user draft insert denied');
select lives_ok($$select public.save_member_profile(pg_temp.input('student'))$$,'Student onboarding saves');
select is((select count(*) from public.profile_drafts),0::bigint,'Submit clears draft atomically');
select is((select status from public.my_membership()),'pending','Student remains pending');
select lives_ok($$select public.save_member_profile(pg_temp.input())$$,'Pending claim can be corrected');
select is((select company from public.profiles where user_id=auth.uid()),'Synthetic company','Professional fields persist');
select is((select available from public.mentorship_preferences where profile_id=auth.uid()),true,'Mentoring preference persists without verification');
select throws_ok($$select public.save_member_profile(pg_temp.input()||'{"verified":true}')$$,'23514',null,'Unknown privilege field rejected');
select throws_ok($$select public.save_member_profile(pg_temp.input()||jsonb_build_object('biography',repeat('x',1001)))$$,'23514',null,'Biography length enforced');
select throws_ok($$select public.save_member_profile(pg_temp.input()||'{"map_opt_in":true,"directory_visible":false}')$$,'23514',null,'Map requires directory consent');
select throws_ok($$select * from public.discover_alumni()$$,'42501',null,'Pending directory denied');
reset role;
-- Explicit synthetic authorization fixture, never client/admin provisioning.
update private.memberships set status='verified',verified_kind='alumni' where user_id='54000000-0000-4000-8000-000000000001';
insert into public.profiles(user_id,display_name,claimed_kind,institution_id,department_id,joining_year,graduation_year,career_interests,directory_visible,map_opt_in,city_id,company)
select id,'Synthetic alumnus '||right(id::text,2),'alumni','50000000-0000-4000-8000-000000000001','51000000-0000-4000-8000-000000000001',2018,2022,array['Research'],true,false,'53000000-0000-4000-8000-000000000001','Synthetic company'
from auth.users where email like 'profile-fixture-%@example.invalid' and id<>'54000000-0000-4000-8000-000000000001';
insert into private.memberships(user_id,status,verified_kind)
select user_id,'verified','alumni' from public.profiles where user_id::text like '54000000%' and user_id<>'54000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"54000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is((select count(*) from public.discover_alumni()),20::bigint,'Default pagination bounded');
select is((select count(*) from public.discover_alumni(p_limit=>21)),21::bigint,'Lookahead page bounded');
select is((select count(*) from public.discover_alumni(p_after=>'54000000-0000-4000-8000-000000000020')),6::bigint,'Keyset pagination returns remaining rows');
select is((select count(*) from public.discover_alumni(p_search=>'professional')),1::bigint,'Name search');
select is((select count(*) from public.discover_alumni(p_year=>1999)),0::bigint,'Graduation filter');
select is((select count(*) from public.discover_alumni(p_profession=>'no match')),0::bigint,'Profession filter');
select is((select count(*) from public.discover_alumni(p_skill=>'52000000-0000-4000-8000-000000000001')),1::bigint,'Skill filter');
select is((select count(*) from public.discover_alumni(p_city=>'53000000-0000-4000-8000-000000000001')),1::bigint,'City filter cannot infer unconsented location');
select is((select city from public.discover_alumni(p_user=>'54000000-0000-4000-8000-000000000002')),null::text,'Unconsented city not returned');
select is((select count(*) from public.profiles),1::bigint,'Base profile remains own only');
select throws_ok($$select public.save_member_profile(pg_temp.input()||'{"graduation_year":2021}')$$,'42501',null,'Verified education cannot change');
select lives_ok($$select public.save_member_profile(pg_temp.input()||'{"company":"Updated synthetic company","directory_visible":false,"map_opt_in":false}')$$,'Verified own professional/privacy edit works');
select is((select count(*) from public.discover_alumni(p_user=>auth.uid())),0::bigint,'Hidden own profile excluded');
select throws_ok($$select * from public.discover_alumni(p_limit=>1000)$$,'23514',null,'Unbounded page denied');
select throws_ok($$select public.save_member_profile(pg_temp.input()||'{"skill_ids":[]}')$$,'23514',null,'Empty skills denied');
reset role;
update private.memberships set status='suspended',verified_kind=null where user_id='54000000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($$select * from public.discover_alumni()$$,'42501',null,'Suspension denies discovery with existing identity');
select throws_ok($$select public.save_member_profile(pg_temp.input())$$,'42501',null,'Suspension denies profile saves');
select throws_ok($$insert into public.profile_drafts(user_id,content) values(auth.uid(),'{}')$$,'42501',null,'Suspension denies drafts');
select * from finish();
rollback;
