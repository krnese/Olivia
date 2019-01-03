

# Getting some mgmt variables...

$omsworkspaceId = 'fd6d4881-9bf9-4e9b-be31-49f43e44a6de'
$omsworkspaceKey = 'IJWSZN2Jz2yHFXeOzL6DqI9krypRfPvw4PdSdIPjMnKy5rul5hUQafW6nB/el7JO27xWj1UdO08HTU1n0HKRag=='

$azMgmtTemplate = 'https://raw.githubusercontent.com/krnese/managedServices/vmManagement/Templates/omsWorkspace.json'
$azSecurityCenterTemplate = 'https://raw.githubusercontent.com/krnese/managedServices/vmManagement/Templates/deployASCwithWorkspaceSettings.json'
$omsExtensionWindowsTemplate = 'https://raw.githubusercontent.com/krnese/managedServices/vmManagement/Templates/omsExtensionWindows.json'
$omsExtensionLinuxTemplate = 'https://raw.githubusercontent.com/krnese/managedServices/vmManagement/Templates/omsExtensionLinux.json'

"Logging in to Azure..."
$Conn = Get-AutomationPSCredential -Name 'MSPAdmin' 
Connect-AzureRmAccount -Credential $conn
"Selecting Azure subscription..."

    $sub = Get-AzureRmSubscription -TenantId b2a0bb8e-3f26-47f8-9040-209289b412a8

    Write-Output $sub

    foreach($s in $sub)
    {
        if($s.Id -ne "0a938bc2-0bb8-4688-bd37-9964427fe0b0")
        {            
            Write-Output "Iterating through customer subscriptions..."
   Try
   {
           Select-AzureRmSubscription -SubscriptionId $s.Id -TenantId b2a0bb8e-3f26-47f8-9040-209289b412a8
   }
   Catch
   {
           $ErrorMessage = 'Failed to logon to Azure...'
           $ErrorMessage += "`n"
           $ErrorMessage += $_
           Write-Error -Message $ErrorMessage `
                       -ErrorAction Stop
   }
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
                                                         -TemplateUri $azMgmtTemplate `
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

        New-AzureRmDeployment -Name ASC `
                             -location $location `
                             -TemplateUri $azSecurityCenterTemplate `
                             -securitySettings "On" `
                             -eMailContact "john@doe.com" `
                             -securityPhoneNumber "555-343" `
                             -Verbose
    
        # Onboarding VMs to management
    
        # Grabbing the workspace
        Write-Output "Grabbing the workspace: `n $workspaceName"

        $workspace = Get-AzureRmResource -ResourceGroupName $rg.ResourceGroupName -Name $workspaceName -ResourceType Microsoft.OperationalInsights/workspaces

        Write-Output $workspace.Id

        Write-Output "Done, now we'll iterate throught the VMs, do a light assessment, and install the OMS extension if missing..."

        $VMs = Get-AzureRmVM

        foreach ($VM in $VMs)
        {
            $deploymentName = (get-random)
            Write-Output $VM.Name

       # Installing OMS agent...

                    if ($VM.OSProfile.WindowsConfiguration -ne $Null)
                    {
                        Write-Output "This is a Windows VM, so OMS extension for Windows Platform will be added"

                        New-AzureRmResourceGroupDeployment -Name $deploymentName `
                                                           -ResourceGroupName $vm.ResourceGroupName `
                                                           -TemplateUri $omsExtensionWindowsTemplate `
                                                           -vmName $vm.Name `
                                                           -location $vm.Location `
                                                           -logAnalytics $workspace.Id `
                                                           -AsJob `
                                                           -verbose

                    }
                    else
                    {
                        Write-Output "This is a Linux VM, so we'll add the OMS extension for Linux Platform"
                        
                        New-AzureRmResourceGroupDeployment -Name $deploymentName `
                                                           -ResourceGroupName $vm.ResourceGroupName `
                                                           -TemplateUri $omsExtensionLinuxTemplate `
                                                           -vmName $vm.Name `
                                                           -location $vm.Location `
                                                           -logAnalytics $workspace.Id `
                                                           -AsJob `
                                                           -verbose                        

                    }
               }
            


    # Send traces to MSP tenant's Log Analytics workspace
    
    Write-Output "Customer was brought into management"

    #import-module C:\AzureDeploy\oms\OMSIngestionAPI\OMSIngestionAPI\OMSIngestionAPI.psm1

        $onboardingTable = @()
        $onboardingData = new-object psobject -Property @{
            ManagedByMspTenant = 'Remotely';
            ResourceGroupName = $RgName;
            SubscriptionId = $s.Id;
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
    }
    else
    {
        # Do nothing

        Write-Output "Azure mgmt services found in customer subscription, and we'll cancel the onboarding and continue the assessment"

    } 
 }