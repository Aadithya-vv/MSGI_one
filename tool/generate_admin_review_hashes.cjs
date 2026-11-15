// Local review-manifest generation only; no credentials, database or network.
const fs=require('node:fs'),crypto=require('node:crypto');
const sha=b=>crypto.createHash('sha256').update(b).digest('hex');
const files=[
 'supabase/migrations/20261115000100_institutional_operations.sql',
 'supabase/review/admin_execution_batch.sql','supabase/review/admin_execution_plan.json','supabase/review/admin_runtime_identity.json',
 'supabase/operations/bootstrap_initial_admin.sql','supabase/operations/manage_administrator.sql',
 'tool/admin_deployment_plan.cjs','tool/admin_deployment_plan.test.cjs','tool/rehearse_admin_deployment.cjs','tool/sql/admin_hosted_inventory.sql',
 'tool/msec_tls_policy.cjs','tool/certs/supabase-prod-ca-2021.crt','tool/supabase_cli_json.cjs',
 'tool/test_clean_admin_migrations.cjs','tool/test_local_administration.cjs','tool/test_local_role_operations.cjs','tool/test_local_bootstrap.cjs',
 'supabase/tests/database/institutional_operations.test.sql',
 'lib/features/administration/domain/administration_repository.dart','lib/features/administration/data/administration_providers.dart',
 'lib/features/administration/presentation/administration_screen.dart','lib/features/administration/presentation/administration_dashboard.dart','lib/features/administration/presentation/membership_request_panel.dart'
];
const record={format:1,notes:'raw SHA identifies exact bytes; LF SHA normalizes CRLF only. This is review metadata, not execution authorization.',files:files.map(file=>{const b=fs.readFileSync(file);return {file,raw_sha256:sha(b),lf_sha256:sha(Buffer.from(b.toString('utf8').replace(/\r\n/g,'\n')))};})};
fs.writeFileSync('supabase/review/admin_implementation_hashes.json',JSON.stringify(record,null,2)+'\n');console.log('Reviewed implementation hashes recorded: '+files.length);
