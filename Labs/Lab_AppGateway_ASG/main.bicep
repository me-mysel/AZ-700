// ============================================================================
// AZ-700 Lab: Application Gateway with Application Security Groups
// ============================================================================
// This lab deploys:
// - VNet with dedicated subnets for AppGW, Web tier, and App tier
// - Application Gateway v2 with backend pool
// - Application Security Groups (ASGs) for web and app tiers
// - NSGs using ASG-based rules
// - Windows VMs with IIS for testing
// ============================================================================

@description('Location for all resources')
param location string = resourceGroup().location

@description('Admin username for VMs')
param adminUsername string = 'azureadmin'

@description('Admin password for VMs')
@secure()
param adminPassword string

@description('Unique DNS prefix for the Public IP')
param dnsLabelPrefix string = 'appgw-${uniqueString(resourceGroup().id)}'

// ============================================================================
// Variables
// ============================================================================
var vnetName = 'vnet-lab-appgw'
var vnetAddressPrefix = '10.10.0.0/16'

var appGatewaySubnetName = 'AppGatewaySubnet'
var appGatewaySubnetPrefix = '10.10.0.0/24'

var webSubnetName = 'WebSubnet'
var webSubnetPrefix = '10.10.1.0/24'

var appSubnetName = 'AppSubnet'
var appSubnetPrefix = '10.10.2.0/24'

var appGatewayName = 'appgw-lab'
var appGatewayPublicIPName = 'pip-appgw'

var asgWebName = 'asg-webservers'
var asgAppName = 'asg-appservers'

var nsgWebName = 'nsg-web-tier'
var nsgAppName = 'nsg-app-tier'

var webVmNames = ['vm-web-01', 'vm-web-02']
var appVmName = 'vm-app-01'

var vmSize = 'Standard_B2s'

// ============================================================================
// Application Security Groups
// ============================================================================
resource asgWeb 'Microsoft.Network/applicationSecurityGroups@2023-09-01' = {
  name: asgWebName
  location: location
  properties: {}
}

resource asgApp 'Microsoft.Network/applicationSecurityGroups@2023-09-01' = {
  name: asgAppName
  location: location
  properties: {}
}

// ============================================================================
// Network Security Groups with ASG-based rules
// ============================================================================
resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgWebName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-HTTP-From-AppGateway'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: appGatewaySubnetPrefix
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [
            {
              id: asgWeb.id
            }
          ]
          destinationPortRange: '80'
          description: 'Allow HTTP traffic from Application Gateway subnet to web servers'
        }
      }
      {
        name: 'Allow-HTTPS-From-AppGateway'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: appGatewaySubnetPrefix
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [
            {
              id: asgWeb.id
            }
          ]
          destinationPortRange: '443'
          description: 'Allow HTTPS traffic from Application Gateway subnet to web servers'
        }
      }
      {
        name: 'Allow-AppGateway-Health-Probes'
        properties: {
          priority: 120
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'GatewayManager'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '65200-65535'
          description: 'Allow Application Gateway v2 health probes'
        }
      }
      {
        name: 'Allow-RDP-For-Management'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [
            {
              id: asgWeb.id
            }
          ]
          destinationPortRange: '3389'
          description: 'Allow RDP for lab management (restrict in production!)'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all other inbound traffic'
        }
      }
    ]
  }
}

resource nsgApp 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgAppName
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-From-WebServers-ASG'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceApplicationSecurityGroups: [
            {
              id: asgWeb.id
            }
          ]
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [
            {
              id: asgApp.id
            }
          ]
          destinationPortRange: '8080'
          description: 'Allow traffic from web tier (ASG) to app tier (ASG) on port 8080'
        }
      }
      {
        name: 'Allow-RDP-For-Management'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationApplicationSecurityGroups: [
            {
              id: asgApp.id
            }
          ]
          destinationPortRange: '3389'
          description: 'Allow RDP for lab management (restrict in production!)'
        }
      }
      {
        name: 'Deny-All-Inbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
          description: 'Deny all other inbound traffic'
        }
      }
    ]
  }
}

