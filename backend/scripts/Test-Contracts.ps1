# Requires PowerShell 7.5+ (Test-Json / JSON Schema 2020-12). No network or packages.
[CmdletBinding()]
param([string]$Root = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$contracts = Join-Path $Root 'contracts'
$eventRoot = Join-Path $contracts 'events'
$exampleRoot = Join-Path $contracts 'examples'
$script:checks = 0
function Assert-Contract([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "CONTRACT CHECK FAILED: $Message" }
    $script:checks++
}
function Read-Contract([string]$Path) {
    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -AsHashtable -Depth 100 -DateKind String
}
function Assert-Event($Event, [string]$Label) {
    $topic = $Event.eventType
    $schemaPath = Join-Path $eventRoot "$topic.schema.json"
    Assert-Contract (Test-Path -LiteralPath $schemaPath) "$Label has no topic schema"
    $json = ConvertTo-Json -InputObject $Event -Depth 100
    Assert-Contract (Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction SilentlyContinue) "$Label schema violation"
    if ($topic -eq 'eligibility.completed') {
        Assert-Contract ($Event.data.applicationId -eq $Event.applicationId) "$Label root/data application binding mismatch"
    }
    # Explicit formats are checked even if a validator treats format as annotation.
    foreach ($name in @('eventId','applicationId','causationId')) {
        if ($Event.ContainsKey($name)) {
            $parsed = [guid]::Empty
            Assert-Contract ([guid]::TryParse([string]$Event[$name], [ref]$parsed)) "$Label invalid $name"
        }
    }
    $when = [DateTimeOffset]::MinValue
    Assert-Contract ([DateTimeOffset]::TryParse([string]$Event.occurredAt,[ref]$when)) "$Label invalid occurredAt"
    foreach ($key in $Event.data.Keys) {
        if ($null -ne $Event.data[$key] -and $key -match 'Id$' -and $key -notin @('questionId','sellerId','marketplaceSellerId','fixtureIdentityId','sellerFixtureId','lenderApplicationId')) {
            $parsed = [guid]::Empty
            Assert-Contract ([guid]::TryParse([string]$Event.data[$key],[ref]$parsed)) "$Label invalid data.$key"
        }
        if ($key -match 'At$' -and $null -ne $Event.data[$key]) {
            $when = [DateTimeOffset]::MinValue
            Assert-Contract ([DateTimeOffset]::TryParse([string]$Event.data[$key],[ref]$when)) "$Label invalid data.$key"
        }
    }
}
$catalog = Read-Contract (Join-Path $eventRoot 'member3-event-payloads.json')
Assert-Contract ($catalog.events.Count -eq 21) 'Expected every one of the 21 implemented topics'
$unique = [System.Collections.Generic.HashSet[string]]::new()
foreach ($entry in $catalog.events) {
    Assert-Contract ($unique.Add($entry.topic)) "Duplicate topic $($entry.topic)"
    $schema = Read-Contract (Join-Path $eventRoot $entry.schema)
    Assert-Contract ($schema.properties.eventType.const -eq $entry.topic) "Wrong eventType for $($entry.topic)"
    Assert-Contract ($schema.properties.producer.const -eq $entry.producer) "Wrong producer for $($entry.topic)"
    $sample = Read-Contract (Join-Path $eventRoot $entry.fixture)
    Assert-Event $sample $entry.topic
    # Each schema must reject unknown envelope fields and the wrong topic.
    $bad = Read-Contract (Join-Path $eventRoot $entry.fixture)
    $bad['unexpectedEnvelopeProperty'] = 'must-reject'
    $badJson = ConvertTo-Json -InputObject $bad -Depth 100
    Assert-Contract (-not (Test-Json -Json $badJson -SchemaFile (Join-Path $eventRoot $entry.schema) -ErrorAction SilentlyContinue)) "$($entry.topic) accepts unknown envelope properties"
    $bad.Remove('unexpectedEnvelopeProperty')
    $bad.eventType = 'wrong.topic'
    $badJson = ConvertTo-Json -InputObject $bad -Depth 100
    Assert-Contract (-not (Test-Json -Json $badJson -SchemaFile (Join-Path $eventRoot $entry.schema) -ErrorAction SilentlyContinue)) "$($entry.topic) accepts wrong event type"
    $bad.eventType = $entry.topic
    $bad.aggregateVersion = 0
    $badJson = ConvertTo-Json -InputObject $bad -Depth 100
    Assert-Contract (-not (Test-Json -Json $badJson -SchemaFile (Join-Path $eventRoot $entry.schema) -ErrorAction SilentlyContinue)) "$($entry.topic) accepts a nonpositive aggregate version"
}
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $exampleRoot 'branches') -Filter '*.json' -File) {
    Assert-Event (Read-Contract $file.FullName) $file.Name
}
foreach ($bank in @('bank-a','nbfc-b')) {
    $journey = Read-Contract (Join-Path $exampleRoot "journeys/$bank.json")
    $appId = $journey.events[0].applicationId
    $trace = $journey.events[0].correlationId
    $eventIds = [System.Collections.Generic.HashSet[string]]::new()
    $integrationVersion = 0
    foreach ($event in $journey.events) {
        Assert-Event $event "$bank/$($event.eventType)"
        Assert-Contract ($event.applicationId -eq $appId) "$bank application binding broken"
        Assert-Contract ($event.correlationId -eq $trace) "$bank correlation continuity broken"
        Assert-Contract ($eventIds.Add($event.eventId)) "$bank duplicate event UUID"
        if ($event.producer -eq 'lender-integration-service') {
            $integrationVersion++
            Assert-Contract ($event.aggregateVersion -eq $integrationVersion) "$bank Integration event ordering is not contiguous"
        }
    }
    $submitted = @($journey.events | Where-Object eventType -eq 'lender.application.submitted')[0]
    foreach ($event in $journey.events | Where-Object { $_.data.ContainsKey('submissionId') }) {
        Assert-Contract ($event.data.submissionId -eq $submitted.data.submissionId) "$bank submission binding broken"
    }
}
# Known semantic failure branches must be rejected by the eligibility schema.
$badEligibility = Read-Contract (Join-Path $exampleRoot 'events/eligibility.completed.json')
$badEligibility.data.outcome = 'ELIGIBLE'
Assert-Contract (-not (Test-Json -Json (ConvertTo-Json $badEligibility -Depth 100) -SchemaFile (Join-Path $eventRoot 'eligibility.completed.schema.json') -ErrorAction SilentlyContinue)) 'Old ELIGIBLE outcome must be rejected'
$badEligibility.data.outcome = 'ACTION_REQUIRED'
Assert-Contract (-not (Test-Json -Json (ConvertTo-Json $badEligibility -Depth 100) -SchemaFile (Join-Path $eventRoot 'eligibility.completed.schema.json') -ErrorAction SilentlyContinue)) 'ACTION_REQUIRED must not contain lender results'
$badDecision = Read-Contract (Join-Path $exampleRoot 'branches/decision.rejected.json')
$badDecision.data.Remove('reasonCode')
Assert-Contract (-not (Test-Json -Json (ConvertTo-Json $badDecision -Depth 100) -SchemaFile (Join-Path $eventRoot 'lender.decision.received.schema.json') -ErrorAction SilentlyContinue)) 'Rejection without reason must be rejected'
$badDecision = Read-Contract (Join-Path $exampleRoot 'events/lender.decision.received.json')
$badDecision.data.Remove('decidedAt')
Assert-Contract (-not (Test-Json -Json (ConvertTo-Json $badDecision -Depth 100) -SchemaFile (Join-Path $eventRoot 'lender.decision.received.schema.json') -ErrorAction SilentlyContinue)) 'Normalized decision must include decidedAt'
foreach ($variant in @('numericMoney','threeDecimalMoney','excessiveRate','nullCausation')) {
    $badOffer = Read-Contract (Join-Path $exampleRoot 'events/loan.offer.created.json')
    switch ($variant) {
        'numericMoney' { $badOffer.data.offeredAmount = 500000 }
        'threeDecimalMoney' { $badOffer.data.offeredAmount = '500000.001' }
        'excessiveRate' { $badOffer.data.annualInterestRatePercent = '100.0001' }
        'nullCausation' { $badOffer['causationId'] = $null }
    }
    Assert-Contract (-not (Test-Json -Json (ConvertTo-Json $badOffer -Depth 100) -SchemaFile (Join-Path $eventRoot 'loan.offer.created.schema.json') -ErrorAction SilentlyContinue)) "Offer schema must reject $variant"
}
# Verify the three exact upstream request/result/receipt examples too.
foreach ($name in @('eligibility-evaluation-request','eligibility-result','eligibility-operation-accepted')) {
    $samplePath = Join-Path $exampleRoot ($name + '.json')
    $schemaPath = Join-Path $contracts ('upstream/' + $name + '.schema.json')
    Assert-Contract (Test-Json -Json (Get-Content -LiteralPath $samplePath -Raw) -SchemaFile $schemaPath -ErrorAction SilentlyContinue) "$name upstream schema violation"
}
$badRequest = Read-Contract (Join-Path $exampleRoot 'eligibility-evaluation-request.json')
$badRequest['financialSnapshotId'] = [guid]::NewGuid().ToString()
Assert-Contract (-not (Test-Json -Json (ConvertTo-Json $badRequest -Depth 100) -SchemaFile (Join-Path $contracts 'upstream/eligibility-evaluation-request.schema.json') -ErrorAction SilentlyContinue)) 'Caller must not preallocate a financial snapshot'
$badRequest.Remove('financialSnapshotId')
$badRequest.Remove('authorisedRetrievalReference')
Assert-Contract (-not (Test-Json -Json (ConvertTo-Json $badRequest -Depth 100) -SchemaFile (Join-Path $contracts 'upstream/eligibility-evaluation-request.schema.json') -ErrorAction SilentlyContinue)) 'Missing trusted financial retrieval reference must be rejected'

