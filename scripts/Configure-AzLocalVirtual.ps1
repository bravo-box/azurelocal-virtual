<#
.SYNOPSIS
    Configure Azure Local Virtual environment with Azure Government endpoints

.DESCRIPTION
    This script sets up the Azure Local Virtual instance on the host VM,
    configuring nested Hyper-V VMs and connecting to Azure Arc with 
    Azure Government cloud endpoints.

.PARAMETER ResourceGroupName
    The name of the Azure resource group

.PARAMETER SubscriptionId
    Azure subscription ID

.PARAMETER TenantId
    Azure tenant ID

.PARAMETER Location
    Azure region (e.g., 'usgovvirginia')

.PARAMETER ServicePrincipalId
    Service principal application ID for Azure Arc onboarding

.PARAMETER ServicePrincipalSecret
    Service principal secret

.PARAMETER AzureEnvironment
    Azure environment - AzureUSGovernment for Gov cloud

.EXAMPLE
    .\Configure-AzLocalVirtual.ps1 -ResourceGroupName "AzLocal-RG" -SubscriptionId "xxx" -TenantId "xxx" -Location "usgovvirginia"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$Location,

    [Parameter(Mandatory = $false)]
    [string]$ServicePrincipalId,

    [Parameter(Mandatory = $false)]
    [string]$ServicePrincipalSecret,

    [Parameter(Mandatory = $false)]
    [ValidateSet('AzureCloud', 'AzureUSGovernment')]
    [string]$AzureEnvironment = 'AzureUSGovernment'
)

# Set error action preference
$ErrorActionPreference = 'Stop'

# Azure Government endpoints
$govEndpoints = @{
    ResourceManager = 'https://management.usgovcloudapi.net'
    ActiveDirectory = 'https://login.microsoftonline.us'
    ArcEndpoint = 'https://gbl.his.arc.azure.us'
    StorageEndpoint = 'core.usgovcloudapi.net'
    KeyVaultDns = 'vault.usgovcloudapi.net'
}

# Commercial Azure endpoints (for reference)
$commercialEndpoints = @{
    ResourceManager = 'https://management.azure.com'
    ActiveDirectory = 'https://login.microsoftonline.com'
    ArcEndpoint = 'https://gbl.his.arc.azure.com'
    StorageEndpoint = 'core.windows.net'
    KeyVaultDns = 'vault.azure.net'
}

# Select endpoints based on environment
$endpoints = if ($AzureEnvironment -eq 'AzureUSGovernment') { $govEndpoints } else { $commercialEndpoints }

Write-Host "=== Azure Local Virtual Configuration Script ===" -ForegroundColor Cyan
Write-Host "Azure Environment: $AzureEnvironment" -ForegroundColor Green
Write-Host "Resource Manager: $($endpoints.ResourceManager)" -ForegroundColor Green
Write-Host "Arc Endpoint: $($endpoints.ArcEndpoint)" -ForegroundColor Green

# Function to log messages
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Level] $Message"
}

# Check if Hyper-V is installed
Write-Log "Checking Hyper-V installation status..."
$hyperV = Get-WindowsFeature -Name Hyper-V
if ($hyperV.InstallState -ne 'Installed') {
    Write-Log "Installing Hyper-V..." -Level "WARNING"
    Install-WindowsFeature -Name Hyper-V -IncludeManagementTools -Restart
    exit 0
}
Write-Log "Hyper-V is installed" -Level "INFO"

# Configure Hyper-V virtual switch
Write-Log "Configuring Hyper-V virtual switch..."
$switchName = "AzLocalBox-vSwitch"
$existingSwitch = Get-VMSwitch -Name $switchName -ErrorAction SilentlyContinue
if (-not $existingSwitch) {
    $netAdapter = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' } | Select-Object -First 1
    New-VMSwitch -Name $switchName -NetAdapterName $netAdapter.Name -AllowManagementOS $true
    Write-Log "Created virtual switch: $switchName"
} else {
    Write-Log "Virtual switch already exists: $switchName"
}

