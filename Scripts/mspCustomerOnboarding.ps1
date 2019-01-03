Connect-AzureRmAccount

"Logging in to Azure..."
$Conn = Get-AutomationPSCredential -Name 'MSPAdmin'
 
Connect-AzureRmAccount -Credential $conn
"Selecting Azure subscription..."
#Select-AzureRmSubscription -SubscriptionId '4b1a121f-fd0e-4a21-94ef-1d246437a7ca' 
$AzureSubscriptionId = '09e8ed26-7d8b-4678-a179-cfca8a0cef5c'

$omsworkspaceId = 'fd6d4881-9bf9-4e9b-be31-49f43e44a6de'
$omsworkspaceKey = 'IJWSZN2Jz2yHFXeOzL6DqI9krypRfPvw4PdSdIPjMnKy5rul5hUQafW6nB/el7JO27xWj1UdO08HTU1n0HKRag=='

# Checking for mgmt artifacts in customer subscription

$workspaces = Get-AzureRmResource -ResourceType Microsoft.OperationalInsights/workspaces

if ([string]::IsNullOrEmpty($workspaces))
{
    Write-Output "No Log Analytics workspaces found, so default workspace will be deployed...."

    $RgName = Get-Random
    $location = 'eastus'
    $deploymentName = Get-Random

    Write-Output "Creating default resource group for Azure mgmt..."
    
    $rg = New-AzureRmResourceGroup -Name $RgName -Location $location -Tag @{ManagedByMsp="Yes"}

    Write-Output "Deploying Azure mgmt into default resource group...."

    $deployment = New-AzureRmResourceGroupDeployment -Name $deploymentName `
                                       -ResourceGroupName $rg.resourcegroupName `
                                       -TemplateUri "https://raw.githubusercontent.com/krnese/managedServices/master/Templates/omsWorkspace.json" `
                                       -omsworkspacename (get-random) `
                                       -omsworkspaceregion 'eastus' `
                                       -omsautomationaccountname (get-random) `
                                       -omsautomationregion 'eastus2' `
                                       -Verbose

    # Using template outputs from previous deployment, into new subscription level deployment
    
    $deploymentOutputs = $deployment.Outputs.Values.value.split('/')
    $workspaceSubscriptionId = $deploymentOutputs[2]
    $workspaceResourceGroup = $deploymentOutputs[4]
    $workspaceName = $deploymentOutputs[8]
    
    # Deploying ARM template for ASC configuration

    Write-Output "Configuring Azure Security Center..."

    New-AzureRmDeployment -Name (get-random) `
                          -location $location `
                          -TemplateUri "https://raw.githubusercontent.com/krnese/managedServices/master/Templates/deployASCwithWorkspaceSettings.json" `
                          -securitySettings "On" `
                          -emailContact "john@doe.com" `
                          -securityPhoneNumber "555-343" `
                          -workspaceSubscriptionId $workspaceSubscriptionId `
                          -workspaceResourceGroup $workspaceResourceGroup `
                          -workspaceName $workspaceName `
                          -Verbose

    # Send traces to MSP tenant's Log Analytics workspace
    
    Write-Output "Customer was brought into management"

    import-module C:\AzureDeploy\oms\OMSIngestionAPI\OMSIngestionAPI\OMSIngestionAPI.psm1

        $onboardingTable = @()
        $onboardingData = new-object psobject -Property @{
            ManagedByMspTenant = 'Remotely';
            ResourceGroupName = $RgName;
            SubscriptionId = $AzureSubscriptionId;
            DeploymentName = $Deployment.DeploymentName;
            OnboardingState = $Deployment.ProvisioningState;
            TimeStamp = $Deployment.TimeStamp.ToUniversalTime().ToString('yyyy-MM-ddtHH:mm:ss');
            Log = 'Onboarding'
        }

    $onboardingTable += $onboardingData

    $onboardingJson = ConvertTo-Json -inputobject $onboardingTable -Depth 100

    Write-Output $onboardingJson 
    
    $LogType = 'AzureManagement'

    Send-OMSAPIIngestionData -customerId $omsworkspaceId -sharedKey $omsworkspaceKey -body $onboardingJson -logType $LogType
    }
    else
    {
        # Send traces to MSP tenant's Log Analytics workspace

        Write-Output "Azure mgmt services found in customer subscription, and we'll cancel the onboarding and continue the assessment"

        $onboardingTable = @()
        $onboardingData = new-object psobject -Property @{
            ManagedByMspTenant = 'Locally';
            SubscriptionId = $AzureSubscriptionId;
            OnboardingState = 'Pending';
            TimeStamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddtHH:mm:ss')
            Log = 'Onboarding'
        }

    $onboardingTable += $onboardingData

    $onboardingJson = ConvertTo-Json -inputobject $onboardingTable -Depth 100

    Write-Output $onboardingJson 
    
    $LogType = 'AzureManagement'

    Send-OMSAPIIngestionData -customerId $omsworkspaceId -sharedKey $omsworkspaceKey -body $onboardingJson -logType $LogType
    }
