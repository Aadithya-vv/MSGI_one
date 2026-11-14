param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9_-]+$')]
    [string]$DeviceId
)
$ErrorActionPreference = 'Stop'
Push-Location ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')))
try {
    # Flutter drive otherwise uninstalls the application and deletes its data.
    & flutter drive --driver=test_driver/demo_driver.dart --target=integration_test/demo_experience_test.dart -d $DeviceId --no-pub --debug --keep-app-running
    if ($LASTEXITCODE -ne 0) { throw 'Android demo acceptance failed.' }
} finally {
    Pop-Location
}
