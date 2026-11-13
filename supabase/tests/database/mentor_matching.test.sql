-- Transactional synthetic fixtures only; never administrator provisioning.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
insert into public.institutions(id,name) values('80000000-0000-4000-8000-000000000001','[SYNTHETIC] Mentor Test Institute');
insert into public.departments(id,institution_id,name) values('81000000-0000-4000-8000-000000000001','80000000-0000-4000-8000-000000000001','[SYNTHETIC] Mentor Test Department');
insert into public.skills(id,name) values('82000000-0000-4000-8000-000000000001','[SYNTHETIC] Mentor Skill A'),('82000000-0000-4000-8000-000000000002','[SYNTHETIC] Mentor Skill B');
insert into auth.users(id,email,email_confirmed_at)
select ('83000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'mentor-fixture-'||n||'@example.invalid',case when n=11 then null else now() end from generate_series(1,12)n;
insert into public.profiles(user_id,display_name,claimed_kind,institution_id,department_id,joining_year,graduation_year,career_interests,directory_visible,professional_domain)
select id,'[SYNTHETIC] Mentor '||right(id::text,2),case when id::text in ('83000000-0000-4000-8000-000000000001','83000000-0000-4000-8000-000000000012') then 'student'::account_kind else 'alumni'::account_kind end,
'80000000-0000-4000-8000-000000000001','81000000-0000-4000-8000-000000000001',2020,2024,array['Research'],id::text<>'83000000-0000-4000-8000-000000000006',
case when id::text='83000000-0000-4000-8000-000000000003' then 'Aerospace' else '[SYNTHETIC] Embedded' end
from auth.users where id::text like '83000000-%';
insert into private.memberships(user_id,status,verified_kind)
select user_id,case when right(user_id::text,2)='07' then 'suspended'::membership_status when right(user_id::text,2)='10' then 'pending'::membership_status else 'verified'::membership_status end,
case when right(user_id::text,2) in ('07','10') then null else claimed_kind end from public.profiles where user_id::text like '83000000-%';
insert into public.mentorship_preferences(profile_id,available)
select user_id,right(user_id::text,2)<>'05' from public.profiles where user_id::text like '83000000-%';
insert into public.profile_skills(profile_id,skill_id)
select p.user_id,s.id from public.profiles p cross join public.skills s
where p.user_id::text like '83000000-%' and right(p.user_id::text,2)<>'04' and s.id::text like '82000000-%'
and not(right(p.user_id::text,2)='03' and right(s.id::text,2)='02');
insert into private.mentor_blocks values('83000000-0000-4000-8000-000000000009','83000000-0000-4000-8000-000000000001');
create function pg_temp.goal() returns jsonb language sql as $$select jsonb_build_object(
'career_interests',array['Research'],'target_domains',array['[SYNTHETIC] Embedded'],
'existing_skill_ids',array['82000000-0000-4000-8000-000000000001'],'learning_skill_ids',array['82000000-0000-4000-8000-000000000002'],'objectives',array['Private objective']);$$;
select ok((select relrowsecurity from pg_class where oid='public.mentor_goals'::regclass),'Goals RLS enabled');
select ok(not has_function_privilege('anon','public.recommend_mentors(text,boolean,text,numeric,uuid,integer)','execute'),'Anonymous recommendations denied');
select ok(not has_table_privilege('authenticated','private.mentor_blocks','select'),'Block identities private');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"83000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is(jsonb_array_length(public.my_mentor_goals()->'existing_skill_ids'),2,'Defaults reuse own profile skills');
select lives_ok($$select public.save_mentor_goals(pg_temp.goal())$$,'Verified student saves private goals');
select is(public.my_mentor_goals()->'objectives','["Private objective"]'::jsonb,'Private objectives persist');
select throws_ok($$select public.save_mentor_goals(pg_temp.goal()||'{"user_id":"83000000-0000-4000-8000-000000000002"}')$$,'23514',null,'Forged preference identity denied');
select throws_ok($$select public.save_mentor_goals(pg_temp.goal()||'{"learning_skill_ids":["ffffffff-ffff-4fff-8fff-ffffffffffff"]}')$$,'23514',null,'Unknown skill denied');
select throws_ok($$insert into public.mentor_goals(user_id) values(auth.uid())$$,'42501',null,'Direct preference writes denied');
select is((select count(*) from public.recommend_mentors(p_domain=>'[SYNTHETIC]')),3::bigint,'Only eligible visible opted-in confirmed unblocked alumni');
select is((select score from public.recommend_mentors(p_domain=>'[SYNTHETIC]') where user_id='83000000-0000-4000-8000-000000000002'),100,'Exact match scores 100 relevance points');
select is((select score from public.recommend_mentors() where user_id='83000000-0000-4000-8000-000000000003'),50,'Partial match uses weighted components');
select is((select score from public.recommend_mentors() where user_id='83000000-0000-4000-8000-000000000004'),85,'Missing skills omitted but evidence capped');
select is((select evidence_count from public.recommend_mentors() where user_id='83000000-0000-4000-8000-000000000004'),2,'Missing evidence disclosed');
select is((select cardinality(shared_skills) from public.recommend_mentors() where user_id='83000000-0000-4000-8000-000000000002'),2,'Explanation includes actual relevant skills');
select is((select matching_domains[1] from public.recommend_mentors() where user_id='83000000-0000-4000-8000-000000000002'),'[SYNTHETIC] Embedded','Domain explanation supported');
select is((select user_id from public.recommend_mentors(p_domain=>'[SYNTHETIC]',p_limit=>1)),'83000000-0000-4000-8000-000000000002'::uuid,'Equal-score tie resolved by UUID');
select is((select user_id from public.recommend_mentors(p_domain=>'[SYNTHETIC]',p_after_rank=>100,p_after_id=>'83000000-0000-4000-8000-000000000002',p_limit=>1)),'83000000-0000-4000-8000-000000000008'::uuid,'Keyset preserves tied rows');
select is((select count(*) from public.recommend_mentors(p_domain=>'Nonexistent domain')),0::bigint,'Domain filter does not invent results');
select throws_ok($$select * from public.recommend_mentors(p_sort=>'injection;select 1')$$,'23514',null,'Sort whitelist enforced');
select throws_ok($$select * from public.recommend_mentors(p_limit=>1000)$$,'23514',null,'Page bound enforced');
select throws_ok($$select * from public.recommend_mentors(p_after_rank=>100)$$,'23514',null,'Incomplete cursor rejected');
select lives_ok($$select public.set_mentor_block('83000000-0000-4000-8000-000000000002',true)$$,'Self-owned mentorship block saves');
select is((select count(*) from public.recommend_mentors() where user_id='83000000-0000-4000-8000-000000000002'),0::bigint,'Forward block excludes mentor');
select lives_ok($$select public.set_mentor_block('83000000-0000-4000-8000-000000000002',false)$$,'Own block can be undone');
select throws_ok($$select public.set_mentor_block(auth.uid(),true)$$,'23514',null,'Self block denied');
select throws_ok($$select public.set_mentor_block('83000000-0000-4000-8000-000000000006',true)$$,'42501',null,'Hidden target cannot be probed through block');
select lives_ok($$select public.request_connection('83000000-0000-4000-8000-000000000002')$$,'Existing connection API reused');
select is((select connection_status from public.recommend_mentors() where user_id='83000000-0000-4000-8000-000000000002'),'pending','Connection status projected safely');
select is((select count(*) from public.recommend_mentors(p_unconnected=>true) where user_id='83000000-0000-4000-8000-000000000002'),0::bigint,'New connections filter excludes pending relationship');
select lives_ok($$select public.save_mentor_goals('{"career_interests":[],"target_domains":[],"existing_skill_ids":[],"learning_skill_ids":[],"objectives":[]}')$$,'Explicit empty preferences allowed');
select is((select max(score) from public.recommend_mentors(p_domain=>'[SYNTHETIC]')),0,'Availability alone cannot generate high scores');
select lives_ok($$select public.save_mentor_goals('{"career_interests":[],"target_domains":["[SYNTHETIC] Embedded"],"existing_skill_ids":[],"learning_skill_ids":[],"objectives":[]}')$$,'Single signal preferences save');
select is((select score from public.recommend_mentors() where user_id='83000000-0000-4000-8000-000000000002'),65,'One personal signal capped at 65 points');
reset role;
update public.institutions set active=false where id='80000000-0000-4000-8000-000000000001';
set local role authenticated;
select is((select count(*) from public.recommend_mentors(p_domain=>'[SYNTHETIC]')),0::bigint,'Inactive institution mentors excluded');
reset role;
update public.institutions set active=true where id='80000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"83000000-0000-4000-8000-000000000010","role":"authenticated"}',true);
select throws_ok($$select * from public.recommend_mentors()$$,'42501',null,'Unverified requester denied');
select throws_ok($$select public.my_mentor_goals()$$,'42501',null,'Unverified private goals denied');
select is((select count(*) from public.mentor_goals),0::bigint,'Other-user preferences unreadable');
reset role;
update private.memberships set status='suspended',verified_kind=null where user_id='83000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"83000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok($$select * from public.recommend_mentors()$$,'42501',null,'Existing suspended identity denied');
select throws_ok($$select public.save_mentor_goals(pg_temp.goal())$$,'42501',null,'Suspended preference save denied');
select * from finish();
rollback;
