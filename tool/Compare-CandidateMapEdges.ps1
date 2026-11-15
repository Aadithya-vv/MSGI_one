# Compare stationary map pixels after additional outward swipes at each edge.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$folder = Join-Path $PSScriptRoot '..\build\task12c\signed-apk'
function Get-MapPixelsHash([string]$file) {
    $image = [Drawing.Bitmap]::FromFile($file)
    try {
        if ($image.Width -ne 1080 -or $image.Height -ne 2340) { throw 'Unexpected disposable display size; review crop first.' }
        # Excludes status bar, header, zoom buttons and draggable city sheet.
        $crop = $image.Clone([Drawing.Rectangle]::new(20,950,1040,600),[Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $locked = $crop.LockBits([Drawing.Rectangle]::new(0,0,$crop.Width,$crop.Height),[Drawing.Imaging.ImageLockMode]::ReadOnly,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
            try {
                $bytes = New-Object byte[] ([Math]::Abs($locked.Stride)*$locked.Height)
                [Runtime.InteropServices.Marshal]::Copy($locked.Scan0,$bytes,0,$bytes.Length)
                $sha = [Security.Cryptography.SHA256]::Create()
                try { return ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() } finally { $sha.Dispose() }
            } finally { $crop.UnlockBits($locked) }
        } finally { $crop.Dispose() }
    } finally { $image.Dispose() }
}
$results = @()
foreach ($zoom in 0..2) {
    foreach ($edge in @('east','west')) {
        $first = Get-MapPixelsHash (Join-Path $folder "map-$zoom-$edge.png")
        $repeated = Get-MapPixelsHash (Join-Path $folder "map-$zoom-$edge-repeat.png")
        $results += [ordered]@{ zoom_step=$zoom; edge=$edge; map_pixels_sha256=$first; repeated_sha256=$repeated; identical=($first -eq $repeated) }
    }
}
$results | ConvertTo-Json -Depth 4 | Set-Content (Join-Path $folder 'edge-pixel-comparison.json') -Encoding UTF8
if (@($results | Where-Object { !$_.identical }).Count) { throw 'Map pixels changed after further outward swipes; investigate before acceptance.' }
$acceptanceFile = Join-Path $folder 'map-acceptance.json'
$acceptance = Get-Content -LiteralPath $acceptanceFile -Raw | ConvertFrom-Json
if (!$acceptance.completed) { throw 'Signed map walkthrough is incomplete.' }
$acceptance.edge_pixel_comparison_pending = $false
$acceptance | Add-Member -NotePropertyName edge_comparisons_passed -NotePropertyValue 6 -Force
$acceptance | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $acceptanceFile -Encoding UTF8
Write-Output 'Six edge comparisons passed: further outward swipes leave map pixels identical.'
