# De-provision MSP resources in customer sub

#4b1a121f-fd0e-4a21-94ef-1d246437a7ca

#Select-AzureRmSubscription -SubscriptionId '74903176-3e4e-492d-9d18-9afab69a0cf8' -TenantId 'b2a0bb8e-3f26-47f8-9040-209289b412a8'

#Select-AzureRmSubscription -SubscriptionId '4b1a121f-fd0e-4a21-94ef-1d246437a7ca' -TenantId 'b2a0bb8e-3f26-47f8-9040-209289b412a8'

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