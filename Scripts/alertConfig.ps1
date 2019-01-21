# VM Alert mgmt

    Write-Output "Authenticating to Azure subs using SPN..."

    $sub = Get-AzureRmSubscription

    Write-Output $sub

    foreach($s in $sub)
    {

         Write-Output "Iterating through customer subscriptions..."
Try
{
        Select-AzureRmSubscription -SubscriptionId $s.Id
}
Catch
{
        $ErrorMessage = 'Failed to logon to Azure...'
        $ErrorMessage += "`n"
        $ErrorMessage += $_
        Write-Error -Message $ErrorMessage `
                    -ErrorAction Stop
}

        Write-Output "Updating VM alert config per new commit..."

        $VMs = Get-AzureRmVm

        Write-Output "Fetched all VMs..."

Try
{  
    Foreach ($vm in $vms)
    {
        Write-Output "Deploying default alerts...."
        Write-output $vm.id

        New-AzureRmResourceGroupDeployment -Name mspAlert `
                                        -ResourceGroupName $vm.ResourceGroupName `
                                        -TemplateUri 'https://raw.githubusercontent.com/krnese/Olivia/master/Templates/azureClassicAlert.json' `
                                        -resourceId $vm.id `
                                        -AsJob

        Write-Output "Done!"                                       
    }
}
Catch
{
    $ErrorMessage = 'Unable to update alert on VM:'
    $ErrorMessage += "`n"
    $ErrorMessage += $vm.Name
    $ErrorMessage += $_
    Write-Error -Message $ErrorMessage `
                -ErrorAction Stop
}

    Write-Output "Job completed"
  
}