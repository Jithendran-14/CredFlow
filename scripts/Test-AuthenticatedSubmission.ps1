param(
    [string]$ApiBaseUrl='http://localhost:8081',
    [ValidateSet('SELLER-104','SELLER-105','SELLER-106','SELLER-107')][string]$MarketplaceSellerId='SELLER-104'
)
$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot 'Import-LocalEnvironment.ps1')
$token = Invoke-RestMethod -Method Post -Uri 'http://localhost:8180/realms/credflow/protocol/openid-connect/token' -Body @{grant_type='client_credentials';client_id='mock-marketplace-client';client_secret=$env:MARKETPLACE_CLIENT_SECRET}
$sellerNumber = $MarketplaceSellerId.Substring(7)
$headers = @{Authorization="Bearer $($token.access_token)";'Idempotency-Key'="authenticated-local-$sellerNumber";'X-Correlation-ID'="authenticated-local-flow-$sellerNumber"}
$inputBody = Get-Content -LiteralPath (Join-Path $repositoryRoot 'contracts/examples/application-request.json') -Raw | ConvertFrom-Json
$inputBody.marketplaceSellerId = $MarketplaceSellerId
$inputBody.marketplaceRequestId = "REQ-$sellerNumber-001"
$inputBody.sellerRequestReference = "SELLER-REQUEST-$sellerNumber-001"
$inputBody.initialSharingConsent.evidenceReference = "MARKETPLACE-CONSENT-$sellerNumber-001"
$body = $inputBody | ConvertTo-Json -Depth 10
$first = Invoke-WebRequest -Method Post -Uri "$ApiBaseUrl/api/v1/applications" -Headers $headers -ContentType 'application/json' -Body $body
if ([int]$first.StatusCode -ne 201) { throw 'Expected 201 on submission.' }
$application = $first.Content | ConvertFrom-Json
$replay = Invoke-RestMethod -Method Post -Uri "$ApiBaseUrl/api/v1/applications" -Headers $headers -ContentType 'application/json' -Body $body
if ($replay.applicationId -ne $application.applicationId) { throw 'Replay created a different resource.' }
$read = Invoke-RestMethod -Method Get -Uri "$ApiBaseUrl/api/v1/applications/$($application.applicationId)" -Headers $headers
if ($read.applicationId -ne $application.applicationId) { throw 'Application read failed.' }
$changed = $body | ConvertFrom-Json
$changed.requestedAmount = '400000.00'
try {
    Invoke-WebRequest -Method Post -Uri "$ApiBaseUrl/api/v1/applications" -Headers $headers -ContentType 'application/json' -Body ($changed | ConvertTo-Json -Depth 10) -ErrorAction Stop | Out-Null
    throw 'Changed payload was unexpectedly accepted.'
} catch {
    if (-not $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 409) { throw }
    $conflict = $_.ErrorDetails.Message | ConvertFrom-Json
    if ($conflict.code -ne 'IDEMPOTENCY_CONFLICT') { throw 'Expected IDEMPOTENCY_CONFLICT.' }
}
Write-Host "PASS: created/replayed/read application $($application.applicationId), status $($application.status), and changed payload returned 409."
Write-Host 'No token or client secret was printed.'
