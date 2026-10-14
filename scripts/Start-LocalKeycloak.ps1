param(
    [Parameter(Mandatory=$true)][string]$KeycloakHome,
    [string]$JavaHome,
    [switch]$Background
)
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Import-LocalEnvironment.ps1')
$runtimeRoot = (Resolve-Path -LiteralPath $KeycloakHome).Path
$launcher = Join-Path $runtimeRoot 'bin/kc.bat'
if (-not (Test-Path -LiteralPath $launcher)) { throw 'KeycloakHome must contain bin/kc.bat.' }
if ($JavaHome) {
    if (-not (Test-Path -LiteralPath (Join-Path $JavaHome 'bin/java.exe'))) { throw 'JavaHome must contain bin/java.exe.' }
    $env:JAVA_HOME = $JavaHome
}
if (-not $env:KEYCLOAK_ADMIN_PASSWORD) { throw 'KEYCLOAK_ADMIN_PASSWORD is missing from .env.' }
$env:KC_BOOTSTRAP_ADMIN_USERNAME = 'admin'
$env:KC_BOOTSTRAP_ADMIN_PASSWORD = $env:KEYCLOAK_ADMIN_PASSWORD
$importDirectory = Join-Path $runtimeRoot 'data/import'
New-Item -ItemType Directory -Force -Path $importDirectory | Out-Null
Copy-Item -LiteralPath (Join-Path $repositoryRoot 'infrastructure/keycloak/credflow-realm.json') -Destination (Join-Path $importDirectory 'credflow-realm.json') -Force
$arguments = 'start-dev --import-realm --http-host=127.0.0.1 --http-port=8180 --hostname=http://localhost:8180'
if ($Background) {
    $logDirectory = Join-Path $repositoryRoot 'work/keycloak'
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    $process = Start-Process -FilePath $launcher -ArgumentList $arguments -WorkingDirectory $runtimeRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logDirectory 'stdout.log') -RedirectStandardError (Join-Path $logDirectory 'stderr.log')
    Set-Content -LiteralPath (Join-Path $logDirectory 'launcher.pid') -Value $process.Id
    Write-Host "Keycloak launch requested. Check http://localhost:8180 and logs in $logDirectory."
} else {
    Push-Location -LiteralPath $runtimeRoot
    try { & $launcher start-dev --import-realm --http-host=127.0.0.1 --http-port=8180 --hostname=http://localhost:8180; if ($LASTEXITCODE -ne 0) { throw 'Keycloak failed; inspect the terminal output.' } }
    finally { Pop-Location }
}
