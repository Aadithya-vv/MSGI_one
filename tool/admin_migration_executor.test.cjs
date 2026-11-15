const test=require('node:test'),assert=require('node:assert/strict'),fs=require('node:fs');
const {execute,REF,MIGRATION_SHA,durableWrite}=require('./admin_migration_executor.cjs');
const {schema,verifySnapshot}=require('./admin_executor_state.cjs');
const {sha,canonical}=require('./admin_deployment_plan.cjs');
const {transport}=require('./admin_executor_transport.cjs');
const {summarize}=require('./msec_session_diagnostics.cjs');
function fixture(){
 const i={history:['00000000000001'],roles:{count:0,without_profile:0,inactive_or_missing_institution:0},tables:[],auth_users_count:0};
 for(const k of ['functions','tables_security','policies','indexes','triggers','constraints','history_columns'])i[k]=[];
 const s={state_md5:'a'.repeat(32),read_only:'on',database:'postgres',role:'postgres',ssl:true,tls_version:'TLSv1.3',active_ddl:0,waiting_locks:0,state:{inventory:i,auth_fingerprint:'safe',catalog:{rls_tables:4}}};
 ['institutions','departments','programmes','skills'].forEach((t,n)=>{s.state.catalog[t+'_count']=[1,1,13,36][n];s.state.catalog[t+'_conflict']=false;});
 const plan={project_ref:REF,dependencies:[{file:'00000000000001_x.sql'}],pre_schema_sha256:sha(Buffer.from(canonical(schema(i)))),post_schema_sha256:sha(Buffer.from(canonical(schema(i))))};
 const post=structuredClone(s);post.state.inventory.history.push('20261115000100');post.state.inventory.tables=[{schema:'private',table:'administration_audit',rows:0},{schema:'private',table:'membership_requests',rows:0}];
 const approval={scope:'one-admin-migration-attempt',project_ref:REF,execution_plan_sha256:'approved',migration_sha256:MIGRATION_SHA,baseline_md5:s.state_md5,expires_utc:new Date(Date.now()+60000).toISOString()};
 const input={project:REF,planHash:'approved',approval,password:'SYNTHETIC_IN_MEMORY_ONLY'};
 let reads=0,writes=0,reserved=false;const receipts=[];
 const io={artifacts:()=>({plan,batch:Buffer.from('reviewed bytes')}),snapshot:async()=>structuredClone(reads++?post:s),backup:async()=>({verified:true}),journal:()=>{if(reserved)throw Error('reserved');reserved=true;return r=>receipts.push(r);},write:async()=>{writes++;return {exit_status:0,commit_acknowledged:true};}};
 return {s,post,plan,input,io,receipts,writes:()=>writes};
}
test('Success uses one write and independent pre/post snapshots',async()=>{const f=fixture();assert.equal((await execute(f.input,f.io)).state,'verified_committed');assert.equal(f.writes(),1);});
for(const [name,mutate] of [
 ['wrong project',f=>f.input.project='wrong'],['missing credentials',f=>f.input.password=''],
 ['wrong migration hash',f=>f.input.approval.migration_sha256='0'.repeat(64)],['wrong plan approval',f=>f.input.approval.execution_plan_sha256='changed'],
 ['absent approval',f=>f.input.approval=null],['expired approval',f=>f.input.approval.expires_utc='2000-01-01'],
 ['missing or invalid backup',f=>f.io.backup=async()=>({verified:false})],
 ['changed history',f=>f.s.state.inventory.history.push('unexpected')],
 ['changed catalogs',f=>f.s.state.catalog.skills_count=35],
 ['conflicting catalog identities',f=>f.s.state.catalog.skills_conflict=true],
 ['unexpected admin',f=>f.s.state.inventory.roles.count=1],['changed ACLs',f=>f.s.state.inventory.functions.push({acl:'unexpected'})],
 ['TLS not verified',f=>f.s.ssl=false],['unexpected database role',f=>f.s.role='unknown'],
 ['concurrent DDL',f=>f.s.active_ddl=1],['baseline approval changed',f=>f.input.approval.baseline_md5='b'.repeat(32)],
 ['file hash mismatch',f=>f.io.artifacts=()=>{throw Error('hash mismatch');}],
])test(name+' fails before any write',async()=>{const f=fixture();mutate(f);await assert.rejects(()=>execute(f.input,f.io));assert.equal(f.writes(),0);});
for(const [name,result] of [['SQL failure',{exit_status:3,commit_acknowledged:false}],['lost acknowledgement before COMMIT',{exit_status:null,commit_acknowledged:false}],['connection lost after COMMIT',{exit_status:2,commit_acknowledged:true}]])test(name+' stops without retry',async()=>{const f=fixture();let calls=0;f.io.write=async()=>{calls++;return result;};await assert.rejects(()=>execute(f.input,f.io));assert.equal(calls,1);assert.equal(f.receipts.at(-1).state,result.commit_acknowledged?'commit_acknowledged_unverified':'stopped_no_retry');});
test('Postflight discrepancy stops after one write',async()=>{const f=fixture();f.post.state.auth_fingerprint='changed';await assert.rejects(()=>execute(f.input,f.io),/auth_data_changed/);assert.equal(f.writes(),1);});
test('Concurrent/repeated attempt cannot write twice',async()=>{const f=fixture();await execute(f.input,f.io);f.io.snapshot=async()=>f.s;await assert.rejects(()=>execute(f.input,f.io));assert.equal(f.writes(),1);});
test('Durable exclusive journal rejects second reservation',()=>{const p='build/admin-journal-test-'+require('node:crypto').randomUUID()+'.json';try{durableWrite(p,{state:'reserved'},true);assert.throws(()=>durableWrite(p,{state:'again'},true));}finally{fs.unlinkSync(p);}});
test('Transport pins CA, IPv6-capable host network, image and secret-free arguments',()=>{
 const plan=JSON.parse(fs.readFileSync('supabase/review/admin_execution_plan.json')).plan;
 let calls=0;const r=transport({plan,password:'SYNTHETIC_SECRET_NEVER_LOGGED',input:Buffer.from('BEGIN;COMMIT;'),baseline:'a'.repeat(32),env:{},spawn:(cmd,args,o)=>{
  if(args[0]==='stop')return {status:0};calls++;assert(!JSON.stringify(args).includes('SYNTHETIC_SECRET'));assert(args.includes('host'));assert(args.includes('none'));assert(args.includes(plan.transport.image));assert.equal(o.env.PGSSLMODE,'verify-full');assert.equal(o.env.PGSSLROOTCERT,'/run/msgi-ca.crt');assert.equal(o.input.toString(),'BEGIN;COMMIT;');return {status:0,stdout:'BEGIN\nCOMMIT\n'};
 }});assert.equal(calls,1);assert.equal(r.commit_acknowledged,true);
});
for(const [name,text] of [['invalid certificate','SSL error: certificate verify failed'],['hostname mismatch','server certificate does not match host name'],['invalid password','password authentication failed'],['timeout','connection timed out']])test(name+' is sanitized and never retried',()=>{assert.doesNotMatch(JSON.stringify(summarize({status:2,stderr:text+' PRIVATE_VALUE'})),/PRIVATE_VALUE/);});
test('Transport rejects host/routing overrides before spawn',()=>{
 const plan=structuredClone(JSON.parse(fs.readFileSync('supabase/review/admin_execution_plan.json')).plan);
 assert.throws(()=>transport({plan,password:'synthetic',input:Buffer.alloc(0),baseline:'a'.repeat(32),env:{PGHOST:'evil'},spawn:()=>assert.fail()}),/routing/);
 plan.transport.host='evil.invalid';assert.throws(()=>transport({plan,password:'synthetic',env:{},spawn:()=>assert.fail()}),/hostname/);
});
