param(
    [string]$SigningDirectory = (Join-Path $env:LOCALAPPDATA 'MSGIOne\signing')
)
$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$frozenApk = Join-Path $workspace 'build\competition-release\MSGI-One-1.0.0-competition.apk'
# Stop before accessing signing material or invoking Flutter. A future release
# needs a separately reviewed version/destination; never replace the frozen demo.
if ((Test-Path -LiteralPath $frozenApk) -or (Test-Path -LiteralPath "$frozenApk.sha256")) {
    throw 'Competition artifact is frozen. Preserve it; obtain approval for a new version and destination before building another release.'
}
$store = Join-Path $SigningDirectory 'msgi-one-competition.p12'
$protectedFile = Join-Path $SigningDirectory 'password.dpapi'
if (!(Test-Path -LiteralPath $store) -or !(Test-Path -LiteralPath $protectedFile)) { throw 'Dedicated signing material missing. Run New-CompetitionSigning.ps1 once.' }
# These values exist only in this process and its build children, never in Git.
$secure = Get-Content -LiteralPath $protectedFile -Raw | ConvertTo-SecureString
$credential = New-Object Management.Automation.PSCredential('signing', $secure)
$names = @('MSGI_RELEASE_STORE_FILE', 'MSGI_RELEASE_STORE_PASSWORD', 'MSGI_RELEASE_KEY_ALIAS', 'MSGI_RELEASE_KEY_PASSWORD', 'GRADLE_OPTS')
$previous = @{}
foreach ($name in $names) { $previous[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
Push-Location $workspace
try {
    $env:MSGI_RELEASE_STORE_FILE = [IO.Path]::GetFullPath($store)
    $env:MSGI_RELEASE_STORE_PASSWORD = $credential.GetNetworkCredential().Password
    $env:MSGI_RELEASE_KEY_ALIAS = 'msgi-one-competition'
    $env:MSGI_RELEASE_KEY_PASSWORD = $env:MSGI_RELEASE_STORE_PASSWORD
    $env:GRADLE_OPTS = "$($previous['GRADLE_OPTS']) -Dorg.gradle.daemon=false"
    # Deliberately no backend defines, local URLs, authentication keys or extra args.
    & flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw 'Release APK build failed.' }
    $output = Join-Path $workspace 'build\competition-release'
    New-Item -ItemType Directory -Path $output -Force | Out-Null
    $apk = Join-Path $output 'MSGI-One-1.0.0-competition.apk'
    [IO.File]::Copy((Join-Path $workspace 'build\app\outputs\flutter-apk\app-release.apk'), $apk, $false)
    $hash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash.ToLowerInvariant()
    [IO.File]::WriteAllText("$apk.sha256", "$hash  $([IO.Path]::GetFileName($apk))`n")
    Write-Output "Release APK: $apk"
    Write-Output "SHA-256: $hash"
} finally {
    foreach ($name in $names) { [Environment]::SetEnvironmentVariable($name, $previous[$name], 'Process') }
    $credential = $null
    $secure = $null
    Pop-Location
}
