// Fixed aggregate-only queries; no private record contents leave PostgreSQL.
const fs = require('node:fs');
const { preflight } = require('./render_msec_reference.cjs');
const { canonical, sha } = require('./admin_deployment_plan.cjs');
const KEYS = ['functions','tables_security','policies','indexes','triggers','constraints','history_columns','default_acls'];
function schema(v) { return Object.fromEntries(KEYS.map(k => [k, ['history_columns','default_acls'].includes(k)?[...(v[k]||[])].map(a=>k==='default_acls'?{...a,acl:[...a.acl].sort()}:a).sort((a,b)=>canonical(a).localeCompare(canonical(b))):v[k]])); }
function expression() {
  const inventory = fs.readFileSync('tool/sql/admin_hosted_inventory.sql','utf8').replace(/;\s*$/, '');
  const catalog = preflight(JSON.parse(fs.readFileSync('supabase/catalogs/msec_reference_manifest.json','utf8'))).replace(/;\s*$/, '');
  return `(select jsonb_build_object('inventory',i.inventory - array['read_only','version','ssl','tls_version','active_ddl','waiting_locks'],
    'catalog',c.catalog_preflight - array['read_only','version'],
    'auth_fingerprint',(select md5(coalesce(string_agg(md5(row_to_json(u)::text),'' order by md5(row_to_json(u)::text)),'')) from auth.users u))
    from (${inventory}) i cross join (${catalog}) c)`;
}
function snapshotSQL() {
  return `begin read only;set local statement_timeout='30s';
  select jsonb_build_object('state',v,'state_md5',md5(v::text),'read_only',current_setting('transaction_read_only'),
  'database',current_database(),'role',current_user,'ssl',(select ssl from pg_stat_ssl where pid=pg_backend_pid()),
  'tls_version',(select version from pg_stat_ssl where pid=pg_backend_pid()),
  'active_ddl',(select count(*) from pg_stat_activity where pid<>pg_backend_pid() and state='active' and backend_type='client backend' and query ~* '^\\s*(alter|create|drop|truncate|reindex)'),
  'waiting_locks',(select count(*) from pg_locks where not granted)) from (select ${expression()} v)s;rollback;`;
}
function requireThat(v, category) { if (!v) { const e = Error(category); e.category = category; throw e; } }
function verifySnapshot(s, plan, post=false) {
  requireThat(s && /^[a-f0-9]{32}$/.test(s.state_md5 || ''), 'invalid_snapshot');
  requireThat(s.read_only === 'on' && s.database === 'postgres' && s.role === 'postgres', 'database_identity');
  requireThat(s.ssl === true && ['TLSv1.2','TLSv1.3'].includes(s.tls_version), 'tls_not_verified');
  requireThat(s.active_ddl === 0 && s.waiting_locks === 0, 'database_busy');
  const v = s.state?.inventory, c = s.state?.catalog;
  requireThat(v && c, 'invalid_snapshot');
  const versions = plan.dependencies.map(d => d.file.slice(0,14));
  if (post) versions.push('20261115000100');
  requireThat(canonical(v.history) === canonical(versions), 'migration_history');
  requireThat(v.roles.count === 0 && v.roles.without_profile === 0 && v.roles.inactive_or_missing_institution === 0, 'administrator_baseline');
  requireThat(['institutions','departments','programmes','skills'].every((t,i) => c[t+'_count'] === [1,1,13,36][i] && c[t+'_conflict'] === false), 'catalog_identity');
  requireThat(c.rls_tables === 4, 'catalog_rls');
  requireThat(sha(Buffer.from(canonical(schema(v)))) === (post ? plan.post_schema_sha256 : plan.pre_schema_sha256), 'schema_or_privilege_drift');
  return s;
}
function preservation(before, after) {
  const b = before.state.inventory, a = after.state.inventory;
  requireThat(before.state.auth_fingerprint === after.state.auth_fingerprint && b.auth_users_count === a.auth_users_count, 'auth_data_changed');
  requireThat(b.tables.every(t => a.tables.some(u => canonical(t) === canonical(u))), 'existing_data_changed');
  requireThat(['administration_audit','membership_requests'].every(t => a.tables.some(u => u.schema === 'private' && u.table === t && u.rows === 0)), 'new_private_tables_not_empty');
}
module.exports = { schema, expression, snapshotSQL, verifySnapshot, preservation, requireThat };
