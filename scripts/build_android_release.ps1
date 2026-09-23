Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

Push-Location $repositoryRoot
try {
  flutter build appbundle --release --dart-define-from-file=config/production.json
} finally {
  Pop-Location
}
