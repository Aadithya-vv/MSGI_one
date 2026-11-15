// Reuses the reviewed Supabase trust anchor and host-network IPv6 transport.
const cp = require('node:child_process');
const crypto = require('node:crypto');
const { pinnedCa, assertHost } = require('./msec_tls_policy.cjs');
const { summarize } = require('./msec_session_diagnostics.cjs');
const { requireThat } = require('./admin_executor_state.cjs');
const OVERRIDES = ['PGHOST','PGHOSTADDR','PGPORT','PGDATABASE','PGUSER','PGPASSWORD','PGOPTIONS','PGSERVICE','PGSERVICEFILE','PGPASSFILE','PGSSLMODE','PGSSLROOTCERT','PGSSLCRL','PGSSLCRLDIR','PGREQUIRESSL','PGCHANNELBINDING','PGGSSENCMODE','DATABASE_URL','SUPABASE_DB_URL','DOCKER_HOST','DOCKER_CONTEXT','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH'];
function transport({plan, password, input, baseline, readOnly=false, spawn=cp.spawnSync, env=process.env}) {
  requireThat(typeof password === 'string' && password.length > 0 && !/[\r\n\0]/.test(password), 'credential_unavailable');
  requireThat(!OVERRIDES.some(k => env[k] !== undefined), 'routing_environment_override');
  const t = plan.transport; assertHost(t.host); const ca = pinnedCa();
  requireThat(t.port === 5432 && t.database === 'postgres' && t.role === 'postgres' && t.sslmode === 'verify-full', 'transport_identity');
  requireThat(/^public\.ecr\.aws\/supabase\/postgres@sha256:[a-f0-9]{64}$/.test(t.image), 'runtime_identity');
  if (!readOnly) requireThat(/^[a-f0-9]{32}$/.test(baseline || ''), 'invalid_baseline');
  const name = 'msgi-admin-client-' + crypto.randomUUID();
  const args = ['run','--name',name,'--rm','--pull','never','-i','--network','host','--read-only','--log-driver','none',
    '--cap-drop','ALL','--security-opt','no-new-privileges','--user','postgres',
    '--mount',`type=bind,source=${ca.path},target=/run/msgi-ca.crt,readonly`,
    '--env','PGPASSWORD','--env','PGSSLMODE','--env','PGSSLROOTCERT','--env','PGCONNECT_TIMEOUT',
    '--entrypoint','psql',t.image,'-X','--no-password','--host',t.host,'--port','5432','--username','postgres','--dbname','postgres',
    '-v','ON_ERROR_STOP=1','-v','VERBOSITY=sqlstate', ...(readOnly ? ['-qAt'] : ['-v',`msgi_baseline_md5=${baseline}`]),'-f','-'];
  let result;
  try {
    result = spawn('docker',args,{input, encoding:'utf8',windowsHide:true,maxBuffer:16*1024*1024,timeout:120000,
      env:{...env,PGPASSWORD:password,PGSSLMODE:'verify-full',PGSSLROOTCERT:'/run/msgi-ca.crt',PGCONNECT_TIMEOUT:'8'}});
  } catch { result = {status:null,error:{code:'EPIPE'}}; }
  finally {
    try { spawn('docker',['stop','--timeout','5',name],{encoding:'utf8',windowsHide:true,timeout:15000,stdio:'pipe'}); } catch {}
  }
  const diagnostic = summarize(result);
  if (readOnly) {
    requireThat(result.status === 0, diagnostic.classification);
    let s; try { s=JSON.parse(result.stdout.trim()); } catch { requireThat(false,'invalid_readonly_response'); }
    return s;
  }
  // Return whitelist-only diagnostics, never raw SQL errors or row values.
  return diagnostic;
}
module.exports = { transport, OVERRIDES };
