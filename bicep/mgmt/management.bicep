@description('Azure region for resources')
param location string = resourceGroup().location

@description('Log Analytics Workspace name')
param workspaceName string = 'AzLocalBox-Workspace'

@description('Log Analytics Workspace SKU')
@allowed([
  'PerGB2018'
  'CapacityReservation'
])
param workspaceSku string = 'PerGB2018'

@description('Log Analytics data retention in days')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

@description('Tags for resources')
param resourceTags object = {
  Project: 'AzureLocalVirtual'
  Environment: 'Lab'
  Solution: 'LocalBox'
}

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: workspaceName
  location: location
  tags: resourceTags
  properties: {
    sku: {
      name: workspaceSku
    }
    retentionInDays: retentionInDays
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

// Solutions for Log Analytics
resource vmInsightsSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'VMInsights(${workspaceName})'
  location: location
  tags: resourceTags
  plan: {
    name: 'VMInsights(${workspaceName})'
    product: 'OMSGallery/VMInsights'
    publisher: 'Microsoft'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource securitySolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'Security(${workspaceName})'
  location: location
  tags: resourceTags
  plan: {
    name: 'Security(${workspaceName})'
    product: 'OMSGallery/Security'
    publisher: 'Microsoft'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
  }
}

resource updatesSolution 'Microsoft.OperationsManagement/solutions@2015-11-01-preview' = {
  name: 'Updates(${workspaceName})'
  location: location
  tags: resourceTags
  plan: {
    name: 'Updates(${workspaceName})'
    product: 'OMSGallery/Updates'
    publisher: 'Microsoft'
    promotionCode: ''
  }
  properties: {
    workspaceResourceId: logAnalyticsWorkspace.id
  }
}

// Outputs
output workspaceId string = logAnalyticsWorkspace.id
output workspaceCustomerId string = logAnalyticsWorkspace.properties.customerId
output workspaceName string = logAnalyticsWorkspace.name
