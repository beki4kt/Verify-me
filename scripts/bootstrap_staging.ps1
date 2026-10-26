[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^postgres(ql)?://')]
  [string]$DatabaseUrl,

  [Parameter(Mandatory = $true)]
  [string]$ExpectedDatabaseHost,

  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[a-z0-9]{20}$')]
  [string]$ExpectedProjectRef,

  [switch]$SkipMigrations
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$databaseUri = [Uri]$DatabaseUrl
if ($ExpectedProjectRef -eq 'lpbdxtzyzlaioggefscc' -or
    $DatabaseUrl.Contains('lpbdxtzyzlaioggefscc')) {
  throw 'Staging bootstrap refuses the production Supabase project.'
}
if ($databaseUri.Host -ne $ExpectedDatabaseHost) {
  throw "Database host '$($databaseUri.Host)' does not match the expected staging host '$ExpectedDatabaseHost'."
}
$databaseUser = [Uri]::UnescapeDataString($databaseUri.UserInfo.Split(':')[0])
$directDatabase = $databaseUri.Host -eq "db.$ExpectedProjectRef.supabase.co"
$pooledDatabase = $databaseUri.Host.EndsWith('.pooler.supabase.com') -and
  $databaseUser -eq "postgres.$ExpectedProjectRef"
if (-not $directDatabase -and -not $pooledDatabase) {
  throw 'The database connection does not identify the expected staging project.'
}
if ([string]::IsNullOrWhiteSpace($env:STAGING_FIXTURE_STAFF_PASSWORD)) {
  throw 'STAGING_FIXTURE_STAFF_PASSWORD is required before any staging writes.'
}

$psqlCommand = Get-Command psql -ErrorAction Stop
$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$migrationDirectory = Join-Path $repositoryRoot 'supabase\migrations'
$seedFile = Join-Path $repositoryRoot 'supabase\seed.sql'
$isolationSeedFile = Join-Path $repositoryRoot 'supabase\staging_isolation_seed.sql'
$verificationFile = Join-Path $repositoryRoot 'supabase\staging_verification.sql'
$schemaFile = Join-Path $repositoryRoot 'supabase\staging_schema_assertions.sql'

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

Invoke-ChekmiSqlFile -FilePath $schemaFile
Invoke-ChekmiSqlFile -FilePath $seedFile
& $psqlCommand.Source $DatabaseUrl '--set=ON_ERROR_STOP=1' "--set=fixture_password=$env:STAGING_FIXTURE_STAFF_PASSWORD" '--file' $isolationSeedFile
if ($LASTEXITCODE -ne 0) { throw 'Synthetic isolation seed failed.' }
Invoke-ChekmiSqlFile -FilePath $verificationFile

Write-Host "CHEKMI staging bootstrap and verification completed for $ExpectedDatabaseHost."
