$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$environmentPath = Join-Path $repositoryRoot '.env'
if (-not (Test-Path -LiteralPath $environmentPath)) { throw 'Run scripts/New-LocalEnvironment.ps1 first.' }
foreach ($line in Get-Content -LiteralPath $environmentPath) {
    if ($line -match '^([A-Z0-9_]+)=(.*)$') { [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process') }
}
