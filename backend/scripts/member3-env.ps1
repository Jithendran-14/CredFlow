param(
    [string]$Path=(Join-Path $PSScriptRoot '..\.env'),
    [ValidateSet('all','orchestration','integration','bank-a','nbfc-b')]
    [string]$Service='all'
)
$ErrorActionPreference='Stop'
if(-not (Test-Path -LiteralPath $Path -PathType Leaf)){
    throw 'Copy .env.example to .env and fill in this service Oracle credentials and confirmed Auth settings first.'
}
foreach($line in [IO.File]::ReadAllLines((Resolve-Path -LiteralPath $Path).Path)){
    $line=$line.Trim()
    if(-not $line -or $line.StartsWith('#')){continue}
    if($line -notmatch '^([A-Z][A-Z0-9_]*)=(.*)$'){throw 'Invalid environment line: expected NAME=value'}
    $name=$Matches[1];$value=$Matches[2].Trim()
    if($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))){
        $value=$value.Substring(1,$value.Length-2)
    }
    [Environment]::SetEnvironmentVariable($name,$value,'Process')
}
$requiredNames = @('AUTH_ISSUER','JWT_AUDIENCE')
$prefixes = switch($Service) {
    'orchestration' { @('ORCHESTRATION') }
    'integration' { @('INTEGRATION') }
    'bank-a' { @('BANK_A') }
    'nbfc-b' { @('NBFC_B') }
    default { @('ORCHESTRATION','INTEGRATION','BANK_A','NBFC_B') }
}
foreach($prefix in $prefixes){
    $requiredNames += ($prefix+'_DB_USER'),($prefix+'_DB_PASSWORD')
    $ownUrl = [Environment]::GetEnvironmentVariable($prefix+'_ORACLE_URL')
    if($prefix -in @('BANK_A','NBFC_B') -and -not [string]::IsNullOrWhiteSpace($ownUrl)){
        $requiredNames += ($prefix+'_ORACLE_URL')
    } else {
        $requiredNames += 'ORACLE_URL'
    }
}
foreach($name in $requiredNames | Select-Object -Unique){
    $value=[Environment]::GetEnvironmentVariable($name)
    if([string]::IsNullOrWhiteSpace($value) -or $value.StartsWith('REPLACE_WITH_')){throw ('Set a real value for '+$name+' in .env')}
}
$jwks=[Environment]::GetEnvironmentVariable('JWT_JWKS_URI')
$pem=[Environment]::GetEnvironmentVariable('JWT_PUBLIC_KEY_LOCATION')
if((-not [string]::IsNullOrWhiteSpace($jwks)) -eq (-not [string]::IsNullOrWhiteSpace($pem))){
    throw 'Configure exactly one of JWT_JWKS_URI and JWT_PUBLIC_KEY_LOCATION.'
}
if(($jwks -and $jwks.StartsWith('REPLACE_WITH_')) -or ($pem -and $pem.StartsWith('REPLACE_WITH_'))){
    throw 'Replace the JWT public-key/JWKS placeholder with the confirmed Auth setting.'
}
if($env:BANK_A_DB_USER -and $env:NBFC_B_DB_USER -and $env:BANK_A_DB_USER.Trim() -ieq $env:NBFC_B_DB_USER.Trim()){
    throw 'Bank A and NBFC B must use separate Oracle schemas/users.'
}
Write-Output ('Loaded environment for '+$Service+'. Credential values are not printed.')
if([string]::IsNullOrWhiteSpace($env:OAUTH_TOKEN_URL)){
    Write-Output 'Machine grants are not configured. Protected service work remains pending until scoped machine authentication is supplied.'
}
