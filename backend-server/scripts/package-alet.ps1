param(
  [Parameter(Mandatory = $true)]
  [string]$Destination
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$backendRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$archivePath = [System.IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $archivePath) { throw "Archive already exists: $archivePath" }
if (-not (Test-Path -LiteralPath (Join-Path $backendRoot 'dist/index.js'))) {
  throw 'Run npm run build before packaging.'
}
$rootFiles = @('package.json', 'package-lock.json', 'tsconfig.json', 'Dockerfile', '.dockerignore', '.env.example', '.env.alet.example', 'README.alet.md')
$files = @($rootFiles | ForEach-Object { Get-Item -LiteralPath (Join-Path $backendRoot $_) })
foreach ($directory in @('src', 'dist', 'scripts', 'certs')) {
  $files += @(Get-ChildItem -LiteralPath (Join-Path $backendRoot $directory) -File -Recurse |
    Where-Object { $_.Name -notmatch '\.map$' })
}
$archive = [System.IO.Compression.ZipFile]::Open($archivePath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  foreach ($file in $files) {
    $relative = $file.FullName.Substring($backendRoot.Length + 1).Replace('\', '/')
    if ($relative -match '(^|/)(node_modules|\.git)/' -or $file.Name -eq '.env') {
      throw "Unexpected private or dependency file: $relative"
    }
    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
      $archive, $file.FullName, $relative, [System.IO.Compression.CompressionLevel]::Optimal
    ) | Out-Null
  }
} finally {
  $archive.Dispose()
}
Get-Item -LiteralPath $archivePath | Select-Object FullName, Length
