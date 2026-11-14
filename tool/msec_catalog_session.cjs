// Dedicated DIRECT PostgreSQL session. Never use a pooled/API write connection.
const cp = require('node:child_process');
const crypto = require('node:crypto');
const { summarize, persist } = require('./msec_session_diagnostics.cjs');
const REF = 'sbgshejyvkptmrffiwvd';
const PAYLOAD_SHA256 = '153f97a2eaff6fa02a723a65bcf4c135ab91bc63b2acb8dc151c93966833e428';
const IMAGE = 'public.ecr.aws/supabase/postgres:17.11.0.019';
const sha256 = bytes => crypto.createHash('sha256').update(bytes).digest('hex');
const CONTROLS = Object.freeze({
  assertClean: "do $context$ begin if coalesce(current_setting('msgi.catalog_payload_approved',true),'')<>'' then raise exception 'Unexpected ambient approval context'; end if; end $context$;",
  set: "set msgi.catalog_payload_approved='msec-reference-v1';",
  verify: "do $context$ begin if current_setting('msgi.catalog_payload_approved',true) is distinct from 'msec-reference-v1' then raise exception 'Session approval not established'; end if; end $context$;",
  reset: 'reset msgi.catalog_payload_approved;',
  verifyReset: "do $context$ begin if coalesce(current_setting('msgi.catalog_payload_approved',true),'')<>'' then raise exception 'Session approval not cleared'; end if; end $context$;",
});
function psqlOperations() {
  // -c/-f operations are ordered and use one psql connection. The file operation
  // reads exactly the stdin buffer, with no prefix/suffix SQL or newline rewriting.
  return ['-X','-v','ON_ERROR_STOP=1','--no-password',
    '-c',CONTROLS.assertClean,'-c',CONTROLS.set,'-c',CONTROLS.verify,
    '-f','-','-c',CONTROLS.reset,'-c',CONTROLS.verifyReset];
}
function executionPlan() {
  const plan = { project_ref: REF, direct_host: `db.${REF}.supabase.co`, port: 5432,
    database: 'postgres', role: 'postgres', image: IMAGE, tls: 'verify-full/system',
    operations: [CONTROLS.assertClean, CONTROLS.set, CONTROLS.verify,
      { stdin_file_sha256: PAYLOAD_SHA256 }, CONTROLS.reset, CONTROLS.verifyReset],
    session: 'dedicated-direct-backend-closed-on-success-or-error' };
  return { ...plan, execution_plan_sha256: sha256(Buffer.from(JSON.stringify(plan))) };
}
function executeDedicated({ payload, project, host, password, spawn = cp.spawnSync }) {
  if (!Buffer.isBuffer(payload) || sha256(payload) !== PAYLOAD_SHA256) throw Error('Raw payload byte identity mismatch');
  if (project !== REF || host !== `db.${REF}.supabase.co`) throw Error('Dedicated-session target mismatch');
  if (typeof password !== 'string' || password.length === 0 || /[\r\n\0]/.test(password)) throw Error('Existing secure SUPABASE_DB_PASSWORD is required for the dedicated direct session');
  // Password is inherited only through the child environment; never argv, SQL,
  // a credential file, repository output or logs. Docker daemon must be trusted.
  // No ports/volumes are published. The short-lived client is removed on exit.
  const client = 'msgi-catalog-client-' + crypto.randomUUID();
  const args = ['run','--name',client,'--rm','--pull','never','-i','--network','bridge','--read-only',
    '--cap-drop','ALL','--security-opt','no-new-privileges','--user','postgres',
    '--env','PGPASSWORD','--env','PGSSLMODE','--env','PGSSLROOTCERT',
    '--entrypoint','psql',IMAGE,'--host',host,'--port','5432','--username','postgres',
    '--dbname','postgres',...psqlOperations()];
  try {
    let result;
    try {
      result = spawn('docker', args, { input: payload, encoding: 'utf8', windowsHide: true,
        maxBuffer: 8 * 1024 * 1024, timeout: 120000,
        env: { ...process.env, PGPASSWORD: password, PGSSLMODE: 'verify-full', PGSSLROOTCERT: 'system' } });
    } catch (error) { result = { status: null, error }; }
    const diagnostic = summarize(result);
    const evidence = persist(client, diagnostic);
    if (result.status !== 0) {
      const error = Error(`Dedicated session failed (${diagnostic.classification}; exit ${diagnostic.exit_status ?? 'unknown'}). Outcome requires read-only inspection; never retry automatically.${evidence ? ' Sanitized evidence: '+evidence : ''}`);
      error.diagnostic = diagnostic;
      throw error;
    }
  } finally {
    // Also close a stuck client/backend if its attached Docker command timed out.
    // Only our freshly generated client identity is targeted; no existing DB.
    try { spawn('docker', ['stop','--timeout','5',client], { encoding: 'utf8', windowsHide: true, timeout: 15000, stdio:'pipe' }); }
    catch { /* Never replace the primary sanitized outcome with raw cleanup errors. */ }
  }
  return { payload_sha256: PAYLOAD_SHA256, execution_plan_sha256: executionPlan().execution_plan_sha256 };
}
module.exports = { REF, PAYLOAD_SHA256, IMAGE, CONTROLS, sha256, psqlOperations, executionPlan, executeDedicated };
