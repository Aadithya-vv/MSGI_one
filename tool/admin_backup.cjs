// DPAPI CurrentUser, authenticated by the OS account. Never persists plaintext.
const fs = require('node:fs'), path = require('node:path'), cp = require('node:child_process');
const { sha } = require('./admin_deployment_plan.cjs');
const { requireThat } = require('./admin_executor_state.cjs');
function crypt(bytes, decrypt=false) {
  const op=decrypt?'Unprotect':'Protect';
  const code=`$ErrorActionPreference='Stop';Add-Type -AssemblyName System.Security;try{$b=[Convert]::FromBase64String([Console]::In.ReadToEnd());$v=[Security.Cryptography.ProtectedData]::${op}($b,$null,[Security.Cryptography.DataProtectionScope]::CurrentUser);[Console]::Out.Write([Convert]::ToBase64String($v));[Array]::Clear($b,0,$b.Length);[Array]::Clear($v,0,$v.Length)}catch{exit 1}`;
  const r=cp.spawnSync('powershell.exe',['-NoProfile','-EncodedCommand',Buffer.from(code,'utf16le').toString('base64')],{input:bytes.toString('base64'),encoding:'utf8',windowsHide:true,timeout:60000,maxBuffer:256*1024*1024});
  requireThat(r.status===0 && /^[A-Za-z0-9+/=]+$/.test(r.stdout.trim()),'backup_encryption_or_decryption');
  return Buffer.from(r.stdout.trim(),'base64');
}
function protectedDirectory(dir) {
  requireThat(!fs.existsSync(dir),'backup_destination_exists');
  const code="$ErrorActionPreference='Stop';$p=[Console]::In.ReadToEnd();New-Item -ItemType Directory -Path $p -ErrorAction Stop|Out-Null;$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User;$acl=New-Object Security.AccessControl.DirectorySecurity;$acl.SetOwner($sid);$acl.SetAccessRuleProtection($true,$false);$acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow')));Set-Acl -LiteralPath $p -AclObject $acl";
  const r=cp.spawnSync('powershell.exe',['-NoProfile','-EncodedCommand',Buffer.from(code,'utf16le').toString('base64')],{input:path.resolve(dir),encoding:'utf8',windowsHide:true,timeout:15000});
  requireThat(r.status===0,'backup_acl');
}
function seal(dir, dump, metadata) {
  requireThat(Buffer.isBuffer(dump) && dump.subarray(0,5).toString()==='PGDMP','backup_format');
  protectedDirectory(dir);
  const cipher=crypt(dump);fs.writeFileSync(path.join(dir,'database.dump.dpapi'),cipher,{flag:'wx'});
  const manifest={...metadata,format:1,project_ref:'sbgshejyvkptmrffiwvd',created_utc:new Date().toISOString(),encryption:'DPAPI-CurrentUser',
    dump:{file:'database.dump.dpapi',cipher_sha256:sha(cipher),plain_sha256:sha(dump),bytes:dump.length}};
  // Both metadata and records are encrypted; a receipt digest is approved separately.
  const sealed=crypt(Buffer.from(JSON.stringify(manifest)));
  fs.writeFileSync(path.join(dir,'manifest.dpapi'),sealed,{flag:'wx'});
  return {manifest_sha256:sha(sealed),manifest};
}
function validateManifest(m,stateMD5,now=Date.now()) {
  requireThat(m.format===1 && m.project_ref==='sbgshejyvkptmrffiwvd' && m.encryption==='DPAPI-CurrentUser','backup_identity');
  requireThat(m.scope==='hosted-predeployment' && m.state_md5===stateMD5,'backup_baseline');
  const age=now-Date.parse(m.created_utc);requireThat(Number.isFinite(age)&&age>=0&&age<=4*3600*1000,'backup_stale');
  requireThat(m.recovery?.verified===true && m.recovery?.state_md5===stateMD5 && m.recovery?.dump_sha256===m.dump.plain_sha256,'backup_recovery_unverified');
  requireThat(m.dump.file==='database.dump.dpapi','backup_inventory');
}
function attest(dir, expected, recovery) {
  const raw=fs.readFileSync(path.join(dir,'manifest.dpapi'));requireThat(sha(raw)===expected,'backup_manifest_integrity');
  const m=JSON.parse(crypt(raw,true).toString());
  requireThat(recovery.verified===true&&recovery.state_md5===m.state_md5&&recovery.dump_sha256===m.dump.plain_sha256,'backup_recovery_unverified');
  // Append a ready receipt; never overwrite the original capture or manifest.
  const sealed=crypt(Buffer.from(JSON.stringify({...m,recovery})));
  fs.writeFileSync(path.join(dir,'ready-manifest.dpapi'),sealed,{flag:'wx'});
  return sha(sealed);
}
function verify(dir, expected, stateMD5, now=Date.now()) {
  const raw=fs.readFileSync(path.join(dir,'ready-manifest.dpapi'));requireThat(sha(raw)===expected,'backup_manifest_integrity');
  let m;try{m=JSON.parse(crypt(raw,true).toString());}catch{requireThat(false,'backup_manifest_decryption');}
  validateManifest(m,stateMD5,now);
  const cipher=fs.readFileSync(path.join(dir,m.dump.file));requireThat(sha(cipher)===m.dump.cipher_sha256,'backup_cipher_integrity');
  const dump=crypt(cipher,true);
  try{requireThat(sha(dump)===m.dump.plain_sha256&&dump.length===m.dump.bytes&&dump.subarray(0,5).toString()==='PGDMP','backup_plain_integrity');}finally{dump.fill(0);}
  return {verified:true,manifest_sha256:expected};
}
module.exports={crypt,protectedDirectory,seal,attest,verify,validateManifest};
