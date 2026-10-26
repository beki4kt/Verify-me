Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repositoryRoot 'assets\branding\chekmi_mark.png'
$masterPath = Join-Path $repositoryRoot 'assets\branding\chekmi_store_icon_1024.png'
$source = [System.Drawing.Image]::FromFile($sourcePath)

function New-BrandIcon {
  param(
    [Parameter(Mandatory)] [int] $Size,
    [Parameter(Mandatory)] [string] $Destination
  )

  $bitmap = [System.Drawing.Bitmap]::new(
    $Size,
    $Size,
    [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
  )
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $bounds = [System.Drawing.Rectangle]::new(0, 0, $Size, $Size)
    $start = [System.Drawing.Color]::FromArgb(13, 10, 16)
    $end = [System.Drawing.Color]::FromArgb(39, 20, 52)
    $gradient = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
      $bounds,
      $start,
      $end,
      42.0
    )
    try { $graphics.FillRectangle($gradient, $bounds) } finally { $gradient.Dispose() }

    $glowSize = [int]($Size * 0.78)
    $glowOffset = [int](($Size - $glowSize) / 2)
    $glow = [System.Drawing.SolidBrush]::new(
      [System.Drawing.Color]::FromArgb(22, 34, 211, 238)
    )
    try {
      $graphics.FillEllipse($glow, $glowOffset, $glowOffset, $glowSize, $glowSize)
    } finally { $glow.Dispose() }

    $logoSize = [int]($Size * 0.68)
    $logoOffset = [int](($Size - $logoSize) / 2)
    $logoBounds = [System.Drawing.Rectangle]::new(
      $logoOffset,
      $logoOffset,
      $logoSize,
      $logoSize
    )
    $graphics.DrawImage($source, $logoBounds)

    $directory = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $directory)) {
      New-Item -ItemType Directory -Path $directory | Out-Null
    }
    $bitmap.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $graphics.Dispose()
    $bitmap.Dispose()
  }
}

function New-TransparentMark {
  param(
    [Parameter(Mandatory)] [int] $Size,
    [Parameter(Mandatory)] [double] $Scale,
    [Parameter(Mandatory)] [string] $Destination
  )

  $bitmap = [System.Drawing.Bitmap]::new(
    $Size,
    $Size,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
  )
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $logoSize = [int]($Size * $Scale)
    $logoOffset = [int](($Size - $logoSize) / 2)
    $graphics.DrawImage(
      $source,
      [System.Drawing.Rectangle]::new($logoOffset, $logoOffset, $logoSize, $logoSize)
    )
    $directory = Split-Path -Parent $Destination
    if (-not (Test-Path -LiteralPath $directory)) {
      New-Item -ItemType Directory -Path $directory | Out-Null
    }
    $bitmap.Save($Destination, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $graphics.Dispose()
    $bitmap.Dispose()
  }
}

try {
  New-BrandIcon -Size 1024 -Destination $masterPath

  $iosDirectory = Join-Path $repositoryRoot 'ios\Runner\Assets.xcassets\AppIcon.appiconset'
  $iosIcons = @{
    'Icon-App-20x20@1x.png' = 20
    'Icon-App-20x20@2x.png' = 40
    'Icon-App-20x20@3x.png' = 60
    'Icon-App-29x29@1x.png' = 29
    'Icon-App-29x29@2x.png' = 58
    'Icon-App-29x29@3x.png' = 87
    'Icon-App-40x40@1x.png' = 40
    'Icon-App-40x40@2x.png' = 80
    'Icon-App-40x40@3x.png' = 120
    'Icon-App-60x60@2x.png' = 120
    'Icon-App-60x60@3x.png' = 180
    'Icon-App-76x76@1x.png' = 76
    'Icon-App-76x76@2x.png' = 152
    'Icon-App-83.5x83.5@2x.png' = 167
    'Icon-App-1024x1024@1x.png' = 1024
  }
  foreach ($entry in $iosIcons.GetEnumerator()) {
    New-BrandIcon -Size $entry.Value -Destination (Join-Path $iosDirectory $entry.Key)
  }

  $androidIcons = @{
    'mipmap-mdpi' = 48
    'mipmap-hdpi' = 72
    'mipmap-xhdpi' = 96
    'mipmap-xxhdpi' = 144
    'mipmap-xxxhdpi' = 192
  }
  foreach ($entry in $androidIcons.GetEnumerator()) {
    $path = Join-Path $repositoryRoot "android\app\src\main\res\$($entry.Key)\ic_launcher.png"
    New-BrandIcon -Size $entry.Value -Destination $path
  }
  New-TransparentMark -Size 432 -Scale 0.66 -Destination (
    Join-Path $repositoryRoot 'android\app\src\main\res\drawable-nodpi\ic_launcher_foreground.png'
  )
  New-TransparentMark -Size 144 -Scale 0.82 -Destination (
    Join-Path $repositoryRoot 'android\app\src\main\res\drawable-nodpi\launch_image.png'
  )

  $webDirectory = Join-Path $repositoryRoot 'web\icons'
  New-BrandIcon -Size 192 -Destination (Join-Path $webDirectory 'Icon-192.png')
  New-BrandIcon -Size 512 -Destination (Join-Path $webDirectory 'Icon-512.png')
  New-BrandIcon -Size 192 -Destination (Join-Path $webDirectory 'Icon-maskable-192.png')
  New-BrandIcon -Size 512 -Destination (Join-Path $webDirectory 'Icon-maskable-512.png')
  New-BrandIcon -Size 64 -Destination (Join-Path $repositoryRoot 'web\favicon.png')

  $launchDirectory = Join-Path $repositoryRoot 'ios\Runner\Assets.xcassets\LaunchImage.imageset'
  New-TransparentMark -Size 168 -Scale 0.88 -Destination (Join-Path $launchDirectory 'LaunchImage.png')
  New-TransparentMark -Size 336 -Scale 0.88 -Destination (Join-Path $launchDirectory 'LaunchImage@2x.png')
  New-TransparentMark -Size 504 -Scale 0.88 -Destination (Join-Path $launchDirectory 'LaunchImage@3x.png')
} finally {
  $source.Dispose()
}

Write-Output 'Generated CHEKMI iOS, Android, web, and launch assets.'
