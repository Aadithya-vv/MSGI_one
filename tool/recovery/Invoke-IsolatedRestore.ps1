param([Parameter(Mandatory=$true)][string]$BackupDirectory)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Security
$source=(Resolve-Path -LiteralPath $BackupDirectory).Path
$expectedManifest='6ce4fa5779fbff0ec6bafc821ca25bddc5b2fcf52834bd7b49daaebc7d38dbfa'
if((Get-FileHash (Join-Path $source 'manifest.json') -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedManifest){throw 'Manifest integrity mismatch'}
$manifest=Get-Content -Raw (Join-Path $source 'manifest.json')|ConvertFrom-Json
if($manifest.project_ref -ne 'sbgshejyvkptmrffiwvd' -or $manifest.backup_id -ne '20261114T134947Z-3d9e4376'){throw 'Unexpected source project or backup identity'}
$sourceAcl=Get-Acl -LiteralPath $source
$currentSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
if(!$sourceAcl.AreAccessRulesProtected -or @($sourceAcl.Access|Where-Object {$_.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value -ne $currentSid}).Count){throw 'Source backup access controls differ from verified user-only policy'}
$id='msgi-recovery-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8)
$work=Join-Path $env:LOCALAPPDATA ('MSGIOne\recovery\'+$id)
New-Item -ItemType Directory -Path $work|Out-Null
$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User
$acl=New-Object Security.AccessControl.DirectorySecurity
$acl.SetOwner($sid);$acl.SetAccessRuleProtection($true,$false)
$rule=New-Object Security.AccessControl.FileSystemAccessRule($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow')
$acl.AddAccessRule($rule);Set-Acl -LiteralPath $work -AclObject $acl
$state=[ordered]@{id=$id;work=$work;source=$source;image='public.ecr.aws/supabase/postgres:17.11.0.019';database='recovery';network='none';shared_volumes=$false;status='starting';steps=@();integrity_files=0;restored=$false}
$statePath=Join-Path $work 'state.json'
Write-Output ("New isolated recovery destination: "+$id+" / "+$work)
function Save-State {$state|ConvertTo-Json -Depth 10|Set-Content $statePath -Encoding UTF8}
function Hash-Bytes([byte[]]$b){$h=[Security.Cryptography.SHA256]::Create();try{([BitConverter]::ToString($h.ComputeHash($b))).Replace('-','').ToLowerInvariant()}finally{$h.Dispose()}}
function Seal-Text($name,$text){$b=[Text.Encoding]::UTF8.GetBytes($text);$c=[Security.Cryptography.ProtectedData]::Protect($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser);[IO.File]::WriteAllBytes((Join-Path $work ($name+'.dpapi')),$c)}
function Docker-Step($name,[string[]]$arguments){$result=& docker @arguments 2>&1;$exit=$LASTEXITCODE;Seal-Text ($name+'.log') ($result -join "`n");$state.steps+=@{name=$name;exit=$exit};Save-State;if($exit -ne 0){throw "Step $name failed; details retained only in encrypted local log"};return ($result -join "`n")}
function Run-SqlFile($name,$path){
 $psi=New-Object Diagnostics.ProcessStartInfo
 $psi.FileName='docker';$psi.Arguments="exec -i $id psql -h /tmp -X -U postgres -d recovery -v ON_ERROR_STOP=1"
 $psi.UseShellExecute=$false;$psi.RedirectStandardInput=$true;$psi.RedirectStandardOutput=$true;$psi.RedirectStandardError=$true;$psi.CreateNoWindow=$true
 $p=New-Object Diagnostics.Process;$p.StartInfo=$psi;$null=$p.Start()
 $out=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync()
 $b=[IO.File]::ReadAllBytes($path);$p.StandardInput.BaseStream.Write($b,0,$b.Length);$p.StandardInput.Close();$p.WaitForExit()
 Seal-Text ($name+'.log') ($out.Result+"`n"+$err.Result)
 $state.steps+=@{name=$name;exit=$p.ExitCode};Save-State
 if($p.ExitCode -ne 0){throw "Step $name failed; details retained only in encrypted local log"}
}
function Write-Sql($name,$text){$p=Join-Path $work ($name+'.sql');[IO.File]::WriteAllText($p,$text,(New-Object Text.UTF8Encoding($false)));return $p}
Save-State
try{
 foreach($f in $manifest.files){
  $cipher=[IO.File]::ReadAllBytes((Join-Path $source $f.name));if((Hash-Bytes $cipher) -ne $f.sha256_encrypted){throw 'Ciphertext hash mismatch'}
  $plain=[Security.Cryptography.ProtectedData]::Unprotect($cipher,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
  if((Hash-Bytes $plain) -ne $f.sha256_plaintext -or $plain.Length -ne $f.plaintext_bytes){throw 'Plaintext integrity mismatch'}
  if($f.name -in @('roles.sql.dpapi','managed-schema.sql.dpapi','application-schema.sql.dpapi','history-schema.sql.dpapi','data-current.sql.dpapi')){[IO.File]::WriteAllBytes((Join-Path $work ($f.name -replace '\.dpapi$','')),$plain)}
  [Array]::Clear($plain,0,$plain.Length);$state.integrity_files++
 }
 $null=Docker-Step 'create' @('run','--pull','never','-d','--name',$id,'--network','none','--read-only','--no-healthcheck','--cap-drop','ALL','--security-opt','no-new-privileges','--memory','1536m','--cpus','2','--user','postgres','--tmpfs','/recovery:rw,noexec,nosuid,size=768m,uid=100,gid=101,mode=0700','--tmpfs','/tmp:rw,noexec,nosuid,size=128m,uid=100,gid=101,mode=0700','--entrypoint','/bin/sh',$state.image,'-c','initdb -D /recovery -A trust --no-locale --encoding=UTF8 >/tmp/init.log 2>&1 && exec postgres -D /recovery -c listen_addresses= -c unix_socket_directories=/tmp -c shared_preload_libraries=pg_stat_statements')
 $ready=$false
 for($i=0;$i -lt 30;$i++){ $r=& docker exec $id pg_isready -h /tmp -U postgres 2>&1;if($LASTEXITCODE -eq 0){$ready=$true;break};Start-Sleep -Milliseconds 500 }
 if(!$ready){throw 'New isolated PostgreSQL did not become ready'}
 # Explicit socket argument avoids any dependency on existing local/remote endpoints.
 $null=Docker-Step 'create-database' @('exec',$id,'createdb','-h','/tmp','-U','postgres','recovery')
 # No host PostgreSQL connection is used.
 $bootstrap=@'
DO $bootstrap$ DECLARE r text; BEGIN
 FOREACH r IN ARRAY ARRAY['anon','authenticated','authenticator','service_role','supabase_admin','supabase_auth_admin','supabase_storage_admin','dashboard_user'] LOOP
 IF NOT EXISTS(SELECT FROM pg_roles WHERE rolname=r) THEN EXECUTE format('CREATE ROLE %I NOLOGIN',r); END IF;
 END LOOP;
END $bootstrap$;
CREATE SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_stat_statements WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE SCHEMA vault;
CREATE EXTENSION IF NOT EXISTS supabase_vault WITH SCHEMA vault;
'@
 Run-SqlFile 'bootstrap' (Write-Sql 'bootstrap' $bootstrap)
 foreach($f in @('roles.sql','managed-schema.sql','application-schema.sql','history-schema.sql')){Run-SqlFile ($f -replace '\.sql$','') (Join-Path $work $f)}
 $data="BEGIN;`nSET LOCAL session_replication_role = replica;`n"+[IO.File]::ReadAllText((Join-Path $work 'data-current.sql'))+"`nCOMMIT;`n"
 Run-SqlFile 'data-restore' (Write-Sql 'data-restore' $data)
 $cipher=[IO.File]::ReadAllBytes((Join-Path $source 'platform-history.log.dpapi'))
 $b=[Security.Cryptography.ProtectedData]::Unprotect($cipher,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
 $t=[Text.Encoding]::UTF8.GetString($b);if($b[0] -eq 255){$t=[Text.Encoding]::Unicode.GetString($b)}
 $history=($t.Substring($t.IndexOf('{'))|ConvertFrom-Json).rows[0].platform_history
 $sql="BEGIN;`n"
 foreach($table in @('auth.schema_migrations','storage.migrations')){
  $rows=$history.PSObject.Properties[$table].Value
  $json=ConvertTo-Json -InputObject @($rows) -Depth 40 -Compress
  $tag='$recovery_'+[guid]::NewGuid().ToString('N')+'$'
  $sql+="INSERT INTO $table SELECT * FROM json_populate_recordset(NULL::$table, $tag$json$tag::json);`n"
 }
 $sql+="COMMIT;`n";Run-SqlFile 'platform-history' (Write-Sql 'platform-history' $sql)
 $state.restored=$true;$state.status='restored-awaiting-validation';Save-State
& (Join-Path $PSScriptRoot 'Test-IsolatedRestore.ps1') -RecoveryDirectory $work
if(!$?){throw 'Isolated validation failed'}
$state.status='verified-logical-restore';Save-State
 Write-Output "RESTORED: $id; all restore steps passed ON_ERROR_STOP. Private state and logs retained in restricted recovery directory."
}catch{$state.status='failed';Save-State;Write-Error 'Recovery failed; inspect only restricted encrypted logs. Never rerun against an existing target.'}
finally{
 foreach($file in Get-ChildItem -LiteralPath $work -Filter '*.sql' -File){
  $b=[IO.File]::ReadAllBytes($file.FullName)
  $encrypted=[Security.Cryptography.ProtectedData]::Protect($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
  $sealed=$file.FullName+'.dpapi';[IO.File]::WriteAllBytes($sealed,$encrypted)
  $verify=[Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($sealed),$null,[Security.Cryptography.DataProtectionScope]::CurrentUser)
  if((Hash-Bytes $b) -ne (Hash-Bytes $verify)){throw 'Staging encryption validation failed; plaintext retained in restricted folder'}
  [Array]::Clear($b,0,$b.Length);[Array]::Clear($verify,0,$verify.Length)
  Remove-Item -LiteralPath $file.FullName
 }
}
