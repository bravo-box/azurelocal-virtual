# Azure Government Configuration Guide

This document provides specific configuration details for deploying Azure Local Virtual in Azure Government Cloud.

## Azure Government Overview

Azure Government is a physically isolated instance of Azure, designed to meet the security and compliance requirements of US federal, state, and local governments and their solution providers.

## Key Differences from Commercial Azure

### 1. Service Endpoints

All Azure services use different endpoints in Azure Government:

| Service | Commercial Azure | Azure Government |
|---------|-----------------|------------------|
| Portal | https://portal.azure.com | https://portal.azure.us |
| Resource Manager | https://management.azure.com | https://management.usgovcloudapi.net |
| Azure AD Authentication | https://login.microsoftonline.com | https://login.microsoftonline.us |
| Azure Arc | https://gbl.his.arc.azure.com | https://gbl.his.arc.azure.us |
| Storage | https://*.blob.core.windows.net | https://*.blob.core.usgovcloudapi.net |
| Key Vault | https://*.vault.azure.net | https://*.vault.usgovcloudapi.net |
| SQL Database | *.database.windows.net | *.database.usgovcloudapi.net |

### 2. Available Regions

Azure Government currently supports these regions:

- **US Gov Virginia** (`usgovvirginia`) - Primary region
- **US Gov Texas** (`usgovtexas`) - Secondary region
- **US Gov Arizona** (`usgovarizona`) - Additional region
- **US DoD East** (`usdodeast`) - DoD IL5 region
- **US DoD Central** (`usdodcentral`) - DoD IL5 region

**Note**: Not all VM sizes are available in all regions. Check availability before deployment.

### 3. Authentication

Azure Government requires separate authentication:

```bash
# Azure CLI
az login --cloud AzureUSGovernment

# PowerShell
Connect-AzAccount -Environment AzureUSGovernment

# Azure SDK (Python example)
from azure.identity import DefaultAzureCredential
from azure.mgmt.resource import ResourceManagementClient

credential = DefaultAzureCredential(authority='https://login.microsoftonline.us')
client = ResourceManagementClient(
    credential,
    subscription_id,
    base_url='https://management.usgovcloudapi.net'
)
```

## Configuring Azure Arc for Government Cloud

### Environment Variables

Set these environment variables on the host VM before installing Azure Arc agent:

```powershell
[System.Environment]::SetEnvironmentVariable('AZURE_RESOURCE_MANAGER', 'https://management.usgovcloudapi.net', 'Machine')
[System.Environment]::SetEnvironmentVariable('AZURE_AUTHORITY_HOST', 'https://login.microsoftonline.us', 'Machine')
[System.Environment]::SetEnvironmentVariable('AZURE_ARC_ENDPOINT', 'https://gbl.his.arc.azure.us', 'Machine')
```

### Arc Agent Connection

When connecting the Arc agent, specify the Government cloud:

```powershell
azcmagent connect `
    --service-principal-id "<app-id>" `
    --service-principal-secret "<secret>" `
    --tenant-id "<tenant-id>" `
    --subscription-id "<subscription-id>" `
    --resource-group "<resource-group>" `
    --location "<location>" `
    --cloud "AzureUSGovernment"
```

### Required Network Access

Ensure these Government endpoints are accessible:

```text
# Azure Arc endpoints (Government)
*.guestconfiguration.azure.us
gbl.his.arc.azure.us
*.guestnotificationservice.azure.us
*.servicebus.usgovcloudapi.net

# Azure Resource Manager
management.usgovcloudapi.net

# Azure AD
login.microsoftonline.us
graph.windows.net

# Azure Storage
*.blob.core.usgovcloudapi.net

# Azure Monitor (if enabled)
*.ods.opinsights.azure.us
*.oms.opinsights.azure.us
```

## Bicep Template Configuration

### Parameter File Updates

Ensure your parameter file specifies Government cloud:

```json
{
  "azureCloudEnvironment": {
    "value": "AzureUSGovernment"
  },
  "location": {
    "value": "usgovvirginia"
  }
}
```

### Storage Account Configuration

Storage accounts in Government cloud use different DNS suffixes:

```bicep
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'azlocalbox${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    // Government cloud uses different endpoint suffixes automatically
    supportsHttpsTrafficOnly: true
  }
}
```

## Compliance and Certifications

Azure Government supports these compliance frameworks:

- **FedRAMP High**: Authorized for High Impact workloads
- **DoD IL2, IL4, IL5**: Department of Defense Impact Levels
- **CJIS**: Criminal Justice Information Services
- **ITAR**: International Traffic in Arms Regulations
- **IRS 1075**: Tax information security
- **NIST 800-171**: Controlled Unclassified Information

### Compliance Tagging

Tag resources appropriately for compliance tracking:

```json
{
  "resourceTags": {
    "value": {
      "Compliance": "FedRAMP",
      "Classification": "Unclassified",
      "ImpactLevel": "IL4",
      "DataSensitivity": "CUI"
    }
  }
}
```

## Service Principal Configuration

### Create Service Principal for Government Cloud

```bash
# Login to Government cloud
az login --cloud AzureUSGovernment

