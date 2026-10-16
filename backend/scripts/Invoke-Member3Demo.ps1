param(
    [Parameter(Mandatory=$true)][string]$GatewayBaseUrl,
    [Parameter(Mandatory=$true)][guid]$ApplicationId,
    [ValidateSet('BANK_A','NBFC_B')][string]$Lender='BANK_A',
    [ValidateSet('ACCEPT','EXPIRE','DECLINE','WITHDRAW','REJECT','CANCEL')][string]$Outcome='ACCEPT',
    [switch]$WithInformationRequest,
    [switch]$WithManualReview,
    [int]$TimeoutSeconds=180,
    [string]$EvidenceDirectory=(Join-Path $PSScriptRoot '..\demo-evidence')
)
$ErrorActionPreference='Stop'
$GatewayBaseUrl=$GatewayBaseUrl.TrimEnd('/')
if($GatewayBaseUrl -notmatch '^https?://'){throw 'GatewayBaseUrl must be the actual Member 1 Gateway URL'}
$tokens=@{}
foreach($role in 'SELLER','LENDER'){
    $token=[Environment]::GetEnvironmentVariable('DEMO_'+$role+'_TOKEN')
    if([string]::IsNullOrWhiteSpace($token)){throw ('Set DEMO_'+$role+'_TOKEN to an access token for the seeded '+$role+' identity')}
    $tokens[$role]=$token
}
$trace='member3-demo-'+[guid]::NewGuid().ToString('N')
$runId=[guid]::NewGuid().ToString()
$marketplaceId='33333333-3333-4333-8333-333333333333'
$bankId=if($env:BANK_A_LENDER_ID){$env:BANK_A_LENDER_ID}else{'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1'}
$nbfcId=if($env:NBFC_B_LENDER_ID){$env:NBFC_B_LENDER_ID}else{'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2'}
$expectedLender=if($Lender -eq 'BANK_A'){$bankId}else{$nbfcId}
$sellerReference=if($Lender -eq 'BANK_A'){'DEMO-BANK-A'}else{'DEMO-NBFC-B'}
$amount=if($Lender -eq 'BANK_A'){'500000.00'}else{'150000.00'}
$age=if($Lender -eq 'BANK_A'){24}else{9}
$evidence=[Collections.Generic.List[object]]::new()
$succeeded=$false

function Request-Api([string]$Role,[string]$Method,[string]$Path,$Body=$null,[string]$Key=''){
    $headers=@{Authorization='Bearer '+$tokens[$Role];'X-Correlation-ID'=$trace}
    if($Key){$headers['Idempotency-Key']=$Key}
    $parameters=@{Uri=$GatewayBaseUrl+$Path;Method=$Method;Headers=$headers;TimeoutSec=30}
    if($null -ne $Body){$parameters.ContentType='application/json';$parameters.Body=($Body|ConvertTo-Json -Depth 20 -Compress)}
    try{
        $result=Invoke-RestMethod @parameters
        $evidence.Add([ordered]@{at=[datetime]::UtcNow.ToString('o');method=$Method;path=$Path;response=$result})
        return $result
    }catch{
        $status=if($_.Exception.Response){[int]$_.Exception.Response.StatusCode}else{0}
        $code='REQUEST_FAILED'
        try{
            $errorBody=$_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction Stop
            if($errorBody.code -match '^[A-Z][A-Z0-9_.:-]{0,99}$'){$code=$errorBody.code}
        }catch{}
        $evidence.Add([ordered]@{at=[datetime]::UtcNow.ToString('o');method=$Method;path=$Path;httpStatus=$status;errorCode=$code})
        throw
    }
}

