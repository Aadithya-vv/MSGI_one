// Local artifact generation. Never connects or executes SQL.
const fs=require('node:fs');
const {sha,canonical}=require('./admin_deployment_plan.cjs');
const {schema,expression,requireThat}=require('./admin_executor_state.cjs');
const OLD='3f4fc4b6f8ca52f5e15fde2b1163cf74e28b40be6b691ffa6f41a7dcae4638bb';
const FILES=['tool/admin_executor_state.cjs','tool/admin_executor_transport.cjs','tool/admin_backup.cjs','tool/admin_migration_executor.cjs','tool/generate_admin_executor_plan.cjs',
 'tool/msec_tls_policy.cjs','tool/msec_session_diagnostics.cjs','tool/admin_deployment_plan.cjs','tool/supabase_cli_json.cjs','tool/render_msec_reference.cjs',
 'tool/request_admin_readonly_credential.ps1','tool/certs/supabase-prod-ca-2021.crt','tool/sql/admin_hosted_inventory.sql',
 'supabase/catalogs/msec_reference_manifest.json','tool/admin_migration_executor.test.cjs','tool/admin_backup.test.cjs',
 'tool/test_admin_executor_postgres.cjs','tool/rehearse_admin_deployment.cjs'];
function generate(){
 const old=JSON.parse(fs.readFileSync('supabase/review/admin_execution_plan.json'));
 requireThat(old.execution_plan_sha256===OLD&&sha(Buffer.from(canonical(old.plan)))===OLD,'task11e_plan_identity');
 const source=fs.readFileSync('supabase/migrations/'+old.plan.migration);
 requireThat(sha(source)==='a93d179f6bea04eb4f4c8b6556ddf1aee46cc2949cbeda28eff64cbfa7d7f120','migration_hash');
 const original=fs.readFileSync(old.plan.batch_file);requireThat(sha(original)===old.plan.batch_sha256,'task11e_batch_identity');
 const pre=JSON.parse(fs.readFileSync('build/task11e-hosted-inventory.json'));
 const post=JSON.parse(fs.readFileSync('build/task11f-post-schema.json'));
 const names=pre.tables.map(t=>{requireThat(/^(public|private)$/.test(t.schema)&&/^[a-z_]+$/.test(t.table),'table_identity');return `"${t.schema}"."${t.table}"`;});
 const controls=`
select set_config('msgi.executor_baseline', :'msgi_baseline_md5', true);
do $executor_lock$ begin
 if not pg_try_advisory_xact_lock(749312050001::bigint) then raise exception 'Concurrent administration deployment'; end if;
end $executor_lock$;
lock table ${[...names,'auth.users','supabase_migrations.schema_migrations'].join(',')} in share row exclusive mode;
do $executor_guard$ begin
 if current_database()<>'postgres' or current_user<>'postgres' then raise exception 'Wrong database identity'; end if;
 if md5((${expression()})::text) is distinct from current_setting('msgi.executor_baseline') then raise exception 'Deployment baseline changed'; end if;
end $executor_guard$;
`;
 // Settings remain transaction local; lock/guard execute before any migration DDL.
 const boundary="set local standard_conforming_strings=on;";
 requireThat(original.toString().includes(boundary),'batch_controls');
 const batch=Buffer.from(original.toString().replace(boundary,boundary+controls));
 fs.writeFileSync('supabase/review/admin_executor_batch.sql',batch);
 const plan={format:1,project_ref:old.plan.project_ref,prior_review_plan_sha256:OLD,migration:old.plan.migration,migration_sha256:sha(source),
  batch_file:'supabase/review/admin_executor_batch.sql',batch_sha256:sha(batch),dependencies:old.plan.dependencies,transport:old.plan.transport,
  pre_schema_sha256:sha(Buffer.from(canonical(schema(pre)))),post_schema_sha256:sha(Buffer.from(canonical(post))),
  files:FILES.map(file=>({file,sha256:sha(fs.readFileSync(file))})),
  concurrency:'exclusive persistent one-attempt journal + pg_try_advisory_xact_lock + fixed table locks + in-transaction aggregate-baseline guard',
  credential:'private child SUPABASE_DB_PASSWORD; no argv/file/log credential; read-only masked launcher cannot execute',
  backup:'DPAPI CurrentUser encrypted custom pg_dump; approved manifest hash; maximum age four hours; matching baseline and verified isolated restore required',
  approval:'explicit one-attempt owner manifest pins this plan and a fresh encrypted backup; no authorization supplied by this task',
  outcome:'one write connection; no automatic retry; every failure retains attempt marker; independent read-only postflight; unknown/committed-but-unverified stops',
  journal:'fixed LOCALAPPDATA/MSGIOne/admin-deployments/project/version.attempt.json, exclusive create before write; never automatically removed',
  sql:'Task11E derivative plus set_config baseline, advisory guard, fixed table locks and baseline check; no administrator/Auth/SMTP/catalog mutation',
  remaining_gates:['fresh verified hosted backup','review exact executor implementation and new plan','private direct authentication','separate explicit one-attempt owner authorization']};
 const record={canonicalization:'Task11E recursive-key-sorted compact JSON plan only; UTF-8 no BOM/newline',execution_plan_sha256:sha(Buffer.from(canonical(plan))),plan};
 fs.writeFileSync('supabase/review/admin_executor_plan.json',JSON.stringify(record,null,2)+'\n');return record;
}
module.exports={generate,FILES};
if(require.main===module){requireThat(process.argv.length===2,'unexpected_arguments');const r=generate();console.log(JSON.stringify({migration_sha256:r.plan.migration_sha256,batch_sha256:r.plan.batch_sha256,execution_plan_sha256:r.execution_plan_sha256}));}
