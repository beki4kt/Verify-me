#Requires -RunAsAdministrator

[CmdletBinding()]
param(
  [ValidateRange(1024, 65535)]
  [int]$Port = 8087
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ruleName = "Chekmi iPhone Preview ($Port)"
$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

if ($null -eq $existingRule) {
  New-NetFirewallRule `
    -DisplayName $ruleName `
    -Description 'Allows an iPhone on the local network to open the Chekmi Flutter preview.' `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort $Port `
    -RemoteAddress LocalSubnet `
    -Profile Private,Public | Out-Null

  Write-Host "Created Windows Firewall rule '$ruleName'." -ForegroundColor Green
} else {
  Set-NetFirewallRule -DisplayName $ruleName -Enabled True | Out-Null
  Write-Host "Windows Firewall rule '$ruleName' is already present and enabled." -ForegroundColor Green
}

Write-Host "Only TCP port $Port from the local subnet is allowed by this rule."