function Wait-Workflow([string[]]$States){
    $deadline=[datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    while([datetime]::UtcNow -lt $deadline){
        $workflow=$null
        try{$workflow=Request-Api 'SELLER' 'GET' ('/api/v1/applications/'+$script:applicationId+'/workflow')}
        catch{if(-not $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -notin 404,503){throw}}
        if($workflow){
            if($workflow.status -in $States){return $workflow}
            if($workflow.processingHealth -eq 'MANUAL_INTERVENTION_REQUIRED'){throw ('Workflow needs intervention; inspect correlation '+$trace)}
            if($workflow.status -in 'CHECK_FAILED','NO_ELIGIBLE_LENDER','REJECTED','CANCELLED','OFFER_DECLINED','OFFER_EXPIRED','OFFER_ACCEPTED'){
                throw ('Unexpected terminal state '+$workflow.status+'; inspect scenario fixtures/contracts')
            }
        }
        Start-Sleep -Seconds 1
    }
    throw ('Timed out waiting for '+($States -join ',')+'; correlation '+$trace)
}

try{
    # Use an application created and routed through the actual Member1/2 services.
    # Their missing publisher, consent and machine APIs are not bypassed here.
    $script:applicationId=$ApplicationId.ToString()
    $initial=Request-Api 'SELLER' 'GET' ('/api/v1/applications/'+$script:applicationId+'/workflow')
    if($initial.status -in 'AWAITING_CONSENT','ACTION_REQUIRED'){
        throw ('Complete upstream prerequisites first: '+$initial.status+' '+$initial.reasonCode+'. See docs/team-contract-alignment.md; this script does not invent a Consent API or financial authorization.')
    }
    $workflow=Wait-Workflow @('LENDER_REVIEW')
    if($workflow.lenderId -ne $expectedLender){throw 'Selected lender differs from fixture expectation; do not override routing to force this scenario'}
    $submission=[string]$workflow.submissionId

    if($Outcome -eq 'CANCEL'){
        $cancelled=$false
        for($attempt=0;$attempt -lt 3 -and -not $cancelled;$attempt++){
            $workflow=Request-Api 'SELLER' 'GET' ('/api/v1/applications/'+$script:applicationId+'/workflow')
            if($workflow.status -eq 'CANCELLED'){$cancelled=$true;break}
            try{
                $null=Request-Api 'SELLER' 'POST' ('/api/v1/applications/'+$script:applicationId+'/cancellation') (@{expectedWorkflowVersion=$workflow.workflowVersion}) ([guid]::NewGuid().ToString())
                $cancelled=$true
            }catch{
                if(-not $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 409){throw}
            }
        }
        if(-not $cancelled){throw 'Cancellation remained conflicted after refreshing the workflow version'}
        $null=Wait-Workflow @('CANCELLED')
    }else{
        if($WithInformationRequest){
            $questionId=[guid]::NewGuid().ToString()
            $null=Request-Api 'LENDER' 'POST' ('/api/v1/submissions/'+$submission+'/information-requests') (@{
                informationRequestId=$questionId;questions=@(@{questionId='Q1';prompt='State the synthetic inventory use.'})
            }) $questionId
            $null=Wait-Workflow @('INFORMATION_REQUIRED')
            $questions=Request-Api 'SELLER' 'GET' ('/api/v1/applications/'+$script:applicationId+'/information-requests')
            $question=@($questions.items|Where-Object informationRequestId -eq $questionId)[0]
            if(-not $question){throw 'Expected question was not exposed by the API'}
            $null=Request-Api 'SELLER' 'POST' ('/api/v1/information-requests/'+$questionId+'/responses') (@{
                expectedInformationVersion=$question.version
                answers=@(@{questionId='Q1';answerText='Synthetic inventory purchase'})
                syntheticDocumentReferences=@('synthetic://inventory/demo')
            }) ([guid]::NewGuid().ToString())
            $null=Wait-Workflow @('LENDER_REVIEW')
            $submissionView=Request-Api 'LENDER' 'GET' ('/api/v1/submissions/'+$submission)
            if($submissionView.status -ne 'SUBMITTED'){throw 'Submission should resume SUBMITTED after answers'}
        }
        if($WithManualReview){
            $decision=[guid]::NewGuid().ToString()
            $null=Request-Api 'LENDER' 'POST' ('/api/v1/submissions/'+$submission+'/decisions') (@{decisionId=$decision;decision='MANUAL_REVIEW'}) $decision
            $null=Wait-Workflow @('MANUAL_REVIEW')
        }
        $decision=[guid]::NewGuid().ToString()
        if($Outcome -eq 'REJECT'){
            $null=Request-Api 'LENDER' 'POST' ('/api/v1/submissions/'+$submission+'/decisions') (@{decisionId=$decision;decision='REJECTED';reasonCode='SYNTHETIC_POLICY'}) $decision
            $null=Wait-Workflow @('REJECTED')
        }else{
            $offerId=[guid]::NewGuid().ToString()
            $expires=[datetime]::UtcNow.AddMinutes($(if($Outcome -eq 'EXPIRE'){1}else{60})).ToString('o')
            $null=Request-Api 'LENDER' 'POST' ('/api/v1/submissions/'+$submission+'/decisions') (@{
                decisionId=$decision;decision='APPROVED';offer=@{
                    offerId=$offerId;offeredAmount=$amount;currency='INR';annualInterestRatePercent='12.50'
                    interestRateType='FIXED';tenureMonths=12;repaymentFrequency='MONTHLY'
                    feesAmount='1000.00';termsReference='synthetic://terms/demo';expiresAt=$expires
                }
            }) $decision
            $null=Wait-Workflow @('OFFER_AVAILABLE')
            $offers=Request-Api 'SELLER' 'GET' ('/api/v1/applications/'+$script:applicationId+'/offers')
            $offer=@($offers.items|Where-Object offerId -eq $offerId)[0]
            if(-not $offer){throw 'Expected offer was not exposed by the API'}
            switch($Outcome){
                'ACCEPT'{
                    $key=[guid]::NewGuid().ToString();$body=@{expectedOfferVersion=$offer.version}
                    $first=Request-Api 'SELLER' 'POST' ('/api/v1/offers/'+$offerId+'/acceptance') $body $key
                    $replay=Request-Api 'SELLER' 'POST' ('/api/v1/offers/'+$offerId+'/acceptance') $body $key
                    if(($first|ConvertTo-Json -Depth 20 -Compress) -ne ($replay|ConvertTo-Json -Depth 20 -Compress)){throw 'Identical acceptance replay changed its recorded result'}
                    $null=Wait-Workflow @('OFFER_ACCEPTED')
                    $deadline=[datetime]::UtcNow.AddSeconds($TimeoutSeconds)
                    do{
                        $offers=Request-Api 'SELLER' 'GET' ('/api/v1/applications/'+$script:applicationId+'/offers')
                        $offer=@($offers.items|Where-Object offerId -eq $offerId)[0]
                        if($offer.lenderAcknowledgementStatus -eq 'FAILED'){throw 'Local acceptance succeeded but lender acknowledgement failed'}
                        if($offer.lenderAcknowledgementStatus -eq 'ACKNOWLEDGED'){break}
                        Start-Sleep -Seconds 1
                    }while([datetime]::UtcNow -lt $deadline)
                    if($offer.lenderAcknowledgementStatus -ne 'ACKNOWLEDGED'){throw 'Lender acknowledgement did not arrive'}
                }
                'DECLINE'{
                    $null=Request-Api 'SELLER' 'POST' ('/api/v1/offers/'+$offerId+'/decline') (@{expectedOfferVersion=$offer.version}) ([guid]::NewGuid().ToString())
                    $null=Wait-Workflow @('OFFER_DECLINED')
                }
                'WITHDRAW'{
                    $null=Request-Api 'LENDER' 'POST' ('/api/v1/submissions/'+$submission+'/offer-withdrawals') (@{offerId=$offerId}) ([guid]::NewGuid().ToString())
                    $null=Wait-Workflow @('OFFER_EXPIRED')
                }
                'EXPIRE'{
                    $null=Wait-Workflow @('OFFER_EXPIRED')
                    $blocked=$false
                    try{$null=Request-Api 'SELLER' 'POST' ('/api/v1/offers/'+$offerId+'/acceptance') (@{expectedOfferVersion=$offer.version}) ([guid]::NewGuid().ToString())}
                    catch{if($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 409){$blocked=$true}else{throw}}
                    if(-not $blocked){throw 'Expired acceptance was not rejected with409'}
                }
            }
        }
    }
    $succeeded=$true
    Write-Output ('Scenario passed: '+$Lender+' '+$Outcome+' application='+$script:applicationId+' correlation='+$trace)
}finally{
    New-Item -ItemType Directory -Force -Path $EvidenceDirectory|Out-Null
    $output=[ordered]@{runId=$runId;correlationId=$trace;applicationId=$script:applicationId;lender=$Lender;outcome=$Outcome;passed=$succeeded;requests=$evidence.ToArray()}
    [IO.File]::WriteAllText((Join-Path ([IO.Path]::GetFullPath($EvidenceDirectory)) ($runId+'.json')),($output|ConvertTo-Json -Depth 30),[Text.UTF8Encoding]::new($false))
}
