param(
    [ValidatePattern('^[A-Za-z0-9._-]+$')][string]$OracleHost = 'localhost',
    [ValidateRange(1,65535)][int]$Port = 1521,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9_]*$')][string]$ServiceName = 'FREEPDB1',
    [string]$SqlPlus = 'sqlplus'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Import-LocalEnvironment.ps1')
$schemaPassword = $env:CF_APPLICATION_PASSWORD
if ($schemaPassword -notmatch '^[A-Za-z0-9_]{12,128}$') { throw 'Invalid CF_APPLICATION_PASSWORD.' }
$sql = "WHENEVER SQLERROR EXIT FAILURE ROLLBACK`nWHENEVER OSERROR EXIT FAILURE ROLLBACK`nSET ECHO OFF`nSET VERIFY OFF`nSET DEFINE OFF`nCONNECT CF_APPLICATION/`"$schemaPassword`"@//$($OracleHost):$Port/$ServiceName`n" + (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'seed-demo-data.sql') -Raw) + "`nEXIT SUCCESS`n"
$result = $sql | & $SqlPlus -L -s /nolog 2>&1
$resultCode = $LASTEXITCODE
foreach ($line in $result) { Write-Host ([string]$line).Replace($schemaPassword,'[REDACTED]') }
if ($resultCode -ne 0) { throw 'Local demo seed failed. Start Application Service first so Flyway creates seller_profile.' }
Write-Host 'Local seller fixtures are ready.'