# All JSON assets must parse. OpenAPI YAML files intentionally contain JSON,
# which is valid YAML and avoids a YAML parser dependency.
foreach ($file in Get-ChildItem -LiteralPath $contracts -Recurse -File -Filter '*.json') {
    $null = Read-Contract $file.FullName
    $script:checks++
}
function Assert-References($Node, $Document, [string]$Label) {
    if ($Node -is [System.Collections.IDictionary]) {
        if ($Node.Contains('$ref') -and $Node['$ref'].StartsWith('#/')) {
            $target = $Document
            foreach ($part in $Node['$ref'].Substring(2).Split('/')) {
                $name = $part.Replace('~1','/').Replace('~0','~')
                Assert-Contract ($target -is [System.Collections.IDictionary] -and $target.Contains($name)) "$Label broken reference $($Node['$ref'])"
                $target = $target[$name]
            }
        }
        foreach ($value in $Node.Values) { Assert-References $value $Document $Label }
    } elseif ($Node -is [System.Collections.IEnumerable] -and $Node -isnot [string]) {
        foreach ($item in $Node) { Assert-References $item $Document $Label }
    }
}
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $contracts 'openapi') -File -Filter '*.yaml') {
    $api = Read-Contract $file.FullName
    Assert-Contract ($api.openapi -match '^3\.') "$($file.Name) missing OpenAPI 3 version"
    Assert-Contract ($api.paths.Count -gt 0) "$($file.Name) has no paths"
    Assert-References $api $api $file.Name
    foreach ($path in $api.paths.Keys) {
        foreach ($method in $api.paths[$path].Keys | Where-Object { $_ -in @('get','post','put','patch','delete') }) {
            $operation = $api.paths[$path][$method]
            Assert-Contract ($operation.responses.Count -gt 0) "$method $path has no responses"
            Assert-Contract ($operation.Contains('security') -or $api.Contains('security')) "$method $path has no explicit security policy"
        }
    }
}
Write-Output "PASS: $script:checks contract assertions, 21 topic schemas, both lender journeys, failure branches, JSON syntax and OpenAPI internal references. This does not prove teammate or live infrastructure compatibility."
