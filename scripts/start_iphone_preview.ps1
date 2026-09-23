[CmdletBinding()]
param(
  [ValidateRange(1024, 65535)]
  [int]$Port = 8087,

  [switch]$Functional,

  [switch]$VisualOnly,

  [switch]$Development,

  [ValidatePattern('^(?:\d{1,3}\.){3}\d{1,3}$')]
  [string]$HostAddress
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Find-ChekmiLanAddress {
  foreach ($networkInterface in [Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()) {
    if (
      $networkInterface.OperationalStatus -ne [Net.NetworkInformation.OperationalStatus]::Up -or
      $networkInterface.NetworkInterfaceType -in @(
        [Net.NetworkInformation.NetworkInterfaceType]::Loopback,
        [Net.NetworkInformation.NetworkInterfaceType]::Tunnel
      )
    ) {
      continue
    }

    $properties = $networkInterface.GetIPProperties()
    $hasIpv4Gateway = $properties.GatewayAddresses | Where-Object {
      $_.Address.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork -and
      $_.Address.ToString() -ne '0.0.0.0'
    }

    if ($null -eq $hasIpv4Gateway) {
      continue
    }

    $address = $properties.UnicastAddresses | Where-Object {
      $_.Address.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork -and
      -not $_.Address.ToString().StartsWith('169.254.')
    } | Select-Object -First 1

    if ($null -ne $address) {
      return $address.Address.ToString()
    }
  }

  throw 'No active local IPv4 address was found. Connect this PC and the iPhone to the same Wi-Fi network, or pass -HostAddress explicitly.'
}

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$flutterCommand = Get-Command flutter -ErrorAction Stop
$previewAddress = if ($HostAddress) { $HostAddress } else { Find-ChekmiLanAddress }
$previewUrl = "http://${previewAddress}:$Port"

if ($Functional -and $VisualOnly) {
  throw 'Choose either -Functional or -VisualOnly, not both.'
}

$flutterArguments = @(
  'run',
  '-d',
  'web-server',
  '--web-hostname=0.0.0.0',
  "--web-port=$Port",
  '--dart-define=CHEKMI_IPHONE_UI=true'
)

if (-not $Development) {
  $flutterArguments += '--release'
}

if ($Functional) {
  $stagingConfiguration = Join-Path $repositoryRoot 'config\staging.json'
  if (-not (Test-Path -LiteralPath $stagingConfiguration -PathType Leaf)) {
    throw 'Functional mode needs config\staging.json. Copy config\staging.example.json, then enter the staging HTTPS values.'
  }

  $flutterArguments += '--dart-define-from-file=config/staging.json'
  Write-Host 'Starting the functional iPhone UI with the staging configuration.' -ForegroundColor Cyan
} elseif ($VisualOnly) {
  $flutterArguments += @(
    '--dart-define=CHEKMI_ENV=development',
    '--dart-define=CHEKMI_UI_PREVIEW=true'
  )
  Write-Host 'Starting the deterministic iPhone visual preview.' -ForegroundColor Cyan
} else {
  $flutterArguments += '--dart-define=CHEKMI_ENV=development'
  Write-Host 'Starting the interactive iPhone demo with local device storage.' -ForegroundColor Cyan
}

Write-Host "Open Safari on the iPhone at: $previewUrl" -ForegroundColor Green
Write-Host $(if ($Development) { 'Runtime: development (hot reload).' } else { 'Runtime: optimized release.' })
Write-Host "Keep this window open. Press Ctrl+C here when testing is finished."
Write-Host "If Safari cannot connect, run scripts\allow_iphone_preview_firewall.ps1 once from an Administrator PowerShell."

Push-Location $repositoryRoot
try {
  & $flutterCommand.Source @flutterArguments
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter preview exited with code $LASTEXITCODE."
  }
} finally {
  Pop-Location
}
