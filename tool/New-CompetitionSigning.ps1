param(
    [string]$SigningDirectory = (Join-Path $env:LOCALAPPDATA 'MSGIOne\signing')
)
$ErrorActionPreference = 'Stop'
$keytool = Join-Path $env:ProgramFiles 'Android\Android Studio\jbr\bin\keytool.exe'
if (!(Test-Path -LiteralPath $keytool)) { throw 'Android Studio keytool unavailable.' }
$directory = [IO.Path]::GetFullPath($SigningDirectory)
if (Test-Path -LiteralPath $directory) { throw 'Signing directory exists; refusing to overwrite any key or credentials.' }
New-Item -ItemType Directory -Path $directory | Out-Null
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true, $false)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent().User
$rule = New-Object Security.AccessControl.FileSystemAccessRule($identity, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
$acl.AddAccessRule($rule)
Set-Acl -LiteralPath $directory -AclObject $acl
$bytes = New-Object byte[] 32
$rng = [Security.Cryptography.RandomNumberGenerator]::Create()
$rng.GetBytes($bytes)
$rng.Dispose()
$password = [Convert]::ToBase64String($bytes)
$env:MSGI_NEW_SIGNING_PASSWORD = $password
try {
    $store = Join-Path $directory 'msgi-one-competition.p12'
    & $keytool -genkeypair -noprompt -storetype PKCS12 -keystore $store -alias msgi-one-competition -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=MSGI One Competition, OU=Development' -storepass:env MSGI_NEW_SIGNING_PASSWORD -keypass:env MSGI_NEW_SIGNING_PASSWORD
    if ($LASTEXITCODE -ne 0) { throw 'Keystore generation failed; existing output will not be overwritten automatically.' }
    $protected = ConvertTo-SecureString $password -AsPlainText -Force | ConvertFrom-SecureString
    [IO.File]::WriteAllText((Join-Path $directory 'password.dpapi'), $protected)
    [IO.File]::WriteAllText((Join-Path $directory 'BACKUP-REQUIRED.txt'), 'Back up the keystore and independently escrow its password using your password manager. The DPAPI file is tied to this Windows account and machine and is not a portable backup. Never commit or distribute signing material with the APK.')
    Write-Output "Dedicated signing material created in $directory. Password output is suppressed. Backup is required."
} finally {
    Remove-Item Env:MSGI_NEW_SIGNING_PASSWORD -ErrorAction SilentlyContinue
    $password = $null
    [Array]::Clear($bytes, 0, $bytes.Length)
}
