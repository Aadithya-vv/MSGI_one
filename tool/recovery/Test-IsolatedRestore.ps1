param([Parameter(Mandatory=$true)][string]$RecoveryDirectory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Security
$work=(Resolve-Path -LiteralPath $RecoveryDirectory).Path
$state=Get-Content -Raw (Join-Path $work 'state.json')|ConvertFrom-Json
$id=$state.id;$source=$state.source
function Unseal($name){$b=[Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes((Join-Path $source $name)),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser);if($b[0] -eq 255){return [Text.Encoding]::Unicode.GetString($b)};return [Text.Encoding]::UTF8.GetString($b)}
function Query($sql){
 $psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName='docker';$psi.Arguments="exec -i $id psql -h /tmp -X -q -A -t -U postgres -d recovery -v ON_ERROR_STOP=1";$psi.UseShellExecute=$false;$psi.RedirectStandardInput=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true
 $p=New-Object Diagnostics.Process;$p.StartInfo=$psi;$null=$p.Start();$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$p.StandardInput.Write("BEGIN READ ONLY;`n"+$sql+"`nCOMMIT;`n");$p.StandardInput.Close();$p.WaitForExit();if($p.ExitCode -ne 0){throw 'Read-only isolated validation query failed; database content withheld'};return $o.Result.TrimEnd("`r","`n")
}
$raw=Unseal 'source-counts-current.log.dpapi';$expected=($raw.Substring($raw.IndexOf('{'))|ConvertFrom-Json).rows[0].inventory
$actual=(Query (Get-Content -Raw (Join-Path $PSScriptRoot 'table-inventory.sql')))|ConvertFrom-Json
$failures=@();foreach($t in $expected.tables){$a=@($actual.tables|Where-Object {$_.schema -eq $t.schema -and $_.table -eq $t.table});if($a.Count -ne 1 -or [long]$a[0].rows -ne [long]$t.rows){$failures+='table-count'}}
if($actual.tables.Count -ne 52 -or $actual.read_only -ne 'on'){$failures+='coverage-or-readonly'}
foreach($e in $expected.extensions){$a=@($actual.extensions|Where-Object {$_.name -eq $e.name});if($a.Count -ne 1 -or $a[0].version -ne $e.version -or $a[0].schema -ne $e.schema){$failures+='extension-compatibility'}}
$catalogSql=@'
SELECT json_build_object(
'tables',(SELECT json_agg(n.nspname||'.'||c.relname ORDER BY n.nspname,c.relname) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind='r' AND n.nspname IN ('auth','storage','public','private','supabase_migrations')),
'constraints',(SELECT json_agg(n.nspname||'.'||c.relname||'.'||k.conname ORDER BY n.nspname,c.relname,k.conname) FROM pg_constraint k JOIN pg_class c ON c.oid=k.conrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('auth','storage','public','private','supabase_migrations')),
'indexes',(SELECT json_agg(schemaname||'.'||indexname ORDER BY schemaname,indexname) FROM pg_indexes WHERE schemaname IN ('auth','storage','public','private','supabase_migrations')),
'functions',(SELECT json_agg(n.nspname||'.'||p.proname ORDER BY n.nspname,p.proname) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('auth','storage','public','private','supabase_migrations')),
'policies',(SELECT json_agg(schemaname||'.'||tablename||'.'||policyname ORDER BY schemaname,tablename,policyname) FROM pg_policies WHERE schemaname IN ('auth','storage','public','private','supabase_migrations')),
'triggers',(SELECT json_agg(n.nspname||'.'||c.relname||'.'||t.tgname ORDER BY n.nspname,c.relname,t.tgname) FROM pg_trigger t JOIN pg_class c ON c.oid=t.tgrelid JOIN pg_namespace n ON n.oid=c.relnamespace WHERE NOT t.tgisinternal AND n.nspname IN ('auth','storage','public','private','supabase_migrations')),
'rls',(SELECT json_agg(n.nspname||'.'||c.relname ORDER BY n.nspname,c.relname) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind='r' AND c.relrowsecurity AND n.nspname IN ('auth','storage','public','private','supabase_migrations')),
'unvalidated_constraints',(SELECT count(*) FROM pg_constraint k JOIN pg_namespace n ON n.oid=k.connamespace WHERE n.nspname IN ('auth','storage','public','private','supabase_migrations') AND NOT convalidated),
'app_functions',(SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('public','private')),
'app_policies',(SELECT count(*) FROM pg_policies WHERE schemaname IN ('public','private')),
'app_rls',(SELECT count(*) FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE c.relkind='r' AND c.relrowsecurity AND n.nspname IN ('public','private')),
'history',(SELECT json_agg(version ORDER BY version) FROM supabase_migrations.schema_migrations),
'orphan_identities',(SELECT count(*) FROM auth.identities i LEFT JOIN auth.users u ON i.user_id=u.id WHERE u.id IS NULL)
);
'@
$cat=Query $catalogSql|ConvertFrom-Json
$checks=0;$expectedObjects=@{tables=@();constraints=@();indexes=@();functions=@();policies=@();triggers=@();rls=@()}
foreach($f in @('application-schema.sql.dpapi','managed-schema.sql.dpapi','history-schema.sql.dpapi')){
 $sql=(Unseal $f).Replace('"','')
 foreach($m in [regex]::Matches($sql,'(?m)^CREATE TABLE IF NOT EXISTS ([\w]+\.[\w]+)')){$expectedObjects.tables+=$m.Groups[1].Value}
 foreach($m in [regex]::Matches($sql,'(?s)ALTER TABLE ONLY ([\w]+\.[\w]+)\s+ADD CONSTRAINT ([\w]+)')){$expectedObjects.constraints+=($m.Groups[1].Value+'.'+$m.Groups[2].Value)}
 foreach($m in [regex]::Matches($sql,'(?m)^CREATE (?:UNIQUE )?INDEX ([\w]+) ON ([\w]+)\.')){$expectedObjects.indexes+=($m.Groups[2].Value+'.'+$m.Groups[1].Value)}
 foreach($m in [regex]::Matches($sql,'(?m)^CREATE OR REPLACE FUNCTION ([\w]+\.[\w]+)\(')){$expectedObjects.functions+=$m.Groups[1].Value}
 foreach($m in [regex]::Matches($sql,'(?m)^CREATE POLICY ([\w]+) ON ([\w]+\.[\w]+)')){$expectedObjects.policies+=($m.Groups[2].Value+'.'+$m.Groups[1].Value)}
 foreach($m in [regex]::Matches($sql,'(?m)^CREATE (?:OR REPLACE )?TRIGGER ([\w]+).*? ON ([\w]+\.[\w]+)')){$expectedObjects.triggers+=($m.Groups[2].Value+'.'+$m.Groups[1].Value)}
 foreach($m in [regex]::Matches($sql,'(?m)^ALTER TABLE (?:ONLY )?([\w]+\.[\w]+) ENABLE ROW LEVEL SECURITY')){$expectedObjects.rls+=$m.Groups[1].Value}
}
foreach($kind in $expectedObjects.Keys){foreach($obj in $expectedObjects[$kind]){$checks++;if($obj -notin $cat.$kind){$failures+='missing-'+$kind}}}
if($cat.app_functions -ne 19 -or $cat.app_policies -ne 19 -or $cat.app_rls -ne 14 -or $cat.orphan_identities -ne 0){$failures+='application-or-auth-integrity'}
$versions=@('20261112000100','20261112000200','20261112000300','20261113000100');if(($cat.history -join ',') -ne ($versions -join ',')){$failures+='migration-history'}
# Recheck FK data after replica-mode COPY; unique indexes and NOT NULL stayed enforced.
$fkSql=@'
SELECT coalesce(json_agg(json_build_object('q',q)),'[]'::json) FROM (
SELECT format('SELECT count(*) FROM %s c WHERE %s AND NOT EXISTS(SELECT 1 FROM %s p WHERE %s);',k.conrelid::regclass,
 string_agg(format('c.%I IS NOT NULL',a.attname),' AND ' ORDER BY keys.ord),k.confrelid::regclass,
 string_agg(format('c.%I = p.%I',a.attname,b.attname),' AND ' ORDER BY keys.ord)) q
FROM pg_constraint k JOIN pg_namespace ns ON ns.oid=k.connamespace
CROSS JOIN LATERAL unnest(k.conkey,k.confkey) WITH ORDINALITY keys(src,dst,ord)
JOIN pg_attribute a ON a.attrelid=k.conrelid AND a.attnum=keys.src JOIN pg_attribute b ON b.attrelid=k.confrelid AND b.attnum=keys.dst
WHERE k.contype='f' AND ns.nspname IN ('public','private','auth','storage','supabase_migrations') GROUP BY k.oid
) s;
'@
$fkQueries=Query $fkSql|ConvertFrom-Json;$fkChecked=0;foreach($q in $fkQueries){if([long](Query $q.q) -ne 0){$failures+='foreign-key-data'};$fkChecked++}
$checkSql=@'
SELECT coalesce(json_agg(json_build_object('q',format('SELECT count(*) FROM %s WHERE NOT (%s);',c.conrelid::regclass,pg_get_expr(c.conbin,c.conrelid)))),'[]'::json) FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace WHERE c.contype='c' AND n.nspname IN ('public','private','auth','storage','supabase_migrations');
'@
$checkQueries=Query $checkSql|ConvertFrom-Json;$checkChecked=0;foreach($q in $checkQueries){if([long](Query $q.q) -ne 0){$failures+='check-constraint-data'};$checkChecked++}
$functionSql=@'
SELECT json_agg(t ORDER BY function_name,arguments) FROM (SELECT n.nspname||'.'||p.proname function_name,pg_get_function_identity_arguments(p.oid) arguments,md5(regexp_replace(p.prosrc,'[[:space:]]','','g')) body_hash,p.prosecdef,p.proconfig FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname IN ('public','private') AND p.prokind='f') t;
'@
$functions=Query $functionSql|ConvertFrom-Json
$sourceFunctions=Get-Content -Raw (Join-Path $PSScriptRoot 'application-functions.json')|ConvertFrom-Json
foreach($f in $sourceFunctions){$a=@($functions|Where-Object {$_.function_name -eq $f.function_name -and $_.arguments -eq $f.arguments});if($a.Count -ne 1 -or $a[0].body_hash -ne $f.body_hash -or $a[0].prosecdef -ne $f.prosecdef -or ($a[0].proconfig -join ',') -ne ($f.proconfig -join ',')){$failures+='function-body-or-security'}}
# Order-independent comparison of every exported COPY row, without displaying rows or hashes.
function Fingerprint($text){$lines=[string[]]@($text.Replace("`r`n","`n").TrimEnd("`n").Split("`n"));if($text.Length -eq 0){$lines=[string[]]@()};[Array]::Sort($lines,[StringComparer]::Ordinal);$sha=[Security.Cryptography.SHA256]::Create();try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))))).Replace('-','')}finally{$sha.Dispose()}}
$data=Unseal 'data-current.sql.dpapi';$copyChecks=0
foreach($m in [regex]::Matches($data.Replace("`r`n","`n"),'(?ms)^COPY (.+?) FROM stdin;\n(.*?)^\\\.\n')){
 $rows=$m.Groups[2].Value;$restoredRows=Query ('COPY '+$m.Groups[1].Value+' TO STDOUT;')
 if((Fingerprint $rows) -ne (Fingerprint $restoredRows)){$failures+='copy-row-fingerprint'};$copyChecks++
}
if($copyChecks -ne 50){$failures+='copy-fingerprint-coverage'}
$inspect=(& docker inspect $id|ConvertFrom-Json)[0]
if($inspect.HostConfig.NetworkMode -ne 'none' -or @($inspect.Mounts|Where-Object {$_.Type -ne 'tmpfs'}).Count -gt 0 -or $inspect.HostConfig.PortBindings.PSObject.Properties.Count -gt 0){$failures+='isolation'}
$summary=[ordered]@{target=$id;source_manifest_verified=$true;tables=$actual.tables.Count;table_counts_match=($failures -notcontains 'table-count');copy_row_fingerprints_checked=$copyChecks;application_function_security_checks=@($sourceFunctions).Count;schema_object_checks=$checks;expected_object_counts=@{};actual_object_counts=@{};application_functions=$cat.app_functions;application_policies=$cat.app_policies;application_rls_tables=$cat.app_rls;foreign_keys_checked=$fkChecked;check_constraints_checked=$checkChecked;unvalidated_constraints=$cat.unvalidated_constraints;auth_identity_integrity=($cat.orphan_identities -eq 0);migration_versions=$cat.history;network=$inspect.HostConfig.NetworkMode;non_tmpfs_mounts=@($inspect.Mounts|Where-Object {$_.Type -ne 'tmpfs'}).Count;failures=$failures;passed=($failures.Count -eq 0)}
foreach($kind in $expectedObjects.Keys){$summary.expected_object_counts[$kind]=@($expectedObjects[$kind]).Count;$summary.actual_object_counts[$kind]=@($cat.$kind).Count}
$summary|ConvertTo-Json -Depth 12|Set-Content (Join-Path $work 'validation.json') -Encoding UTF8
$summary|ConvertTo-Json -Depth 12
if($failures.Count){throw 'Isolated recovery validation failed; see safe validation.json'}
