# Fixed, owner-authorized Task 12C destination. No arbitrary Flutter arguments.
$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$original = Join-Path $workspace 'build\competition-release\MSGI-One-1.0.0-competition.apk'
$expected = 'aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809'
$output = Join-Path $workspace 'build\competition-release-candidate\MSGI-One-1.0.1-rc1.apk'
if ((Get-FileHash -LiteralPath $original).Hash.ToLowerInvariant() -ne $expected) { throw 'Original APK changed.' }
if ((Test-Path -LiteralPath $output) -or (Test-Path -LiteralPath "$output.sha256")) { throw 'Candidate exists; refusing replacement.' }
$signing = Join-Path $env:LOCALAPPDATA 'MSGIOne\signing'
$store = Join-Path $signing 'msgi-one-competition.p12'
$protected = Join-Path $signing 'password.dpapi'
if (!(Test-Path -LiteralPath $store) -or !(Test-Path -LiteralPath $protected)) { throw 'Approved signing identity unavailable.' }
$javaHome = 'C:\Program Files\Android\Android Studio\jbr'
$apksigner = Join-Path $env:LOCALAPPDATA 'Android\Sdk\build-tools\36.0.0\apksigner.bat'
if (!(Test-Path -LiteralPath (Join-Path $javaHome 'bin\java.exe')) -or !(Test-Path -LiteralPath $apksigner)) { throw 'Existing signing verifier unavailable.' }
$names = @('MSGI_RELEASE_STORE_FILE','MSGI_RELEASE_STORE_PASSWORD','MSGI_RELEASE_KEY_ALIAS','MSGI_RELEASE_KEY_PASSWORD','GRADLE_OPTS','JAVA_HOME')
$previous = @{}
foreach ($name in $names) { $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
Push-Location $workspace
try {
    $secure = Get-Content -LiteralPath $protected -Raw | ConvertTo-SecureString
    $credential = New-Object Management.Automation.PSCredential('signing', $secure)
    $env:MSGI_RELEASE_STORE_FILE = $store
    $env:MSGI_RELEASE_STORE_PASSWORD = $credential.GetNetworkCredential().Password
    $env:MSGI_RELEASE_KEY_PASSWORD = $env:MSGI_RELEASE_STORE_PASSWORD
    $env:MSGI_RELEASE_KEY_ALIAS = 'msgi-one-competition'
    $env:JAVA_HOME = $javaHome
    $env:GRADLE_OPTS = "$($previous['GRADLE_OPTS']) -Dorg.gradle.daemon=false"
    # Refresh generated plugin registration after Flutter integration runs.
    # Keep the committed lockfile; do not upgrade dependencies.
    & flutter build apk --release --build-name=1.0.1 --build-number=2 --dart-define=MSGI_COMPETITION_ONLY=true
    if ($LASTEXITCODE -ne 0) { throw 'Candidate release build failed.' }
    $built = Join-Path $workspace 'build\app\outputs\flutter-apk\app-release.apk'
    # Capture native warnings separately: Windows PowerShell treats stderr as
    # terminating errors even when apksigner returns success. Trust its exit code
    # and validated certificate, never suppress a failed verification.
    $jar = Join-Path ([IO.Path]::GetDirectoryName($apksigner)) 'lib\apksigner.jar'
    $verifyProcess = Start-Process -FilePath (Join-Path $javaHome 'bin\java.exe') -ArgumentList @('--enable-native-access=ALL-UNNAMED','-jar',"`"$jar`"",'verify','--verbose','--print-certs',"`"$built`"") -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput 'build\task12c\signature-stdout.txt' -RedirectStandardError 'build\task12c\signature-stderr.txt'
    if ($verifyProcess.ExitCode -ne 0) { throw 'Candidate signature verification failed.' }
    $verification = Get-Content 'build\task12c\signature-stdout.txt'
    $cert = '857fbe0fc6d3366bb46c59745fce24eb03cef23b78a6b030a24148fb0d995cc4'
    if (($verification -join "`n") -notmatch "certificate SHA-256 digest: $cert") { throw 'Candidate certificate differs from approved identity.' }
    if ((Get-FileHash -LiteralPath $original).Hash.ToLowerInvariant() -ne $expected) { throw 'Original APK changed during build.' }
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($output)) | Out-Null
    [IO.File]::Copy($built, $output, $false)
    $hash = (Get-FileHash -LiteralPath $output).Hash.ToLowerInvariant()
    $stream = [IO.File]::Open("$output.sha256", [IO.FileMode]::CreateNew)
    try { $bytes = [Text.Encoding]::UTF8.GetBytes("$hash  $([IO.Path]::GetFileName($output))`n"); $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
    $verification | Set-Content 'build\task12c\signature-verification.txt' -Encoding UTF8
    Write-Output "Candidate: $output"
    Write-Output "SHA-256: $hash"
} finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process') }
    $credential = $null; $secure = $null
    Pop-Location
}
