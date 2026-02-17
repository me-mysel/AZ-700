// AZ-700 Lab 4: Hub-Spoke Architecture with VNet Peering

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Admin username for VMs')
param adminUsername string = 'azureadmin'

@description('Admin password for VMs')
@secure()
param adminPassword string

var hubNvaPrivateIp = '10.0.2.4'

resource hubVnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-hub'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/16']
    }
    subnets: [
      {
        name: 'snet-hub-shared'
        properties: { addressPrefix: '10.0.1.0/24' }
      }
      {
        name: 'snet-hub-nva'
        properties: { addressPrefix: '10.0.2.0/24' }
      }
    ]
  }
}

resource spoke1Vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-spoke1'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.1.0.0/16'] }
    subnets: [{
      name: 'snet-spoke1-workload'
      properties: {
        addressPrefix: '10.1.1.0/24'
        routeTable: { id: spoke1RouteTable.id }
      }
    }]
  }
}

resource spoke2Vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-spoke2'
  location: location
  properties: {
    addressSpace: { addressPrefixes: ['10.2.0.0/16'] }
    subnets: [{
      name: 'snet-spoke2-workload'
      properties: {
        addressPrefix: '10.2.1.0/24'
        routeTable: { id: spoke2RouteTable.id }
      }
    }]
  }
}

resource hubToSpoke1 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: hubVnet
  name: 'hub-to-spoke1'
  properties: {
    remoteVirtualNetwork: { id: spoke1Vnet.id }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource spoke1ToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: spoke1Vnet
  name: 'spoke1-to-hub'
  properties: {
    remoteVirtualNetwork: { id: hubVnet.id }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource hubToSpoke2 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: hubVnet
  name: 'hub-to-spoke2'
  properties: {
    remoteVirtualNetwork: { id: spoke2Vnet.id }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource spoke2ToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: spoke2Vnet
  name: 'spoke2-to-hub'
  properties: {
    remoteVirtualNetwork: { id: hubVnet.id }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

resource spoke1RouteTable 'Microsoft.Network/routeTables@2023-09-01' = {
  name: 'rt-spoke1'
  location: location
  properties: {
    routes: [{
      name: 'to-spoke2-via-hub'
      properties: {
        addressPrefix: '10.2.0.0/16'
        nextHopType: 'VirtualAppliance'
        nextHopIpAddress: hubNvaPrivateIp
      }
    }]
  }
}

resource spoke2RouteTable 'Microsoft.Network/routeTables@2023-09-01' = {
  name: 'rt-spoke2'
  location: location
  properties: {
    routes: [{
      name: 'to-spoke1-via-hub'
      properties: {
        addressPrefix: '10.1.0.0/16'
        nextHopType: 'VirtualAppliance'
        nextHopIpAddress: hubNvaPrivateIp
      }
    }]
  }
}

resource hubNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-hub'
  location: location
  properties: {
    securityRules: [
      { name: 'AllowRDP', properties: { priority: 1000, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: '*', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '3389' }}
      { name: 'AllowICMP', properties: { priority: 1100, direction: 'Inbound', access: 'Allow', protocol: 'Icmp', sourceAddressPrefix: '10.0.0.0/8', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '*' }}
    ]
  }
}

resource spokeNsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-spokes'
  location: location
  properties: {
    securityRules: [
      { name: 'AllowRDP', properties: { priority: 1000, direction: 'Inbound', access: 'Allow', protocol: 'Tcp', sourceAddressPrefix: '*', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '3389' }}
      { name: 'AllowICMP', properties: { priority: 1100, direction: 'Inbound', access: 'Allow', protocol: 'Icmp', sourceAddressPrefix: '10.0.0.0/8', sourcePortRange: '*', destinationAddressPrefix: '*', destinationPortRange: '*' }}
    ]
  }
}

resource hubVmPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-vm-hub-nva'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource spoke1VmPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-vm-spoke1'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource spoke2VmPip 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: 'pip-vm-spoke2'
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource hubVmNic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-hub-nva'
  location: location
  properties: {
    ipConfigurations: [{
      name: 'ipconfig1'
      properties: {
        subnet: { id: hubVnet.properties.subnets[1].id }
        privateIPAllocationMethod: 'Static'
        privateIPAddress: hubNvaPrivateIp
        publicIPAddress: { id: hubVmPip.id }
      }
    }]
    enableIPForwarding: true
    networkSecurityGroup: { id: hubNsg.id }
  }
}

resource spoke1VmNic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-spoke1'
  location: location
  properties: {
    ipConfigurations: [{
      name: 'ipconfig1'
      properties: {
        subnet: { id: spoke1Vnet.properties.subnets[0].id }
        privateIPAllocationMethod: 'Dynamic'
        publicIPAddress: { id: spoke1VmPip.id }
      }
    }]
    networkSecurityGroup: { id: spokeNsg.id }
  }
}

resource spoke2VmNic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-vm-spoke2'
  location: location
  properties: {
    ipConfigurations: [{
      name: 'ipconfig1'
      properties: {
        subnet: { id: spoke2Vnet.properties.subnets[0].id }
        privateIPAllocationMethod: 'Dynamic'
        publicIPAddress: { id: spoke2VmPip.id }
      }
    }]
    networkSecurityGroup: { id: spokeNsg.id }
  }
}

resource hubVm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-hub-nva'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    osProfile: { computerName: 'vm-hub-nva', adminUsername: adminUsername, adminPassword: adminPassword }
    storageProfile: {
      imageReference: { publisher: 'MicrosoftWindowsServer', offer: 'WindowsServer', sku: '2022-datacenter-azure-edition', version: 'latest' }
      osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'Standard_LRS' }}
    }
    networkProfile: { networkInterfaces: [{ id: hubVmNic.id }] }
  }
}

resource spoke1Vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-spoke1'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    osProfile: { computerName: 'vm-spoke1', adminUsername: adminUsername, adminPassword: adminPassword }
    storageProfile: {
      imageReference: { publisher: 'MicrosoftWindowsServer', offer: 'WindowsServer', sku: '2022-datacenter-azure-edition', version: 'latest' }
      osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'Standard_LRS' }}
    }
    networkProfile: { networkInterfaces: [{ id: spoke1VmNic.id }] }
  }
}

resource spoke2Vm 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: 'vm-spoke2'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B2s' }
    osProfile: { computerName: 'vm-spoke2', adminUsername: adminUsername, adminPassword: adminPassword }
    storageProfile: {
      imageReference: { publisher: 'MicrosoftWindowsServer', offer: 'WindowsServer', sku: '2022-datacenter-azure-edition', version: 'latest' }
      osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'Standard_LRS' }}
    }
    networkProfile: { networkInterfaces: [{ id: spoke2VmNic.id }] }
  }
}

resource hubVmExt 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = {
  parent: hubVm
  name: 'EnableRouting'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -Command "Set-ItemProperty -Path HKLM:\\SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters -Name IpEnableRouter -Value 1; netsh advfirewall firewall add rule name=ICMP protocol=icmpv4 dir=in action=allow; Restart-Computer -Force"'
    }
  }
}

output hubVmPublicIp string = hubVmPip.properties.ipAddress
output hubVmPrivateIp string = hubNvaPrivateIp
output spoke1VmPublicIp string = spoke1VmPip.properties.ipAddress
output spoke2VmPublicIp string = spoke2VmPip.properties.ipAddress
