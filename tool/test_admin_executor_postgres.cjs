// Called ONLY from the network-none, freshly-created synthetic rehearsal cluster.
const fs=require('node:fs'),cp=require('node:child_process'),assert=require('node:assert/strict');
const {snapshotSQL,schema,preservation}=require('./admin_executor_state.cjs');
const {sha,canonical}=require('./admin_deployment_plan.cjs');
const backup=require('./admin_backup.cjs');
function run({sql,docker,name}){
 assert.match(name,/^msgi-admin-review-[a-f0-9-]{36}$/);
 // Both renamed databases belong to this NEW disposable container. Using its
 // postgres database lets the exact production identity guard run unchanged.
 sql('alter database postgres rename to review_parent;alter database executor_fixture rename to postgres;','template1');
 const db='postgres',results={scope:'synthetic isolated local only',passed:[],failures:[]};
 const check=(v,label)=>{if(!v)console.error('11F_CHECK_FAILED: '+label);assert(v,label);results.passed.push(label);console.log('PASS 11F: '+label);};
 const q=(text,target=db,allow=false,tags=false)=>sql(text,target,allow,tags);
 const snap=(target=db)=>JSON.parse(q(snapshotSQL(),target).stdout.trim());
 const plan=JSON.parse(fs.readFileSync('supabase/review/admin_executor_plan.json'));
 const batch=fs.readFileSync(plan.plan.batch_file);
 // Local synthetic role removal gives the exact reviewed zero-admin baseline.
 q('delete from private.account_roles;');
 const before=snap();
 check(sha(Buffer.from(canonical(schema(before.state.inventory))))===plan.plan.pre_schema_sha256,'Exact hosted baseline schema/ACL identity reproduced');
 function apply(input= batch,target=db,baseline=before.state_md5){return q(Buffer.from("\\set msgi_baseline_md5 "+baseline+'\n'+input.toString()),target,true,true);}
 const wrong=apply(batch,db,'0'.repeat(32));check(wrong.status!==0&&!/^COMMIT$/m.test(wrong.stdout)&&snap().state_md5===before.state_md5,'Changed baseline fails before DDL and rolls back');
 const mid=apply(Buffer.from(batch.toString().replace('\ninsert into supabase_migrations.schema_migrations','\nselect 1/0;\ninsert into supabase_migrations.schema_migrations')));
 check(mid.status!==0&&!/^COMMIT$/m.test(mid.stdout)&&snap().state_md5===before.state_md5,'Executor SQL failure rolls back schema/data/history');
 // Real concurrent session holds the fixed advisory key. No remote destination.
 const locker=cp.spawn('docker',['exec','-i',name,'psql','-h','/tmp','-X','-qAt','-U','postgres','-d',db],{windowsHide:true,stdio:['pipe','pipe','pipe']});
 locker.stdin.write('begin;select pg_advisory_xact_lock(749312050001::bigint);select pg_sleep(12);rollback;\n');locker.stdin.end();
 let locked=false;for(let n=0;n<30;n++){
  // bigint key is exposed as high/low parts; query exact reconstructed key instead.
  const c=q("select count(*) from pg_locks where locktype='advisory' and ((classid::bigint<<32)|objid::bigint)=749312050001 and granted;");
  if(Number(c.stdout.trim())>0){locked=true;break;}cp.spawnSync('powershell.exe',['-NoProfile','-Command','Start-Sleep -Milliseconds 100'],{windowsHide:true});
 }
 check(locked,'Independent PostgreSQL session acquired deployment advisory lock');
 const concurrent=apply();check(concurrent.status!==0&&!/^COMMIT$/m.test(concurrent.stdout),'Actual concurrent execution rejected without COMMIT');
 // Wait boundedly for this fixture's lock, never interfere with existing sessions.
 for(let n=0;n<70;n++){const c=q("select count(*) from pg_locks where locktype='advisory' and ((classid::bigint<<32)|objid::bigint)=749312050001 and granted;");if(Number(c.stdout.trim())===0)break;cp.spawnSync('powershell.exe',['-NoProfile','-Command','Start-Sleep -Milliseconds 200'],{windowsHide:true});}
 // Custom-format full logical dump of this synthetic database, not hosted data.
 const dumpResult=cp.spawnSync('docker',['exec',name,'pg_dump','-h','/tmp','-U','postgres','-d',db,'--format=custom','--serializable-deferrable'],{encoding:null,windowsHide:true,timeout:60000,maxBuffer:64*1024*1024});
 check(dumpResult.status===0&&dumpResult.stdout.subarray(0,5).toString()==='PGDMP','Read-only custom dump readable in memory');
 const dir='build/admin-encrypted-rehearsal-'+require('node:crypto').randomUUID();
 const receipt=backup.seal(dir,dumpResult.stdout,{scope:'synthetic-local-rehearsal',state_md5:before.state_md5});
 const cipher=fs.readFileSync(dir+'/database.dump.dpapi');
 const plain=backup.crypt(cipher,true);
 check(sha(plain)===receipt.manifest.dump.plain_sha256,'DPAPI encrypt/decrypt round-trip preserves exact custom dump');
 const tampered=Buffer.from(cipher);tampered[Math.floor(tampered.length/2)]^=1;let rejected=false;try{backup.crypt(tampered,true);}catch{rejected=true;}check(rejected,'Tampered encrypted dump rejected');
 docker(['exec',name,'createdb','-h','/tmp','-U','postgres','executor_recovery']);
 const restored=docker(['exec','-i',name,'pg_restore','-h','/tmp','-U','postgres','-d','executor_recovery','--exit-on-error','--single-transaction'],plain, true);
 plain.fill(0);dumpResult.stdout.fill(0);
 check(restored.status===0,'Fresh isolated database restores complete synthetic logical archive');
 const recovered=snap('executor_recovery');
 // Database identity is intentionally postgres in snapshot. Ignore the catalog's
 // current_database field when comparing the differently named recovery target.
 const original=structuredClone(before.state),copy=structuredClone(recovered.state);
 delete original.catalog.database;delete copy.catalog.database;
 delete original.inventory.database;delete copy.inventory.database;
 original.inventory.default_acls=schema(original.inventory).default_acls;
 copy.inventory.default_acls=schema(copy.inventory).default_acls;
 const grants=target=>JSON.parse(q("select jsonb_agg(jsonb_build_array(n.nspname,c.relname,r.rolname,p,has_table_privilege(r.oid,c.oid,p)) order by n.nspname,c.relname,r.rolname,p) from pg_class c join pg_namespace n on n.oid=c.relnamespace cross join pg_roles r cross join unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER','MAINTAIN'])p where c.relkind='r' and n.nspname in ('public','private');",target).stdout.trim());
 check(canonical(grants(db))===canonical(grants('executor_recovery')),'Every role/table effective privilege matches after restore');
 // pg_dump may elide an explicit owner-only ACL; NULL means the same default
 // owner rights. Accept only this known representation after the exhaustive
 // role/privilege matrix above, preserving owner and RLS checks separately.
 const ownerOnly=original.inventory.tables_security.find(t=>t.schema==='private'&&t.name==='mentor_blocks');
 const restoredOwner=copy.inventory.tables_security.find(t=>t.schema==='private'&&t.name==='mentor_blocks');
 if(canonical(ownerOnly.acl)===canonical(['postgres=arwdDxtm/postgres'])&&restoredOwner.acl===null)restoredOwner.acl=ownerOnly.acl;
 const oldCheck=original.inventory.constraints.find(c=>c.name==='city_centroid_bounds');
 const newCheck=copy.inventory.constraints.find(c=>c.name==='city_centroid_bounds');
 if(oldCheck.definition!==newCheck.definition){
  check(sha(Buffer.from(oldCheck.definition))==='98ed2fbfaad8184d08059361a4fdd544d78e9703b8450547e890c5c5c51345f3'&&sha(Buffer.from(newCheck.definition))==='d57300a0d54bbe921dc84724943aaa51aea853f90ea8867a5b5091c7b4008983','Only reviewed PostgreSQL AND-parenthesis normalization is accepted');
  const predicate=d=>d.replace(/^CHECK\s*/,'');
  const equivalent=q(`select bool_and((${predicate(oldCheck.definition)}) is not distinct from (${predicate(newCheck.definition)})) from unnest(array[-100::numeric,-85,-84,0,84,85,100,null]) as a(centroid_latitude) cross join unnest(array[-181::numeric,-180,-179,0,179,180,181,null]) as b(centroid_longitude);`);
  check(equivalent.stdout.trim()==='t','Restored city bounds retain reviewed boundary and NULL truth table');
  newCheck.definition=oldCheck.definition;
 }
 if(canonical(original)!==canonical(copy)){
  const fields=Object.keys(original.inventory).filter(k=>canonical(original.inventory[k])!==canonical(copy.inventory[k]));
  console.error('11F_RESTORE_DIFFERENT_FIELDS: '+fields.join(','));
  fs.writeFileSync('build/task11f-restore-diff.json',JSON.stringify(Object.fromEntries(fields.map(k=>[k,{original:original.inventory[k].filter(a=>!copy.inventory[k].some(b=>canonical(a)===canonical(b))),restored:copy.inventory[k].filter(a=>!original.inventory[k].some(b=>canonical(a)===canonical(b)))}])),null,2));
 }
 check(canonical(original)===canonical(copy),'Restored logical schema/functions/RLS/grants/data/auth/history match with disclosed representation normalization');
 check(recovered.state.inventory.tables.length===before.state.inventory.tables.length,'Recovery covers every application table');
 const readySHA=backup.attest(dir,receipt.manifest_sha256,{verified:true,state_md5:before.state_md5,dump_sha256:receipt.manifest.dump.plain_sha256,scope:'synthetic isolated full logical restore',application_tables:before.state.inventory.tables.length});
 let syntheticBlocked=false;try{backup.verify(dir,readySHA,before.state_md5);}catch{syntheticBlocked=true;}check(syntheticBlocked,'Synthetic backup cannot authorize hosted execution');
 results.backup={scope:'synthetic-local',encryption:'DPAPI-CurrentUser',cipher_integrity:true,restore_verified:true,application_tables:before.state.inventory.tables.length,functions:before.state.inventory.functions.length,auth_fingerprint_match:true,plaintext_files_created:0,hosted_backup_created:false};
 const applied=apply();check(applied.status===0&&/^COMMIT$/m.test(applied.stdout),'Guarded executor batch commits with explicit acknowledgement');
 const after=snap();preservation(before,after);check(true,'Executor preserves existing records and creates no administrator');
 check(sha(Buffer.from(canonical(schema(after.state.inventory))))===plan.plan.post_schema_sha256,'Exact postdeployment schema/privilege identity matches');
 const repeated=apply();check(repeated.status!==0&&snap().state_md5===after.state_md5,'Repeated execution stops without changes');
 // Lost acknowledgement classifications: actual committed state read independently.
 const {summarize}=require('./msec_session_diagnostics.cjs');
 const lost=summarize({status:2,stdout:applied.stdout.replace(/^COMMIT\r?\n/m,''),stderr:'connection lost'});
 check(!lost.commit_acknowledged&&snap().state.inventory.history.length===12,'Committed transaction with lost acknowledgement requires read-only investigation');
 results.batch_sha256=plan.plan.batch_sha256;results.execution_plan_sha256=plan.execution_plan_sha256;
 fs.writeFileSync('build/task11f-postgres-results.json',JSON.stringify(results,null,2)+'\n');
 // Keep the restored test destination explicit; no database rename/cleanup is
 // needed in this disposable cluster. Reinstate ONLY its synthetic reviewer
 // fixture for the parent harness's subsequent local workload measurements.
 q("insert into private.account_roles(user_id,role) values('e1000000-0000-4000-8000-000000000001','administrator');");
 console.log('TASK11F_POSTGRES_CHECKS='+results.passed.length);
}
module.exports={run};