# Create service principal
az ad sp create-for-rbac \
    --name "AzLocalArc-SP" \
    --role "Azure Connected Machine Onboarding" \
    --scopes "/subscriptions/<subscription-id>/resourceGroups/<rg>"

# Save the output
```

### Assign Additional Roles

For full Azure Local functionality:

```bash
# Azure Stack HCI Resource Provider contributor
az role assignment create \
    --assignee "<sp-app-id>" \
    --role "Azure Stack HCI Administrator" \
    --scope "/subscriptions/<subscription-id>"

# Reader role for resource discovery
az role assignment create \
    --assignee "<sp-app-id>" \
    --role "Reader" \
    --scope "/subscriptions/<subscription-id>"
```

## Key Vault Configuration

### Create Key Vault in Government Cloud

```bash
az keyvault create \
    --name "azlocal-kv-unique" \
    --resource-group "AzLocal-RG" \
    --location "usgovvirginia" \
    --sku "premium" \
    --enable-rbac-authorization false

# Add secrets
az keyvault secret set \
    --vault-name "azlocal-kv-unique" \
    --name "adminPassword" \
    --value "<strong-password>"
```

### Access Key Vault from Bicep

```json
{
  "windowsAdminPassword": {
    "reference": {
      "keyVault": {
        "id": "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault>"
      },
      "secretName": "adminPassword"
    }
  }
}
```

## Monitoring and Logging

### Log Analytics Configuration

Log Analytics in Government cloud:

```bicep
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location  // Must be Government region
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}
```

### Azure Monitor Endpoints

Update monitoring endpoints for Government:

```text
# Log Analytics ingestion
*.ods.opinsights.azure.us

# Log Analytics query
*.oms.opinsights.azure.us

# Application Insights
*.applicationinsights.us
```

## Networking Considerations

### Network Security Groups

Configure NSG rules to allow Government cloud endpoints:

```bicep
{
  name: 'Allow-Azure-Gov-Services'
  properties: {
    priority: 1100
    protocol: 'Tcp'
    access: 'Allow'
    direction: 'Outbound'
    destinationAddressPrefix: 'AzureCloud.usgovvirginia'
    destinationPortRanges: ['443', '80']
  }
}
```

### Service Tags for Government

Use Government-specific service tags:

- `AzureCloud.usgovvirginia`
- `AzureCloud.usgovtexas`
- `AzureActiveDirectory`
- `AzureResourceManager`

## Troubleshooting Government-Specific Issues

### Issue: Cannot connect to portal.azure.com

**Solution**: Use Government portal
```
https://portal.azure.us
```

### Issue: Authentication fails with commercial endpoints

**Solution**: Verify environment is set correctly
```powershell
Get-AzContext | Select-Object Environment
# Should show: AzureUSGovernment
```

### Issue: Arc agent cannot connect

**Solution**: Verify cloud parameter
```powershell
azcmagent show | Select-String "cloud"
# Should show: AzureUSGovernment
```

### Issue: Storage account cannot be accessed

**Solution**: Use Government endpoints
```
# Wrong: https://storage.blob.core.windows.net
# Correct: https://storage.blob.core.usgovcloudapi.net
```

## Additional Resources

- [Azure Government Documentation](https://learn.microsoft.com/en-us/azure/azure-government/)
- [Compare Azure Government and Global Azure](https://learn.microsoft.com/en-us/azure/azure-government/compare-azure-government-global-azure)
- [Azure Government Security](https://learn.microsoft.com/en-us/azure/azure-government/documentation-government-plan-security)
- [Azure Government Compliance](https://learn.microsoft.com/en-us/azure/azure-government/documentation-government-plan-compliance)
- [Azure Arc for Government](https://learn.microsoft.com/en-us/azure/azure-arc/overview)

## Support

For Azure Government-specific support:

- **Portal**: https://portal.azure.us
- **Azure Support**: Open a support ticket through the Government portal
- **Documentation**: Check Azure Government Learn documentation

---

**Security Note**: Always follow your organization's security policies and compliance requirements when working with Azure Government resources.
