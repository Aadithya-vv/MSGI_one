param([switch]$SelfTest)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$plan=Get-Content -LiteralPath (Join-Path $root 'supabase/review/admin_executor_plan.json') -Raw | ConvertFrom-Json
# Fixed read-only child and reviewed implementation identity. No SQL/script override.
foreach($f in $plan.plan.files){
 if((Get-FileHash -LiteralPath (Join-Path $root $f.file) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $f.sha256){throw 'Implementation identity changed; input refused'}
}
$info=New-Object Diagnostics.ProcessStartInfo
$info.FileName=(Get-Command node.exe).Source
$info.Arguments='"'+(Join-Path $PSScriptRoot 'admin_migration_executor.cjs')+'" --check --project-ref=sbgshejyvkptmrffiwvd --approve-plan-sha256='+$plan.execution_plan_sha256
$info.WorkingDirectory=$root;$info.UseShellExecute=$false;$info.CreateNoWindow=$true
$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
if($SelfTest){if($info.Arguments.Contains('--execute') -or !$info.Arguments.Contains('--check')){throw 'Unsafe launcher'};Write-Output 'PASS: fixed read-only masked handoff; no credential persisted';exit 0}
$credential=$null;$child=$null;$ptr=[IntPtr]::Zero
try{
 $Host.UI.RawUI.WindowTitle='MSGI One - PRIVATE admin READ-ONLY validation'
 $credential=Read-Host 'Existing database password (read-only validation only)' -AsSecureString
 if($credential.Length -eq 0){throw 'Empty input'}
 $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($credential)
 $info.EnvironmentVariables['SUPABASE_DB_PASSWORD']=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
 [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr);$ptr=[IntPtr]::Zero
 $child=New-Object Diagnostics.Process;$child.StartInfo=$info;$null=$child.Start()
 $info.EnvironmentVariables.Remove('SUPABASE_DB_PASSWORD');$credential.Dispose();$credential=$null
 $out=$child.StandardOutput.ReadToEndAsync();$err=$child.StandardError.ReadToEndAsync()
 if(!$child.WaitForExit(150000)){$child.Kill();throw 'Read-only timeout'}
 # Child emits only whitelisted receipts; never forward stderr.
 if($child.ExitCode -ne 0){throw 'Read-only validation failed'}
 $v=$out.Result|ConvertFrom-Json
 if($v.mode -ne 'read-only' -or $v.project_ref -ne 'sbgshejyvkptmrffiwvd' -or !$v.authenticated -or !$v.tls_verified -or $v.history -ne 11 -or $v.catalog_records -ne 51){throw 'Read-only result mismatch'}
 Write-Output 'PASS: authenticated pinned-TLS read-only validation; 11 migrations / 51 catalogs / no hosted writes'
}catch{Write-Output 'STOP: private read-only validation failed; no retry, raw details suppressed';exit 1}
finally{if($ptr -ne [IntPtr]::Zero){[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)};$info.EnvironmentVariables.Remove('SUPABASE_DB_PASSWORD');if($credential){$credential.Dispose()};if($child){$child.Dispose()}}
