param(
    [Parameter(Mandatory = $true)]
    [string] $clientSecret,
    [string] $suffix
)

########################################
# Login to Azure with PS and Azure CLI #
########################################

$cred = New-Object `
    System.Management.Automation.PSCredential ($env:ARM_CLIENT_ID, (ConvertTo-SecureString $clientSecret -AsPlainText -Force))

try {
    $x = Connect-AzAccount `
        -ServicePrincipal `
        -Credential $cred `
        -TenantId $env:ARM_TENANT_ID `
        -SubscriptionId $env:ARM_SUBSCRIPTION_ID `
        -InformationAction Ignore `
        -WarningAction Ignore

    $y = az login `
        --service-principal `
        -u $env:ARM_CLIENT_ID `
        -p $ClientSecret `
        --tenant $env:ARM_TENANT_ID `
        -o none

    $z = az account set `
        -s $env:ARM_SUBSCRIPTION_ID `
        -o none
}
catch {

    Write-Host "========================================"
    Write-Host "= Unsuccessful When Logging Into Azure ="
    Write-Host "========================================"
    Write-Host $_

}

Write-Host "=================================="
Write-Host "= Successfully Logged Into Azure ="
Write-Host "=================================="

###################################
# Test Infrastructure is deployed #
###################################

## Create Global Test Variables

$environ = Get-AzContext | Select-Object -ExpandProperty Subscription | Select-Object -ExpandProperty Name

$rgName = "RG-$environ-Core$(if ($suffix) { "-$suffix".ToLower() })"

