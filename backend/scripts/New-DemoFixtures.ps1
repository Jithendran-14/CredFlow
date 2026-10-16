param(
    [datetime]$AsOfDate = (Get-Date).Date,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\demo-data')
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$marketplaceId = '33333333-3333-4333-8333-333333333333'
$bankId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1'
$nbfcId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2'
$firstCurrentMonth = [datetime]::new($AsOfDate.Year, $AsOfDate.Month, 1)
$definitions = @(
    @{Reference='DEMO-BANK-A';Subject='demo-seller-bank-a';Age=24;Gross='660000.00';Returns='60000.00';Payout='550000.00';Amount='500000.00';Lender=$bankId;Limit='600000.00'},
    @{Reference='DEMO-NBFC-B';Subject='demo-seller-nbfc-b';Age=9;Gross='220000.00';Returns='20000.00';Payout='180000.00';Amount='150000.00';Lender=$nbfcId;Limit='200000.00'}
)
$fixtures = foreach ($definition in $definitions) {
    $months = foreach ($offset in -3..-1) {
        $period = $firstCurrentMonth.AddMonths($offset)
        [ordered]@{
            month=$period.ToString('yyyy-MM'); periodStart=$period.ToString('yyyy-MM-dd'); periodEnd=$period.AddMonths(1).AddDays(-1).ToString('yyyy-MM-dd')
            grossSales=$definition.Gross; returnsAmount=$definition.Returns
            payoutAmount=$definition.Payout; orderCount=100; returnedOrderCount=10
            coverageStatus='COMPLETE'
        }
    }
    [ordered]@{
        marketplaceId=$marketplaceId; marketplaceSellerId=$definition.Reference
        sellerId=('SELLER-'+$definition.Reference); sellerSubject=$definition.Subject; fixtureIdentityId='DEMO-VERIFIED-001'
        businessProfile=@{displayName='Synthetic Demo Seller';businessName='Synthetic Demo Shop';businessStartDate=$AsOfDate.AddMonths(-$definition.Age).ToString('yyyy-MM-dd')}
        requestedAmount=$definition.Amount;currency='INR';loanPurpose='WORKING_CAPITAL'
        asOfDate=$AsOfDate.ToString('yyyy-MM-dd');sourceProvider='SYNTHETIC_MARKETPLACE';dataReference=$definition.Reference;dataVersion='1';retrievedAt=[datetime]::UtcNow.ToString('o');coverageStatus='COMPLETE';months=@($months)
        verificationStatus='VERIFIED'
        targetForAgreedDemoRules=@{selectedLenderId=$definition.Lender;indicativeMaxAmount=$definition.Limit;outcome='EVALUATED'}
    }
}
$document=[ordered]@{
    schemaVersion='1.0';purpose='Fictional Member2-format dataset definitions for owners to seed and authorize. Actual rule thresholds and financial sellerFixtureId mapping require their confirmation.'
    bankAId=$bankId;nbfcBId=$nbfcId;fixtures=@($fixtures)
}
$json=$document | ConvertTo-Json -Depth 12
[IO.File]::WriteAllText((Join-Path ([IO.Path]::GetFullPath($OutputDirectory)) 'marketplace-and-verification.json'), $json, [Text.UTF8Encoding]::new($false))
Write-Output 'Generated two synthetic fixture definitions. No database or API was modified.'
Write-Output 'Member 1 imports marketplace records; Member 2 imports verification fixtures and evaluates their own seeded rules.'
