// CLI 3.1.0: explicit output-format works for migration list; -o json does not.
const crypto = require('node:crypto');
const CONTRACT = Object.freeze({
  flags: ['--output-format=json'],
  parse: 'one JSON value; optional leading BOM/whitespace; no stderr/table fallback',
  projects: 'object with projects array',
  migrations: 'object with migrations array and target.project_ref',
  query: 'object with rows array OR bare array normalized to rows',
  execution_review: 'renewed execution-plan review required after runner change',
});
const CONTRACT_SHA256 = crypto.createHash('sha256').update(JSON.stringify(CONTRACT)).digest('hex');
function label(args) {
  const key = args.slice(0, 2).join(' ');
  if (!['projects list', 'migration list', 'db query'].includes(key)) throw Error('Unsupported read-only CLI response contract');
  return key;
}
function jsonArgs(args) {
  label(args);
  if (args.some(a => /^--output(?:-format)?(?:=|$)|^-o$/.test(a))) throw Error('Conflicting CLI output option');
  return [...args, ...CONTRACT.flags];
}
function parseResponse(args, stdout) {
  const command = label(args);
  let json;
  try { json = JSON.parse(stdout.replace(/^\uFEFF/, '').trim()); }
  catch { throw Error(`Expected supported CLI JSON response from ${command}; raw output suppressed`); }
  if (command === 'projects list' && json && !Array.isArray(json) && Array.isArray(json.projects)) return json;
  if (command === 'migration list' && json && Array.isArray(json.migrations) &&
      json.target && typeof json.target.project_ref === 'string') return json;
  if (command === 'db query') {
    if (Array.isArray(json)) return { rows: json };
    if (json && Array.isArray(json.rows)) return json;
  }
  throw Error(`Unsupported JSON structure from ${command}; raw output suppressed`);
}
module.exports = { CONTRACT, CONTRACT_SHA256, jsonArgs, parseResponse };
