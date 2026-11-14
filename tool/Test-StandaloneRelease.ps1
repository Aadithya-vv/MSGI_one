param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^emulator-\d+$')]
    [string]$DeviceId,
    [string]$OutputDirectory = 'build/competition-release/emulator-acceptance'
)
$ErrorActionPreference = 'Stop'
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$checks = New-Object Collections.Generic.List[string]
function Read-Ui {
    & $adb -s $DeviceId shell uiautomator dump /sdcard/msgi-release-check.xml | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'UI tree dump failed' }
    $raw = & $adb -s $DeviceId shell cat /sdcard/msgi-release-check.xml
    return [xml]($raw -join "`n")
}
function Nodes($ui) { return @($ui.SelectNodes('//node')) }
function Label($node) { return "$($node.text)$($node.'content-desc')" }
function Tap([string]$pattern) {
    $ui = Read-Ui
    $node = @(Nodes $ui | Where-Object { (Label $_) -match $pattern } | Select-Object -First 1)
    if (!$node.Count) { throw "Control not found: $pattern" }
    $bounds = @([regex]::Matches($node[0].bounds, '\d+') | ForEach-Object { [int]$_.Value })
    & $adb -s $DeviceId shell input tap ([int](($bounds[0]+$bounds[2])/2)) ([int](($bounds[1]+$bounds[3])/2))
    Start-Sleep -Milliseconds 500
}
function Check([string]$pattern, [string]$name) {
    $ui = Read-Ui
    if (!@(Nodes $ui | Where-Object { (Label $_) -match $pattern }).Count) { throw "Screen assertion failed: $name" }
    $checks.Add($name)
    & $adb -s $DeviceId shell screencap -p /sdcard/msgi-release-check.png
    # ADB progress is written to stderr even on success in Windows PowerShell.
    $savedPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $adb -s $DeviceId pull /sdcard/msgi-release-check.png (Join-Path $OutputDirectory "$name.png") 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'Screenshot pull failed' }
    } finally {
        $ErrorActionPreference = $savedPreference
    }
}
$ui = Read-Ui
if (@(Nodes $ui | Where-Object { (Label $_) -eq 'Explore Demo' }).Count) { Tap '^Explore Demo$' }
$ui = Read-Ui
if (@(Nodes $ui | Where-Object { (Label $_) -match '^Student demo' }).Count) { Tap '^Student demo' }
$ui = Read-Ui
if (@(Nodes $ui | Where-Object { (Label $_) -eq 'Alumni' }).Count) { Tap '^Alumni$'; Tap '^Student$' }
if (@(Nodes $ui | Where-Object { (Label $_) -eq 'Staff / Faculty' }).Count) { Tap '^Staff / Faculty$'; Tap '^Student$' }
Check 'Welcome, Mira Rao' 'student-home'
Tap '^Discover\s+Tab'; Check 'Discover|alumni' 'student-discovery'
Tap '^Map\s+Tab'; Check 'Global alumni map' 'student-map'
Tap '^Network\s+Tab'; Check 'My network' 'student-network'
Tap '^Profile\s+Tab'; Check 'Mira Rao' 'student-profile'
Tap '^Home\s+Tab'; Tap '^Find a mentor$'; Check 'Mentor recommendations' 'student-mentors'
& $adb -s $DeviceId shell input keyevent 4
Check 'Welcome, Mira Rao' 'mentor-android-back'
Tap '^Opportunities$'; Check 'Career Bridge|Opportunities' 'student-opportunities'
& $adb -s $DeviceId shell input keyevent 4
Tap '^Student$'; Tap '^Alumni$'; Check 'Welcome, Arjun Iyer' 'alumni-home'
Tap '^Profile\s+Tab'; Check 'Arjun Iyer' 'alumni-profile'
Tap '^Home\s+Tab'; Tap '^Alumni$'; Tap '^Staff / Faculty$'; Check 'Welcome, Kavya Sen' 'staff-home'
Tap '^Profile\s+Tab'; Check 'Kavya Sen' 'staff-profile'
Tap '^Home\s+Tab'
& $adb -s $DeviceId shell am force-stop com.msgi.nexus.msgi_nexus
& $adb -s $DeviceId shell am start -W -n com.msgi.nexus.msgi_nexus/.MainActivity | Out-File (Join-Path $OutputDirectory 'restart-timing.txt')
Check 'Welcome, Kavya Sen' 'staff-persisted-after-restart'
$checks | ConvertTo-Json | Set-Content (Join-Path $OutputDirectory 'passed-checks.json')
Write-Output "PASS: $($checks.Count) standalone release emulator checks."
