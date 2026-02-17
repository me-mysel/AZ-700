// ============================================================================
// Lab: Private Link, Private Endpoints & Service Endpoints
// ============================================================================
// This Bicep template deploys infrastructure to demonstrate:
// - Service Endpoints
// - Private Endpoints
// - Private Link Service
// ============================================================================

@description('Location for all resources')
param location string = resourceGroup().location

@description('Admin username for VMs')
param adminUsername string = 'azureuser'

@description('Admin password for VMs')
@secure()
param adminPassword string

@description('Unique suffix for globally unique names')
param uniqueSuffix string = uniqueString(resourceGroup().id)

// ============================================================================
// Variables
// ============================================================================

var vnetHubName = 'vnet-hub'
var vnetConsumerName = 'vnet-consumer'
var storageNamePE = 'stpelab${uniqueSuffix}'
var storageNameSE = 'stselab${uniqueSuffix}'

// ============================================================================
// Virtual Networks
// ============================================================================

// Hub VNet - contains test VM, Private Endpoints, Private Link Service
resource vnetHub 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetHubName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'subnet-vm'
        properties: {
          addressPrefix: '10.0.1.0/24'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [ location ]
            }
          ]
        }
      }
      {
        name: 'subnet-pe'
        properties: {
          addressPrefix: '10.0.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'subnet-pls'
        properties: {
          addressPrefix: '10.0.3.0/24'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'subnet-pls-nat'
        properties: {
          addressPrefix: '10.0.4.0/24'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'subnet-backend'
        properties: {
          addressPrefix: '10.0.5.0/24'
        }
      }
    ]
  }
}

// Consumer VNet - simulates external customer
resource vnetConsumer 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetConsumerName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.1.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'subnet-consumer'
        properties: {
          addressPrefix: '10.1.1.0/24'
        }
      }
      {
        name: 'subnet-pe'
        properties: {
          addressPrefix: '10.1.2.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
        }
      }
    ]
  }
}

// ============================================================================
// Storage Accounts
// ============================================================================

// Storage Account with Private Endpoint (public access disabled)
resource storageAccountPE 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageNamePE
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    publicNetworkAccess: 'Disabled'  // Key: Public access disabled
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'None'
    }
  }
}

// Storage Account with Service Endpoint only
resource storageAccountSE 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageNameSE
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    publicNetworkAccess: 'Enabled'  // Public endpoint exists
    networkAcls: {
      defaultAction: 'Deny'  // But default action is Deny
      bypass: 'None'
      virtualNetworkRules: [
        {
          id: '${vnetHub.id}/subnets/subnet-vm'
          action: 'Allow'
        }
      ]
    }
  }
}

// Blob container for testing
resource blobContainerPE 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccountPE.name}/default/testcontainer'
  properties: {
    publicAccess: 'None'
  }
}

resource blobContainerSE 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccountSE.name}/default/testcontainer'
  properties: {
    publicAccess: 'None'
  }
}

// ============================================================================
// Private Endpoint for Storage Account
// ============================================================================

resource privateEndpointStorage 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'pe-storage-blob'
  location: location
  properties: {
    subnet: {
      id: '${vnetHub.id}/subnets/subnet-pe'
    }
    privateLinkServiceConnections: [
      {
        name: 'storage-connection'
        properties: {
          privateLinkServiceId: storageAccountPE.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
  }
}

// ============================================================================
// Private DNS Zone for Storage
// ============================================================================

resource privateDnsZoneBlob 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
}

// Link DNS Zone to Hub VNet
resource privateDnsZoneLinkHub 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZoneBlob
  name: 'link-vnet-hub'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnetHub.id
    }
  }
}

// DNS Zone Group - auto-creates A record
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: privateEndpointStorage
  name: 'storage-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: privateDnsZoneBlob.id
        }
      }
    ]
  }
}

// ============================================================================
// Network Security Groups
// ============================================================================

resource nsgVm 'Microsoft.Network/networkSecurityGroups@2023-05-01' = {
  name: 'nsg-vm'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowSSH'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// ============================================================================
// Test VM (Hub VNet)
// ============================================================================

resource publicIpVmTest 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-vm-test'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nicVmTest 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'vm-test-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${vnetHub.id}/subnets/subnet-vm'
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpVmTest.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgVm.id
    }
  }
}

resource vmTest 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: 'vm-test'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    osProfile: {
      computerName: 'vm-test'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicVmTest.id
        }
      ]
    }
  }
}

// Install tools on VM (dnsutils for nslookup/dig, curl for testing)
resource vmTestExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: vmTest
  name: 'install-tools'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'apt-get update && apt-get install -y dnsutils curl iputils-ping || true'
    }
  }
}

// ============================================================================
// Consumer VM (Consumer VNet)
// ============================================================================

