# Deployment Guide - Azure Local Virtual for Azure Government

This guide provides detailed step-by-step instructions for deploying Azure Local Virtual in Azure Government.

## Table of Contents

1. [Pre-Deployment Setup](#pre-deployment-setup)
2. [Infrastructure Deployment](#infrastructure-deployment)
3. [Host VM Configuration](#host-vm-configuration)
4. [Azure Arc Registration](#azure-arc-registration)
5. [Post-Deployment Validation](#post-deployment-validation)

## Pre-Deployment Setup

### 1. Install Required Tools

#### Azure CLI
```bash
# Install Azure CLI (Windows)
Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi
Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'

# Verify installation
az --version
```

#### Bicep CLI
```bash
az bicep install
az bicep version
```

#### Azure PowerShell
```powershell
Install-Module -Name Az -Repository PSGallery -Force -AllowClobber
Import-Module Az
```

### 2. Login to Azure Government

```bash
# Azure CLI
az login --cloud AzureUSGovernment

# PowerShell
Connect-AzAccount -Environment AzureUSGovernment
```

### 3. Set Subscription Context

```bash
# List subscriptions
az account list --output table

# Set active subscription
az account set --subscription "<subscription-id>"
```

### 4. Create Key Vault and Store Credentials

```bash
# Create Key Vault
az keyvault create \
    --name "azlocal-kv-$(date +%s)" \
    --resource-group "AzLocal-Prereqs-RG" \
    --location "usgovvirginia" \
    --enable-rbac-authorization false

# Store admin password
az keyvault secret set \
    --vault-name "<vault-name>" \
    --name "adminPassword" \
    --value "<strong-password>"
```

### 5. Update Parameter File

Edit `bicep/host/host.parameters.gov.json`:

```json
{
  "windowsAdminPassword": {
    "reference": {
      "keyVault": {
        "id": "/subscriptions/<sub-id>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault-name>"
      },
      "secretName": "adminPassword"
    }
  }
}
```

## Infrastructure Deployment

### Option 1: Using PowerShell Script (Recommended)

```powershell
# Navigate to repository root
cd azurelocal-virtual

# Run deployment script
.\scripts\Deploy-AzLocalVirtual.ps1 `
    -ResourceGroupName "AzLocal-RG" `
    -Location "usgovvirginia" `
    -ParameterFile ".\bicep\host\host.parameters.gov.json"
```

### Option 2: Using Azure CLI

```bash
# Create resource group
az group create \
    --name "AzLocal-RG" \
    --location "usgovvirginia"

# Deploy Bicep template
az deployment group create \
    --name "AzLocalVirtual-Deployment" \
    --resource-group "AzLocal-RG" \
    --template-file "bicep/host/host.bicep" \
    --parameters @bicep/host/host.parameters.gov.json
```

### Monitor Deployment

```bash
# Check deployment status
az deployment group show \
    --name "AzLocalVirtual-Deployment" \
    --resource-group "AzLocal-RG" \
    --query "properties.provisioningState"

# Get deployment outputs
az deployment group show \
    --name "AzLocalVirtual-Deployment" \
    --resource-group "AzLocal-RG" \
    --query "properties.outputs"
```

### Expected Deployment Time

- **Infrastructure deployment**: 10-15 minutes
- **VM provisioning**: 5-10 minutes
- **Hyper-V installation**: 5 minutes + reboot
- **Total**: Approximately 20-30 minutes

## Host VM Configuration

### 1. Connect to Host VM

#### Option A: Direct RDP
```bash
# Get VM public IP
$publicIP = az deployment group show \
    --name "AzLocalVirtual-Deployment" \
    --resource-group "AzLocal-RG" \
    --query "properties.outputs.publicIPAddress.value" -o tsv

# Connect via RDP
mstsc /v:$publicIP
```

#### Option B: Azure Bastion (if deployed)
1. Navigate to portal.azure.us
2. Go to the VM resource
3. Click "Connect" > "Bastion"
4. Enter credentials and connect

### 2. Copy Configuration Script

Copy `scripts/Configure-AzLocalVirtual.ps1` to the host VM:

```powershell
# From your local machine
$vmIP = "<vm-public-ip>"
$localPath = ".\scripts\Configure-AzLocalVirtual.ps1"
$remotePath = "C:\Temp\Configure-AzLocalVirtual.ps1"

# Create remote session
$session = New-PSSession -ComputerName $vmIP -Credential (Get-Credential)

# Copy file
Copy-Item -Path $localPath -Destination $remotePath -ToSession $session

# Close session
Remove-PSSession $session
```

### 3. Run Configuration Script

On the host VM, open PowerShell as Administrator:

```powershell
# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Run configuration
cd C:\Temp
.\Configure-AzLocalVirtual.ps1 `
    -ResourceGroupName "AzLocal-RG" `
    -SubscriptionId "<subscription-id>" `
    -TenantId "<tenant-id>" `
    -Location "usgovvirginia" `
    -AzureEnvironment "AzureUSGovernment"
```

**Note**: The VM will restart automatically after Hyper-V installation. Reconnect after reboot.

### 4. Verify Hyper-V Installation

After reboot:

```powershell
# Check Hyper-V role
Get-WindowsFeature -Name Hyper-V

# Check virtual switch
Get-VMSwitch

# Verify nested virtualization support
Get-VMProcessor -VMName * | Select-Object VMName, ExposeVirtualizationExtensions
```

## Azure Arc Registration

### 1. Prepare Service Principal (if not already created)

```bash
# Create service principal
az ad sp create-for-rbac \
    --name "AzLocalArc-SP" \
    --role "Azure Connected Machine Onboarding" \
    --scopes "/subscriptions/<subscription-id>/resourceGroups/AzLocal-RG"

# Save the output - you'll need appId and password
```

### 2. Install Azure Arc Agent

On the host VM:

```powershell
# Download Arc agent installer
$url = "https://aka.ms/AzureConnectedMachineAgent"
$output = "C:\Temp\AzureConnectedMachineAgent.msi"
Invoke-WebRequest -Uri $url -OutFile $output

# Install agent
msiexec /i $output /qn /l*v "C:\Temp\arc-install.log"

# Verify installation
& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" version
```

### 3. Connect to Azure Arc

```powershell
# Connect using service principal
& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect `
    --service-principal-id "<sp-app-id>" `
    --service-principal-secret "<sp-secret>" `
    --tenant-id "<tenant-id>" `
    --subscription-id "<subscription-id>" `
    --resource-group "AzLocal-RG" `
    --location "usgovvirginia" `
    --cloud "AzureUSGovernment"
```

### 4. Verify Arc Connection

```bash
# Check connection status
az connectedmachine show \
    --name "<vm-name>" \
    --resource-group "AzLocal-RG"
```

## Post-Deployment Validation

### 1. Verify Infrastructure

```bash
# List all resources
az resource list \
    --resource-group "AzLocal-RG" \
    --output table

# Check VM status
az vm get-instance-view \
    --name "<vm-name>" \
    --resource-group "AzLocal-RG" \
    --query "instanceView.statuses[?starts_with(code, 'PowerState/')].displayStatus" -o tsv
```

### 2. Test Connectivity

```powershell
# From host VM, test Azure endpoints
Test-NetConnection -ComputerName management.usgovcloudapi.net -Port 443
Test-NetConnection -ComputerName login.microsoftonline.us -Port 443
Test-NetConnection -ComputerName gbl.his.arc.azure.us -Port 443
```

### 3. Verify Hyper-V Capabilities

```powershell
# Check Hyper-V service
Get-Service -Name vmms

# Verify VM switch
Get-VMSwitch | Format-List Name, SwitchType, NetAdapterInterfaceDescription

# Check available resources
Get-VMHost | Select-Object MemoryCapacity, LogicalProcessorCount
```

### 4. Review Configuration

```powershell
# Check configuration file
Get-Content C:\VMs\config.json | ConvertFrom-Json

# Verify environment variables
[System.Environment]::GetEnvironmentVariable('AZURE_RESOURCE_MANAGER', 'Machine')
[System.Environment]::GetEnvironmentVariable('AZURE_AUTHORITY_HOST', 'Machine')
```

## Troubleshooting Common Issues

### Issue: Deployment fails with quota exceeded

**Solution**:
```bash
# Check current quota
az vm list-usage --location usgovvirginia --output table

# Request quota increase via portal or support ticket
```

### Issue: Hyper-V installation fails

**Check**:
1. VM size supports nested virtualization
2. Hardware virtualization is enabled
3. VM is not already a nested VM

**Solution**:
```powershell
# Verify VM size
Get-AzVM -ResourceGroupName "AzLocal-RG" -Name "<vm-name>" | Select-Object -ExpandProperty HardwareProfile

# Ensure E-series or D-series v3 or later
```

### Issue: Cannot connect to Azure Government endpoints

**Solution**:
```powershell
# Verify DNS resolution
Resolve-DnsName management.usgovcloudapi.net
Resolve-DnsName login.microsoftonline.us

# Check firewall/NSG rules
Test-NetConnection -ComputerName management.usgovcloudapi.net -Port 443 -InformationLevel Detailed
```

### Issue: Arc agent connection fails

**Solution**:
```powershell
# Check agent logs
Get-Content "C:\ProgramData\AzureConnectedMachineAgent\Log\azcmagent.log" -Tail 50

# Verify service principal permissions
az role assignment list --assignee "<sp-app-id>" --output table

# Reconnect with debug logging
& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect --verbose
```

## Next Steps

After successful deployment and configuration:

1. **Create nested VMs** for Azure Local cluster nodes
2. **Configure Windows Admin Center** for management
3. **Deploy Azure Local cluster** using cluster creation wizard
4. **Enable Azure Arc services** (Azure Stack HCI, AKS)
5. **Configure monitoring** with Azure Monitor and Log Analytics

## Additional Resources

- [Azure Local Deployment Guide](https://learn.microsoft.com/en-us/azure/azure-local/deploy/)
- [Azure Arc Documentation](https://learn.microsoft.com/en-us/azure/azure-arc/)
- [Azure Government Documentation](https://learn.microsoft.com/en-us/azure/azure-government/)
- [Nested Virtualization in Azure](https://learn.microsoft.com/en-us/azure/virtual-machines/nested-virtualization)

---

**Questions?** Open an issue in the repository or consult Azure Government support.
