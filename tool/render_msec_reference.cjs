// Pure local renderer. Never connects to a database or grants deployment approval.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const REF = 'sbgshejyvkptmrffiwvd';
const normalize = text => text.replace(/\r\n/g, '\n');
const hash = text => crypto.createHash('sha256').update(normalize(text)).digest('hex');
const literal = value => "'" + value.replaceAll("'", "''") + "'";
const specs = {
  institutions: 'id uuid,name text,catalog_key text,active boolean',
  departments: 'id uuid,institution_id uuid,name text,active boolean',
  programmes: 'id uuid,institution_id uuid,application_key text,name text,level text,active boolean',
  skills: 'name text',
};
function records(m) {
  if (m.project_ref !== REF || m.programmes.length !== 13 || m.skills.length !== 36 ||
      m.programmes.filter(p => p.level === 'undergraduate').length !== 9 ||
      m.programmes.filter(p => p.level === 'postgraduate').length !== 4) throw Error('Invalid manifest scope');
  const result = { institutions: [m.institution], departments: [m.department], programmes: m.programmes, skills: m.skills.map(s => ({ name: s.name })) };
  for (const [table, rows] of Object.entries(result)) {
    const fields = specs[table].split(',').map(f => f.split(' ')[0]);
    if (rows.some(r => fields.some(f => r[f] === undefined))) throw Error('Incomplete manifest tuple');
    if (new Set(rows.map(r => r.id || r.name.toLowerCase().trim())).size !== rows.length) throw Error('Duplicate manifest identity');
  }
  return result;
}
function relation(table, rows) { return `jsonb_to_recordset(${literal(JSON.stringify(rows))}::jsonb) as e(${specs[table]})`; }
function match(table) {
  return specs[table].split(',').map(f => f.split(' ')[0]).map(f => `s.${f} is not distinct from e.${f}`).join(' and ');
}
function conflict(table, rows) { return `exists(select 1 from public.${table} s where not exists(select 1 from ${relation(table, rows)} where ${match(table)}))`; }
function fragment(tables, data) {
  return `-- Generated reviewed fragment; execute ONLY through msec_reference_atomic.sql / guarded runner.\n-- No independent BEGIN/COMMIT, upsert, update, delete, grants or RLS changes.\ndo $catalog$\nbegin\n if current_setting('msgi.reference_bundle',true) is distinct from 'msec-reference-v1' then\n  raise exception 'Atomic reference bundle required';\n end if;\n` + tables.map(table => {
    const cols = specs[table].split(',').map(f => f.split(' ')[0]).join(',');
    const key = table === 'skills' ? 'name' : 'id';
    return ` if ${conflict(table, data[table])} then raise exception 'Unexpected ${table} identity or authoritative fields; no reconciliation allowed'; end if;\n insert into public.${table}(${cols}) select ${cols} from ${relation(table, data[table])}\n where not exists(select 1 from public.${table} s where s.${key}=e.${key});\n if (select count(*) from public.${table})<>${data[table].length} or ${conflict(table, data[table])} then\n  raise exception 'Exact ${table} tuple verification failed';\n end if;\n`;
  }).join('') + 'end;\n$catalog$;\n';
}
function render(m) {
  const data = records(m);
  const msec = fragment(['institutions', 'departments', 'programmes'], data);
  const skills = fragment(['skills'], data);
  const bundle = `-- Authoritative 51-record atomic payload. Project identity is enforced by the runner, not a SQL label.\nbegin;\nset local lock_timeout='5s';\nset local statement_timeout='30s';\nset local search_path='';\nset local standard_conforming_strings=on;\ndo $approval$ begin\n if current_setting('msgi.catalog_payload_approved',true) is distinct from 'msec-reference-v1' then\n  raise exception 'Explicit hash-bound runner approval required';\n end if;\nend $approval$;\nlock table public.institutions,public.departments,public.programmes,public.skills in share row exclusive mode;\nset local msgi.reference_bundle='msec-reference-v1';\n` + msec + skills + `select jsonb_build_object('institutions',(select count(*) from public.institutions),'departments',(select count(*) from public.departments),'programmes',(select count(*) from public.programmes),'skills',(select count(*) from public.skills)) as reference_counts;\ncommit;\n`;
  return { msec, skills, bundle };
}
function preflight(m) {
  const data = records(m);
  return `select jsonb_build_object('read_only',current_setting('transaction_read_only'),'database',current_database(),'version',current_setting('server_version_num')::int/10000,'history',(select jsonb_agg(version order by version) from supabase_migrations.schema_migrations),` +
    Object.keys(data).map(t => `'${t}_conflict',${conflict(t, data[t])}`).join(',') +
    ',' + Object.keys(data).map(t => `'${t}_count',(select count(*) from public.${t})`).join(',') +
    `,'rls_tables',(select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('institutions','departments','programmes','skills') and c.relrowsecurity)) as catalog_preflight;`;
}
module.exports = { REF, hash, normalize, records, render, preflight };
if (require.main === module) {
  const root = path.resolve(__dirname, '..');
  const dir = path.join(root, 'supabase/catalogs');
  const manifest = fs.readFileSync(path.join(dir, 'msec_reference_manifest.json'), 'utf8');
  const result = render(JSON.parse(manifest));
  const files = { 'msec.sql': result.msec, 'starter_skills_proposed.sql': result.skills, 'msec_reference_atomic.sql': result.bundle };
  for (const [file, text] of Object.entries(files)) fs.writeFileSync(path.join(dir, file), text);
  const hashes = Object.fromEntries(Object.entries({ 'msec_reference_manifest.json': manifest, ...files }).map(([file, text]) => [file, hash(text)]));
  fs.writeFileSync(path.join(dir, 'msec_reference_hashes.json'), JSON.stringify({ project_ref: REF, hash_format: 'SHA-256 UTF-8 LF', hashes }, null, 2) + '\n');
  console.log('Rendered local proposal only. Bundle SHA-256: ' + hashes['msec_reference_atomic.sql']);
}
