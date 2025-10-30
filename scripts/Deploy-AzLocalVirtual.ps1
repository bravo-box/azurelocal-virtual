<#
.SYNOPSIS
    Deploy Azure Local Virtual infrastructure to Azure Government

.DESCRIPTION
    This script deploys the Azure Local Virtual host VM and supporting infrastructure
    to Azure Government using Bicep templates.

.PARAMETER ResourceGroupName
    Name of the resource group to create/use

.PARAMETER Location
    Azure Government region (e.g., 'usgovvirginia', 'usgovtexas')

.PARAMETER ParameterFile
    Path to the Bicep parameter file

.PARAMETER SubscriptionId
    Azure subscription ID (optional, uses current context if not provided)

.EXAMPLE
    .\Deploy-AzLocalVirtual.ps1 -ResourceGroupName "AzLocal-RG" -Location "usgovvirginia" -ParameterFile ".\bicep\host\host.parameters.gov.json"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [ValidateSet('usgovvirginia', 'usgovtexas', 'usgovarizona', 'usdodeast', 'usdodcentral')]
    [string]$Location,

    [Parameter(Mandatory = $false)]
    [string]$ParameterFile = ".\bicep\host\host.parameters.gov.json",

    [Parameter(Mandatory = $false)]
    [string]$SubscriptionId
)

$ErrorActionPreference = 'Stop'

# Function to log messages
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

Write-Log "=== Azure Local Virtual Deployment Script ===" -Level "INFO"
Write-Log "Target Environment: Azure US Government" -Level "INFO"

# Check if Az module is installed
Write-Log "Checking Azure PowerShell modules..."
if (-not (Get-Module -ListAvailable -Name Az.Accounts)) {
    Write-Log "Azure PowerShell module not found. Installing..." -Level "WARNING"
    Install-Module -Name Az -Force -AllowClobber -Scope CurrentUser
}

# Check if Bicep CLI is installed
Write-Log "Checking Bicep CLI..."
$bicepVersion = az bicep version 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Log "Bicep CLI not found. Installing..." -Level "WARNING"
    az bicep install
} else {
    Write-Log "Bicep CLI version: $bicepVersion"
}

# Connect to Azure Government
Write-Log "Connecting to Azure US Government..."
try {
    if ($SubscriptionId) {
        Connect-AzAccount -Environment AzureUSGovernment -Subscription $SubscriptionId
    } else {
        Connect-AzAccount -Environment AzureUSGovernment
    }
    $context = Get-AzContext
    Write-Log "Connected to subscription: $($context.Subscription.Name)" -Level "SUCCESS"
} catch {
    Write-Log "Failed to connect to Azure: $_" -Level "ERROR"
    exit 1
}

# Create resource group if it doesn't exist
Write-Log "Checking resource group: $ResourceGroupName"
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Log "Creating resource group: $ResourceGroupName in $Location"
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location
    Write-Log "Resource group created" -Level "SUCCESS"
} else {
    Write-Log "Resource group already exists" -Level "INFO"
}

# Verify parameter file exists
if (-not (Test-Path $ParameterFile)) {
    Write-Log "Parameter file not found: $ParameterFile" -Level "ERROR"
    exit 1
}

# Get the Bicep template path
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$templateFile = Join-Path $scriptPath "..\bicep\host\host.bicep"

if (-not (Test-Path $templateFile)) {
    Write-Log "Template file not found: $templateFile" -Level "ERROR"
    exit 1
}

Write-Log "Using template: $templateFile"
Write-Log "Using parameters: $ParameterFile"

# Deploy the Bicep template
Write-Log "Starting deployment..." -Level "INFO"
$deploymentName = "AzLocalVirtual-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

try {
    $deployment = New-AzResourceGroupDeployment `
        -Name $deploymentName `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile $templateFile `
        -TemplateParameterFile $ParameterFile `
        -Verbose

    if ($deployment.ProvisioningState -eq 'Succeeded') {
        Write-Log "Deployment completed successfully!" -Level "SUCCESS"
        Write-Log "Deployment outputs:" -Level "INFO"
        $deployment.Outputs.Keys | ForEach-Object {
            $key = $_
            $value = $deployment.Outputs[$key].Value
            Write-Log "  $key = $value" -Level "INFO"
        }

        # Save outputs to file
        $outputFile = "deployment-outputs-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $deployment.Outputs | ConvertTo-Json -Depth 10 | Out-File $outputFile
        Write-Log "Outputs saved to: $outputFile" -Level "SUCCESS"

        # Display connection information
        Write-Log "`n=== Connection Information ===" -Level "SUCCESS"
        if ($deployment.Outputs.publicIPFqdn) {
            Write-Log "VM FQDN: $($deployment.Outputs.publicIPFqdn.Value)" -Level "INFO"
        }
        if ($deployment.Outputs.publicIPAddress) {
            Write-Log "VM Public IP: $($deployment.Outputs.publicIPAddress.Value)" -Level "INFO"
        }
        Write-Log "`nNext steps:" -Level "INFO"
        Write-Log "1. RDP to the host VM using the credentials provided" -Level "INFO"
        Write-Log "2. Run Configure-AzLocalVirtual.ps1 on the host VM" -Level "INFO"
        Write-Log "3. Follow the configuration steps to set up nested VMs" -Level "INFO"

    } else {
        Write-Log "Deployment failed with state: $($deployment.ProvisioningState)" -Level "ERROR"
        exit 1
    }
} catch {
    Write-Log "Deployment failed: $_" -Level "ERROR"
    Write-Log "Error details: $($_.Exception.Message)" -Level "ERROR"
    exit 1
}

Write-Log "Deployment script completed" -Level "SUCCESS"
