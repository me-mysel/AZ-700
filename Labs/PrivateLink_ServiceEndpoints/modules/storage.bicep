// ============================================================================
// Module: Storage Account
// ============================================================================

@description('Storage account name')
param storageAccountName string

@description('Location for the storage account')
param location string

@description('Enable public network access')
param publicNetworkAccess string = 'Enabled'

@description('Default network action')
param defaultNetworkAction string = 'Deny'

@description('Virtual network rules')
param virtualNetworkRules array = []

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: defaultNetworkAction
      bypass: 'None'
      virtualNetworkRules: virtualNetworkRules
    }
  }
}

output storageAccountId string = storageAccount.id
output storageAccountName string = storageAccount.name
output blobEndpoint string = storageAccount.properties.primaryEndpoints.blob