Describe "Azure Resource Group in $environ$(if ($suffix) { "-$suffix".ToLower() })" {

    # Initialise Necessary Variables

    $rg = Get-AzResourceGroup -Name $rgName

    # Run Tests

    It "should exist" {

        $rg.ResourceGroupName | Should -Be $rgName

    }

    It "should have a location of UK South" {

        $rg.Location | Should -Be "uksouth"

    }
}
Describe "Azure API Management Gateway in $environ$(if ($suffix) { "-$suffix".ToLower() })" {

    # Initialise Necessary Variables

    $apim = Get-AzApiManagement -ResourceGroupName $rgName -Name "sra-$environ-apim$(if ($suffix) { "-$suffix".ToLower() })"

    $apimCont = New-AzApiManagementContext -ResourceGroupName $rgName -ServiceName "sra-$environ-apim$(if ($suffix) { "-$suffix".ToLower() })"
    
    $expectedSROperations = @(
        "Organisation_GetOrganisation",
        "Organisation_GetPeopleForOrganisation",
        "Organisation_SearchPeopleForOrganisation",
        "Person_GetPerson",
        "Search_SearchOrganisation",
        "Search_SearchPerson",
        "Search_SearchPersonAndOrganisation",
        "Search_SearchPersonAutoComplete"
    )

    $expectedDSOperations = @(
        "FirmSearch",
        "GetAllFirms",
        "GetAllOrganisations",
        "GetFirm",
        "OrganisationSearch"
    )

    # Run Tests

    It "should exist" {

        $apim.Name | Should -Be "sra-$environ-apim$(if ($suffix) { "-$suffix".ToLower() })"

    }

    It "should have a location of UK South" {

        $apim.Location | Should -Be "UK South"
    }

    It "should have an API called sra-digital-register, it should be current and a subscription should be required" {

        $api = Get-AzApiManagementApi -Context $apimCont -ApiId sra-digital-register

        $api | Should -Not -BeNullOrEmpty

        $api.ApiId | Should -Be "sra-digital-register"

        $api.IsCurrent | Should -BeTrue

        $api.SubscriptionRequired | Should -BeTrue

    }

    It "should have an API called sra-data-share-api, it should be current and a subscription should be required" {

        $api = Get-AzApiManagementApi -Context $apimCont -ApiId sra-data-share-api

        $api | Should -Not -BeNullOrEmpty

        $api.ApiId | Should -Be "sra-data-share-api"

        $api.IsCurrent | Should -BeTrue

        $api.SubscriptionRequired | Should -BeTrue

    }

    It "should have a product called DigitalRegister and it should be published" {

        $apiProd = Get-AzApiManagementProduct -Context $apimCont -Title DigitalRegister | Where-Object { $_.Title -eq "DigitalRegister" }

        $apiProd | Should -Not -BeNullOrEmpty

        $apiProd.Title | Should -Be "DigitalRegister"

        $apiProd.State | Should -Be "Published"
    }

    It "should have a product called DataSharing and it should be published" {

        $apiProd = Get-AzApiManagementProduct -Context $apimCont -Title DataSharing | Where-Object { $_.Title -eq "DataSharing" }

        $apiProd | Should -Not -BeNullOrEmpty

        $apiProd.Title | Should -Be "DataSharing"

        $apiProd.State | Should -Be "Published"
    }

    foreach ($exSROp in $expectedSROperations) {
        It "should have the solicitors register API with an operation called $exSROp" {

            $operation = Get-AzApiManagementOperation -Context $apimCont -ApiId sra-digital-register -OperationId $exSROp

            $operation | Should -Not -BeNullOrEmpty

            $operation.Name | Should -Be $exSROp
        }
    }

    foreach ($exDSOp in $expectedDSOperations) {
        It "should have the datashare API with an operation called $exDSOp" {

            $operation = Get-AzApiManagementOperation -Context $apimCont -ApiId sra-data-share-api -OperationId $exDSOp

            $operation | Should -Not -BeNullOrEmpty

            $operation.Name | Should -Be $exDSOp
        }
    }

}
Describe "Azure App Service Plan in $environ$(if ($suffix) { "-$suffix".ToLower() })" {

    # Initialise Necessary Variables

    $asp = Get-AzAppServicePlan -ResourceGroupName $rgName
    
    # Run Tests

    It "should exist" {

        $asp.Name | Should -Be "sra-$environ-digitalregister-asp$(if ($suffix) { "-$suffix".ToLower() })"

    }

    It "should have a location of UK South" {

        $asp.GeoRegion | Should -Be "UK South"

    }

    It "should be set to Standard S1 tier" {

        $asp.Sku.Tier | Should -Be "Standard"
        
        $asp.Sku.Size | Should -Be "S1"

    }
}
Describe "Digital Register Azure App Service in $environ$(if ($suffix) { "-$suffix".ToLower() })" {

    # Initialise Necessary Variables
    
    $api = Get-AzWebApp -ResourceGroupName $rgName -Name "sra-$environ-digitalregister-api$(if ($suffix) { "-$suffix".ToLower() })"
    
    $apiSettings = az webapp config appsettings list --resource-group $rgName --name "sra-$environ-digitalregister-api$(if ($suffix) { "-$suffix".ToLower() })" | ConvertFrom-Json
    
    $apiSettingNames = $apiSettings | Select-Object -ExpandProperty name

    $connectionString = az webapp config connection-string list --resource-group $rgName --name "sra-$environ-digitalregister-api$(if ($suffix) { "-$suffix".ToLower() })" | ConvertFrom-Json

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


    # Run Tests

    It "should exist and be enabled" {

        $api.Name | Should -Be "sra-$environ-digitalregister-api$(if ($suffix) { "-$suffix".ToLower() })"
        
        $api.Enabled | should -BeTrue

    }

    It "should have a location of UK South" {

        $api.Location | Should -Be "UK South"

    }

    It "should only allow HTTPS traffic" {

        $api.HttpsOnly | Should -BeTrue

    }

    It "should have an app setting called SearchService_ApiKey" {

        $webKey = (Get-AzSearchQueryKey -ResourceGroupName $rgName -ServiceName "sra-$environ-ss$(if ($suffix) { "-$suffix".ToLower() })" | Where-Object { $_.Name -eq "SRA_Web" }).Key

        $settingValue = $apiSettings[($apiSettingNames.IndexOf("SearchService_ApiKey"))] | Select-Object -ExpandProperty value

        "SearchService_ApiKey" | Should -BeIn $apiSettingNames

        $settingValue | Should -Be $webKey
    }

    It "should have an app setting called SearchService_ApiVersion" {

        $settingValue = $apiSettings[($apiSettingNames.IndexOf("SearchService_ApiVersion"))] | Select-Object -ExpandProperty value

        "SearchService_ApiVersion" | Should -BeIn $apiSettingNames
        
        $settingValue | Should -Be "2019-05-06"

    }

    It "should have an app setting called SearchService_BaseUri" {
        
        $settingValue = $apiSettings[($apiSettingNames.IndexOf("SearchService_BaseUri"))] | Select-Object -ExpandProperty value

        "SearchService_BaseUri" | Should -BeIn $apiSettingNames
        
        $settingValue | Should -Be "https://sra-$environ-ss$(if ($suffix) { "-$suffix".ToLower() }).search.windows.net/"

    }

    It "should have a connection string called DigitalRegister" {

        $connStringName = $connectionString | Select-Object -ExpandProperty name
       
        $connStringName | Should -Be "DigitalRegister"
    }

}
Describe "Data Share Azure App Service in $environ$(if ($suffix) { "-$suffix".ToLower() })" {

    # Initialise Necessary Variables
    
    $api = Get-AzWebApp -ResourceGroupName $rgName -Name "sra-$environ-datashare-api$(if ($suffix) { "-$suffix".ToLower() })"
    
    $apiSettings = az webapp config appsettings list --resource-group $rgName --name "sra-$environ-datashare-api$(if ($suffix) { "-$suffix".ToLower() })" | ConvertFrom-Json
    
    $apiSettingNames = $apiSettings | Select-Object -ExpandProperty name

    $connectionString = az webapp config connection-string list --resource-group $rgName --name "sra-$environ-datashare-api$(if ($suffix) { "-$suffix".ToLower() })" | ConvertFrom-Json

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12


    # Run Tests

    It "should exist and be enabled" {

        $api.Name | Should -Be "sra-$environ-datashare-api$(if ($suffix) { "-$suffix".ToLower() })"
        
        $api.Enabled | should -BeTrue

    }

    It "should have a location of UK South" {

        $api.Location | Should -Be "UK South"

    }

    It "should only allow HTTPS traffic" {

        $api.HttpsOnly | Should -BeTrue

    }

    It "should have an app setting called KeyVaultName" {

        $kvName = (Get-AzKeyVault -ResourceGroupName $rgName -VaultName "sra-$environ-kv$(if ($suffix) { "-$suffix".ToLower() })").VaultName

        $settingValue = $apiSettings[($apiSettingNames.IndexOf("KeyVaultName"))] | Select-Object -ExpandProperty value

        "KeyVaultName" | Should -BeIn $apiSettingNames

        $settingValue | Should -Be $kvName
    }

    It "should have a connection string called DataSharing" {

        $connStringName = $connectionString | Select-Object -ExpandProperty name
       
        $connStringName | Should -Contain "DataSharing"
       
    }

    It "should have a connection string called AzureWebJobsDashboard" {

        $connStringName = $connectionString | Select-Object -ExpandProperty name
       
        $connStringName | Should -Contain "AzureWebJobsDashboard"
       
    }

}
Describe "Azure SQL Server in $environ$(if ($suffix) { "-$suffix".ToLower() })" {

    # Initialise Necessary Variables

    $sqls = Get-AzSqlServer -ResourceGroupName $rgName -ServerName "sra-$environ-sqls$(if ($suffix) { "-$suffix".ToLower() })"
    
    # Run Tests

    It "should exist" {

        $sqls.ServerName | Should -Be "sra-$environ-sqls$(if ($suffix) { "-$suffix".ToLower() })"

    }

    It "should have a location of UK South" {

        $sqls.Location | Should -Be "uksouth"

    }

    It "should have Advanced Data Security Enabled" {
    
        $sqlAS = Get-AzSqlServerAdvancedDataSecurityPolicy -ResourceGroupName $rgName -ServerName "sra-$($environ.ToLower())-sqls$(if ($suffix) { "-$suffix".ToLower() })" -WarningAction Ignore
    
        $sqlAS | Should -Not -BeNullOrEmpty

        $sqlAS.IsEnabled | Should -BeTrue
    }


    It "should have Threat Protection and email admins Enabled" {
    
        $sqlTP = Get-AzSqlServerAdvancedThreatProtectionSetting -ResourceGroupName $rgName -ServerName "sra-$($environ.ToLower())-sqls$(if ($suffix) { "-$suffix".ToLower() })" -WarningAction Ignore
    
        $sqlTP | Should -Not -BeNullOrEmpty

        $sqlTP.ThreatDetectionState | Should -Be "Enabled"

        $sqlTP.EmailAdmins | Should -BeTrue
    }
   

    It "should have Auditing Enabled connected to a Storage Account and Log Analytics" {
    
        $sqlAu = Get-AzSqlServerAudit -ResourceGroupName $rgName -ServerName "sra-$($environ.ToLower())-sqls$(if ($suffix) { "-$suffix".ToLower() })" -WarningAction Ignore
    
        $sqlAu | Should -Not -BeNullOrEmpty

        $sqlAu.BlobStorageTargetState | Should -Be "Enabled"

        $sqlAu.StorageAccountResourceId | Should -Not -BeNullOrEmpty

        $sqlAu.LogAnalyticsTargetState | Should -Be "Enabled"

        $sqlAu.WorkspaceResourceId | Should -Not -BeNullOrEmpty
    }

    It "should have a firewall rule for Azure IPs" {
   
        $sqlFw = Get-AzSqlServerFirewallRule -ResourceGroupName $rgName -ServerName "sra-$($environ.ToLower())-sqls$(if ($suffix) { "-$suffix".ToLower() })" -WarningAction Ignore
    
        $sqlFw | Should -Not -BeNullOrEmpty

        "AllowAllWindowsAzureIps" | Should -BeIn $sqlFw.FirewallRuleName
    }

}
Describe "Azure SQL Database in $environ$(if ($suffix) { "-$suffix".ToLower() })" {

    # Initialise Necessary Variables

    $sqldb = Get-AzSqlDatabase -ResourceGroupName $rgName -ServerName "sra-$($environ.ToLower())-sqls$(if ($suffix) { "-$suffix".ToLower() })" -DatabaseName digital_register -WarningAction Ignore
    
    # Run Tests

    It "should exist" {

        $sqldb.DatabaseName | Should -Be "digital_register"

    }

    It "should have a location of UK South" {

        $sqldb.Location | Should -Be "uksouth"

    }
}
Describe "Azure Data Factory in $environ$(if ($suffix) { "-$suffix".ToLower() })" {

    # Initialise Necessary Variables

    $adf = Get-AzDataFactoryV2 -ResourceGroupName $rgName -Name "sra-$environ-adf$(if ($suffix) { "-$suffix".ToLower() })"
    
    $expectedPipelineNames = @( 
        "cdm_pipeline"
    )

    $expectedDatasetNames = @( 
        "cdm_source_dataset", 
        "dr_register_table_cdm",
        "dr_source_delta_id_table",
        "dr_source_table_cdm",
        "dr_target_dataset_cdm" 
    )

    $expectedLinkedServiceNames = @(
        "Key_Vault", 
        "DR_Database",
        "CDM_Connection"
    )

    # Run Tests

    It "should exist" {

        $adf.DataFactoryName | Should -Be "sra-$environ-adf$(if ($suffix) { "-$suffix".ToLower() })"

    }

    It "should have a location of UK South" {

        $adf.Location | Should -Be "uksouth"
    }

    It "should have a trigger called dr_daily_trigger" {

        $triggers = Get-AzDataFactoryV2Trigger -DataFactoryName "sra-$environ-adf$(if ($suffix) { "-$suffix".ToLower() })" -ResourceGroupName $rgName

        $triggers | Should -Not -BeNullOrEmpty

        $triggers.Name | Should -Be "dr_daily_trigger"
    
    }

    foreach ($exPipeline in $expectedPipelineNames) {
        It "should have a pipeline called $exPipeline" {

            $pipeline = Get-AzDataFactoryV2Pipeline -DataFactoryName "sra-$environ-adf$(if ($suffix) { "-$suffix".ToLower() })" -ResourceGroupName $rgName -Name $exPipeline

            $pipeline | Should -Not -BeNullOrEmpty

            $pipeline.Name | Should -Be $exPipeline
    
        }
    }
  
    foreach ($exDataset in $expectedDatasetNames) {
        It "should have a dataset called $exDataset" {

            $dataset = Get-AzDataFactoryV2Dataset -DataFactoryName "sra-$environ-adf$(if ($suffix) { "-$suffix".ToLower() })" -ResourceGroupName $rgName -Name $exDataset

            $dataset | Should -Not -BeNullOrEmpty

            $dataset.Name | Should -Be $exDataset

        } 
    }

    foreach ($exLinkedService in $expectedLinkedServiceNames) {
        It "should have a linked service called $exLinkedService" {

            $linkedService = Get-AzDataFactoryV2LinkedService -DataFactoryName "sra-$environ-adf$(if ($suffix) { "-$suffix".ToLower() })" -ResourceGroupName $rgName -Name $exLinkedService

            $linkedService | Should -Not -BeNullOrEmpty

            $linkedService.Name | Should -Be $exLinkedService

        }
    }
}
Describe "Azure Search Service in $environ$(if ($suffix) { "-$suffix".ToLower() })" {

    # Initialise Necessary Variables
    
    $ss = Get-AzSearchService -ResourceGroupName $rgName -Name "sra-$environ-ss$(if ($suffix) { "-$suffix".ToLower() })"

    $ssadminkey = Get-AzSearchAdminKeyPair -ResourceGroupName $rgName -ServiceName "sra-$environ-ss$(if ($suffix) { "-$suffix".ToLower() })"
    
    # Run Tests

    It "should exist" {

        $ss.Name | Should -Be "sra-$environ-ss$(if ($suffix) { "-$suffix".ToLower() })"

    }

    It "should have a location of UK South" {

        $ss.Location | Should -Be "UK South"
    }

    It "should have an index called digitalregister-person" {

        try {

            Invoke-RestMethod `
                -Method Get `
                -Uri "https://sra-$environ-ss$(if ($suffix) { "-$suffix".ToLower() }).search.windows.net/datasources/digitalregister-person?api-version=2019-05-06" `
                -Headers @{
                "api-key"      = "$( $ssadminkey.Primary )"
                "Content-Type" = "application/json"
            } `
                -UseBasicParsing

        }
        catch {
            
            $err = $_

        }

        $err | Should -BeNullOrEmpty

        
    }

    It "should have an indexer called digitalregister-person" {

        try {

            Invoke-RestMethod `
                -Method Get `
                -Uri "https://sra-$environ-ss$(if ($suffix) { "-$suffix".ToLower() }).search.windows.net/indexers/digitalregister-person?api-version=2019-05-06" `
                -Headers @{
                "api-key"      = "$( $ssadminkey.Primary )"
                "Content-Type" = "application/json"
            } `
                -UseBasicParsing

        }
        catch {
            
            $err = $_

        }

        $err | Should -BeNullOrEmpty

       
    }

    It "should have an data source called digitalregister-person" {

        try {

            Invoke-RestMethod `
                -Method Get `
                -Uri "https://sra-$environ-ss$(if ($suffix) { "-$suffix".ToLower() }).search.windows.net/indexes/digitalregister-person?api-version=2019-05-06" `
                -Headers @{
                "api-key"      = "$( $ssadminkey.Primary )"
                "Content-Type" = "application/json"
            } `
                -UseBasicParsing

        }
        catch {
            
            $err = $_

        }

        $err | Should -BeNullOrEmpty

        
    }

    It "should have an index called digitalregister-organisation" {

        try {

            Invoke-RestMethod `
                -Method Get `
                -Uri "https://sra-$environ-ss$(if ($suffix) { "-$suffix".ToLower() }).search.windows.net/datasources/digitalregister-organisation?api-version=2019-05-06" `
                -Headers @{
                "api-key"      = "$( $ssadminkey.Primary )"
                "Content-Type" = "application/json"
            } `
                -UseBasicParsing

        }
        catch {
            
            $err = $_

        }

        $err | Should -BeNullOrEmpty

        
    }

    It "should have an indexer called digitalregister-organisation" {

        try {

            Invoke-RestMethod `
                -Method Get `
                -Uri "https://sra-$environ-ss$(if ($suffix) { "-$suffix".ToLower() }).search.windows.net/indexers/digitalregister-organisation?api-version=2019-05-06" `
                -Headers @{
                "api-key"      = "$( $ssadminkey.Primary )"
                "Content-Type" = "application/json"
            } `
                -UseBasicParsing

        }
        catch {
            
            $err = $_

        }

        $err | Should -BeNullOrEmpty

       
    }

    It "should have an data source called digitalregister-organisation" {

        try {

            Invoke-RestMethod `
                -Method Get `
                -Uri "https://sra-$environ-ss$(if ($suffix) { "-$suffix".ToLower() }).search.windows.net/indexes/digitalregister-organisation?api-version=2019-05-06" `
                -Headers @{
                "api-key"      = "$( $ssadminkey.Primary )"
                "Content-Type" = "application/json"
            } `
                -UseBasicParsing

        }
        catch {
            
            $err = $_

        }

        $err | Should -BeNullOrEmpty

        
    }

    It "should have two query keys called SRA_Web and SRA_Automation" {
        
        $keys = Get-AzSearchQueryKey -ResourceGroupName $rgName -ServiceName "sra-$environ-ss$(if ($suffix) { "-$suffix".ToLower() })" | Select-Object -ExpandProperty Name

        $keys | Should -Not -BeNullOrEmpty

        "SRA_Web" | Should -BeIn $keys

        "SRA_Automation" | Should -BeIn $keys
        
    }
}
Describe "Azure Key Vault in $environ$(if ($suffix) { "-$suffix".ToLower() })" {

    # Initialise Necessary Variables

    $kv = Get-AzKeyVault -ResourceGroupName $rgName -VaultName "sra-$environ-kv$(if ($suffix) { "-$suffix".ToLower() })" -ErrorAction SilentlyContinue

    $expectedSecrets = @(
        "CDMConnString",
        "DigitalRegisterDBConnString",
        "DSA-ApplicationInsightsInstrumentationKey",
        "DSA-Dashboard-ConnectionString",
        "DSA-DBconnectionstring",
        "dsa-filestoreconnectionstring"
        "DSA-SearchApiKey"
        "DSA-SearchApiUrlBase"
        "DSA-SearchApiUrlPath"
        "$($environ)ApimDSKey"
        "$($environ)ApimKey"
    )

    # Run Tests

    It "should exist" {

        $kv.VaultName | Should -Be "sra-$environ-kv$(if ($suffix) { "-$suffix".ToLower() })"

    }

    It "should have a location of UK South" {

        $kv.Location | Should -Be "uksouth"

    }

    
    It "should be enabled for template deployment only" {

        $kv.EnabledForTemplateDeployment | Should -BeTrue

        $kv.EnabledForDeployment | Should -BeFalse
    }

    It "should have an access policy for Terraform" {

        $kvaccpols = $kv.AccessPolicies

        foreach ($kvaccpol in $kvaccpols) {

            if ($kvaccpol.DisplayName.ToLower() -like "Terraform*".ToLower()) {
                
                $kvap = $kvaccpol
                break
            
            }
            else {
            
                $kvap = $null
          
            }
        }

        $kvap.DisplayName | Should -Not -BeNullOrEmpty
    }

    It "should have an access policy for ADF" {

        $kvaccpols = $kv.AccessPolicies

        foreach ($kvaccpol in $kvaccpols) {

            if ($kvaccpol.DisplayName.ToLower() -like "sra-$environ-adf*".ToLower()) {
                
                $kvap = $kvaccpol
                break
            
            }
            else {
            
                $kvap = $null
          
            }
        }

        $kvap.DisplayName | Should -Not -BeNullOrEmpty
    }

    # Run Tests

    foreach ($exSecret in $expectedSecrets) {
        It "should contain a secret called $exSecret and it should be enabled" {

            $secret = Get-AzKeyVaultSecret -VaultName "sra-$environ-kv$(if ($suffix) { "-$suffix".ToLower() })" -Name $exSecret

            $secret | Should -Not -BeNullOrEmpty

            $secret.Name | Should -Be $exSecret
        
            $secret.Enabled | Should -BeTrue

            $secret.SecretValue | Should -Not -BeNullOrEmpty

            $secret.SecretValue | Should -Not -Be "Unknown"
       
        }
    }
}

#########################################
# Logout to Azure with PS and Azure CLI #
#########################################

try {

    $x = Disconnect-AzAccount

    $x = az logout

    Write-Host "===================================="
    Write-Host "= Successfully Logged Out Of Azure ="
    Write-Host "===================================="

}
catch {

    Write-Host "==========================="
    Write-Host "= Cannot Log Out Of Azure ="
    Write-Host "==========================="
    Write-Host $_

}