// ============================================================================
// Virtual Network
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
        name: appGatewaySubnetName
        properties: {
          addressPrefix: appGatewaySubnetPrefix
          // Note: AppGateway subnet should NOT have an NSG attached
        }
      }
      {
        name: webSubnetName
        properties: {
          addressPrefix: webSubnetPrefix
          networkSecurityGroup: {
            id: nsgWeb.id
          }
        }
      }
      {
        name: appSubnetName
        properties: {
          addressPrefix: appSubnetPrefix
          networkSecurityGroup: {
            id: nsgApp.id
          }
        }
      }
    ]
  }
}

// ============================================================================
// Public IP for Application Gateway
// ============================================================================
resource appGatewayPublicIP 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: appGatewayPublicIPName
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

// ============================================================================
// Application Gateway
// ============================================================================
resource appGateway 'Microsoft.Network/applicationGateways@2023-09-01' = {
  name: appGatewayName
  location: location
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
      capacity: 2
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: vnet.properties.subnets[0].id
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIP'
        properties: {
          publicIPAddress: {
            id: appGatewayPublicIP.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'webBackendPool'
        properties: {
          backendAddresses: [
            {
              ipAddress: nicWeb[0].properties.ipConfigurations[0].properties.privateIPAddress
            }
            {
              ipAddress: nicWeb[1].properties.ipConfigurations[0].properties.privateIPAddress
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'httpSettings'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: false
          requestTimeout: 30
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, 'healthProbe')
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', appGatewayName, 'appGatewayFrontendIP')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', appGatewayName, 'port_80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'routingRule'
        properties: {
          priority: 100
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', appGatewayName, 'httpListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', appGatewayName, 'webBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', appGatewayName, 'httpSettings')
          }
        }
      }
    ]
    probes: [
      {
        name: 'healthProbe'
        properties: {
          protocol: 'Http'
          path: '/'
          interval: 30
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: false
          host: '127.0.0.1'
          match: {
            statusCodes: [
              '200-399'
            ]
          }
        }
      }
    ]
  }
}

// ============================================================================
// Network Interfaces for Web VMs (associated with ASG)
// ============================================================================
resource nicWeb 'Microsoft.Network/networkInterfaces@2023-09-01' = [for (vmName, i) in webVmNames: {
  name: 'nic-${vmName}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[1].id
          }
          applicationSecurityGroups: [
            {
              id: asgWeb.id
            }
          ]
        }
      }
    ]
  }
}]

// ============================================================================
// Network Interface for App VM (associated with ASG)
// ============================================================================
resource nicApp 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: 'nic-${appVmName}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[2].id
          }
          applicationSecurityGroups: [
            {
              id: asgApp.id
            }
          ]
        }
      }
    ]
  }
}

// ============================================================================
// Web Tier VMs with IIS
// ============================================================================
resource vmWeb 'Microsoft.Compute/virtualMachines@2023-09-01' = [for (vmName, i) in webVmNames: {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
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
          id: nicWeb[i].id
        }
      ]
    }
  }
}]

// ============================================================================
// Install IIS on Web VMs using Custom Script Extension
// ============================================================================
resource iisExtension 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for (vmName, i) in webVmNames: {
  parent: vmWeb[i]
  name: 'InstallIIS'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -Command "Install-WindowsFeature -Name Web-Server -IncludeManagementTools; Remove-Item C:\\inetpub\\wwwroot\\iisstart.htm -Force; Add-Content -Path C:\\inetpub\\wwwroot\\iisstart.htm -Value \'<html><body><h1>Hello from ${vmName}</h1><p>This response is from the web tier behind Application Gateway</p><p>Server: ${vmName}</p></body></html>\'"'
    }
  }
}]

// ============================================================================
// App Tier VM
// ============================================================================
resource vmApp 'Microsoft.Compute/virtualMachines@2023-09-01' = {
  name: appVmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: appVmName
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
          id: nicApp.id
        }
      ]
    }
  }
}

// ============================================================================
// Outputs
// ============================================================================
output appGatewayPublicIP string = appGatewayPublicIP.properties.ipAddress
output appGatewayFQDN string = appGatewayPublicIP.properties.dnsSettings.fqdn
output webVm1PrivateIP string = nicWeb[0].properties.ipConfigurations[0].properties.privateIPAddress
output webVm2PrivateIP string = nicWeb[1].properties.ipConfigurations[0].properties.privateIPAddress
output appVmPrivateIP string = nicApp.properties.ipConfigurations[0].properties.privateIPAddress
output asgWebId string = asgWeb.id
output asgAppId string = asgApp.id
