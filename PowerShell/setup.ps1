# Misc
$today = Get-Date -Format yyyy-M-d
$variablesPathFileName = "c:\azuressissetupvariables$today.txt"

# Subscription and Resource Group
$SubscriptionName = <your Azure Subscription Name>
$ResourceGroupName = "Azure_SSIS_Demo_$(Get-Random)"

# Azure SQL Database logical server
$SQLServerName = "sql-server-$(Get-Random)"
$SQLServerAdmin = "server_admin_$(Get-Random)"
$SQLServerPass = "P@ssword$(Get-Random)"
$FirewallIPAddress = Invoke-RestMethod http://ipinfo.io/json | Select -exp ip
    
# SSISDB info
$SSISDBServerEndpoint = "$SQLServerName.database.windows.net"
$SSISDBServerAdminUserName = $SQLServerAdmin
$SSISDBServerAdminPassword = $SQLServerPass
$SSISDBPricingTier = "S0"

# Data factory name. Must be globally unique
# !!!!In public preview, only EastUS amd EastUS2 are supported.
$DataFactoryName = "DFSSISDEMO$(Get-Random)" 
$DataFactoryLocation = "EastUS" 

# Azure-SSIS integration runtime information. This is a Data Factory compute resource for running SSIS packages
$AzureSSISName = "azuressisdemo"
$AzureSSISDescription = "Azure SSIS demo"
# In public preview, only EastUS and NorthEurope are supported.
$AzureSSISLocation = "EastUS" 
# In public preview, only Standard_A4_v2, Standard_A8_v2, Standard_D1_v2, Standard_D2_v2, Standard_D3_v2, Standard_D4_v2 are supported
$AzureSSISNodeSize = "Standard_A4_v2"
# In public preview, only 1-10 nodes are supported.
$AzureSSISNodeNumber = 2 
# In public preview, only 1-8 parallel executions per node are supported.
$AzureSSISMaxParallelExecutionsPerNode = 2 


Login-AzureRmAccount
Select-AzureRmSubscription -SubscriptionName $SubscriptionName

Write-Output "!!!!Variable Values!!!!" | Add-Content $variablesPathFileName
Write-Output "today = $today" | Add-Content $variablesPathFileName
Write-Output "SubscriptionName = $SubscriptionName"  | Add-Content $variablesPathFileName
Write-Output "ResourceGroupName = $ResourceGroupName"  | Add-Content $variablesPathFileName
Write-Output "SQLServerName = $SQLServerName.database.windows.net"  | Add-Content $variablesPathFileName
Write-Output "SQLServerAdmin = $SQLServerAdmin"  | Add-Content $variablesPathFileName
Write-Output "SQLServerPass = $SQLServerPass"  | Add-Content $variablesPathFileName
Write-Output "FirewallIPAddress = $FirewallIPAddress"  | Add-Content $variablesPathFileName
Write-Output "DataFactoryLocation = $DataFactoryLocation"  | Add-Content $variablesPathFileName
Write-Output "DataFactoryName = $DataFactoryName"  | Add-Content $variablesPathFileName
Write-Output "AzureSSISName = $AzureSSISName" | Add-Content $variablesPathFileName

New-AzureRmResourceGroup -Location $DataFactoryLocation -Name $ResourceGroupName

New-AzureRmSqlServer -ResourceGroupName $ResourceGroupName `
    -ServerName $SQLServerName `
    -Location $DataFactoryLocation `
    -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SQLServerAdmin, $(ConvertTo-SecureString -String $SQLServerPass -AsPlainText -Force))

New-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName `
    -ServerName $SQLServerName `
    -FirewallRuleName "ClientIPAddress_$today" -StartIpAddress $FirewallIPAddress -EndIpAddress $FirewallIPAddress

New-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -AllowAllAzureIPs

$SSISDBConnectionString = "Data Source=" + $SSISDBServerEndpoint + ";User ID="+ $SSISDBServerAdminUserName +";Password="+ $SSISDBServerAdminPassword
$sqlConnection = New-Object System.Data.SqlClient.SqlConnection $SSISDBConnectionString;
Try
{
    $sqlConnection.Open();
}
Catch [System.Data.SqlClient.SqlException]
{
    Write-Warning "Cannot connect to your Azure SQL DB logical server/Azure SQL MI server, exception: $_"  ;
    Write-Warning "Please make sure the server you specified has already been created. Do you want to proceed? [Y/N]"
    $yn = Read-Host
    if(!($yn -ieq "Y"))
    {
        Return;
    } 
}

Set-AzureRmDataFactoryV2 -ResourceGroupName $ResourceGroupName `
                        -Location $DataFactoryLocation `
                        -Name $DataFactoryName


$secpasswd = ConvertTo-SecureString $SSISDBServerAdminPassword -AsPlainText -Force
$serverCreds = New-Object System.Management.Automation.PSCredential($SSISDBServerAdminUserName, $secpasswd)
Set-AzureRmDataFactoryV2IntegrationRuntime  -ResourceGroupName $ResourceGroupName `
                                            -DataFactoryName $DataFactoryName `
                                            -Name $AzureSSISName `
                                            -Type Managed `
                                            -CatalogServerEndpoint $SSISDBServerEndpoint `
                                            -CatalogAdminCredential $serverCreds `
                                            -CatalogPricingTier $SSISDBPricingTier `
                                            -Description $AzureSSISDescription `
                                            -Location $AzureSSISLocation `
                                            -NodeSize $AzureSSISNodeSize `
                                            -NodeCount $AzureSSISNodeNumber `
                                            -MaxParallelExecutionsPerNode $AzureSSISMaxParallelExecutionsPerNode 


write-host("##### Starting your Azure-SSIS integration runtime. This command takes 20 to 30 minutes to complete. #####")
Start-AzureRmDataFactoryV2IntegrationRuntime -ResourceGroupName $ResourceGroupName `
                                             -DataFactoryName $DataFactoryName `
                                             -Name $AzureSSISName `
                                             -Force
write-host("##### Completed #####")


# Verify script output and delete resource group
Pause

Stop-AzureRmDataFactoryV2IntegrationRuntime -ResourceGroupName $ResourceGroupName `
                                            -DataFactoryName $DataFactoryName `
                                            -Name $AzureSSISName `
                                            -Force

Remove-AzureRmResourceGroup -Name $ResourceGroupName

