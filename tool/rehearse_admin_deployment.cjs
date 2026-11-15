// Hosted writes are impossible: every mutation targets a fresh network-none,
// tmpfs-only container. Only LOCAL Auth schema (no records) is read as a fixture.
const fs=require('node:fs'),cp=require('node:child_process'),crypto=require('node:crypto'),assert=require('node:assert/strict');
const {generate,sha,canonical}=require('./admin_deployment_plan.cjs');
const name='msgi-admin-review-'+crypto.randomUUID(),runtime=JSON.parse(fs.readFileSync('supabase/review/admin_runtime_identity.json','utf8')),image=runtime.image_reference;
const M='a1100000-0000-4000-8000-000000000001',P='a1110000-0000-4000-8000-000000000001',actor='e1000000-0000-4000-8000-000000000001';
const result={passed:[],performance:{},failures:[]};let started=false,stage='initialization';
const check=(v,label)=>{stage=label;assert(v,label);result.passed.push(label);console.log('PASS: '+label);};
function docker(args,input,allow=false){const r=cp.spawnSync('docker',args,{input,encoding:'utf8',windowsHide:true,timeout:120000,maxBuffer:16*1024*1024});if(r.status!==0&&!allow)throw Error('Local command failed at '+stage);return r;}
const sql=(text,db='postgres',allow=false,tags=false)=>docker(['exec','-i',name,'psql','-h','/tmp','-X',tags?'-At':'-qAt','-U','postgres','-d',db,'-v','ON_ERROR_STOP=1','-v','VERBOSITY=sqlstate'],text,allow);
const json=(text,db='postgres')=>{const value=sql(text,db).stdout.trim();return value==='t'?true:value==='f'?false:JSON.parse(value);};
const quote=s=>"'"+s.replaceAll("'","''")+"'";
function tables(db='postgres',columns){
 const list=columns||json("select json_agg(json_build_object('schema',n.nspname,'table',c.relname,'columns',(select string_agg(quote_ident(a.attname),',' order by a.attnum) from pg_attribute a where a.attrelid=c.oid and a.attnum>0 and not a.attisdropped)) order by n.nspname,c.relname) from pg_class c join pg_namespace n on n.oid=c.relnamespace where c.relkind='r' and n.nspname in ('public','private','auth','supabase_migrations');",db);
 return list.map(t=>({...t,...json(`select json_build_object('rows',count(*),'digest',md5(coalesce(string_agg(md5(row_to_json(v)::text),'' order by md5(row_to_json(v)::text)),''))) from (select ${t.columns} from "${t.schema}"."${t.table}")v;`,db)}));
}
function metadata(db='postgres'){
 let q=fs.readFileSync('tool/sql/admin_hosted_inventory.sql','utf8');return json('begin read only;'+q.replace(/\) as inventory;\s*$/,' )::text;')+'rollback;',db);
}
function state(db='postgres'){return {tables:tables(db),metadata:metadata(db)};}
function same(a,b){return canonical(a)===canonical(b);}
function history(db='postgres'){return json('select coalesce(json_agg(version order by version),\'[]\') from supabase_migrations.schema_migrations;',db);}
function planTime(query,asDefiner=false){const r=sql('begin;set local role '+(asDefiner?'postgres':'authenticated')+";select set_config('request.jwt.claim.sub',"+quote(actor)+",true);explain(analyze,buffers,format json) "+query+';rollback;').stdout;const v=JSON.parse(r.slice(r.indexOf('[')));const nodes=[];function visit(p){nodes.push(p['Node Type']);for(const child of p.Plans||[])visit(child);}visit(v[0].Plan);return {execution_ms:v[0]['Execution Time'],planning_ms:v[0]['Planning Time'],node_types:nodes,shared_hit_blocks:v[0].Plan['Shared Hit Blocks']};}
try{
 const record=generate(),batch=fs.readFileSync(record.plan.batch_file);
 check(sha(batch)===record.plan.batch_sha256,'Generated batch matches its independent SHA-256');
 const auth=docker(['exec','supabase_db_msgi_one_clean_9a7b7923','pg_dump','-U','postgres','-d','postgres','--schema-only','--schema=auth','--no-owner','--no-privileges']).stdout;
 docker(['run','--rm','--pull','never','-d','--name',name,'--network','none','--read-only','--no-healthcheck','--user','postgres','--tmpfs','/case:rw,nosuid,size=1024m,uid=100,gid=101,mode=0700','--tmpfs','/tmp:rw,nosuid,size=64m,uid=100,gid=101,mode=0700','--entrypoint','/bin/sh',image,'-c','initdb -D /case -A trust --no-locale --encoding=UTF8 >/tmp/init.log 2>&1 && exec postgres -D /case -c listen_addresses= -c unix_socket_directories=/tmp']);started=true;
 for(let i=0;i<40;i++){if(docker(['exec',name,'pg_isready','-h','/tmp','-U','postgres'],undefined,true).status===0)break;if(i===39)throw Error('Database readiness');cp.spawnSync('powershell.exe',['-NoProfile','-Command','Start-Sleep -Milliseconds 200'],{windowsHide:true});}
 const target=JSON.parse(docker(['inspect',name]).stdout)[0];check(target.HostConfig.NetworkMode==='none'&&target.Mounts.every(m=>m.Type==='tmpfs'),'New rehearsal target has no network, shared volumes or published ports');
 check(target.Image===runtime.image_id,'Rehearsal uses the exact reviewed immutable runtime image');
 sql('create role anon;create role authenticated;create role service_role;create role supabase_admin;create role supabase_auth_admin;create role supabase_storage_admin;create role authenticator;create role dashboard_user;create schema extensions;'+auth+'\ngrant usage on schema auth,extensions to anon,authenticated,service_role;alter default privileges for role postgres in schema public grant execute on functions to anon,authenticated,service_role;alter default privileges for role postgres in schema public grant all on tables to anon,authenticated,service_role;alter default privileges for role postgres in schema public grant all on sequences to anon,authenticated,service_role;create schema supabase_migrations;create table supabase_migrations.schema_migrations(version text primary key,name text,statements text[]);');
 for(const d of record.plan.dependencies){const source=fs.readFileSync('supabase/migrations/'+d.file,'utf8');sql(source);sql('insert into supabase_migrations.schema_migrations(version,name) values('+quote(d.file.slice(0,14))+','+quote(d.file.slice(15,-4))+');');}
 const refs=fs.readFileSync('supabase/catalogs/msec_reference_atomic.sql');check(sha(refs)==='153f97a2eaff6fa02a723a65bcf4c135ab91bc63b2acb8dc151c93966833e428','Approved reference fixture bytes unchanged');sql("set msgi.catalog_payload_approved='msec-reference-v1';\n"+refs.toString());
 sql(`insert into auth.users(id,email,email_confirmed_at) select ('e1000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'rehearsal-'||n||'@example.test',now() from generate_series(1,8)n;
 insert into public.profiles(user_id,display_name,claimed_kind,institution_id,programme_id,joining_year,graduation_year,degree,career_interests) select id,'[SYNTHETIC REHEARSAL] Alumni','alumni','${M}','${P}',2020,2024,'Synthetic test claim',array['Engineering'] from auth.users;
 insert into private.memberships(user_id,status,verified_kind) select user_id,case right(user_id::text,1) when '3' then 'pending' when '4' then 'rejected' when '5' then 'suspended' when '6' then 'pending' else 'verified' end::public.membership_status,case when right(user_id::text,1) not in ('3','4','5','6') then 'alumni'::public.account_kind end from public.profiles;
 insert into private.account_roles(user_id,role) values('${actor}','administrator');
 insert into private.verification_audit(subject_id,actor_id,previous_status,new_status,verified_kind,reason) values('e1000000-0000-4000-8000-000000000003','${actor}',null,'pending',null,'Synthetic pre-migration audit');
 insert into public.connections(sender_id,recipient_id) values('${actor}','e1000000-0000-4000-8000-000000000002');
 insert into public.opportunities(id,author_id,title,description,kind) values('e2000000-0000-4000-8000-000000000001','e1000000-0000-4000-8000-000000000002','[SYNTHETIC] Rehearsal opportunity','Synthetic data preservation opportunity only','job');
 insert into public.reports(reporter_id,target_opportunity_id,reason,details) values('${actor}','e2000000-0000-4000-8000-000000000001','other','Synthetic pre-migration report contents only');`);
 const before=state();result.baseline={tables:before.tables.length,functions:before.metadata.functions.length,role_count:before.metadata.roles.count};
 const hosted=JSON.parse(fs.readFileSync('build/task11e-hosted-inventory.json','utf8'));
 result.baseline.local_server_version=before.metadata.version;result.baseline.hosted_server_version=hosted.version;
 result.baseline_schema_differences={functions:same(before.metadata.functions,hosted.functions),tables_security:same(before.metadata.tables_security,hosted.tables_security),policies:same(before.metadata.policies,hosted.policies),indexes:same(before.metadata.indexes,hosted.indexes),constraints:same(before.metadata.constraints,hosted.constraints),triggers:same(before.metadata.triggers,hosted.triggers)};
 result.baseline_metadata_mismatches={};
 for(const key of ['functions','policies','indexes','constraints','triggers']){if(!result.baseline_schema_differences[key]){result.baseline_metadata_mismatches[key]=before.metadata[key].filter(x=>!hosted[key].some(y=>same(x,y))).map(x=>({name:x.name||x.policyname||x.indexname,table:x.table||x.tablename,fields:Object.keys(x).filter(k=>!hosted[key].some(y=>(y.name||y.policyname||y.indexname)===(x.name||x.policyname||x.indexname)&&same(y[k],x[k])))}));}}
 check(Object.values(result.baseline_schema_differences).every(Boolean),'Reconstructed eleven-migration application metadata matches hosted baseline');
 // Every failure case is a separate copy of this NEW synthetic database.
 for(const type of ['orphan','midflight']){
  docker(['exec',name,'createdb','-h','/tmp','-U','postgres','-T','postgres',type]);
  if(type==='orphan')sql("insert into auth.users(id,email) values('e9000000-0000-4000-8000-000000000001','orphan@example.test');insert into private.account_roles(user_id,role) values('e9000000-0000-4000-8000-000000000001','administrator');",type);
  const snap=state(type),input=type==='midflight'?Buffer.from(batch.toString().replace('\ninsert into supabase_migrations.schema_migrations','\nselect 1/0;\ninsert into supabase_migrations.schema_migrations')):batch;
  const r=sql(input,type,true,true);const code=r.stderr.match(/ERROR:\s*([A-Z0-9]{5})/)?.[1];result.failure_cases={...result.failure_cases,[type]:{exit:r.status,sqlstate:code,commit_acknowledged:/^COMMIT$/m.test(r.stdout)}};check(r.status!==0&&!/^COMMIT$/m.test(r.stdout)&&code===(type==='orphan'?'23502':'22012'),type+' failure has no COMMIT acknowledgement');check(same(snap,state(type)),type+' failure rolls back schema, data, grants and history completely');
 }
 const execution=sql(batch,'postgres',false,true);check(/^COMMIT$/m.test(execution.stdout)&&execution.status===0,'Migration and history insert commit together with explicit COMMIT acknowledgement');
 const after=metadata(),original=before.tables.filter(t=>t.schema!=='supabase_migrations');check(same(original,tables('postgres',original)),'All pre-existing non-history table columns/counts/fingerprints preserved');
 check(history().length===12,'Exactly one reviewed history record added');
 check(json("select count(*) from private.account_roles r join public.profiles p on p.user_id=r.user_id and p.institution_id=r.institution_id;")===before.metadata.roles.count,'Role identities preserved with exact reviewed institution backfill');
 check(json('select (select count(*) from private.administration_audit)+(select count(*) from private.membership_requests);')===0,'New internal tables empty; migration creates no administrator or request');
 const changed=before.metadata.functions.filter(f=>!after.functions.some(a=>a.name===f.name&&a.arguments===f.arguments&&a.body_hash===f.body_hash)).map(f=>f.name).sort();result.changed_functions=changed;
 const expected=['private.is_admin','private.member_verified','public.moderate_report','public.pending_memberships','public.pending_memberships_v2','public.report_career_opportunity','public.review_membership','public.verification_history'].sort();check(same(changed,expected),'Only eight reviewed existing function bodies change');
 const changedPolicies=before.metadata.policies.filter(p=>!after.policies.some(a=>same(a,p)));check(changedPolicies.length===1&&changedPolicies[0].policyname==='reporter_read','Only reviewed report SELECT policy changes');
 check(before.metadata.functions.every(f=>after.functions.some(a=>a.name===f.name&&a.arguments===f.arguments&&same(a.acl,f.acl))),'All pre-existing function grants preserved');
 check(after.tables_security.every(t=>t.rls),'All twenty application tables retain RLS');
 check(json("select count(*)=8 and bool_and(not has_function_privilege('service_role',p.oid,'EXECUTE') and not has_function_privilege('anon',p.oid,'EXECUTE') and has_function_privilege('authenticated',p.oid,'EXECUTE')) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('administration_context','administration_members','decide_institutional_membership','request_membership_review','own_review_status','administration_history','administration_reports','decide_institutional_report');"),'Every new RPC explicitly denies inherited service-role and anonymous execution');
 const repeatBefore=state(),repeat=sql(batch,'postgres',true,true);check(repeat.status!==0&&!/^COMMIT$/m.test(repeat.stdout)&&same(repeatBefore,state()),'Repeated application fails closed with no partial changes or duplicate history');
 result.post_schema={tables:after.tables.length,functions:after.functions.length,indexes:after.indexes.length,policies:after.policies.length,triggers:after.triggers.length,constraints:after.constraints.length};
 for(const file of fs.readdirSync('supabase/tests/database').filter(f=>f.endsWith('.sql')).sort()){const out=sql(fs.readFileSync('supabase/tests/database/'+file)).stdout;check(!/^not ok/m.test(out),'pgTAP '+file);result.pgtap_passed=(result.pgtap_passed||0)+out.split(/\r?\n/).filter(l=>/^ok \d+/.test(l)).length;}
 // Workload is explicitly synthetic, after preservation comparisons.
 stage='representative queue fixture';
 sql(`insert into auth.users(id,email,email_confirmed_at) select ('e3000000-0000-4000-8000-'||lpad(n::text,12,'0'))::uuid,'queue-'||n||'@example.test',now() from generate_series(1,5000)n;
 insert into public.profiles(user_id,display_name,claimed_kind,institution_id,programme_id,joining_year,graduation_year,career_interests) select id,'[SYNTHETIC QUEUE] Member','alumni','${M}','${P}',2020,2024,array['Engineering'] from auth.users where id::text like 'e3000000-%';
 insert into private.memberships(user_id) select user_id from public.profiles where user_id::text like 'e3000000-%';analyze public.profiles;analyze private.memberships;`);
 stage='performance query plans';
 result.performance={queue_rows:5000,first_page:planTime("select public.administration_members('pending',null,0,30)"),deep_page:planTime("select public.administration_members('pending',null,4500,30)"),overview:planTime('select public.administration_context()'),filtered_scan:planTime("select p.user_id from public.profiles p join private.memberships m on m.user_id=p.user_id where m.status='pending' and p.claimed_kind='alumni' and private.admin_scope(p.user_id) order by p.created_at,p.user_id limit 30",true)};
 check(true,'Representative local 5,000-row queue measured without hosted stress');
 result.batch_sha256=record.plan.batch_sha256;result.execution_plan_sha256=record.execution_plan_sha256;result.finished_utc=new Date().toISOString();
 fs.writeFileSync('build/task11e-rehearsal.json',JSON.stringify(result,null,2));console.log(JSON.stringify({checks:result.passed.length,pgtap:result.pgtap_passed,performance:result.performance,post_schema:result.post_schema}));
}catch(error){result.failures.push(stage);fs.writeFileSync('build/task11e-rehearsal.json',JSON.stringify(result,null,2));console.error('ADMIN_REHEARSAL_FAILED at '+stage+'; no hosted connection; raw rows suppressed');process.exitCode=1;}
finally{if(started)docker(['stop','--timeout','5',name],undefined,true);}
