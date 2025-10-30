@description('Azure region for resources')
param location string = resourceGroup().location

@description('Name of the LocalBox host VM')
param vmName string = 'AzLocalBox-Host'

@description('Size of the LocalBox host VM - must support nested virtualization')
@allowed([
  'Standard_D16s_v5'
  'Standard_D32s_v5'
  'Standard_D48s_v5'
  'Standard_E16s_v5'
  'Standard_E32s_v5'
  'Standard_E48s_v5'
])
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

@description('Public IP allocation method')
@allowed([
  'Dynamic'
  'Static'
])
param publicIPAllocationMethod string = 'Static'

@description('Deploy Azure Bastion')
param deployBastion bool = false

@description('Bastion subnet address prefix')
param bastionSubnetPrefix string = '10.0.250.0/24'

@description('Azure Cloud environment - set to AzureUSGovernment for Gov cloud')
@allowed([
  'AzureCloud'
  'AzureUSGovernment'
])
param azureCloudEnvironment string = 'AzureUSGovernment'

@description('Log Analytics Workspace ID')
param workspaceId string = ''

@description('Tags for resources')
param resourceTags object = {
  Project: 'AzureLocalVirtual'
  Environment: 'Lab'
  Solution: 'LocalBox'
}

// Network Security Group
resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: '${vmName}-NSG'
  location: location
  tags: resourceTags
  properties: {
    securityRules: [
      {
        name: 'Allow-RDP'
        properties: {
          priority: 1000
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
      {
        name: 'Allow-WinRM'
        properties: {
          priority: 1010
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '5985-5986'
        }
      }
      {
        name: 'Allow-HTTPS'
        properties: {
          priority: 1020
          protocol: 'Tcp'
          access: 'Allow'
          direction: 'Inbound'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
}

// Virtual Network
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: virtualNetworkName
  location: location
  tags: resourceTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: networkSecurityGroup.id
          }
        }
      }
      {
        name: 'AzureBastionSubnet'
        properties: {
          addressPrefix: bastionSubnetPrefix
        }
      }
    ]
  }
}

// Public IP for VM
resource publicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: '${vmName}-PIP'
  location: location
  tags: resourceTags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: publicIPAllocationMethod
    dnsSettings: {
      domainNameLabel: toLower('${vmName}-${uniqueString(resourceGroup().id)}')
    }
  }
}

// Public IP for Bastion
resource bastionPublicIP 'Microsoft.Network/publicIPAddresses@2023-05-01' = if (deployBastion) {
  name: 'AzLocalBox-Bastion-PIP'
  location: location
  tags: resourceTags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Azure Bastion
resource bastion 'Microsoft.Network/bastionHosts@2023-05-01' = if (deployBastion) {
  name: 'AzLocalBox-Bastion'
  location: location
  tags: resourceTags
  sku: {
    name: 'Standard'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: '${virtualNetwork.id}/subnets/AzureBastionSubnet'
          }
          publicIPAddress: {
            id: bastionPublicIP.id
          }
        }
      }
    ]
  }
}

// Network Interface
resource networkInterface 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: '${vmName}-NIC'
  location: location
  tags: resourceTags
  properties: {
    ipConfigurations: [
      {
        name: 'ipConfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: '${virtualNetwork.id}/subnets/${subnetName}'
          }
          publicIPAddress: {
            id: publicIP.id
          }
        }
      }
    ]
    enableAcceleratedNetworking: true
  }
}

// Storage Account for diagnostics
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'azlocalbox${uniqueString(resourceGroup().id)}'
  location: location
  tags: resourceTags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
  }
}

// Virtual Machine
resource virtualMachine 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  tags: resourceTags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
        version: 'latest'
      }
      osDisk: {
        name: '${vmName}-OSDisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
        diskSizeGB: 256
      }
      dataDisks: [
        {
          name: '${vmName}-DataDisk1'
          diskSizeGB: 1024
          lun: 0
          createOption: 'Empty'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: windowsAdminUsername
      adminPassword: windowsAdminPassword
      windowsConfiguration: {
        provisionVMAgent: true
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByPlatform'
          automaticByPlatformSettings: {
            rebootSetting: 'IfRequired'
          }
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageAccount.properties.primaryEndpoints.blob
      }
    }
  }
}

// VM Extension - Enable Hyper-V and configure nested virtualization
resource hyperVExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: virtualMachine
  name: 'EnableHyperV'
  location: location
  tags: resourceTags
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: []
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Bypass -Command "Install-WindowsFeature -Name Hyper-V, RSAT-Hyper-V-Tools, Hyper-V-PowerShell -IncludeManagementTools; Restart-Computer -Force"'
    }
  }
}

// VM Extension - Log Analytics agent (if workspace provided)
resource logAnalyticsExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = if (!empty(workspaceId)) {
  parent: virtualMachine
  name: 'MicrosoftMonitoringAgent'
  location: location
  tags: resourceTags
  properties: {
    publisher: 'Microsoft.EnterpriseCloud.Monitoring'
    type: 'MicrosoftMonitoringAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: true
    settings: {
      workspaceId: !empty(workspaceId) ? reference(workspaceId, '2022-10-01').customerId : ''
    }
    protectedSettings: {
      workspaceKey: !empty(workspaceId) ? listKeys(workspaceId, '2022-10-01').primarySharedKey : ''
    }
  }
  dependsOn: [
    hyperVExtension
  ]
}

// Output values
output vmName string = virtualMachine.name
output vmId string = virtualMachine.id
output publicIPAddress string = publicIP.properties.ipAddress
output publicIPFqdn string = publicIP.properties.dnsSettings.fqdn
output privateIPAddress string = networkInterface.properties.ipConfigurations[0].properties.privateIPAddress
output vmResourceGroup string = resourceGroup().name
output azureCloudEnvironment string = azureCloudEnvironment
