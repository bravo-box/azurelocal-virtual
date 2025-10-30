# Azure Local Virtual - Government Cloud Edition

Code to build an Azure Local Virtual instance in Azure. Based on the arc-localbox solution accelerator with modifications for Azure Government Cloud.

## Overview

Azure Local Virtual is a solution accelerator that automates the deployment of a virtualized Azure Local instance in Azure Government. It uses nested Hyper-V virtualization to create a sandbox environment for evaluating, testing, and developing hybrid cloud scenarios with Azure Local and Azure Arc technologies.

This solution is specifically configured for **Azure Government Cloud** with appropriate endpoints and compliance considerations for FedRAMP and other federal requirements.

## Features

- ✅ Automated deployment via Bicep templates
- ✅ Azure Government cloud endpoints configured
- ✅ Nested Hyper-V virtualization support
- ✅ Azure Bastion integration (optional)
- ✅ Network security group with RDP, WinRM, and HTTPS access
- ✅ Azure Arc integration ready
- ✅ Diagnostic storage and boot diagnostics enabled
- ✅ Windows Server 2022 Datacenter Azure Edition

## Architecture

The solution deploys the following components:

1. **Host VM**: A Windows Server 2022 Datacenter Azure Edition VM with:
   - Hyper-V role enabled for nested virtualization
   - Minimum recommended size: Standard_E32s_v5 (32 vCPUs, 256 GB RAM)
   - Premium SSD storage for OS and data disks
   - Accelerated networking enabled

2. **Networking**:
   - Virtual Network with configurable address space
   - Network Security Group with required inbound rules
   - Public IP address with DNS name
   - Optional Azure Bastion for secure RDP access

3. **Storage**:
   - Boot diagnostics storage account
   - Data disk for nested VM storage

## Prerequisites

- Azure Government subscription
- Azure CLI with Bicep support
- PowerShell 7.0 or later with Az modules
- Appropriate permissions to create resources in Azure Government
- Azure Key Vault (recommended) for storing admin credentials

## Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/bravo-box/azurelocal-virtual.git
cd azurelocal-virtual
```

### 2. Configure Parameters

Edit `bicep/host/host.parameters.gov.json` with your specific values:

```json
{
  "location": { "value": "usgovvirginia" },
  "vmName": { "value": "YourVMName" },
  "windowsAdminUsername": { "value": "youradmin" },
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

### 3. Deploy Infrastructure

Using PowerShell:

```powershell
.\scripts\Deploy-AzLocalVirtual.ps1 `
    -ResourceGroupName "AzLocal-RG" `
    -Location "usgovvirginia" `
    -ParameterFile ".\bicep\host\host.parameters.gov.json"
```

Using Azure CLI:

```bash
az login --cloud AzureUSGovernment
az account set --subscription "<subscription-id>"
az group create --name AzLocal-RG --location usgovvirginia
az deployment group create \
    --resource-group AzLocal-RG \
    --template-file bicep/host/host.bicep \
    --parameters @bicep/host/host.parameters.gov.json
```

### 4. Configure the Host VM

After deployment, RDP into the host VM and run:

```powershell
.\Configure-AzLocalVirtual.ps1 `
    -ResourceGroupName "AzLocal-RG" `
    -SubscriptionId "<subscription-id>" `
    -TenantId "<tenant-id>" `
    -Location "usgovvirginia" `
    -AzureEnvironment "AzureUSGovernment"
```

## Azure Government Considerations

This solution is specifically configured for Azure Government with the following modifications:

### Endpoints

| Service | Commercial | Government |
|---------|-----------|------------|
| Portal | portal.azure.com | portal.azure.us |
| Resource Manager | management.azure.com | management.usgovcloudapi.net |
| Active Directory | login.microsoftonline.com | login.microsoftonline.us |
| Azure Arc | gbl.his.arc.azure.com | gbl.his.arc.azure.us |
| Storage | core.windows.net | core.usgovcloudapi.net |
| Key Vault | vault.azure.net | vault.usgovcloudapi.net |

### Supported Regions

- US Gov Virginia (`usgovvirginia`)
- US Gov Texas (`usgovtexas`)
- US Gov Arizona (`usgovarizona`)
- US DoD East (`usdodeast`)
- US DoD Central (`usdodcentral`)

### Compliance

- FedRAMP High compliance ready
- CJIS, ITAR, and DoD IL2/IL4/IL5 supported
- All data remains within US sovereign boundaries

## VM Size Recommendations

Azure Local Virtual requires VMs that support nested virtualization:

| VM Size | vCPUs | RAM | Use Case |
|---------|-------|-----|----------|
| Standard_D16s_v5 | 16 | 64 GB | Development/Testing |
| Standard_E16s_v5 | 16 | 128 GB | Small demos |
| Standard_E32s_v5 | 32 | 256 GB | **Recommended** - Full features |
| Standard_E48s_v5 | 48 | 384 GB | Large-scale testing |

## Cost Considerations

Running this solution in Azure Government will incur costs. Key cost factors:

- Host VM compute (largest cost component)
- Storage (Premium SSD disks)
- Network egress
- Azure Bastion (if deployed)
- Public IP address

**💡 Tip**: Deallocate the VM when not in use to save on compute costs.

## Post-Deployment Steps

1. **RDP Access**: Use the public IP or FQDN to connect via RDP
2. **Configure Hyper-V**: The script installs Hyper-V; VM will restart
3. **Create Nested VMs**: Use Hyper-V Manager to create Azure Local cluster VMs
4. **Register with Azure Arc**: Connect the instance to Azure Arc for management
5. **Configure Azure Local**: Complete the Azure Local cluster setup

## Troubleshooting

### Common Issues

**Issue**: Deployment fails with "QuotaExceeded"
- **Solution**: Request quota increase for the selected VM family in your region

**Issue**: Cannot RDP to the VM
- **Solution**: Verify NSG rules and public IP is attached. Check if Azure Bastion is deployed.

**Issue**: Hyper-V role installation fails
- **Solution**: Ensure VM size supports nested virtualization (Dv3, Ev3, or later)

**Issue**: Azure Arc connection fails
- **Solution**: Verify Azure Government endpoints are configured correctly. Check environment variables.

## Security Best Practices

1. **Use Azure Key Vault** for storing admin credentials
2. **Enable Azure Bastion** for secure RDP access without public IPs
3. **Implement RBAC** with least privilege access
4. **Enable Azure Monitor** and Log Analytics for monitoring
5. **Regular Updates**: Keep Windows Server and Azure agents updated
6. **Network Isolation**: Use NSG rules to restrict access to known IPs

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This solution accelerator is provided as-is for evaluation and development purposes. It is not officially supported by Microsoft for production workloads. Always follow your organization's security and compliance requirements when deploying to Azure Government.

## References

- [Azure Local Documentation](https://learn.microsoft.com/en-us/azure/azure-local/)
- [Azure Arc Jumpstart](https://jumpstart.azure.com/)
- [Azure Government Documentation](https://learn.microsoft.com/en-us/azure/azure-government/)
- [Azure Government vs Commercial](https://learn.microsoft.com/en-us/azure/azure-government/compare-azure-government-global-azure)

## Support

For issues and questions:
- Open an issue in this repository
- Refer to [Azure Government Support](https://learn.microsoft.com/en-us/azure/azure-government/documentation-government-get-started-connect-with-portal)

---

**Last Updated**: October 2025