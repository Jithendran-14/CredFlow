$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Import-LocalEnvironment.ps1')
$token = Invoke-RestMethod -Method Post -Uri 'http://localhost:8180/realms/credflow/protocol/openid-connect/token' -Body @{grant_type='client_credentials';client_id='mock-marketplace-client';client_secret=$env:MARKETPLACE_CLIENT_SECRET}
$headers = @{Authorization="Bearer $($token.access_token)";'Idempotency-Key'='demo-104';'X-Correlation-ID'='demo-flow-104'}
$body = Get-Content -LiteralPath (Join-Path $repositoryRoot 'contracts/examples/application-request.json') -Raw
$first = Invoke-RestMethod -Method Post -Uri 'http://localhost:8080/api/v1/applications' -Headers $headers -ContentType 'application/json' -Body $body
$second = Invoke-RestMethod -Method Post -Uri 'http://localhost:8080/api/v1/applications' -Headers $headers -ContentType 'application/json' -Body $body
if ($first.applicationId -ne $second.applicationId -or $first.status -ne 'AWAITING_CONSENT') { throw 'Submission/idempotency verification failed.' }
Write-Host "Application $($first.applicationId) is AWAITING_CONSENT; duplicate request returned the same application."