resource publicIpVmConsumer 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-vm-consumer'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource nicVmConsumer 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'vm-consumer-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${vnetConsumer.id}/subnets/subnet-consumer'
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpVmConsumer.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsgVm.id
    }
  }
}

resource vmConsumer 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: 'vm-consumer'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    osProfile: {
      computerName: 'vm-consumer'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicVmConsumer.id
        }
      ]
    }
  }
}

resource vmConsumerExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: vmConsumer
  name: 'install-tools'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'apt-get update && apt-get install -y dnsutils curl iputils-ping || true'
    }
  }
}

// ============================================================================
// Private Link Service (Provider Side)
// ============================================================================

// Internal Load Balancer for Private Link Service
resource loadBalancer 'Microsoft.Network/loadBalancers@2023-05-01' = {
  name: 'lb-internal-pls'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontend'
        properties: {
          subnet: {
            id: '${vnetHub.id}/subnets/subnet-pls'
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backend-pool'
      }
    ]
    probes: [
      {
        name: 'health-probe'
        properties: {
          protocol: 'Tcp'
          port: 80
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'http-rule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', 'lb-internal-pls', 'frontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', 'lb-internal-pls', 'backend-pool')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', 'lb-internal-pls', 'health-probe')
          }
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          enableFloatingIP: false
          idleTimeoutInMinutes: 4
        }
      }
    ]
  }
}

// Backend VM for Private Link Service
resource nicBackend 'Microsoft.Network/networkInterfaces@2023-05-01' = {
  name: 'vm-backend-nic'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${vnetHub.id}/subnets/subnet-backend'
          }
          privateIPAllocationMethod: 'Dynamic'
          loadBalancerBackendAddressPools: [
            {
              id: '${loadBalancer.id}/backendAddressPools/backend-pool'
            }
          ]
        }
      }
    ]
  }
}

resource vmBackend 'Microsoft.Compute/virtualMachines@2023-07-01' = {
  name: 'vm-backend'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'
    }
    osProfile: {
      computerName: 'vm-backend'
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicBackend.id
        }
      ]
    }
  }
}

// Install nginx on backend VM using simple Python HTTP server as fallback
resource vmBackendExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  parent: vmBackend
  name: 'install-nginx'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'mkdir -p /var/www/html && echo "Hello from Private Link Service Backend!" > /var/www/html/index.html && cd /var/www/html && nohup python3 -m http.server 80 > /var/log/webserver.log 2>&1 &'
    }
  }
}

// Private Link Service
resource privateLinkService 'Microsoft.Network/privateLinkServices@2023-05-01' = {
  name: 'pls-web-service'
  location: location
  properties: {
    loadBalancerFrontendIpConfigurations: [
      {
        id: '${loadBalancer.id}/frontendIPConfigurations/frontend'
      }
    ]
    ipConfigurations: [
      {
        name: 'nat-ip-config'
        properties: {
          subnet: {
            id: '${vnetHub.id}/subnets/subnet-pls-nat'
          }
          privateIPAllocationMethod: 'Dynamic'
          primary: true
        }
      }
    ]
    visibility: {
      subscriptions: [
        '*'
      ]
    }
    autoApproval: {
      subscriptions: [
        subscription().subscriptionId
      ]
    }
  }
  dependsOn: [
    loadBalancer
  ]
}

// ============================================================================
// Private Endpoint to Private Link Service (Consumer Side)
// ============================================================================

resource privateEndpointPLS 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: 'pe-consumer-to-pls'
  location: location
  properties: {
    subnet: {
      id: '${vnetConsumer.id}/subnets/subnet-pe'
    }
    privateLinkServiceConnections: [
      {
        name: 'pls-connection'
        properties: {
          privateLinkServiceId: privateLinkService.id
        }
      }
    ]
  }
}

// ============================================================================
// Outputs
// ============================================================================

output vmTestPublicIp string = publicIpVmTest.properties.ipAddress
output vmConsumerPublicIp string = publicIpVmConsumer.properties.ipAddress
output storageAccountPEName string = storageAccountPE.name
output storageAccountSEName string = storageAccountSE.name
output privateLinkServiceId string = privateLinkService.id
output privateEndpointStorageIp string = privateEndpointStorage.properties.customDnsConfigs[0].ipAddresses[0]
output instructions string = '''
=== Lab Deployment Complete ===

To start the lab exercises, follow the README.md instructions.

Quick Start:
1. SSH to vm-test: ssh azureuser@<vmTestPublicIp>
2. Test Service Endpoint: nslookup <storageAccountSEName>.blob.core.windows.net
3. Test Private Endpoint: nslookup <storageAccountPEName>.blob.core.windows.net

Key Observations:
- Service Endpoint storage resolves to PUBLIC IP
- Private Endpoint storage resolves to PRIVATE IP (10.0.2.x)
'''
