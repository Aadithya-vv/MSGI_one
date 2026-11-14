// Whitelist-only incident evidence. Never persist raw stdout/stderr, errors,
// environment, credentials, connection URLs or query text.
const fs = require('node:fs');
const path = require('node:path');
function summarize(result = {}) {
  const stderr = typeof result.stderr === 'string' ? result.stderr : '';
  const stdout = typeof result.stdout === 'string' ? result.stdout : '';
  const allowedCodes = ['ENOENT','EACCES','EPERM','ETIMEDOUT','ECONNREFUSED','ENETUNREACH','EPIPE'];
  const errorCode = allowedCodes.includes(result.error?.code) ? result.error.code : null;
  const status = Number.isInteger(result.status) ? result.status : null;
  let classification = status === 0 ? 'client_completed' : 'unclassified_failure';
  if (errorCode === 'ETIMEDOUT') classification = 'client_timeout';
  else if (['ENOENT','EACCES','EPERM'].includes(errorCode)) classification = 'client_start_failure';
  else if ([125,126,127].includes(status)) classification = 'docker_client_or_image_failure';
  else if (/could not translate host name|name or service not known|temporary failure in name resolution/i.test(stderr)) classification = 'dns_failure';
  else if (/network is unreachable|network unreachable|ENETUNREACH/i.test(stderr)) classification = 'network_unreachable';
  else if (/connection refused/i.test(stderr)) classification = 'connection_refused';
  else if (/timeout expired|connection timed out/i.test(stderr)) classification = 'connection_timeout';
  else if (/certificate verify failed|root certificate file|SSL error|hostname.*does not match|does not match host name|self.signed certificate/i.test(stderr)) classification = 'tls_validation_failure';
  else if (/no password supplied|fe_sendauth/i.test(stderr)) classification = 'password_unavailable';
  else if (/password authentication failed|SASL authentication failed/i.test(stderr)) classification = 'authentication_rejected';
  else if (status === 3 || /\bERROR:/i.test(stderr)) classification = 'sql_statement_failure';
  const commit = /^\s*COMMIT\s*$/m.test(stdout);
  return {
    exit_status: status, signal: ['SIGTERM','SIGKILL','SIGINT'].includes(result.signal) ? result.signal : null,
    native_error_code: errorCode, classification,
    transaction_begin_observed: /^\s*BEGIN\s*$/m.test(stdout),
    commit_acknowledged: commit,
    outcome_hint: commit ? 'commit_acknowledged_verify_records_read_only' : 'no_commit_acknowledgement_outcome_requires_read_only_inspection',
    automatic_retry_permitted: false,
  };
}
function persist(client, diagnostic) {
  if (!/^msgi-catalog-client-[a-f0-9-]{36}$/.test(client)) return null;
  // Reconstruct all fields from safe values; callers cannot add arbitrary data.
  const safe = summarize({});
  const classifications = ['client_completed','unclassified_failure','client_timeout','client_start_failure','docker_client_or_image_failure','dns_failure','network_unreachable','connection_refused','connection_timeout','tls_validation_failure','password_unavailable','authentication_rejected','sql_statement_failure'];
  safe.exit_status = Number.isInteger(diagnostic.exit_status) ? diagnostic.exit_status : null;
  safe.signal = ['SIGTERM','SIGKILL','SIGINT'].includes(diagnostic.signal) ? diagnostic.signal : null;
  safe.native_error_code = ['ENOENT','EACCES','EPERM','ETIMEDOUT','ECONNREFUSED','ENETUNREACH','EPIPE'].includes(diagnostic.native_error_code) ? diagnostic.native_error_code : null;
  safe.classification = classifications.includes(diagnostic.classification) ? diagnostic.classification : 'unclassified_failure';
  safe.transaction_begin_observed = diagnostic.transaction_begin_observed === true;
  safe.commit_acknowledged = diagnostic.commit_acknowledged === true;
  safe.outcome_hint = safe.commit_acknowledged ? 'commit_acknowledged_verify_records_read_only' : 'no_commit_acknowledgement_outcome_requires_read_only_inspection';
  const basename = client + '.diagnostic.json';
  try {
    const dir = path.resolve(__dirname, '..', 'build');
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, basename), JSON.stringify(safe, null, 2), { flag: 'wx', mode: 0o600 });
    return 'build/' + basename;
  } catch { return null; }
}
module.exports = { summarize, persist };
