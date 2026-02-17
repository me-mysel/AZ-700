// AZ-700 Lab 5: VPN Gateway Fundamentals
// This lab creates a VNet-to-VNet VPN connection to simulate S2S VPN concepts
// (Actual S2S requires on-premises hardware, so we simulate with Azure-to-Azure)

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Admin username for VMs')
param adminUsername string = 'azureadmin'

@description('Admin password for VMs')
@secure()
param adminPassword string

@description('VPN Gateway SKU - Only AZ SKUs are supported (non-AZ deprecated)')
@allowed(['VpnGw1AZ', 'VpnGw2AZ'])
param vpnGatewaySku string = 'VpnGw1AZ'

@description('Shared key for VPN connection')
@secure()
param vpnSharedKey string

// ============================================================================
// VARIABLES
// ============================================================================
var onPremVnetName = 'vnet-onprem-simulated'
var onPremAddressPrefix = '192.168.0.0/16'
var onPremGatewaySubnetPrefix = '192.168.255.0/27'
var onPremWorkloadSubnetPrefix = '192.168.1.0/24'

var azureVnetName = 'vnet-azure-hub'
var azureAddressPrefix = '10.0.0.0/16'
var azureGatewaySubnetPrefix = '10.0.255.0/27'
var azureWorkloadSubnetPrefix = '10.0.1.0/24'

// ============================================================================
// "ON-PREMISES" SIMULATED VNET (represents your datacenter)
// ============================================================================
resource onPremVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: onPremVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [onPremAddressPrefix]
    }
    subnets: [
      {
        name: 'GatewaySubnet'  // MUST be named exactly 'GatewaySubnet'
        properties: {
          addressPrefix: onPremGatewaySubnetPrefix
        }
      }
      {
        name: 'snet-onprem-workload'
        properties: {
          addressPrefix: onPremWorkloadSubnetPrefix
          networkSecurityGroup: { id: onPremNsg.id }
        }
      }
    ]
  }
}

// ============================================================================
// AZURE HUB VNET
// ============================================================================
resource azureVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: azureVnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [azureAddressPrefix]
    }
    subnets: [
      {
        name: 'GatewaySubnet'  // MUST be named exactly 'GatewaySubnet'
        properties: {
          addressPrefix: azureGatewaySubnetPrefix
        }
      }
      {
        name: 'snet-azure-workload'
        properties: {
          addressPrefix: azureWorkloadSubnetPrefix
          networkSecurityGroup: { id: azureNsg.id }
        }
      }
    ]
  }
}