# Create directory structure for VM storage
Write-Log "Creating directory structure..."
$vmStoragePath = "C:\VMs"
$vhdPath = "$vmStoragePath\VHDs"
$isoPath = "$vmStoragePath\ISOs"

@($vmStoragePath, $vhdPath, $isoPath) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
        Write-Log "Created directory: $_"
    }
}

# Install Azure PowerShell modules for Gov cloud
Write-Log "Checking Azure PowerShell modules..."
$requiredModules = @('Az.Accounts', 'Az.Resources', 'Az.ConnectedMachine', 'Az.StackHCI')
foreach ($module in $requiredModules) {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        Write-Log "Installing module: $module" -Level "WARNING"
        Install-Module -Name $module -Force -AllowClobber -Scope AllUsers
    }
}

# Connect to Azure (Gov cloud)
Write-Log "Connecting to Azure $AzureEnvironment..."
if ($ServicePrincipalId -and $ServicePrincipalSecret) {
    $securePassword = ConvertTo-SecureString $ServicePrincipalSecret -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($ServicePrincipalId, $securePassword)
    Connect-AzAccount -ServicePrincipal -Credential $credential -Tenant $TenantId -Environment $AzureEnvironment -Subscription $SubscriptionId
} else {
    Connect-AzAccount -Environment $AzureEnvironment -Tenant $TenantId -Subscription $SubscriptionId
}

# Configure Azure Arc agent environment variables for Gov cloud
if ($AzureEnvironment -eq 'AzureUSGovernment') {
    Write-Log "Setting Azure Arc environment variables for Government cloud..."
    [System.Environment]::SetEnvironmentVariable('AZURE_RESOURCE_MANAGER', $endpoints.ResourceManager, 'Machine')
    [System.Environment]::SetEnvironmentVariable('AZURE_AUTHORITY_HOST', $endpoints.ActiveDirectory, 'Machine')
    [System.Environment]::SetEnvironmentVariable('AZURE_ARC_ENDPOINT', $endpoints.ArcEndpoint, 'Machine')
}

# Download and prepare Windows Server ISO (placeholder - actual ISO download requires licenses)
Write-Log "Note: Windows Server ISO must be manually placed in $isoPath" -Level "WARNING"
Write-Log "Required: Windows Server 2022 Datacenter Azure Edition ISO"

# Create configuration file for nested VMs
$configFile = @{
    AzureEnvironment = $AzureEnvironment
    Endpoints = $endpoints
    ResourceGroup = $ResourceGroupName
    Subscription = $SubscriptionId
    Tenant = $TenantId
    Location = $Location
    VMStoragePath = $vmStoragePath
    SwitchName = $switchName
} | ConvertTo-Json -Depth 10

$configPath = "$vmStoragePath\config.json"
$configFile | Out-File -FilePath $configPath -Encoding UTF8
Write-Log "Configuration saved to: $configPath"

# Note: Nested virtualization settings will be configured after VMs are created
Write-Log "Note: Configure nested virtualization settings after creating VMs:" -Level "INFO"
Write-Log "  Set-VMNetworkAdapter -VMName <vm-name> -MacAddressSpoofing On" -Level "INFO"
Write-Log "  Set-VMProcessor -VMName <vm-name> -ExposeVirtualizationExtensions `$true" -Level "INFO"

Write-Log "Azure Local Virtual configuration completed successfully!" -Level "INFO"
Write-Log "Next steps:" -Level "INFO"
Write-Log "1. Place Windows Server 2022 Datacenter Azure Edition ISO in $isoPath" -Level "INFO"
Write-Log "2. Use Hyper-V Manager to create nested cluster VMs" -Level "INFO"
Write-Log "3. Configure nested VMs with MAC address spoofing and virtualization extensions" -Level "INFO"
Write-Log "4. Install Azure Arc agent and connect to Azure Government" -Level "INFO"
Write-Log "5. Deploy Azure Local cluster using Windows Admin Center or PowerShell" -Level "INFO"

# Export configuration for use by other scripts
return @{
    Success = $true
    ConfigPath = $configPath
    Endpoints = $endpoints
    Environment = $AzureEnvironment
}
