const test=require('node:test'),assert=require('node:assert/strict');
const {validateManifest}=require('./admin_backup.cjs');
function fixture(){return {format:1,project_ref:'sbgshejyvkptmrffiwvd',encryption:'DPAPI-CurrentUser',scope:'hosted-predeployment',state_md5:'a'.repeat(32),created_utc:new Date().toISOString(),dump:{file:'database.dump.dpapi',plain_sha256:'b'.repeat(64)},recovery:{verified:true,state_md5:'a'.repeat(32),dump_sha256:'b'.repeat(64)}};}
test('Synthetic metadata fixture satisfies the complete manifest gate',()=>assert.doesNotThrow(()=>validateManifest(fixture(),'a'.repeat(32))));
for(const [name,mutate] of [
 ['wrong project',m=>m.project_ref='wrong'],['wrong encryption',m=>m.encryption='none'],['synthetic scope',m=>m.scope='synthetic-local-rehearsal'],
 ['stale backup',m=>m.created_utc='2000-01-01'],['future timestamp',m=>m.created_utc=new Date(Date.now()+3600000).toISOString()],
 ['changed baseline',m=>m.state_md5='changed'],['missing recovery',m=>m.recovery=null],['unverified restore',m=>m.recovery.verified=false],
 ['different restored dump',m=>m.recovery.dump_sha256='changed'],['different restored state',m=>m.recovery.state_md5='changed'],['path traversal',m=>m.dump.file='../secret'],
])test(name+' rejected',()=>{const m=fixture();mutate(m);assert.throws(()=>validateManifest(m,'a'.repeat(32)));});
