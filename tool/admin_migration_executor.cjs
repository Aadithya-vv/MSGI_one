// Default/--check is read-only. Never run --execute without a NEW owner approval.
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {sha,canonical}=require('./admin_deployment_plan.cjs');
const {snapshotSQL,verifySnapshot,preservation,requireThat}=require('./admin_executor_state.cjs');
const {transport}=require('./admin_executor_transport.cjs');
const backup=require('./admin_backup.cjs');
const REF='sbgshejyvkptmrffiwvd',MIGRATION_SHA='a93d179f6bea04eb4f4c8b6556ddf1aee46cc2949cbeda28eff64cbfa7d7f120';
function artifacts(approvedHash){
 const r=JSON.parse(fs.readFileSync('supabase/review/admin_executor_plan.json'));
 requireThat(r.execution_plan_sha256===approvedHash&&sha(Buffer.from(canonical(r.plan)))===approvedHash,'execution_plan_hash');
 const p=r.plan;requireThat(p.project_ref===REF&&p.migration==='20261115000100_institutional_operations.sql'&&p.migration_sha256===MIGRATION_SHA,'project_or_migration_identity');
 requireThat(sha(fs.readFileSync('supabase/migrations/'+p.migration))===MIGRATION_SHA,'migration_hash');
 for(const f of p.files)requireThat(sha(fs.readFileSync(f.file))===f.sha256,'implementation_hash');
 for(const f of p.dependencies)requireThat(sha(Buffer.from(fs.readFileSync('supabase/migrations/'+f.file,'utf8').replace(/\r\n/g,'\n')))===f.lf_sha256,'dependency_hash');
 const migrations=fs.readdirSync('supabase/migrations').filter(f=>f.endsWith('.sql')).sort();
 requireThat(canonical(migrations)===canonical([...p.dependencies.map(f=>f.file),p.migration].sort()),'pending_migrations');
 requireThat(fs.readFileSync('supabase/.temp/project-ref','utf8').trim()===REF,'linked_project_identity');
 const batch=fs.readFileSync(p.batch_file);requireThat(sha(batch)===p.batch_sha256,'batch_hash');
 return {plan:p,batch};
}
function durableWrite(file,value,exclusive=false){
 const fd=fs.openSync(file,exclusive?'wx':'r+');try{const b=Buffer.from(JSON.stringify(value));fs.writeSync(fd,b,0,b.length,0);fs.ftruncateSync(fd,b.length);fs.fsyncSync(fd);}finally{fs.closeSync(fd);}
}
function journal(){
 const dir=path.join(process.env.LOCALAPPDATA,'MSGIOne','admin-deployments',REF);
 if(!fs.existsSync(dir))backup.protectedDirectory(dir);
 const file=path.join(dir,'20261115000100.attempt.json');
 try{durableWrite(file,{state:'attempt_reserved',started_utc:new Date().toISOString(),automatic_retry:false},true);}catch{requireThat(false,'attempt_already_reserved_or_journal_unavailable');}
 return value=>durableWrite(file,value);
}
async function execute({project,planHash,approval,password},io){
 // io is a testable capability boundary. Production CLI below supplies fixed adapters.
 requireThat(project===REF,'project_identity');
 const {plan,batch}=io.artifacts(planHash);
 requireThat(plan.project_ref===REF,'project_identity');
 requireThat(typeof password==='string'&&password.length>0&&!/[\r\n\0]/.test(password),'credential_unavailable');
 const pre=verifySnapshot(await io.snapshot(plan,password),plan);
 requireThat(approval?.scope==='one-admin-migration-attempt'&&approval.project_ref===REF&&approval.execution_plan_sha256===planHash&&approval.migration_sha256===MIGRATION_SHA,'owner_approval');
 requireThat(approval.baseline_md5===pre.state_md5,'approved_baseline_changed');
 requireThat(Date.parse(approval.expires_utc)>Date.now()&&Date.parse(approval.expires_utc)<=Date.now()+4*3600*1000,'approval_expired_or_excessive');
 const b=await io.backup(approval,pre);requireThat(b?.verified===true,'backup_gate');
 const save=io.journal();let attempted=false,diagnostic;
 try{
  // Never retry or release this durable marker, even after rollback/unknown outcome.
  save({state:'write_starting',plan_sha256:planHash,baseline_md5:pre.state_md5,automatic_retry:false});attempted=true;
  diagnostic=await io.write({plan,password,input:batch,baseline:pre.state_md5});
  save({state:diagnostic.commit_acknowledged?'commit_acknowledged_verification_pending':'outcome_uncertain',diagnostic,automatic_retry:false});
  requireThat(diagnostic.exit_status===0&&diagnostic.commit_acknowledged===true,'write_failed_or_outcome_uncertain');
  const post=verifySnapshot(await io.snapshot(plan,password),plan,true);preservation(pre,post);
  save({state:'verified_committed',plan_sha256:planHash,automatic_retry:false});
  return {state:'verified_committed',history:12,catalog_records:51,administrator_roles:0};
 }catch(e){
  // The error category is fixed internally, never a raw transport/SQL exception.
  const allowed=['write_failed_or_outcome_uncertain','migration_history','administrator_baseline','catalog_identity','schema_or_privilege_drift','auth_data_changed','existing_data_changed','new_private_tables_not_empty','database_busy','tls_not_verified','invalid_snapshot','database_identity','catalog_rls'];
  const category=allowed.includes(e.category)?e.category:'execution_or_postflight_failure';
  try{save({state:diagnostic?.commit_acknowledged?'commit_acknowledged_unverified':attempted?'stopped_no_retry':'reserved_no_retry',category,diagnostic,automatic_retry:false});}catch{}
  requireThat(false,category);
 }
}
function snapshot(plan,password){return transport({plan,password,input:Buffer.from(snapshotSQL()),readOnly:true});}
async function main(args){
 const allowed=args.every(a=>a==='--check'||a==='--execute'||/^--(project-ref|approve-plan-sha256|approval-file)=/.test(a));requireThat(allowed,'unexpected_arguments');
 const opt=k=>args.find(a=>a.startsWith('--'+k+'='))?.slice(k.length+3);
 requireThat(new Set(args.map(a=>a.split('=')[0])).size===args.length,'duplicate_arguments');
 requireThat(!(args.includes('--execute')&&args.includes('--check')),'conflicting_modes');
 const project=opt('project-ref');requireThat(project===REF,'project_identity');
 const planHash=opt('approve-plan-sha256');const {plan}=artifacts(planHash);
 const password=process.env.SUPABASE_DB_PASSWORD;delete process.env.SUPABASE_DB_PASSWORD;
 requireThat(typeof password==='string'&&password.length>0,'credential_unavailable');
 if(!args.includes('--execute')){
  const s=verifySnapshot(snapshot(plan,password),plan);
  return {mode:'read-only',project_ref:REF,tls_verified:true,authenticated:true,history:11,catalog_records:51,administrator_roles:0,baseline_md5:s.state_md5};
 }
 const approval=JSON.parse(fs.readFileSync(opt('approval-file'),'utf8'));
 return execute({project,planHash,approval,password},{artifacts,snapshot,backup:(a,s)=>backup.verify(a.backup_directory,a.backup_manifest_sha256,s.state_md5),journal,write:transport});
}
module.exports={artifacts,execute,main,journal,durableWrite,snapshot,REF,MIGRATION_SHA};
if(require.main===module)main(process.argv.slice(2)).then(r=>console.log(JSON.stringify(r))).catch(e=>{console.error(JSON.stringify({state:'stopped',category:e.category||'local_artifact_or_io_failure',automatic_retry:false}));process.exitCode=1;});
