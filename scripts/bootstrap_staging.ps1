[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^postgres(ql)?://')]
  [string]$DatabaseUrl,

  [Parameter(Mandatory = $true)]
  [string]$ExpectedDatabaseHost,

  [switch]$SkipMigrations
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$databaseUri = [Uri]$DatabaseUrl
if ($databaseUri.Host -ne $ExpectedDatabaseHost) {
  throw "Database host '$($databaseUri.Host)' does not match the expected staging host '$ExpectedDatabaseHost'."
}

$psqlCommand = Get-Command psql -ErrorAction Stop
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$migrationDirectory = Join-Path $repositoryRoot 'supabase\migrations'
$seedFile = Join-Path $repositoryRoot 'supabase\seed.sql'
$verificationFile = Join-Path $repositoryRoot 'supabase\staging_verification.sql'

function Invoke-ChekmiSqlFile {
  param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath
  )

  Write-Host "Applying $([IO.Path]::GetFileName($FilePath))"
  & $psqlCommand.Source $DatabaseUrl '--set=ON_ERROR_STOP=1' '--file' $FilePath
  if ($LASTEXITCODE -ne 0) {
    throw "psql failed while applying $FilePath"
  }
}

if (-not $SkipMigrations) {
  Get-ChildItem -LiteralPath $migrationDirectory -Filter '*.sql' -File |
    Sort-Object Name |
    ForEach-Object { Invoke-ChekmiSqlFile -FilePath $_.FullName }
}

Invoke-ChekmiSqlFile -FilePath $seedFile
Invoke-ChekmiSqlFile -FilePath $verificationFile

Write-Host "CHEKMI staging bootstrap and verification completed for $ExpectedDatabaseHost."
