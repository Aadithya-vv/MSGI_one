-- Transactional isolated synthetic security and lifecycle fixtures.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
insert into public.institutions(id,name) values('90000000-0000-4000-8000-000000000001','[SYNTHETIC] Career Institute A'),('90000000-0000-4000-8000-000000000002','[SYNTHETIC] Career Institute B');
insert into public.departments(id,institution_id,name) values
('91000000-0000-4000-8000-000000000001','90000000-0000-4000-8000-000000000001','Career Department A'),
('91000000-0000-4000-8000-000000000002','90000000-0000-4000-8000-000000000002','Career Department B'),
('91000000-0000-4000-8000-000000000003','90000000-0000-4000-8000-000000000001','Career Department C');
insert into public.skills(id,name) values('92000000-0000-4000-8000-000000000001','[SYNTHETIC] Career skill');
insert into auth.users(id,email,email_confirmed_at) select ('93000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'career-fixture-'||n||'@example.invalid',now() from generate_series(1,6)n;
insert into public.profiles(user_id,display_name,claimed_kind,institution_id,department_id,joining_year,graduation_year,career_interests,directory_visible)
select id,'[SYNTHETIC] Career Author',case when right(id::text,2) in ('02','06') then 'student'::account_kind else 'alumni'::account_kind end,
case when right(id::text,2)='03' then '90000000-0000-4000-8000-000000000002'::uuid else '90000000-0000-4000-8000-000000000001'::uuid end,
case when right(id::text,2)='03' then '91000000-0000-4000-8000-000000000002'::uuid when right(id::text,2)='06' then '91000000-0000-4000-8000-000000000003'::uuid else '91000000-0000-4000-8000-000000000001'::uuid end,
2020,2024,array['Engineering'],true from auth.users where id::text like '93000000-%';
insert into private.memberships(user_id,status,verified_kind)
select user_id,case when right(user_id::text,2)='04' then 'pending'::membership_status when right(user_id::text,2)='05' then 'suspended'::membership_status else 'verified'::membership_status end,
case when right(user_id::text,2) in ('04','05') then null else claimed_kind end from public.profiles where user_id::text like '93000000-%';
insert into public.profile_skills values('93000000-0000-4000-8000-000000000002','92000000-0000-4000-8000-000000000001');
create function pg_temp.post() returns jsonb language sql as $$select jsonb_build_object('title','Synthetic Career Position','description','Explicitly synthetic opportunity for security testing.',
'kind','job','location_text','Synthetic city','external_url','https://example.com/apply','status','published','professional_domain','CareerFixtureDomain','organization','Synthetic organization',
'remote',true,'referral',true,'audience','community','skill_ids',array['92000000-0000-4000-8000-000000000001']);$$;
select ok(not has_function_privilege('anon','public.career_opportunities(jsonb,jsonb,integer,uuid)','execute'),'Anonymous discovery denied');
select ok((select relrowsecurity from pg_class where oid='public.opportunity_skills'::regclass),'Required skills RLS enabled');
select ok(private.safe_career_url('https://example.com/apply?role=engineer'),'Public HTTPS accepted');
select ok(not private.safe_career_url('javascript:alert(1)'),'Script URL denied');
select ok(not private.safe_career_url('https://user:secret@example.com/job'),'URL credentials denied');
select ok(not private.safe_career_url('https://127.0.0.1/job'),'Private numeric host denied');
select ok(not private.safe_career_url('https://example.com:8080/job'),'Explicit port denied');
select ok(not private.safe_career_url('https://machine.local/job'),'Local DNS denied');
select ok(not private.safe_career_url('https://example.com/%0d%0aevil'),'Encoded CRLF denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is(public.career_can_publish(),true,'Verified alumnus can publish');
select is(public.save_career_opportunity('94000000-0000-4000-8000-000000000001',pg_temp.post()),'94000000-0000-4000-8000-000000000001'::uuid,'Author creates post');
select is(public.save_career_opportunity('94000000-0000-4000-8000-000000000001',pg_temp.post()),'94000000-0000-4000-8000-000000000001'::uuid,'Duplicate submission idempotent');
select is((select count(*) from public.opportunities where id='94000000-0000-4000-8000-000000000001'),1::bigint,'Only one retry row');
select throws_ok($$select public.save_career_opportunity('94000000-0000-4000-8000-000000000002',pg_temp.post()||'{"author_id":"93000000-0000-4000-8000-000000000003"}')$$,'23514',null,'Forged author field denied');
select throws_ok($$select public.save_career_opportunity('94000000-0000-4000-8000-000000000002',pg_temp.post()||'{"external_url":"https://user:secret@example.com"}')$$,'23514',null,'Unsafe application link denied by RPC');
select throws_ok($$select public.save_career_opportunity('94000000-0000-4000-8000-000000000002',pg_temp.post()||'{"audience":"department","institution_id":"90000000-0000-4000-8000-000000000002"}')$$,'23514',null,'Forged institutional scope denied');
select throws_ok($$select public.save_career_opportunity('94000000-0000-4000-8000-000000000002',pg_temp.post()||'{"skill_ids":["ffffffff-ffff-4fff-8fff-ffffffffffff"]}')$$,'23514',null,'Unknown catalog skill denied');
select lives_ok($$select public.save_career_opportunity('94000000-0000-4000-8000-000000000002',pg_temp.post()||'{"status":"draft"}')$$,'Private draft saves');
select lives_ok($$select public.save_career_opportunity('94000000-0000-4000-8000-000000000003',pg_temp.post()||'{"audience":"department"}')$$,'Department audience derives from author');
select lives_ok($$select public.save_career_opportunity('94000000-0000-4000-8000-000000000001',pg_temp.post()||'{"title":"Updated synthetic post"}',(select updated_at from public.opportunities where id='94000000-0000-4000-8000-000000000001'))$$,'Author edits own version');
select throws_ok($$select public.save_career_opportunity('94000000-0000-4000-8000-000000000001',pg_temp.post(),'2000-01-01')$$,'40001',null,'Stale edits do not overwrite');
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is(public.career_can_publish(),false,'Verified student cannot publish under existing model');
select throws_ok($$select public.save_career_opportunity('94000000-0000-4000-8000-000000000004',pg_temp.post())$$,'42501',null,'Student publishing denied server-side');
select is((select count(*) from public.career_opportunities('{"domain":"CareerFixtureDomain"}')),2::bigint,'Student sees published authorized rows only');
select is((select (r->>'shared_count')::int from public.career_opportunities('{"domain":"CareerFixtureDomain","sort":"relevance"}',null,1) r),1,'Skill overlap computed server-side');
select is((select count(*) from public.career_opportunities('{"kind":"internship","domain":"CareerFixtureDomain"}')),0::bigint,'Type filter');
select is((select count(*) from public.career_opportunities('{"location":"Nonexistent","domain":"CareerFixtureDomain"}')),0::bigint,'Location filter');
select is((select count(*) from public.career_opportunities('{"remote":true,"domain":"CareerFixtureDomain"}')),2::bigint,'Remote filter');
select is((select count(*) from public.career_opportunities('{"skill":"92000000-0000-4000-8000-000000000001","domain":"CareerFixtureDomain"}')),2::bigint,'Catalog skill filter');
select is((select count(*) from public.career_opportunities('{"domain":"CareerFixtureDomain","scope":"department"}')),1::bigint,'Audience filter');
select throws_ok($$select * from public.career_opportunities('{}',null,1000)$$,'23514',null,'Unbounded pagination denied');
select is((select count(*) from public.career_opportunities('{"domain":"CareerFixtureDomain"}',(select jsonb_build_object('rank',r->'rank','created_at',r->'created_at','id',r->'id') from public.career_opportunities('{"domain":"CareerFixtureDomain"}',null,1) r))),1::bigint,'Cursor returns remaining tied row');
select lives_ok($$select public.report_career_opportunity('94000000-0000-4000-8000-000000000001','other','Synthetic moderation report details.')$$,'Visible post can be reported');
select is((select count(*) from public.reports where target_opportunity_id='94000000-0000-4000-8000-000000000001'),1::bigint,'Own report readable');
select lives_ok($$select public.report_career_opportunity('94000000-0000-4000-8000-000000000001','other','Duplicate synthetic report details.')$$,'Repeated open report idempotent');
select is((select count(*) from public.reports where target_opportunity_id='94000000-0000-4000-8000-000000000001'),1::bigint,'No duplicate open report');
select throws_ok($$select public.report_career_opportunity('94000000-0000-4000-8000-000000000002','other','Hidden draft must not be reportable.')$$,'42501',null,'Hidden draft report denied');
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select throws_ok($$select public.save_career_opportunity('94000000-0000-4000-8000-000000000001',pg_temp.post())$$,'42501',null,'Foreign author cannot edit');
select throws_ok($$select public.transition_career_opportunity('94000000-0000-4000-8000-000000000001','archive')$$,'42501',null,'Foreign author cannot archive');
select is((select count(*) from public.career_opportunities('{"domain":"CareerFixtureDomain"}')),1::bigint,'Cross-institution department post hidden');
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000006","role":"authenticated"}',true);
select is((select count(*) from public.career_opportunities('{"domain":"CareerFixtureDomain"}')),1::bigint,'Other department cannot see scoped post');
reset role;
update public.profiles set directory_visible=false where user_id='93000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is((select r->>'author_name' from public.career_opportunities('{}',null,1,'94000000-0000-4000-8000-000000000001') r),null::text,'Private author name not exposed');
select is((select (r->>'author_available')::boolean from public.career_opportunities('{}',null,1,'94000000-0000-4000-8000-000000000001') r),false,'Private author profile link unavailable');
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.transition_career_opportunity('94000000-0000-4000-8000-000000000001','close')$$,'Author closes own post');
select lives_ok($$select public.transition_career_opportunity('94000000-0000-4000-8000-000000000001','archive')$$,'Archive preserves reported post');
select lives_ok($$select public.transition_career_opportunity('94000000-0000-4000-8000-000000000001','archive')$$,'Repeated archive safe');
select is((select count(*) from public.career_opportunities('{"mine":true,"status":"all"}',null,21,'94000000-0000-4000-8000-000000000001')),1::bigint,'Author can inspect archive');
select throws_ok($$select public.save_career_opportunity('94000000-0000-4000-8000-000000000001',pg_temp.post())$$,'23514',null,'Archived post is read-only');
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000004","role":"authenticated"}',true);
select throws_ok($$select * from public.career_opportunities()$$,'42501',null,'Pending requester denied');
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000005","role":"authenticated"}',true);
select throws_ok($$select public.save_career_opportunity('94000000-0000-4000-8000-000000000004',pg_temp.post())$$,'42501',null,'Suspended publisher denied');
reset role;
update private.memberships set status='suspended',verified_kind=null where user_id='93000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"93000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is((select count(*) from public.career_opportunities('{"domain":"CareerFixtureDomain"}')),0::bigint,'Suspension removes author published rows');
select * from finish();
rollback;
