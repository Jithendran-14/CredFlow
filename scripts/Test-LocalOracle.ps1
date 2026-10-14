param(
    [ValidatePattern('^[A-Za-z0-9._-]+$')][string]$OracleHost = 'localhost',
    [ValidateRange(1,65535)][int]$Port = 1521,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9_]*$')][string]$ServiceName = 'FREEPDB1',
    [string]$SqlPlus = 'sqlplus'
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Import-LocalEnvironment.ps1')
foreach ($schema in @('CF_APPLICATION','CF_CONSENT','CF_ELIGIBILITY','CF_ORCHESTRATION','CF_LENDER_INTEGRATION','CF_AUDIT')) {
    $schemaPassword = [Environment]::GetEnvironmentVariable("$($schema)_PASSWORD",'Process')
    if ($schemaPassword -notmatch '^[A-Za-z0-9_]{12,128}$') { throw "Invalid $($schema)_PASSWORD." }
    $sql = "WHENEVER SQLERROR EXIT FAILURE`nWHENEVER OSERROR EXIT FAILURE`nSET ECHO OFF`nSET VERIFY OFF`nSET DEFINE OFF`nSET HEADING OFF`nSET FEEDBACK OFF`nCONNECT $schema/`"$schemaPassword`"@//$($OracleHost):$Port/$ServiceName`nSELECT SYS_CONTEXT('USERENV','SESSION_USER') FROM dual;`nEXIT SUCCESS`n"
    $result = $sql | & $SqlPlus -L -s /nolog 2>&1
    $resultCode = $LASTEXITCODE
    if ($resultCode -ne 0 -or -not (($result -join "`n") -match $schema)) {
        foreach ($line in $result) { Write-Host ([string]$line).Replace($schemaPassword,'[REDACTED]') }
        throw "$schema connection verification failed."
    }
    Write-Host "$schema connected successfully."
}
