// ============================================================================
// AZ-700 Lab 2: Private Endpoint + DNS Resolution
// ============================================================================
// This lab demonstrates:
//   1. Private DNS Zone creation and VNet linking
//   2. Storage Account with Private Endpoint
//   3. VM to test DNS resolution
//   4. How privatelink CNAME chain works
// ============================================================================

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Unique suffix for globally unique names')
param uniqueSuffix string = uniqueString(resourceGroup().id)

@description('Admin username for the VM')
param adminUsername string = 'azureadmin'

@description('Admin password for the VM')
@secure()
param adminPassword string

// ============================================================================
// VARIABLES
// ============================================================================

var vnetName = 'vnet-lab02-hub'
var vnetAddressPrefix = '10.0.0.0/16'

var subnetVmName = 'snet-vms'
var subnetVmPrefix = '10.0.1.0/24'

var subnetPeName = 'snet-privateendpoints'
var subnetPePrefix = '10.0.2.0/24'

var vmName = 'vm-dnstest'
var storageAccountName = 'stlab02${uniqueSuffix}'
var privateEndpointName = 'pe-storage-blob'
var privateDnsZoneName = 'privatelink.blob.core.windows.net'

// ============================================================================
// VIRTUAL NETWORK
// ============================================================================

resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetVmName
        properties: {
          addressPrefix: subnetVmPrefix
        }
      }
      {
        name: subnetPeName
        properties: {
          addressPrefix: subnetPePrefix
          // Private Endpoints don't need delegation, but we can enable network policies
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

// ============================================================================
// STORAGE ACCOUNT (Target for Private Endpoint)
// ============================================================================

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    // IMPORTANT: We'll disable public access to force private endpoint usage
    publicNetworkAccess: 'Disabled'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'None'
    }
  }
}

// ============================================================================
// PRIVATE DNS ZONE
// ============================================================================

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'  // Private DNS Zones are always 'global'
  properties: {}
}

// ============================================================================
// VNET LINK TO PRIVATE DNS ZONE
// ============================================================================

resource vnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: '${vnetName}-link'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false  // No autoregistration for this zone (it's for storage, not VMs)
  }
}

// ============================================================================
// PRIVATE ENDPOINT FOR STORAGE BLOB
// ============================================================================

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = {
  name: privateEndpointName
  location: location
  properties: {
    subnet: {
      id: vnet.properties.subnets[1].id  // snet-privateendpoints
    }
    privateLinkServiceConnections: [
      {
        name: '${privateEndpointName}-connection'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: [
            'blob'  // Subresource type - 'blob' for Blob Storage
          ]
        }
      }
    ]
  }
}

// ============================================================================
// PRIVATE DNS ZONE GROUP (Auto-creates A record in Private DNS Zone)
// ============================================================================

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-blob-core-windows-net'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

// ============================================================================
// NETWORK SECURITY GROUP FOR VM SUBNET
// ============================================================================

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-${subnetVmName}'
  location: location
  properties: {
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '3389'
        }
      }
    ]
  }
}

// ============================================================================
// PUBLIC IP FOR VM (For RDP access during lab)
// ============================================================================

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-${vmName}'
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// ============================================================================
// NETWORK INTERFACE FOR VM
// ============================================================================

resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-${vmName}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id  // snet-vms
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
    networkSecurityGroup: {
      id: nsg.id
    }
  }
}

// ============================================================================
// VIRTUAL MACHINE (For testing DNS resolution)
// ============================================================================

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_B2s'  // Cost-effective for labs
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
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
          id: nic.id
        }
      ]
    }
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================

output resourceGroupName string = resourceGroup().name
output vnetName string = vnet.name
output storageAccountName string = storageAccount.name
output storageBlobFqdn string = '${storageAccount.name}.blob.core.windows.net'
output privateEndpointIp string = privateEndpoint.properties.customDnsConfigs[0].ipAddresses[0]
output privateDnsZoneName string = privateDnsZone.name
output vmPublicIp string = publicIp.properties.ipAddress
output vmName string = vm.name

output labInstructions string = '''
================================================================================
LAB 2: PRIVATE ENDPOINT + DNS RESOLUTION
================================================================================

STEP 1: RDP to the VM
  - Use the vmPublicIp output above
  - Username: azureadmin
  - Password: (the one you provided)

STEP 2: Test DNS Resolution (from inside the VM)
  Open PowerShell and run:
  
  # This should resolve to the PRIVATE IP (10.0.2.x)
  nslookup ${storageAccountName}.blob.core.windows.net
  
  # You should see:
  # - First a CNAME to: ${storageAccountName}.privatelink.blob.core.windows.net
  # - Then the A record resolving to the private endpoint IP

STEP 3: Test from your LOCAL machine (outside Azure)
  # This will resolve to the PUBLIC IP (since you're not in the VNet)
  nslookup ${storageAccountName}.blob.core.windows.net
  
  # Notice the difference! Same FQDN, different resolution based on WHERE you query from.

STEP 4: Explore in the Portal
  - Go to Private DNS Zone: privatelink.blob.core.windows.net
  - Check the A record that was auto-created
  - Check the VNet link

WHAT YOU LEARNED:
  ✅ Private Endpoint creates a NIC with private IP in your VNet
  ✅ Private DNS Zone stores the A record mapping FQDN to private IP
  ✅ VNet Link allows VMs in linked VNets to resolve the private IP
  ✅ The CNAME chain: storage.blob.core.windows.net → storage.privatelink.blob.core.windows.net

================================================================================
'''
