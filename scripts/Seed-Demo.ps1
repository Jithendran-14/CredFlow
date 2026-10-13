$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Import-LocalEnvironment.ps1')
$sql = "WHENEVER SQLERROR EXIT FAILURE ROLLBACK`nCONNECT CF_APPLICATION/$env:CF_APPLICATION_PASSWORD@//localhost:1521/FREEPDB1`n" + (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'seed-demo-data.sql') -Raw) + "`nEXIT`n"
$sql | docker compose --env-file (Join-Path $repositoryRoot '.env') -f (Join-Path $repositoryRoot 'infrastructure/compose.yml') exec -T oracle sqlplus -s /nolog
if ($LASTEXITCODE -ne 0) { throw 'Demo seed failed.' }
