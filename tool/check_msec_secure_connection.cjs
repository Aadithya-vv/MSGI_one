// Dedicated read-only acceptance. Never imports/calls executeDedicated.
const cp = require('node:child_process');
const crypto = require('node:crypto');
const { run } = require('./deploy_msec_reference.cjs');
const { HOST, pinnedCa } = require('./msec_tls_policy.cjs');
const { summarize } = require('./msec_session_diagnostics.cjs');
const IMAGE = 'public.ecr.aws/supabase/postgres:17.11.0.019';
const SQL = `begin read only;
select jsonb_build_object('read_only',current_setting('transaction_read_only'),
 'database',current_database(),'role',current_user,
 'ssl',(select ssl from pg_stat_ssl where pid=pg_backend_pid()),
 'tls_version',(select version from pg_stat_ssl where pid=pg_backend_pid()),
 'history',(select jsonb_agg(version order by version) from supabase_migrations.schema_migrations),
 'institutions',(select count(*) from public.institutions),
 'departments',(select count(*) from public.departments),
 'programmes',(select count(*) from public.programmes),
 'skills',(select count(*) from public.skills));
commit;`;
function directReadOnly({ password = '', spawn = cp.spawnSync } = {}) {
  const ca = pinnedCa();
  if (typeof password !== 'string' || /[\r\n\0]/.test(password)) throw Error('Invalid credential input; value suppressed');
  const client = 'msgi-readonly-client-' + crypto.randomUUID();
  let r;
  try {
    r = spawn('docker',['run','--name',client,'--rm','--pull','never','-i','--network','host','--read-only',
      '--cap-drop','ALL','--security-opt','no-new-privileges','--user','postgres',
      '--mount',`type=bind,source=${ca.path},target=/run/msgi-ca.crt,readonly`,
      '--env','PGPASSWORD','--env','PGSSLMODE','--env','PGSSLROOTCERT','--env','PGCONNECT_TIMEOUT',
      '--entrypoint','psql',IMAGE,'-X','-qAt','--no-password','--host',HOST,'--port','5432',
      '--username','postgres','--dbname','postgres','-v','ON_ERROR_STOP=1','-f','-'],{
        input:Buffer.from(SQL),encoding:'utf8',windowsHide:true,timeout:20000,maxBuffer:1024*1024,
        env:{...process.env,PGPASSWORD:password,PGSSLMODE:'verify-full',PGSSLROOTCERT:'/run/msgi-ca.crt',PGCONNECT_TIMEOUT:'8'},
      });
  } finally {
    try { spawn('docker',['stop','--timeout','2',client],{encoding:'utf8',windowsHide:true,timeout:10000,stdio:'pipe'}); } catch {}
  }
  const diagnostic = summarize(r);
  if (r.status !== 0) return {authenticated:false,credential_supplied:password.length>0,
    tls_verified:['password_unavailable','authentication_rejected'].includes(diagnostic.classification),diagnostic};
  let j;try { j=JSON.parse(r.stdout.trim()); } catch { throw Error('Read-only acceptance JSON invalid; raw output suppressed'); }
  const versions=['20261112000100','20261112000200','20261112000300','20261113000100','20261113000200','20261113000300','20261114000100','20261114000200','20261114000300','20261114000400','20261114000500'];
  if (!password || j.read_only!=='on' || j.database!=='postgres' || j.role!=='postgres' || j.ssl!==true ||
      JSON.stringify(j.history)!==JSON.stringify(versions) || ['institutions','departments','programmes','skills'].some(k=>j[k]!==0)) throw Error('Read-only secure acceptance identity/state mismatch');
  return {authenticated:true,credential_supplied:true,tls_verified:true,...j};
}
module.exports={directReadOnly,SQL};
if(require.main===module){
  try {
    if(process.argv.length!==2)throw Error('No SQL, host or deployment arguments accepted');
    const metadata=run(['--check','--project-ref=sbgshejyvkptmrffiwvd']);
    const acceptance=directReadOnly({password:process.env.SUPABASE_DB_PASSWORD||''});
    console.log(JSON.stringify({metadata,acceptance},null,2));
    if(!acceptance.authenticated)process.exitCode=2;
  }catch{console.error('Secure read-only check failed; no deployment performed; raw details suppressed');process.exitCode=1;}
}