// ============================================================================
// NETWORK SECURITY GROUPS
// ============================================================================
resource onPremNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-onprem'
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
      {
        name: 'AllowICMP'
        properties: {
          priority: 1100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Icmp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

resource azureNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-azure'
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
      {
        name: 'AllowICMP'
        properties: {
          priority: 1100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Icmp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// ============================================================================
// PUBLIC IPs FOR VPN GATEWAYS
// ============================================================================
resource onPremVpnGwPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-vpngw-onprem'
  location: location
  sku: { name: 'Standard' }
  zones: ['1', '2', '3']  // Required for AZ VPN Gateway SKUs
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource azureVpnGwPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-vpngw-azure'
  location: location
  sku: { name: 'Standard' }
  zones: ['1', '2', '3']  // Required for AZ VPN Gateway SKUs
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// ============================================================================
// VPN GATEWAYS (Route-based, which is recommended for most scenarios)
// NOTE: VPN Gateway deployment takes 30-45 minutes!
// ============================================================================
resource onPremVpnGw 'Microsoft.Network/virtualNetworkGateways@2023-09-01' = {
  name: 'vpngw-onprem'
  location: location
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'  // Route-based is recommended (vs Policy-based)
    sku: {
      name: vpnGatewaySku
      tier: vpnGatewaySku
    }
    enableBgp: true  // Enable BGP for dynamic routing
    bgpSettings: {
      asn: 65001  // On-premises ASN (simulated)
    }
    ipConfigurations: [
      {
        name: 'vnetGatewayConfig'
        properties: {
          publicIPAddress: { id: onPremVpnGwPip.id }
          subnet: { id: resourceId('Microsoft.Network/virtualNetworks/subnets', onPremVnetName, 'GatewaySubnet') }
        }
      }
    ]
  }
  dependsOn: [onPremVnet]
}

resource azureVpnGw 'Microsoft.Network/virtualNetworkGateways@2023-09-01' = {
  name: 'vpngw-azure'
  location: location
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    sku: {
      name: vpnGatewaySku
      tier: vpnGatewaySku
    }
    enableBgp: true
    bgpSettings: {
      asn: 65002  // Custom ASN for Azure gateway (65515 is reserved)
    }
    ipConfigurations: [
      {
        name: 'vnetGatewayConfig'
        properties: {
          publicIPAddress: { id: azureVpnGwPip.id }
          subnet: { id: resourceId('Microsoft.Network/virtualNetworks/subnets', azureVnetName, 'GatewaySubnet') }
        }
      }
    ]
  }
  dependsOn: [azureVnet]
}

// ============================================================================
// LOCAL NETWORK GATEWAYS (Represent the "other side" of the connection)
// ============================================================================
resource lngOnPrem 'Microsoft.Network/localNetworkGateways@2023-09-01' = {
  name: 'lng-onprem'
  location: location
  properties: {
    gatewayIpAddress: onPremVpnGwPip.properties.ipAddress
    bgpSettings: {
      asn: 65001
      bgpPeeringAddress: onPremVpnGw.properties.bgpSettings.bgpPeeringAddress
    }
    localNetworkAddressSpace: {
      addressPrefixes: []  // Empty when using BGP (routes learned dynamically)
    }
  }
  dependsOn: [onPremVpnGw]
}

resource lngAzure 'Microsoft.Network/localNetworkGateways@2023-09-01' = {
  name: 'lng-azure'
  location: location
  properties: {
    gatewayIpAddress: azureVpnGwPip.properties.ipAddress
    bgpSettings: {
      asn: 65002
      bgpPeeringAddress: azureVpnGw.properties.bgpSettings.bgpPeeringAddress
    }
    localNetworkAddressSpace: {
      addressPrefixes: []  // Empty when using BGP
    }
  }
  dependsOn: [azureVpnGw]
}

// ============================================================================
// VPN CONNECTIONS (IPsec tunnels)
// ============================================================================
resource connOnPremToAzure 'Microsoft.Network/connections@2023-09-01' = {
  name: 'conn-onprem-to-azure'
  location: location
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: { id: onPremVpnGw.id }
    localNetworkGateway2: { id: lngAzure.id }
    sharedKey: vpnSharedKey
    enableBgp: true
    connectionProtocol: 'IKEv2'
  }
}

resource connAzureToOnPrem 'Microsoft.Network/connections@2023-09-01' = {
  name: 'conn-azure-to-onprem'
  location: location
  properties: {
    connectionType: 'IPsec'
    virtualNetworkGateway1: { id: azureVpnGw.id }
    localNetworkGateway2: { id: lngOnPrem.id }
    sharedKey: vpnSharedKey
    enableBgp: true
    connectionProtocol: 'IKEv2'
  }
}

// ============================================================================
// TEST VMs
// ============================================================================
resource onPremVmPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-vm-onprem'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource azureVmPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-vm-azure'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource onPremVmNic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-onprem'
  location: location
  properties: {
    ipConfigurations: [{
      name: 'ipconfig1'
      properties: {
        subnet: { id: onPremVnet.properties.subnets[1].id }
        privateIPAllocationMethod: 'Static'
        privateIPAddress: '192.168.1.4'
        publicIPAddress: { id: onPremVmPip.id }
      }
    }]
    networkSecurityGroup: { id: onPremNsg.id }
  }
}

resource azureVmNic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-azure'
  location: location
  properties: {
    ipConfigurations: [{
      name: 'ipconfig1'
      properties: {
        subnet: { id: azureVnet.properties.subnets[1].id }
        privateIPAllocationMethod: 'Static'
        privateIPAddress: '10.0.1.4'
        publicIPAddress: { id: azureVmPip.id }
      }
    }]
    networkSecurityGroup: { id: azureNsg.id }
  }
}

resource onPremVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-onprem'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    osProfile: {
      computerName: 'vm-onprem'
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
        managedDisk: { storageAccountType: 'Standard_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [{ id: onPremVmNic.id }]
    }
  }
}

resource azureVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-azure'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    osProfile: {
      computerName: 'vm-azure'
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
        managedDisk: { storageAccountType: 'Standard_LRS' }
      }
    }
    networkProfile: {
      networkInterfaces: [{ id: azureVmNic.id }]
    }
  }
}

// Enable ICMP on VMs via custom script extension
resource onPremVmExt 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: onPremVm
  name: 'EnableICMP'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -Command "netsh advfirewall firewall add rule name=ICMP protocol=icmpv4 dir=in action=allow"'
    }
  }
}

resource azureVmExt 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: azureVm
  name: 'EnableICMP'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -Command "netsh advfirewall firewall add rule name=ICMP protocol=icmpv4 dir=in action=allow"'
    }
  }
}

// ============================================================================
// OUTPUTS
// ============================================================================
output onPremVmPublicIp string = onPremVmPip.properties.ipAddress
output onPremVmPrivateIp string = '192.168.1.4'
output azureVmPublicIp string = azureVmPip.properties.ipAddress
output azureVmPrivateIp string = '10.0.1.4'
output onPremVpnGwPublicIp string = onPremVpnGwPip.properties.ipAddress
output azureVpnGwPublicIp string = azureVpnGwPip.properties.ipAddress
output onPremBgpAsn int = 65001
output azureBgpAsn int = 65002
