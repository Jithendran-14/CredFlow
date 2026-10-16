param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('orchestration','integration','bank-a','nbfc-b')]
    [string]$Service,
    [string]$EnvFile=(Join-Path $PSScriptRoot '..\.env')
)
$ErrorActionPreference='Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if(Test-Path -LiteralPath $EnvFile -PathType Leaf){
    . (Join-Path $PSScriptRoot 'member3-env.ps1') -Path $EnvFile -Service $Service
} else {
    Write-Output 'No environment file found; using the current process environment.'
}
$jar = switch($Service){
    'orchestration' {'backend/orchestration-service/target/orchestration-service-1.0.0.jar'}
    'integration' {'backend/lender-integration-service/target/lender-integration-service-1.0.0.jar'}
    'bank-a' {'mocks/mock-bank-a/target/mock-bank-a-1.0.0.jar'}
    'nbfc-b' {'mocks/mock-nbfc-b/target/mock-nbfc-b-1.0.0.jar'}
}
$jarPath=Join-Path $projectRoot $jar
if(-not (Test-Path -LiteralPath $jarPath -PathType Leaf)){
    throw 'Executable JAR is missing. Run mvn clean package from the nested backend folder first.'
}
& java -jar $jarPath
exit $LASTEXITCODE
