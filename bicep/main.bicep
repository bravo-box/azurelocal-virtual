targetScope = 'resourceGroup'

@description('Azure region for resources')
param location string = resourceGroup().location

@description('Deploy management resources (Log Analytics)')
param deployManagement bool = true

@description('Name of the LocalBox host VM')
param vmName string = 'AzLocalBox-Host'

@description('Size of the LocalBox host VM')
param vmSize string = 'Standard_E32s_v5'

@description('Admin username for the VM')
param windowsAdminUsername string

@description('Admin password for the VM')
@secure()
param windowsAdminPassword string

@description('Virtual Network Name')
param virtualNetworkName string = 'AzLocalBox-VNet'

@description('Virtual Network Address Prefix')
param addressPrefix string = '10.0.0.0/16'

@description('Subnet Name')
param subnetName string = 'AzLocalBox-Subnet'

@description('Subnet Address Prefix')
param subnetAddressPrefix string = '10.0.1.0/24'

@description('Deploy Azure Bastion')
param deployBastion bool = false

@description('Bastion subnet address prefix')
param bastionSubnetPrefix string = '10.0.250.0/24'

@description('Azure Cloud environment')
@allowed([
  'AzureCloud'
  'AzureUSGovernment'
])
param azureCloudEnvironment string = 'AzureUSGovernment'

@description('Log Analytics Workspace name')
param workspaceName string = 'AzLocalBox-Workspace'

@description('Tags for resources')
param resourceTags object = {
  Project: 'AzureLocalVirtual'
  Environment: 'Lab'
  Solution: 'LocalBox'
}

// Deploy management resources
module managementResources 'mgmt/management.bicep' = if (deployManagement) {
  name: 'managementDeploy'
  params: {
    location: location
    workspaceName: workspaceName
    workspaceSku: 'PerGB2018'
    retentionInDays: 30
    resourceTags: resourceTags
  }
}

// Deploy host infrastructure
module hostResources 'host/host.bicep' = {
  name: 'hostDeploy'
  params: {
    location: location
    vmName: vmName
    vmSize: vmSize
    windowsAdminUsername: windowsAdminUsername
    windowsAdminPassword: windowsAdminPassword
    virtualNetworkName: virtualNetworkName
    addressPrefix: addressPrefix
    subnetName: subnetName
    subnetAddressPrefix: subnetAddressPrefix
    publicIPAllocationMethod: 'Static'
    deployBastion: deployBastion
    bastionSubnetPrefix: bastionSubnetPrefix
    azureCloudEnvironment: azureCloudEnvironment
    workspaceId: deployManagement && managementResources != null ? managementResources.outputs.workspaceId : ''
    resourceTags: resourceTags
  }
}

// Outputs
output vmName string = hostResources.outputs.vmName
output vmId string = hostResources.outputs.vmId
output publicIPAddress string = hostResources.outputs.publicIPAddress
output publicIPFqdn string = hostResources.outputs.publicIPFqdn
output privateIPAddress string = hostResources.outputs.privateIPAddress
output vmResourceGroup string = hostResources.outputs.vmResourceGroup
output azureCloudEnvironment string = hostResources.outputs.azureCloudEnvironment
output workspaceId string = deployManagement && managementResources != null ? managementResources.outputs.workspaceId : ''
output workspaceName string = deployManagement && managementResources != null ? managementResources.outputs.workspaceName : ''
