const fs=require('fs'),cp=require('child_process');
const {render}=require('./prepare_hosted_catalogs.cjs');
const manifest={project_ref:'sbgshejyvkptmrffiwvd',review_status:'APPROVED',institutional_source:'Synthetic local test fixture only',institutional_approver:'Synthetic local verifier',city_source:'Synthetic local fixture',city_approver:'Synthetic local verifier',institutions:["[SYNTHETIC LOCAL] O'Brien $$ Catalog Institute"],departments:[{institution:"[SYNTHETIC LOCAL] O'Brien $$ Catalog Institute",name:'[SYNTHETIC LOCAL] Catalog Department'}],skills:['[SYNTHETIC LOCAL] Catalog Skill'],cities:[{name:'[SYNTHETIC LOCAL] Catalog City',country_code:'IN'}]};
const body=render(manifest).replace(/^begin;\s*$/m,'').replace(/^commit;\s*$/m,'');
const invoke='$catalog_test$'+body+'$catalog_test$';
let sql=`begin;create extension if not exists pgtap with schema extensions;set local search_path=public,extensions;select no_plan();
select throws_ok(${invoke},'P0001',null,'Unapproved catalog execution denied');
select set_config('msgi.catalog_approved','yes',true);
select lives_ok(${invoke},'Reviewed synthetic import succeeds');
select lives_ok(${invoke},'Identical import is repeatable');
select is((select count(*) from public.institutions where name like '[SYNTHETIC LOCAL] O% Catalog Institute'),1::bigint,'No duplicate institution');
select is((select count(*) from public.departments where name='[SYNTHETIC LOCAL] Catalog Department'),1::bigint,'No duplicate department');
select is((select count(*) from public.skills where name='[SYNTHETIC LOCAL] Catalog Skill'),1::bigint,'No duplicate skill');
select is((select count(*) from public.cities where name='[SYNTHETIC LOCAL] Catalog City'),1::bigint,'No duplicate city');
update public.institutions set active=false where name like '[SYNTHETIC LOCAL] O% Catalog Institute';
select throws_ok(${invoke},'P0001',null,'Inactive institution requires separate review');
select is((select active from public.institutions where name like '[SYNTHETIC LOCAL] O% Catalog Institute'),false,'Importer never silently reactivates records');
select * from finish();rollback;`;
try{const output=cp.execFileSync('docker',['exec','-i','supabase_db_msgi_one_clean_9a7b7923','psql','-X','-qAt','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1'],{input:sql,encoding:'utf8',stdio:['pipe','pipe','pipe']});const lines=output.split(/\r?\n/).filter(x=>/^(?:not )?ok\b|^1\.\.|^#/.test(x));console.log(lines.join('\n'));if(lines.some(x=>/^not ok/.test(x)))process.exitCode=1;}catch{console.error('Local transactional catalog test failed; raw response suppressed');process.exitCode=1;}
