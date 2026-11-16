# Deterministic packaging only: crop/contain/resize, no redraw or recoloring.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
$workspace=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source=Join-Path $workspace 'assets\branding\msgi-one-logo-original.png'
if((Get-FileHash $source).Hash.ToLowerInvariant() -ne '6b2ba085ddf111e60508f8507b73d7034f5bebf981da3b9b9469f862aa1b7f54'){throw 'Approved original logo differs; review before generating assets'}
$image=[Drawing.Bitmap]::FromFile($source)
function Save-Contained([Drawing.Image]$art,[int]$canvas,[int]$artWidth,[string]$relative,[bool]$opaque=$false){
 $path=Join-Path $workspace $relative
 [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))|Out-Null
 $bitmap=[Drawing.Bitmap]::new($canvas,$canvas,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
 $graphics=[Drawing.Graphics]::FromImage($bitmap)
 try{
  if($opaque){$graphics.Clear([Drawing.Color]::FromArgb(255,245,247,252))}else{$graphics.Clear([Drawing.Color]::Transparent)}
  $graphics.InterpolationMode=[Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode=[Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $height=[int][Math]::Round($artWidth*$art.Height/$art.Width)
  $graphics.DrawImage($art,[Drawing.Rectangle]::new([int](($canvas-$artWidth)/2),[int](($canvas-$height)/2),$artWidth,$height))
  $bitmap.Save($path,[Drawing.Imaging.ImageFormat]::Png)
 }finally{$graphics.Dispose();$bitmap.Dispose()}
}
try{
 if($image.Width -ne 1254 -or $image.Height -ne 1254){throw 'Unexpected source dimensions'}
 # Contains the complete emblem above the wordmark, including its edge pixels.
 $emblem=$image.Clone([Drawing.Rectangle]::new(150,118,960,774),[Drawing.Imaging.PixelFormat]::Format32bppArgb)
 try{
  $emblem.Save((Join-Path $workspace 'assets\branding\msgi-one-emblem.png'),[Drawing.Imaging.ImageFormat]::Png)
  foreach($entry in @(@('mdpi',48),@('hdpi',72),@('xhdpi',96),@('xxhdpi',144),@('xxxhdpi',192))){
   Save-Contained $emblem $entry[1] ([int]($entry[1]*0.82)) ('android/app/src/main/res/mipmap-'+$entry[0]+'/ic_launcher.png') $true
  }
  Save-Contained $emblem 432 240 'android/app/src/main/res/drawable-xxxhdpi/msgi_launcher_foreground.png'
  Save-Contained $emblem 1152 672 'android/app/src/main/res/drawable-xxxhdpi/msgi_splash_icon.png'
  Save-Contained $image 800 800 'android/app/src/main/res/drawable-xxxhdpi/msgi_splash_legacy.png'
 }finally{$emblem.Dispose()}
}finally{$image.Dispose()}
Write-Output 'Approved original preserved; emblem crop and proportional Android assets prepared.'
