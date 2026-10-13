$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$destination = Join-Path $repositoryRoot '.env'
if (Test-Path -LiteralPath $destination) { throw '.env already exists. Preserve its credentials; no file was overwritten.' }
$lines = Get-Content -LiteralPath (Join-Path $repositoryRoot '.env.example')
$generated = foreach ($line in $lines) {
    if ($line -match '^([A-Z0-9_]+)=__GENERATE__$') {
        $secretBytes = New-Object byte[] 18
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        try { $rng.GetBytes($secretBytes) } finally { $rng.Dispose() }
        $secretValue = 'Cf9_' + ([BitConverter]::ToString($secretBytes)).Replace('-', '').ToLowerInvariant()
        "$($Matches[1])=$secretValue"
    } else { $line }
}
[IO.File]::WriteAllLines($destination, [string[]]$generated, (New-Object System.Text.UTF8Encoding($false)))
Write-Host 'Created local .env with generated development credentials.'
