# Sample queries for Azure Resource Graph

# List all resources across tenants (assuming appropriate RBAC permissions are set, i.e., minimum /*/read)

Search-AzureRmGraph -Query "summarize count()"

# List all resource types, summarized by count

Search-AzureRmGraph -Query "summarize count() by tostring(type)"

# List top 10 regions with most resources

Search-AzureRmGraph -Query "summarize count() by tostring(location) | top 10 by location asc"

# List Windows vs Linux deployments

Search-AzureRmGraph -Query "where type =~ 'Microsoft.Compute/virtualMachines' | extend os = properties.storageProfile.osDisk.osType | summarize count() by tostring(os)"

# List VM deployment summarized by tenant

Search-AzureRmGraph -Query "where type =~ 'Microsoft.Compute/virtualMachines' | summarize count() by tenantId"

# Summarize resources across tenants

Search-AzureRmGraph -Query "summarize count() by tenantId"

# See if any Azure mgmt services are deployed

Search-AzureRmGraph -Query "where type =~ 'Microsoft.OperationalInsights/workspaces' or type =~ 'Microsoft.Automation/automationAccounts' or type =~ 'Microsoft.RecoveryServices/vaults' | project name, location, resourceGroup, type, subscriptionId"
