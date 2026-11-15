// LOCAL artifact generation only. No process execution, network or deployment.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const ROOT=path.resolve(__dirname,'..'),FILE='20261115000100_institutional_operations.sql';
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const canonical=v=>JSON.stringify(sort(v));
function sort(v){return Array.isArray(v)?v.map(sort):v&&typeof v==='object'?Object.fromEntries(Object.keys(v).sort().map(k=>[k,sort(v[k])])):v;}
function splitSql(sql){
 let start=0,quote=null,dollar=null,line=false,block=0;const result=[];
 for(let i=0;i<sql.length;i++){
  const c=sql[i],n=sql[i+1];if(line){if(c==='\n')line=false;continue;}
  if(block){if(c==='/'&&n==='*'){block++;i++;}else if(c==='*'&&n==='/'){block--;i++;}continue;}
  if(dollar){if(sql.startsWith(dollar,i)){i+=dollar.length-1;dollar=null;}continue;}
  if(quote){if(c===quote){if(n===quote)i++;else quote=null;}continue;}
  if(c==='-'&&n==='-'){line=true;i++;continue;}if(c==='/'&&n==='*'){block++;i++;continue;}
  if(c==="'"||c==='"'){quote=c;continue;}if(c==='$'){const d=sql.slice(i).match(/^\$(?:[a-zA-Z_][a-zA-Z_0-9]*)?\$/);if(d){dollar=d[0];i+=dollar.length-1;continue;}}
  if(c===';'){const text=sql.slice(start,i+1);result.push({start,end:i+1,text});start=i+1;}
 }
 if(quote||dollar||block||sql.slice(start).replace(/--[^\n]*/g,'').trim())throw Error('Incomplete SQL or unsupported trailing content');
 return result;
}
function head(s){return s.replace(/^(?:\s|--[^\n]*(?:\n|$)|\/\*[\s\S]*?\*\/)+/g,'').trim();}
function render(source){
 const sql=source.toString('utf8').replace(/\r\n/g,'\n');if(!Buffer.from(source.toString('utf8')).equals(source))throw Error('SQL must be UTF-8');
 const statements=splitSql(sql);if(head(statements[0].text).toLowerCase()!=='begin;'||head(statements.at(-1).text).toLowerCase()!=='commit;')throw Error('Expected migration-owned BEGIN/COMMIT');
 if(statements.slice(1,-1).some(x=>/^(begin|commit|rollback|savepoint)\b/i.test(head(x.text))))throw Error('Unexpected nested transaction boundary');
 const last=statements.at(-1),first=statements[0];
 const controls="\nset local lock_timeout='5s';\nset local statement_timeout='60s';\nset local standard_conforming_strings=on;\n";
 const delimiter='$msgi_reviewed_migration_source$';if(sql.includes(delimiter))throw Error('History delimiter collision');
 const history="\ninsert into supabase_migrations.schema_migrations(version,name,statements) values('20261115000100','institutional_operations',array["+delimiter+sql+delimiter+"]);\n";
 const batch=Buffer.from(sql.slice(0,first.end)+controls+sql.slice(first.end,last.start)+history+sql.slice(last.start),'utf8');
 return {batch,statements,source_lf_sha256:sha(Buffer.from(sql))};
}
function generate(){
 const runtime=JSON.parse(fs.readFileSync(path.join(ROOT,'supabase/review/admin_runtime_identity.json'),'utf8'));
 if(!/^public\.ecr\.aws\/supabase\/postgres@sha256:[0-9a-f]{64}$/.test(runtime.image_reference)||!/^sha256:[0-9a-f]{64}$/.test(runtime.image_id))throw Error('Unexpected reviewed runtime identity');
 const source=fs.readFileSync(path.join(ROOT,'supabase/migrations',FILE)),r=render(source);
 const historical=fs.readdirSync(path.join(ROOT,'supabase/migrations')).filter(f=>f.endsWith('.sql')&&f!==FILE).sort();
 if(historical.length!==11)throw Error('Expected exactly eleven dependencies');
 const inventory=r.statements.map((s,i)=>({ordinal:i+1,head:head(s.text).split('\n')[0],lf_statement_sha256:sha(Buffer.from(s.text))}));
 const plan={format:1,project_ref:'sbgshejyvkptmrffiwvd',migration:FILE,migration_raw_sha256:sha(source),migration_lf_sha256:r.source_lf_sha256,
  batch_file:'supabase/review/admin_execution_batch.sql',batch_sha256:sha(r.batch),
  generator_lf_sha256:sha(Buffer.from(fs.readFileSync(__filename,'utf8').replace(/\r\n/g,'\n'))),
  dependencies:historical.map(file=>({file,lf_sha256:sha(Buffer.from(fs.readFileSync(path.join(ROOT,'supabase/migrations',file),'utf8').replace(/\r\n/g,'\n')))})),
  preflight_sql_file:'tool/sql/admin_hosted_inventory.sql',preflight_sql_lf_sha256:sha(Buffer.from(fs.readFileSync(path.join(ROOT,'tool/sql/admin_hosted_inventory.sql'),'utf8').replace(/\r\n/g,'\n'))),
  expected_schema:{tables:20,functions:48,indexes:54,policies:23,triggers:6,constraints:114,new_private_tables_empty:true,new_rpc_service_role_execute:false},
  transport:{host:'db.sbgshejyvkptmrffiwvd.supabase.co',port:5432,database:'postgres',role:'postgres',network:'host',image:runtime.image_reference,image_id:runtime.image_id,pull:'never',read_only_root:true,cap_drop:['ALL'],no_new_privileges:true,user:'postgres',log_driver:'none',client_identity:'new unique UUID, removed on exit; no retry',stdin:'exact verified batch Buffer; no shell newline rewriting',ca_mount:{target:'/run/msgi-ca.crt',read_only:true},environment:{PGSSLMODE:'verify-full',PGSSLROOTCERT:'/run/msgi-ca.crt',PGCONNECT_TIMEOUT:'8',PGPASSWORD:'private child handoff only; no value in manifest'},reject_routing_overrides:['PGHOST','PGHOSTADDR','PGPORT','PGDATABASE','PGUSER','PGOPTIONS','PGSERVICE','PGSERVICEFILE','PGPASSFILE','DATABASE_URL'],sslmode:'verify-full',ca_file:'tool/certs/supabase-prod-ca-2021.crt',ca_sha256:'700723581420dd1ac98fd7e9ac529f0ef210eadcaf87fc868a3ad7d114c2f3b7',hostname_verification:true,tls_fallback:false,connect_timeout_seconds:8,client_timeout_seconds:120,psql_flags:['-X','--no-password','-v','ON_ERROR_STOP=1','-f','-'],credential:'temporary masked owner handoff; child PGPASSWORD environment only; never argv/files'},
  atomicity:{transactions:1,history_insert:'before the single COMMIT, with original LF source stored as data',lock_timeout:'5s',statement_timeout:'60s per statement',source_byte_identity:'batch is a disclosed LF derivative with added transaction-local controls/history insert; not the migration file unchanged'},
  preflight:['fresh exact authenticated project/host/region and verified TLS','eleven exact applied dependencies; only this migration pending','exact 51 catalog tuples and safe data/security baseline','zero orphan/invalid role bindings; owner-approved scope interpretation','current verified backup and reviewed recovery; independent DPAPI/full-service limits accepted','no concurrent DDL/deployment; production window and lock review','migration/batch/plan/dependency/CA hashes match; fresh execution-code review','explicit owner authorization for this batch and one history row; no roles/seeds/Auth changes'],
  postflight:['explicit PostgreSQL COMMIT command tag and successful client exit; neither alone is sufficient','independent read-only verification of version twelve, expected schema/RLS/ACLs and 51 catalog tuples','all original table columns/fingerprints preserved; role institution backfill only from reviewed profiles','private new tables empty; no new users or administrator roles'],
  incident:{automatic_retry:false,on_failure:'stop; inspect connection/COMMIT/history/schema/fingerprints read-only; no repair/retry/restore without new approval',down_migration:'none approved',forward_fix:'separate reviewed payload/backup/approval; never erase audit or reset database'},
  limitations:['local generator has no hosted execution capability','future dedicated migration executor and private handoff must be independently reviewed; do not reuse catalog runner approval','current backup predates hosted schema/catalog updates; fresh backup required before execution'],inventory};
 const dir=path.join(ROOT,'supabase/review');fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(ROOT,plan.batch_file),r.batch);
 const record={canonicalization:'recursive lexicographic object keys; arrays in order; compact JSON UTF-8 without BOM/newline; digest excludes this envelope',execution_plan_sha256:sha(Buffer.from(canonical(plan))),plan};
 fs.writeFileSync(path.join(dir,'admin_execution_plan.json'),JSON.stringify(record,null,2)+'\n');return record;
}
module.exports={sha,canonical,splitSql,render,generate,head};
if(require.main===module){if(process.argv.length!==2)throw Error('Generator accepts no deployment arguments');const r=generate();console.log(JSON.stringify({migration_sha256:r.plan.migration_raw_sha256,batch_sha256:r.plan.batch_sha256,execution_plan_sha256:r.execution_plan_sha256,statements:r.plan.inventory.length}));}
