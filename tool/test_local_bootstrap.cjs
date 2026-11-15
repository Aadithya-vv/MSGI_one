// Tests the actual owner operation in a rollback-only isolated transaction.
const fs=require('fs'),cp=require('child_process');
const container=process.env.MSGI_BOOTSTRAP_TEST_CONTAINER||'supabase_db_msgi_one_clean_9a7b7923';
if(process.env.MSGI_BOOTSTRAP_TEST_CONTAINER){
 if(!/^msgi-admin-clean-[a-f0-9-]{36}$/.test(container))throw Error('Unexpected disposable bootstrap target');
 const target=JSON.parse(cp.execFileSync('docker',['inspect',container],{encoding:'utf8',stdio:['pipe','pipe','pipe']}))[0];
 if(target.HostConfig.NetworkMode!=='none'||target.Mounts.some(m=>m.Type!=='tmpfs'))throw Error('Bootstrap target is not isolated');
}
const operation=fs.readFileSync('supabase/operations/bootstrap_initial_admin.sql','utf8').replace(/^\uFEFF/,'');
const test=(expression)=>'select '+expression+';\n';
// Restore the harness path before pgTAP's own unqualified helper calls execute.
const invoke='$bootstrap_test$'+operation+'\nset local search_path=public,extensions;\n$bootstrap_test$';
let sql=`begin; create extension if not exists pgtap with schema extensions; set local search_path=public,extensions; select no_plan();
select set_config('msgi.bootstrap_user','66000000-0000-4000-8000-000000000001',true);
select set_config('msgi.bootstrap_kind','student',true);
select set_config('msgi.bootstrap_approver','Synthetic independent verifier',true);
select set_config('msgi.bootstrap_reason','Synthetic local bootstrap acceptance',true);
`;
sql+=test(`throws_ok(${invoke},'P0001',null,'Approval guard denies unapproved bootstrap')`);
sql+=`select set_config('msgi.bootstrap_approved','yes',true);`;
sql+=test(`throws_ok(${invoke},'P0001',null,'Unknown user denied')`);
sql+=`insert into auth.users(id,email) values('66000000-0000-4000-8000-000000000001','bootstrap-fixture@example.invalid');`;
sql+=test(`throws_ok(${invoke},'P0001',null,'Unconfirmed user denied')`);
sql+=`update auth.users set email_confirmed_at=now() where id='66000000-0000-4000-8000-000000000001';`;
sql+=test(`throws_ok(${invoke},'P0001',null,'Missing onboarding denied')`);
sql+=`insert into public.institutions(id,name) values('67000000-0000-4000-8000-000000000001','Synthetic bootstrap institute');
insert into public.departments(id,institution_id,name) values('67000000-0000-4000-8000-000000000002','67000000-0000-4000-8000-000000000001','Synthetic bootstrap department');
insert into public.skills(id,name) values('67000000-0000-4000-8000-000000000003','Synthetic bootstrap skill');
insert into public.profiles(user_id,display_name,claimed_kind,institution_id,department_id,joining_year,graduation_year,career_interests) values('66000000-0000-4000-8000-000000000001','Synthetic bootstrap candidate','student','67000000-0000-4000-8000-000000000001','67000000-0000-4000-8000-000000000002',2020,2024,array['Research']);
insert into private.memberships(user_id) values('66000000-0000-4000-8000-000000000001');
insert into public.profile_skills(profile_id,skill_id) values('66000000-0000-4000-8000-000000000001','67000000-0000-4000-8000-000000000003');
select set_config('msgi.bootstrap_kind','alumni',true);`;
sql+=test(`throws_ok(${invoke},'P0001',null,'Approved kind must match reviewed profile')`);
sql+=`select set_config('msgi.bootstrap_kind','student',true);set local role authenticated;`;
sql+=test(`throws_ok(${invoke},'42501',null,'Ordinary client cannot execute owner provisioning')`);
sql+=`reset role;`;
sql+=test(`lives_ok(${invoke},'Owner-approved complete candidate provisioned')`);
sql+=`set local search_path=public,extensions;`;
sql+=test(`is((select status::text from private.memberships where user_id='66000000-0000-4000-8000-000000000001'),'verified','Membership explicitly verified')`);
sql+=test(`is((select role from private.account_roles where user_id='66000000-0000-4000-8000-000000000001'),'administrator','Private administrator role assigned')`);
sql+=test(`is((select count(*) from private.verification_audit where subject_id='66000000-0000-4000-8000-000000000001' and reason like '%Synthetic independent verifier%'),1::bigint,'Independent authorizer recorded in audit')`);
sql+=test(`lives_ok(${invoke},'Exact approved rerun is idempotent')`);
sql+=`set local search_path=public,extensions;`;
sql+=test(`is((select count(*) from private.verification_audit where subject_id='66000000-0000-4000-8000-000000000001'),1::bigint,'No duplicate bootstrap audit')`);
sql+=`select * from finish();rollback;`;
try{
 const result=cp.execFileSync('docker',['exec','-i',container,'psql',...(process.env.MSGI_BOOTSTRAP_TEST_CONTAINER?['-h','/tmp']:[]),'-X','-qAt','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],{input:sql,encoding:'utf8',stdio:['pipe','pipe','pipe']});
 const lines=result.split(/\r?\n/).filter(x=>/^(?:not )?ok\b|^1\.\.|^#/.test(x));console.log(lines.join('\n'));
 if(lines.some(x=>/^not ok/.test(x))||!lines.some(x=>/^1\.\./.test(x)))process.exitCode=1;
}catch(error){
 const message=String(error.stderr||'').split(/\r?\n/).find(l=>l.startsWith('ERROR:'));
 if(message)console.error(message.slice(0,240));
 console.error('Isolated bootstrap test failed; no credentials or raw responses displayed');process.exitCode=1;
}
