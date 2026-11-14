// Default mode is read-only. --execute requires NEW owner approval outside this tool.
const fs = require('node:fs');
const path = require('node:path');
const cp = require('node:child_process');
const crypto = require('node:crypto');
const { REF, hash, normalize, render, preflight } = require('./render_msec_reference.cjs');
const ROOT = path.resolve(__dirname, '..');
const FILES = ['msec_reference_manifest.json', 'msec.sql', 'starter_skills_proposed.sql', 'msec_reference_atomic.sql'];
const OVERRIDES = ['PGHOST', 'PGHOSTADDR', 'PGPORT', 'PGDATABASE', 'PGUSER', 'PGPASSWORD', 'PGSERVICE', 'PGSERVICEFILE', 'PGOPTIONS', 'PGPASSFILE', 'PGSSLMODE', 'DATABASE_URL', 'SUPABASE_DB_URL', 'SUPABASE_DB_HOST', 'SUPABASE_DB_PORT', 'SUPABASE_DB_NAME', 'SUPABASE_DB_USER', 'SUPABASE_PROJECT_REF', 'SUPABASE_PROJECT_ID', 'SUPABASE_API_HOST', 'SUPABASE_API_URL', 'SUPABASE_API_ENDPOINT', 'SUPABASE_URL', 'SUPABASE_WORKDIR', 'SUPABASE_PROFILE'];
function parse(text) {
  const i = text.search(/[\[{]/);
  if (i < 0) throw Error('Expected supported CLI JSON response');
  try { return JSON.parse(text.slice(i)); } catch { throw Error('Invalid CLI JSON response; raw response suppressed'); }
}
function invoke(args) {
  // Public reference SQL can exceed Windows argument limits. Stage only these
  // verified bytes, never credentials or user data, in a unique read-only file.
  let staged;
  const last = args.at(-1);
  if (/^(select |set msgi\.)/i.test(last)) {
    const dir = path.join(ROOT, 'build');
    fs.mkdirSync(dir, { recursive: true });
    staged = path.join(dir, `catalog-query-${crypto.randomUUID()}.sql`);
    fs.writeFileSync(staged, last, { flag: 'wx', mode: 0o600 });
    if (hash(fs.readFileSync(staged, 'utf8')) !== hash(last)) throw Error('Staged SQL identity mismatch');
    fs.chmodSync(staged, 0o400);
    args = [...args.slice(0, -1), '--file', staged];
  }
  // Single-quoted PowerShell arguments + encoded source avoid shell interpolation.
  const quote = s => "'" + s.replaceAll("'", "''") + "'";
  const command = `$ErrorActionPreference='Continue'; & npx.cmd ${['--no-install', 'supabase', ...args].map(quote).join(' ')}; exit $LASTEXITCODE`;
  try {
    const r = cp.spawnSync('powershell.exe', ['-NoProfile', '-EncodedCommand', Buffer.from(command, 'utf16le').toString('base64')], { cwd: ROOT, encoding: 'utf8', windowsHide: true, maxBuffer: 8 * 1024 * 1024 });
    if (r.status !== 0) throw Error('CLI operation failed; raw response suppressed. Inspect hosted state read-only before any retry.');
    return parse(r.stdout);
  } finally {
    if (staged) { fs.chmodSync(staged, 0o600); fs.unlinkSync(staged); }
  }
}
function run(args, io = {}) {
  const read = io.read || (p => fs.readFileSync(path.join(ROOT, p), 'utf8'));
  const cli = io.cli || invoke;
  const env = io.env || process.env;
  let execute = false, checkOnly = false, approval, project = REF;
  for (const arg of args) {
    if (arg === '--execute') execute = true;
    else if (arg === '--check') checkOnly = true;
    else if (arg.startsWith('--approve-sha256=')) approval = arg.slice(17);
    else if (arg.startsWith('--project-ref=')) project = arg.slice(14);
    else throw Error('Unexpected runner argument; connection overrides are not accepted');
  }
  if (execute && checkOnly) throw Error('Conflicting execution and read-only flags');
  if (project !== REF) throw Error('Wrong project: refused before any SQL');
  if (OVERRIDES.some(k => env[k] !== undefined)) throw Error('Connection/profile environment override refused');
  for (const file of ['.env', '.env.local', 'supabase/.env', 'supabase/.env.local']) {
    let text;
    try { text = read(file); } catch (e) { if (e.code === 'ENOENT') continue; throw e; }
    for (const line of text.split(/\r?\n/)) {
      const match = line.match(/^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=/);
      if (match && OVERRIDES.includes(match[1])) throw Error('Connection override in dotenv file refused');
    }
  }
  if (read('supabase/.temp/project-ref').trim() !== REF) throw Error('Wrong linked project');
  const lock = JSON.parse(read('supabase/catalogs/msec_reference_hashes.json'));
  if (lock.project_ref !== REF || Object.keys(lock.hashes).sort().join() !== [...FILES].sort().join()) throw Error('Unexpected hash manifest');
  const texts = Object.fromEntries(FILES.map(file => {
    const text = normalize(read('supabase/catalogs/' + file));
    if (hash(text) !== lock.hashes[file]) throw Error('Altered catalog payload hash');
    return [file, text];
  }));
  const manifest = JSON.parse(texts['msec_reference_manifest.json']);
  const generated = render(manifest);
  if (generated.msec !== texts['msec.sql'] || generated.skills !== texts['starter_skills_proposed.sql'] || generated.bundle !== texts['msec_reference_atomic.sql']) throw Error('Manifest and generated SQL differ');
  const digest = lock.hashes['msec_reference_atomic.sql'];
  if (execute && approval !== digest) throw Error('Explicit approval must equal the exact reviewed bundle SHA-256');
  const projects = cli(['projects', 'list', '--workdir', ROOT]).projects;
  const metadata = projects?.find(p => p.id === REF && p.ref === REF);
  if (!metadata || !metadata.linked || metadata.database?.host !== `db.${REF}.supabase.co` || metadata.region !== 'ap-northeast-2') throw Error('Authenticated project/database metadata mismatch');
  let url;
  try { url = new URL(read('supabase/.temp/pooler-url').trim()); } catch { throw Error('Invalid cached database destination'); }
  if (!['postgres:', 'postgresql:'].includes(url.protocol) || url.hostname !== 'aws-0-ap-northeast-2.pooler.supabase.com' || decodeURIComponent(url.username) !== `postgres.${REF}` || url.password || !['', '5432', '6543'].includes(url.port) || url.pathname !== '/postgres' || [...url.searchParams].some(([k,v]) => k !== 'sslmode' || v !== 'require')) throw Error('Unexpected database host, identity or connection options');
  const history = cli(['migration', 'list', `--remote=${REF}`, '--workdir', ROOT]);
  const versions = ['20261112000100','20261112000200','20261112000300','20261113000100','20261113000200','20261113000300','20261114000100','20261114000200','20261114000300','20261114000400','20261114000500'];
  if (history.target?.project_ref !== REF || history.migrations?.length !== 11 || history.migrations.some((r,i) => r.local !== versions[i] || r.remote !== versions[i])) throw Error('Unexpected migration history');
  // --remote uses the supported CLI's authenticated project routing, not a caller URL.
  const result = cli(['db', 'query', `--remote=${REF}`, '--read-only', '--workdir', ROOT, preflight(manifest)]);
  const p = result.rows?.[0]?.catalog_preflight;
  if (!p || p.read_only !== 'on' || p.database !== 'postgres' || p.version !== 17 || p.rls_tables !== 4 || JSON.stringify(p.history) !== JSON.stringify(versions) || ['institutions','departments','programmes','skills'].some(t => p[t+'_conflict'])) throw Error('Catalog preflight failed: unexpected records, schema or identity');
  if (execute) {
    // Execute the verified in-memory snapshot, never a caller-supplied SQL file.
    const sql = "set msgi.catalog_payload_approved='msec-reference-v1';\n" + texts['msec_reference_atomic.sql'];
    cli(['db', 'query', `--remote=${REF}`, '--yes', '--workdir', ROOT, sql]);
    // Multi-statement response shapes vary; verify persisted tuples through a
    // separate read-only request instead of assuming COMMIT returns SELECT rows.
    const post = cli(['db', 'query', `--remote=${REF}`, '--read-only', '--workdir', ROOT, preflight(manifest)]).rows?.[0]?.catalog_preflight;
    if (!post || post.read_only !== 'on' || post.institutions_count !== 1 || post.departments_count !== 1 || post.programmes_count !== 13 || post.skills_count !== 36 || ['institutions','departments','programmes','skills'].some(t => post[t+'_conflict'])) throw Error('Post-write verification unexpected: STOP and inspect read-only; do not retry');
  }
  return { mode: execute ? 'executed' : 'read-only-check', project_ref: REF, database_host_verified: true, payload_sha256: digest,
    observed_preflight_counts: Object.fromEntries(['institutions','departments','programmes','skills'].map(t => [t,p[t+'_count']])),
    expected: { institutions: 1, departments: 1, programmes: 13, skills: 36 } };
}
module.exports = { run, OVERRIDES };
if (require.main === module) {
  try { console.log(JSON.stringify(run(process.argv.slice(2)), null, 2)); }
  catch (e) { console.error(e.message); process.exitCode = 1; }
}
