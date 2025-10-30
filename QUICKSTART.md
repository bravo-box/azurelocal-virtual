# Quick Start Guide - Azure Local Virtual

Get up and running with Azure Local Virtual in Azure Government in minutes!

## Prerequisites Checklist

- [ ] Azure Government subscription
- [ ] Azure CLI installed
- [ ] PowerShell 7+ installed
- [ ] Appropriate permissions (Contributor or Owner)

## 5-Minute Setup

### Step 1: Login to Azure Government (1 min)

```bash
# Login
az login --cloud AzureUSGovernment

# Set subscription
az account set --subscription "<your-subscription-id>"
```

### Step 2: Create Key Vault for Secrets (2 min)

```bash
# Create resource group
az group create --name "AzLocal-Prereqs-RG" --location "usgovvirginia"

# Create Key Vault
VAULT_NAME="azlocal-kv-$(date +%s)"
az keyvault create \
    --name "$VAULT_NAME" \
    --resource-group "AzLocal-Prereqs-RG" \
    --location "usgovvirginia"

# Store admin password (replace with strong password)
az keyvault secret set \
    --vault-name "$VAULT_NAME" \
    --name "adminPassword" \
    --value "YourStrongPassword123!"

# Get Key Vault ID for later
az keyvault show --name "$VAULT_NAME" --query id -o tsv
```

### Step 3: Clone and Configure (1 min)

```bash
# Clone repository
git clone https://github.com/bravo-box/azurelocal-virtual.git
cd azurelocal-virtual

# Edit parameter file
# Replace placeholders with your values:
# - <subscription-id>
# - <rg-name> (use "AzLocal-Prereqs-RG")
# - <vault-name> (use value from Step 2)
nano bicep/main.parameters.gov.json
```

### Step 4: Deploy Infrastructure (1 min to start, ~30 min total)

#### Option A: PowerShell

```powershell
.\scripts\Deploy-AzLocalVirtual.ps1 `
    -ResourceGroupName "AzLocal-RG" `
    -Location "usgovvirginia" `
    -ParameterFile ".\bicep\main.parameters.gov.json"
```

#### Option B: Azure CLI

```bash
# Create resource group
az group create --name "AzLocal-RG" --location "usgovvirginia"

# Deploy
az deployment group create \
    --name "AzLocalVirtual-$(date +%Y%m%d-%H%M%S)" \
    --resource-group "AzLocal-RG" \
    --template-file "bicep/main.bicep" \
    --parameters @bicep/main.parameters.gov.json
```

## What Gets Deployed

✅ Windows Server 2022 Datacenter VM (Standard_E32s_v5)  
✅ Virtual Network with subnets  
✅ Network Security Group  
✅ Azure Bastion (optional)  
✅ Log Analytics Workspace  
✅ Storage Account for diagnostics  
✅ Public IP with DNS name  

## After Deployment

### Get Connection Info

```bash
# Get public IP
az vm show -d \
    --resource-group "AzLocal-RG" \
    --name "AzLocalBox-Host" \
    --query publicIps -o tsv

# Get FQDN
az network public-ip show \
    --resource-group "AzLocal-RG" \
    --name "AzLocalBox-Host-PIP" \
    --query dnsSettings.fqdn -o tsv
```

### Connect via RDP

**Option 1: Direct RDP** (if public IP is enabled)
```bash
mstsc /v:<public-ip-or-fqdn>
```

**Option 2: Azure Bastion** (if deployed)
1. Go to https://portal.azure.us
2. Navigate to the VM
3. Click "Connect" → "Bastion"
4. Enter credentials

### Run Configuration Script

On the host VM:

```powershell
# Download the configuration script (if not already copied)
# Run as Administrator
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Run configuration
.\Configure-AzLocalVirtual.ps1 `
    -ResourceGroupName "AzLocal-RG" `
    -SubscriptionId "<subscription-id>" `
    -TenantId "<tenant-id>" `
    -Location "usgovvirginia"
```

## Next Steps

1. **Create Nested VMs**: Use Hyper-V Manager to create cluster nodes
2. **Deploy Azure Local**: Follow Windows Admin Center wizard
3. **Register with Arc**: Connect to Azure Arc for management
4. **Deploy Workloads**: Start running VMs and containers

## Estimated Costs

Based on Azure Government pricing (US Gov Virginia):

| Resource | Size/Type | Estimated Cost/Month* |
|----------|-----------|----------------------|
| VM (E32s_v5) | 32 vCPU, 256GB RAM | ~$1,800 |
| Storage | Premium SSD (1.25TB) | ~$200 |
| Public IP | Static | ~$4 |
| Bastion | Standard | ~$140 |
| **Total** | | **~$2,144/month** |

*Costs are estimates and vary by region. Deallocate VM when not in use to save ~$1,800/month.

## Troubleshooting

### Issue: Deployment fails with quota error
```bash
# Check quota
az vm list-usage --location usgovvirginia --output table

# Request increase via portal or:
az support tickets create --ticket-name "Quota-Increase" ...
```

### Issue: Cannot RDP to VM
1. Check NSG rules allow RDP (port 3389)
2. Verify VM is running: `az vm get-instance-view ...`
3. Try Azure Bastion if deployed

### Issue: Hyper-V installation fails
- Ensure VM size supports nested virtualization (E-series or D-series v3+)
- Check VM extensions: `az vm extension list ...`

## Important Commands

```bash
# Check deployment status
az deployment group show \
    --name "<deployment-name>" \
    --resource-group "AzLocal-RG" \
    --query properties.provisioningState

# List all resources
az resource list \
    --resource-group "AzLocal-RG" \
    --output table

# Get VM status
az vm get-instance-view \
    --resource-group "AzLocal-RG" \
    --name "AzLocalBox-Host" \
    --query instanceView.statuses

# Deallocate VM (to save costs)
az vm deallocate \
    --resource-group "AzLocal-RG" \
    --name "AzLocalBox-Host"

# Start VM
az vm start \
    --resource-group "AzLocal-RG" \
    --name "AzLocalBox-Host"

# Delete all resources
az group delete \
    --name "AzLocal-RG" \
    --yes --no-wait
```

## Getting Help

- 📖 **Full Documentation**: See [README.md](README.md)
- 🚀 **Deployment Guide**: See [docs/DEPLOYMENT_GUIDE.md](docs/DEPLOYMENT_GUIDE.md)
- 🏛️ **Gov Configuration**: See [docs/AZURE_GOVERNMENT_CONFIG.md](docs/AZURE_GOVERNMENT_CONFIG.md)
- 🏗️ **Architecture**: See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- 🤝 **Contributing**: See [CONTRIBUTING.md](CONTRIBUTING.md)
- 🐛 **Issues**: Open an issue on GitHub

## Security Reminder

🔒 **Important Security Notes**:
- Default NSG allows RDP from any IP - restrict in production!
- Use Azure Bastion for secure access
- Store credentials in Key Vault, never in code
- Enable Azure Monitor for security alerting
- Follow your organization's compliance requirements

---

**Ready to deploy?** Start with Step 1 above! 🚀

**Estimated total time**: ~30 minutes for infrastructure + 1-2 hours for full Azure Local cluster setup.
