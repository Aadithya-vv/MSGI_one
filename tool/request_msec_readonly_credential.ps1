param([switch]$SelfTest, [string]$ReceiptPath)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$entry = Join-Path $PSScriptRoot 'check_msec_secure_connection.cjs'

function New-ReadOnlyChild([Security.SecureString]$Credential) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = (Get-Command node.exe -ErrorAction Stop).Source
    $info.Arguments = '"' + $entry + '"'
    $info.WorkingDirectory = $root
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential)
    try {
        $info.EnvironmentVariables['SUPABASE_DB_PASSWORD'] = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
    } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
    return $info
}

if ($SelfTest) {
    $before = [Environment]::GetEnvironmentVariable('SUPABASE_DB_PASSWORD', 'Process')
    $synthetic = ConvertTo-SecureString 'SYNTHETIC_LOCAL_HANDOFF_ONLY' -AsPlainText -Force
    try {
        $info = New-ReadOnlyChild $synthetic
        if ($info.UseShellExecute -or !$info.RedirectStandardOutput -or !$info.RedirectStandardError) { throw 'Unsafe child process configuration' }
        if ($info.Arguments -ne ('"' + $entry + '"') -or $info.Arguments.Contains('SYNTHETIC_') -or $info.Arguments.Contains('--execute')) { throw 'Unsafe child command' }
        if ($info.EnvironmentVariables['SUPABASE_DB_PASSWORD'] -ne 'SYNTHETIC_LOCAL_HANDOFF_ONLY') { throw 'Private child handoff failed' }
        if ([Environment]::GetEnvironmentVariable('SUPABASE_DB_PASSWORD', 'Process') -ne $before) { throw 'Parent environment changed' }
        $info.EnvironmentVariables.Remove('SUPABASE_DB_PASSWORD')
        if ($info.EnvironmentVariables.ContainsKey('SUPABASE_DB_PASSWORD')) { throw 'Child environment not cleared' }
        Write-Output 'PASS: fixed read-only child; no credential in argv; parent environment unchanged; private child environment cleared. No connection attempted.'
    } finally { $synthetic.Dispose() }
    exit 0
}

