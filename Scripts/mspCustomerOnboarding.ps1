
Connect-AzureRmAccount

"Logging in to Azure..."
$Conn = Get-AutomationPSCredential -Name 'MSPAdmin'
 
Connect-AzureRmAccount -Credential $conn
"Selecting Azure subscription..."

# Set subscription context 

Select-AzureRmSubscription -SubscriptionId <customer Subscription Id>

# Checking for mgmt artifacts in customer subscription

$workspaces = Get-AzureRmResource -ResourceType Microsoft.OperationalInsights/workspaces

if ([string]::IsNullOrEmpty($workspaces))
{
    Write-Output "No Log Analytics workspaces found, so default workspace will be deployed...."

    $omsExtensionWindowsTemplate = 'https://raw.githubusercontent.com/krnese/Olivia/master/Templates/omsExtensionWindows.json'
    $omsExtensionLinuxTemplate = 'https://raw.githubusercontent.com/krnese/Olivia/master/Templates/omsExtensionLinux.json'

    $RgName = Get-Random
    $location = 'eastus'
    $workspaceLocation = 'westeurope'
    $automationLocation = 'westeurope'
    $deploymentName = Get-Random
    $workspaceName = Get-Random
    $automationName = Get-Random

    Write-Output "Deploying Azure mgmt into default resource group...."

    $deployment = New-AzureRmDeployment -Name $deploymentName `
                                       -Location $location `
                                       -rgName $RgName `
                                       -rgLocation $location `
                                       -TemplateUri "https://raw.githubusercontent.com/krnese/Olivia/master/Templates/rgWithAzureMgmt.json" `
                                       -workspacename $workspaceName `
                                       -workspaceLocation $workspaceLocation `
                                       -automationaccountname $automationName `
                                       -automationLocation $automationLocation `
                                       -Verbose

    # Onboarding VMs to management
    
        # Grabbing the workspace
        Write-Output "Grabbing the workspace: `n $workspaceName"

        $workspace = Get-AzureRmResource -ResourceGroupName $rgName -Name $workspaceName -ResourceType Microsoft.OperationalInsights/workspaces

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

    Write-Output "Customer was brought into management"
}
else {
    Write-Output "Mgmt services already present in customer subscription..."
}