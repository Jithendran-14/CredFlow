param(
    [string]$OracleHost = 'localhost',
    [ValidateRange(1,65535)][int]$Port = 1521,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9_]*$')][string]$ServiceName = 'FREEPDB1',
    [string]$SqlPlus = 'sqlplus',
    [switch]$UseOsAuthentication
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Import-LocalEnvironment.ps1')
$schemas = @('CF_APPLICATION','CF_CONSENT','CF_ELIGIBILITY','CF_ORCHESTRATION','CF_LENDER_INTEGRATION','CF_AUDIT')
$sensitiveValues = @()
$sqlLines = @('WHENEVER SQLERROR EXIT FAILURE','WHENEVER OSERROR EXIT FAILURE','SET ECHO OFF','SET VERIFY OFF','SET DEFINE OFF','SET SERVEROUTPUT ON')
if ($UseOsAuthentication) {
    if ($OracleHost -ne 'localhost') { throw 'Windows OS authentication is only supported for the local database.' }
    $sqlLines += 'CONNECT / AS SYSDBA'
    $sqlLines += "ALTER SESSION SET CONTAINER=$ServiceName;"
} else {
    if ($OracleHost -notmatch '^[A-Za-z0-9._-]+$') { throw 'Invalid Oracle host.' }
    $securePassword = Read-Host 'SYSTEM password (used only for this setup)' -AsSecureString
    $passwordPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    try { $adminPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($passwordPointer) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passwordPointer) }
    if ($adminPassword -match '["\r\n]' -or [string]::IsNullOrEmpty($adminPassword)) { throw 'Password must be nonempty and cannot contain double quotes or line breaks.' }
    $sensitiveValues += $adminPassword
    $sqlLines += "CONNECT SYSTEM/`"$adminPassword`"@//$($OracleHost):$Port/$ServiceName"
}
$sqlLines += 'SET SERVEROUTPUT ON'
foreach ($schema in $schemas) {
    $schemaPassword = [Environment]::GetEnvironmentVariable("$($schema)_PASSWORD",'Process')
    if ($schemaPassword -notmatch '^[A-Za-z0-9_]{12,128}$') { throw "Generate a valid local $($schema)_PASSWORD first." }
    $sensitiveValues += $schemaPassword
    $sqlLines += @"
DECLARE
  user_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO user_count FROM dba_users WHERE username='$schema';
  IF user_count=0 THEN
    EXECUTE IMMEDIATE 'CREATE USER $schema IDENTIFIED BY "$schemaPassword" DEFAULT TABLESPACE USERS QUOTA 200M ON USERS';
    DBMS_OUTPUT.PUT_LINE('Created $schema');
  ELSE
    DBMS_OUTPUT.PUT_LINE('$schema already exists; password preserved');
  END IF;
  EXECUTE IMMEDIATE 'GRANT CREATE SESSION, CREATE TABLE, CREATE SEQUENCE, CREATE PROCEDURE, CREATE TRIGGER, CREATE VIEW TO $schema';
END;
/
"@
}
$sqlLines += 'EXIT SUCCESS'
$result = ($sqlLines -join "`n") | & $SqlPlus -L -s /nolog 2>&1
$resultCode = $LASTEXITCODE
foreach ($line in $result) {
    $safeLine = [string]$line
    foreach ($value in $sensitiveValues) { $safeLine = $safeLine.Replace($value,'[REDACTED]') }
    Write-Host $safeLine
}
$adminPassword = $null
$schemaPassword = $null
$sensitiveValues = $null
$sqlLines = $null
if ($resultCode -ne 0) { throw 'Oracle schema setup failed. Earlier successful CREATE/GRANT statements may already be committed; rerun after fixing the reported cause.' }
Write-Host 'CredFlow service schemas are ready. Existing passwords were not changed.'