# A private-input window must never accept an arbitrary script or SQL operation.
$expected = @{
    'tool/check_msec_secure_connection.cjs' = '63f419c68237ab7f846c56b88a03ce15840c84405bc3c392dabe31154545db71'
    'tool/msec_catalog_session.cjs' = '3ea90ff3f257d425ba5c31073e345e2532d4635f5b139b66e224b8ede2dc1722'
    'tool/msec_tls_policy.cjs' = '2d633c3cff12b787412a25279899b7373e4ba523cdc60b8d5d79d1aa049cdcbd'
    'tool/deploy_msec_reference.cjs' = 'fbe21267ac43a7d3e7562c18712df3fa5eb41f5a6a1aa19030a0f20a1a272cfe'
    'tool/supabase_cli_json.cjs' = '26b139dca22f6ab4cbca9517d163879ecb89ac07c7c85e6720432f556ca3b74a'
    'tool/msec_session_diagnostics.cjs' = '845770134969b4369808e00d23b81d8d14640e07ba93e0dd6dc5c1abe6b39a20'
    'tool/render_msec_reference.cjs' = '787d8d4b6e7d41fa81f36cf3df04f99230e83b712254c264e5ab35bc2e853574'
    'supabase/catalogs/msec_reference_atomic.sql' = '153f97a2eaff6fa02a723a65bcf4c135ab91bc63b2acb8dc151c93966833e428'
    'tool/certs/supabase-prod-ca-2021.crt' = '700723581420dd1ac98fd7e9ac529f0ef210eadcaf87fc868a3ad7d114c2f3b7'
}
foreach ($file in $expected.Keys) {
    if ((Get-FileHash -LiteralPath (Join-Path $root $file) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected[$file]) { throw 'Reviewed read-only implementation changed; no credential requested' }
}
$build = [IO.Path]::GetFullPath((Join-Path $root 'build'))
$receipt = [IO.Path]::GetFullPath($ReceiptPath)
if (!$receipt.StartsWith($build + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -or
    [IO.Path]::GetFileName($receipt) -notmatch '^task11b5e-private-[a-f0-9-]{36}\.json$' -or (Test-Path -LiteralPath $receipt)) {
    throw 'Unexpected or existing receipt path'
}
[IO.File]::WriteAllText($receipt, '{"status":"awaiting_private_input"}')
function Save-SafeReceipt($Value) { $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $receipt -Encoding UTF8 }

$credential = $null
$child = $null
$info = $null
try {
    $Host.UI.RawUI.WindowTitle = 'MSGI One - PRIVATE read-only database authentication'
    Write-Host 'READ-ONLY: sbgshejyvkptmrffiwvd / postgres'
    Write-Host 'Pinned Supabase CA, exact hostname, verify-full. No catalog deployment.'
    Write-Host 'Enter the existing DATABASE password here only. Input is masked; never send it in chat.'
    $credential = Read-Host -Prompt 'Database password' -AsSecureString
    if ($credential.Length -eq 0) { Save-SafeReceipt @{status='cancelled'}; exit 2 }
    $info = New-ReadOnlyChild $credential
    Save-SafeReceipt @{status='running_read_only_validation'}
    $child = New-Object Diagnostics.Process
    $child.StartInfo = $info
    $null = $child.Start()
    # The OS has copied the child environment; do not retain the handoff in PSI.
    $info.EnvironmentVariables.Remove('SUPABASE_DB_PASSWORD')
    $credential.Dispose(); $credential = $null
    $out = $child.StandardOutput.ReadToEndAsync()
    $err = $child.StandardError.ReadToEndAsync()
    if (!$child.WaitForExit(90000)) {
        try { $child.Kill() } catch {}
        Save-SafeReceipt @{status='validation_timeout';automatic_retry=$false}; exit 3
    }
    # Never persist stderr or arbitrary stdout. Project reference/counts/SSL/history only.
    try { $data = $out.Result | ConvertFrom-Json } catch { throw 'Read-only result unavailable' }
    if ($data.metadata.project_ref -ne 'sbgshejyvkptmrffiwvd') { throw 'Read-only result target mismatch' }
    $a = $data.acceptance
    $versions = @('20261112000100','20261112000200','20261112000300','20261113000100','20261113000200','20261113000300','20261114000100','20261114000200','20261114000300','20261114000400','20261114000500')
    if ($child.ExitCode -eq 0 -and $a.authenticated -eq $true -and $a.read_only -eq 'on' -and
        $a.database -eq 'postgres' -and $a.role -eq 'postgres' -and $a.ssl -eq $true -and
        $a.tls_version -in @('TLSv1.2','TLSv1.3') -and (@($a.history) -join ',') -eq ($versions -join ',') -and
        $data.metadata.execution_plan_sha256 -eq '1dc1532047b90c92e8eab593bd57715d8a736178b35e61c912a72e7d72f52a5a' -and
        $data.metadata.payload_sha256 -eq '153f97a2eaff6fa02a723a65bcf4c135ab91bc63b2acb8dc151c93966833e428' -and
        $a.institutions -eq 0 -and $a.departments -eq 0 -and $a.programmes -eq 0 -and $a.skills -eq 0) {
        Save-SafeReceipt @{status='succeeded';project_ref='sbgshejyvkptmrffiwvd';authenticated=$true;tls_verified=$true;
            read_only='on';database='postgres';role='postgres';tls_version=$a.tls_version;history=@($a.history);
            counts=@{institutions=0;departments=0;programmes=0;skills=0};
            execution_plan_sha256=$data.metadata.execution_plan_sha256;payload_sha256=$data.metadata.payload_sha256}
        Write-Host 'Read-only authentication PASSED. No deployment performed.'
    } else {
        $category = 'unclassified_failure'
        if ($a.diagnostic.classification -in @('authentication_rejected','password_unavailable','network_unreachable','dns_failure','tls_validation_failure','connection_timeout','connection_refused')) { $category = $a.diagnostic.classification }
        Save-SafeReceipt @{status='validation_failed';classification=$category;automatic_retry=$false}
        Write-Host 'Read-only validation failed. No retry or deployment performed.'
    }
} catch {
    Save-SafeReceipt @{status='validation_failed';classification='safe_handoff_or_result_failure';automatic_retry=$false}
    Write-Host 'Private validation stopped. Raw errors suppressed. No deployment performed.'
} finally {
    if ($info) { $info.EnvironmentVariables.Remove('SUPABASE_DB_PASSWORD') }
    if ($credential) { $credential.Dispose() }
    if ($child) { $child.Dispose() }
}
