$ErrorActionPreference='Stop'
$projectRoot=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$checks=0
function Assert-Boundary([bool]$Condition,[string]$Message){
    if(-not $Condition){throw $Message}
    $script:checks++
}
$services=@(
    @{Path='backend/orchestration-service';Artifact='orchestration-service';Main='OrchestrationServiceApplication';Own='ORCHESTRATION';Port=8084},
    @{Path='backend/lender-integration-service';Artifact='lender-integration-service';Main='LenderIntegrationServiceApplication';Own='INTEGRATION';Port=8087},
    @{Path='mocks/mock-bank-a';Artifact='mock-bank-a';Main='MockBankAApplication';Own='BANK_A';Port=8091},
    @{Path='mocks/mock-nbfc-b';Artifact='mock-nbfc-b';Main='MockNbfcBApplication';Own='NBFC_B';Port=8092}
)
foreach($service in $services){
    $module=Join-Path $projectRoot $service.Path
    [xml]$pom=Get-Content -LiteralPath (Join-Path $module 'pom.xml') -Raw
    Assert-Boundary ($pom.project.artifactId -eq $service.Artifact) 'Incorrect deployable artifact identity'
    $pluginNames=@($pom.project.build.plugins.plugin | ForEach-Object {$_.artifactId})
    Assert-Boundary ($pluginNames -contains 'spring-boot-maven-plugin') 'Missing executable packaging plugin'
    $app=Get-ChildItem -LiteralPath (Join-Path $module 'src/main/java') -Recurse -Filter ($service.Main+'.java')
    Assert-Boundary (@($app).Count -eq 1) 'Expected exactly one owning application entrypoint'
    $properties=Get-Content -LiteralPath (Join-Path $module 'src/main/resources/application.properties') -Raw
    Assert-Boundary ($properties.Contains('spring.application.name='+$service.Artifact)) 'Wrong service name'
    Assert-Boundary ($properties.Contains($service.Own+'_DB_PASSWORD')) 'Missing owning schema password setting'
    foreach($layer in @('controller','service','dto','api','entity','repository','scheduler')){
        $layerPath=Join-Path $module ('src/main/java/com/credflow/'+$layer)
        Assert-Boundary (Test-Path -LiteralPath $layerPath -PathType Container) ('Missing layer package '+$layer)
        $files=@(Get-ChildItem -LiteralPath $layerPath -File -Filter '*.java')
        Assert-Boundary ($files.Count -gt 0) ('Empty layer package '+$layer)
        foreach($file in $files){
            $source=Get-Content -LiteralPath $file.FullName -Raw
            Assert-Boundary ($source.Contains('package com.credflow.'+$layer+';')) ('Wrong Java package in '+$file.Name)
        }
    }
    foreach($other in $services | Where-Object {$_.Artifact -ne $service.Artifact}){
        Assert-Boundary (-not $properties.Contains($other.Own+'_DB_PASSWORD')) 'Peer database credentials leaked into application configuration'
        $dependencies=@($pom.project.dependencies.dependency | ForEach-Object {$_.artifactId})
        Assert-Boundary ($dependencies -notcontains $other.Artifact) 'An application depends on another executable application'
    }
}
foreach($library in @('member3-common')){
    $module=Join-Path $projectRoot ('backend/'+$library)
    [xml]$pom=Get-Content -LiteralPath (Join-Path $module 'pom.xml') -Raw
    $plugins=@($pom.project.build.plugins.plugin | ForEach-Object {$_.artifactId})
    Assert-Boundary ($plugins -notcontains 'spring-boot-maven-plugin') 'Library must not be packaged as an application'
    Assert-Boundary (-not (Test-Path -LiteralPath (Join-Path $module 'src/main/resources/application.properties'))) 'Library must not carry application runtime properties'
}
$javaFiles=Get-ChildItem -LiteralPath $projectRoot -Recurse -File -Filter '*.java' | Where-Object {$_.FullName -notmatch '[\\/]target[\\/]'}
Assert-Boundary (-not ($javaFiles | Where-Object Name -eq 'SimulatorDataSources.java')) 'Combined routing datasource must be absent'
Assert-Boundary (-not ($javaFiles | Where-Object Name -eq 'MockExternalSystemsApplication.java')) 'Combined application must be absent'
foreach($obsolete in @('WorkflowModule.java','IntegrationModule.java')){
    Assert-Boundary (-not ($javaFiles | Where-Object Name -eq $obsolete)) 'Old combined module file remains'
}
$defaults=Get-Content -LiteralPath (Join-Path $projectRoot 'backend/member3-common/src/main/resources/member3-defaults.properties') -Raw
Assert-Boundary ($defaults.Contains('BANK_A_URL:http://localhost:8091')) 'Missing independent Bank A URL'
Assert-Boundary ($defaults.Contains('NBFC_B_URL:http://localhost:8092')) 'Missing independent NBFC B URL'
Write-Output "PASS: $checks service boundary assertions. These are source/configuration checks; live process and Oracle verification remain separate."
