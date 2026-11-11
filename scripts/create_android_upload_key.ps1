Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$secretDirectory = Join-Path $env:USERPROFILE 'Documents\Chekmi-Secrets'
$keystorePath = Join-Path $secretDirectory 'chekmi-upload.jks'
$recoveryPath = Join-Path $secretDirectory 'android-upload-key.txt'
$propertiesPath = Join-Path $repositoryRoot 'android\key.properties'
$keytool = 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
$alias = 'chekmi-upload'

if (-not (Test-Path -LiteralPath $keytool)) {
  throw 'Android Studio keytool was not found.'
}
if (Test-Path -LiteralPath $keystorePath) {
  throw "Upload keystore already exists at $keystorePath. It was not replaced."
}
if (-not (Test-Path -LiteralPath $secretDirectory)) {
  New-Item -ItemType Directory -Path $secretDirectory | Out-Null
}

$alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
$bytes = [byte[]]::new(32)
$generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
try { $generator.GetBytes($bytes) } finally { $generator.Dispose() }
$password = -join ($bytes | ForEach-Object { $alphabet[$_ % $alphabet.Length] })

& $keytool -genkeypair `
  -keystore $keystorePath `
  -storetype JKS `
  -alias $alias `
  -keyalg RSA `
  -keysize 4096 `
  -validity 10000 `
  -dname 'CN=CHEKMI, OU=Mobile, O=CHEKMI, L=Addis Ababa, C=ET' `
  -storepass $password `
  -keypass $password `
  -noprompt
if ($LASTEXITCODE -ne 0) { throw 'keytool failed to create the upload key.' }

@"
storeFile=$($keystorePath.Replace('\','/'))
storePassword=$password
keyAlias=$alias
keyPassword=$password
"@ | Set-Content -LiteralPath $propertiesPath -Encoding ascii

@"
CHEKMI Android upload key
Created: $([DateTimeOffset]::Now.ToString('u'))
Keystore: $keystorePath
Alias: $alias
Store password: $password
Key password: $password

Back up this file and the .jks file in a secure password manager. Losing this
upload key can delay future Play Store updates.
"@ | Set-Content -LiteralPath $recoveryPath -Encoding utf8

$account = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
icacls $secretDirectory /inheritance:r /grant:r "${account}:(OI)(CI)F" | Out-Null

Write-Output "Created the Android upload key and recovery record in $secretDirectory."
Write-Output 'No signing secret was printed.'
