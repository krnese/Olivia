# De-provision Mgmt resources in customer sub

# Connect and set subscription context

Login-AzureRmAccount

Select-AzureRmSubscription -SubscriptionId <subId>

$VMs = Get-AzureRmVm

Write-Output "Fetched all VMs..."

    Foreach ($vm in $vms)
    {
    Write-Output "Removing OMS VM exension...."
    Write-output $vm.id
Try
{
    Remove-AzureRmVMExtension -VMName $vm.Name -ResourceGroupName $vm.ResourceGroupName -Name 'omsOnboarding' -Force -Verbose

    Write-Output "Done!"
}
Catch
{
    $ErrorMessage = 'Unable to remove OMS VM Extension'
    $ErrorMessage += "`n"
    $ErrorMessage += $vm.Name
    $ErrorMessage += $_
    Write-Error -Message $ErrorMessage `
                -ErrorAction Stop
}
    }

# Removing Mgmt Services...
Try
{
    $workspace = Get-AzureRmResource -ResourceType Microsoft.OperationalInsights/workspaces

    Write-Output "Removing Azure mgmt services..."
    Remove-AzureRmResourceGroup -Name $workspace.ResourceGroupName -Force -Verbose

    Write-Output $workspace "Status: Removed"
}
Catch
{
    $ErrorMessage = 'Unable to remove Azure mgmt services'
    $ErrorMessage += "`n"
    $ErrorMessage += $workspace.ResourceId
    $ErrorMessage += $_
    Write-Error -Message $ErrorMessage `
                -ErrorAction Stop
}

    Write-Output "Done!"