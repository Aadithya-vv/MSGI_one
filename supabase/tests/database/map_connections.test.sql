-- Task 05 synthetic fixtures; all changes roll back.
begin;
create extension if not exists pgtap with schema extensions;
set local search_path=public,extensions;
select no_plan();
insert into public.institutions(id,name) values('71000000-0000-4000-8000-000000000001','Map security fixture institute');
insert into public.departments(id,institution_id,name) values('71000000-0000-4000-8000-000000000002','71000000-0000-4000-8000-000000000001','Map security fixture department');
insert into public.cities(id,name,country_code,centroid_latitude,centroid_longitude) values
 ('72000000-0000-4000-8000-000000000001','MapPrivacyFixture Alpha','IN',20.12345,75.12345),
 ('72000000-0000-4000-8000-000000000002','MapPrivacyFixture Beta','GB',51.5,-0.1);
insert into auth.users(id,email,email_confirmed_at) select ('73000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'map-network-fixture-'||n||'@example.invalid',case when n=8 then null else now() end from generate_series(1,10)n;
insert into public.profiles(user_id,display_name,claimed_kind,institution_id,department_id,joining_year,graduation_year,career_interests,directory_visible,map_opt_in,city_id,professional_domain)
select id,'Map fixture '||right(id::text,2),'alumni','71000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000002',2020,2024,array['Research'],right(id::text,2)<>'05',right(id::text,2) not in ('05','06'),
 case when right(id::text,2)='10' then '72000000-0000-4000-8000-000000000002' else '72000000-0000-4000-8000-000000000001' end::uuid,
 case when right(id::text,2)='10' then 'Research' else 'Engineering' end
from auth.users where id::text like '73000000%';
insert into private.memberships(user_id,status,verified_kind) select user_id,
 case right(user_id::text,2) when '03' then 'pending' when '04' then 'suspended' else 'verified' end::public.membership_status,
 case when right(user_id::text,2) in ('03','04') then null when right(user_id::text,2)='07' then 'student' else 'alumni' end::public.account_kind
from public.profiles where user_id::text like '73000000%';
select is((select centroid_latitude::text from public.cities where id='72000000-0000-4000-8000-000000000001'),'20.1','Only coarsened city coordinates stored');
select ok(not has_function_privilege('anon','public.alumni_city_clusters(text,text,uuid,integer)','execute'),'Anonymous map denied');
select ok(not has_function_privilege('anon','public.request_connection(uuid)','execute'),'Anonymous connection denied');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"73000000-0000-4000-8000-000000000003","role":"authenticated"}',true);
select throws_ok($$select * from public.alumni_city_clusters()$$,'42501',null,'Pending map denied');
select throws_ok($$select * from public.map_city_members('72000000-0000-4000-8000-000000000001')$$,'42501',null,'Pending city detail denied');
select throws_ok($$select public.request_connection('73000000-0000-4000-8000-000000000002')$$,'42501',null,'Pending requester denied');
select set_config('request.jwt.claims','{"sub":"73000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select is((select alumni_count from public.alumni_city_clusters('MapPrivacyFixture') where city_id='72000000-0000-4000-8000-000000000001'),3::bigint,'Aggregate excludes hidden, map-off, pending, suspended, student and unconfirmed');
select is((select count(*) from public.map_city_members('72000000-0000-4000-8000-000000000001')),3::bigint,'City members match aggregate eligibility');
select is((select count(*) from public.alumni_city_clusters('MapPrivacyFixture','Research')),1::bigint,'Domain filter consistent');
select is((select count(*) from public.alumni_city_clusters('MapPrivacyFixture Beta')),1::bigint,'Location filter');
select is((select count(*) from public.map_city_members('72000000-0000-4000-8000-000000000001','Research')),0::bigint,'City detail does not widen domain filter');
select is((select count(*) from public.alumni_city_clusters('MapPrivacyFixture','',null,1)),1::bigint,'City pagination bounded');
select is((select count(*) from public.alumni_city_clusters('MapPrivacyFixture','','72000000-0000-4000-8000-000000000001')),1::bigint,'City keyset advances');
select is((select count(*) from public.map_city_members('72000000-0000-4000-8000-000000000001','','73000000-0000-4000-8000-000000000002')),1::bigint,'City member pagination advances');
select throws_ok($$select * from public.alumni_city_clusters(p_limit=>1000)$$,'23514',null,'Unbounded map query denied');
select throws_ok($$select public.request_connection(auth.uid())$$,'23514',null,'Self connection denied');
select throws_ok($$select public.request_connection('73000000-0000-4000-8000-000000000004')$$,'42501',null,'Suspended target denied');
select throws_ok($$select public.request_connection('73000000-0000-4000-8000-000000000005')$$,'42501',null,'Hidden target denied');
select set_config('test.connection_id',public.request_connection('73000000-0000-4000-8000-000000000002')::text,true);
select is(public.request_connection('73000000-0000-4000-8000-000000000002')::text,current_setting('test.connection_id'),'Duplicate request is idempotent');
select is((select count(*) from public.network_connections('outgoing')),1::bigint,'Outgoing request visible');
select throws_ok($$select public.manage_connection(current_setting('test.connection_id')::uuid,'accepted')$$,'42501',null,'Sender cannot accept');
select throws_ok($$insert into public.connections(sender_id,recipient_id) values('73000000-0000-4000-8000-000000000002',auth.uid())$$,'42501',null,'Forged identities denied');
select set_config('request.jwt.claims','{"sub":"73000000-0000-4000-8000-000000000010","role":"authenticated"}',true);
select is((select count(*) from public.network_connections('all')),0::bigint,'Unrelated user sees no private relationships');
select throws_ok($$select public.manage_connection(current_setting('test.connection_id')::uuid,'accepted')$$,'42501',null,'Unrelated transition denied');
select set_config('request.jwt.claims','{"sub":"73000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select is(public.request_connection('73000000-0000-4000-8000-000000000001')::text,current_setting('test.connection_id'),'Opposite duplicate preserves same relationship');
select is((select count(*) from public.network_connections('incoming')),1::bigint,'Incoming request visible');
select lives_ok($$select public.manage_connection(current_setting('test.connection_id')::uuid,'accepted')$$,'Recipient accepts');
select lives_ok($$select public.manage_connection(current_setting('test.connection_id')::uuid,'accepted')$$,'Accept repeat idempotent');
select is((select count(*) from public.network_connections('accepted')),1::bigint,'Accepted connection visible');
select lives_ok($$select public.manage_connection(current_setting('test.connection_id')::uuid,'removed')$$,'Either participant removes accepted connection');
select lives_ok($$select public.manage_connection(current_setting('test.connection_id')::uuid,'removed')$$,'Removal repeat idempotent');
select is((select count(*) from public.network_connections('accepted')),0::bigint,'Removed connection no longer accepted');
select set_config('request.jwt.claims','{"sub":"73000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select lives_ok($$select public.request_connection('73000000-0000-4000-8000-000000000002')$$,'Explicit reconnect after removal');
select lives_ok($$select public.manage_connection(current_setting('test.connection_id')::uuid,'cancelled')$$,'Sender cancels outgoing request');
select lives_ok($$select public.manage_connection(current_setting('test.connection_id')::uuid,'cancelled')$$,'Cancel repeat idempotent');
select public.request_connection('73000000-0000-4000-8000-000000000002');
select set_config('request.jwt.claims','{"sub":"73000000-0000-4000-8000-000000000002","role":"authenticated"}',true);
select lives_ok($$select public.manage_connection(current_setting('test.connection_id')::uuid,'rejected')$$,'Recipient declines');
select set_config('request.jwt.claims','{"sub":"73000000-0000-4000-8000-000000000001","role":"authenticated"}',true);
select throws_ok($$select public.request_connection('73000000-0000-4000-8000-000000000002')$$,'23514',null,'Declined requests cannot be spammed open');
select throws_ok($$select * from public.network_connections(p_limit=>1000)$$,'23514',null,'Network pagination bounded');
select is((select count(*) from public.network_connections('all',current_setting('test.connection_id')::uuid,21,'73000000-0000-4000-8000-000000000002')),0::bigint,'Network keyset does not repeat cursor');
reset role;
update public.profiles set directory_visible=false,map_opt_in=false where user_id='73000000-0000-4000-8000-000000000002';
set local role authenticated;
select is((select display_name from public.network_connections('all',p_peer=>'73000000-0000-4000-8000-000000000002')),null::text,'Hidden peer name not newly exposed');
select is((select alumni_count from public.alumni_city_clusters('MapPrivacyFixture') where city_id='72000000-0000-4000-8000-000000000001'),2::bigint,'Consent withdrawal immediately changes aggregate');
reset role;
update private.memberships set status='suspended',verified_kind=null where user_id='73000000-0000-4000-8000-000000000001';
set local role authenticated;
select throws_ok($$select * from public.alumni_city_clusters()$$,'42501',null,'Existing identity loses map after suspension');
select throws_ok($$select * from public.network_connections()$$,'42501',null,'Existing identity loses network after suspension');
select * from finish();
rollback;
