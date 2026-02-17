---
tags:
  - AZ-700
  - azure/networking
  - domain/core-networking
  - vnet
  - subnets
  - ip-addressing
  - cidr
  - address-space
  - subnet-delegation
aliases:
  - VNet
  - Virtual Network
  - IP Addressing
created: 2025-01-01
updated: 2026-02-07
---

# Virtual Networks, Subnets & IP Addressing

## AZ-700 Exam Domain: Design and Implement Core Networking Infrastructure (25-30%)

> [!info] Related Notes
> - [[Azure_DNS]] — Name resolution within VNets
> - [[VNet_Peering_Routing]] — Connecting VNets and routing traffic
> - [[NAT_Gateway]] — Outbound internet connectivity for VNet resources
> - [[Private_Endpoints]] — Private IP access to PaaS services in your VNet
> - [[NSG_ASG_Firewall]] — Securing traffic at subnet/NIC level
> - [[Azure_Virtual_Network_Manager]] — Managing VNets at scale

---

## 1. Key Concepts & Definitions

### What is Azure Virtual Network (VNet)?

**Azure Virtual Network (VNet)** is the fundamental building block for private networking in Azure. It provides an isolated, secure environment where Azure resources can communicate with each other, the internet, and on-premises networks. VNets are similar to traditional networks in your own data center but offer the scalability, availability, and isolation benefits of Azure infrastructure.

### Why VNets Matter for AZ-700

Understanding VNets is foundational to almost every Azure networking topic. VNets are required for:
- Virtual Machine deployment
- VPN and ExpressRoute connectivity
- Load balancers and Application Gateways
- Azure Kubernetes Service (AKS)
- Private Endpoints and Service Endpoints
- Azure Firewall and network security

### Core Terminology

| Term | Definition |
|------|------------|
| **Virtual Network (VNet)** | Logically isolated network in Azure that enables resources to communicate securely |
| **Subnet** | Logical segment within a VNet used to organize and secure resources |
| **Address Space** | The CIDR block(s) assigned to a VNet defining available IP ranges |
| **CIDR** | Classless Inter-Domain Routing notation (e.g., 10.0.0.0/16) |
| **Private IP** | Non-routable IP assigned from subnet range to Azure resources |
| **Public IP** | Internet-routable IP address for external connectivity |
| **NIC** | Network Interface Card connecting a resource to a subnet |
| **Delegation** | Assigning a subnet to a specific Azure service |
| **Service Endpoint** | Secure, optimized path to Azure PaaS services |
| **Private Endpoint** | Private IP address for PaaS services within VNet |

### VNet Characteristics

| Characteristic | Description |
|----------------|-------------|
| **Scope** | Regional (bound to a single Azure region) |
| **Isolation** | Complete network isolation from other VNets by default |
| **Address Space** | Supports multiple non-overlapping CIDR blocks |
| **DNS** | Built-in Azure DNS or custom DNS servers |
| **Subscription** | Lives within a single subscription |
| **Traffic** | Free ingress/egress within same VNet |

---

## 2. Architecture Overview

### VNet with Multiple Subnets

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                      AZURE VIRTUAL NETWORK ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│                             VNET: 10.0.0.0/16                                       │
│                        (65,536 addresses available)                                  │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                        APPLICATION TIER SUBNETS                              │   │
│  │                                                                              │   │
│  │  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────┐  │   │
│  │  │   snet-frontend      │  │   snet-backend       │  │   snet-database  │  │   │
│  │  │   10.0.1.0/24        │  │   10.0.2.0/24        │  │   10.0.3.0/24    │  │   │
│  │  │   (251 usable)       │  │   (251 usable)       │  │   (251 usable)   │  │   │
│  │  │                      │  │                      │  │                  │  │   │
│  │  │ ┌────┐ ┌────┐ ┌────┐│  │ ┌────┐ ┌────┐ ┌────┐│  │ ┌────┐ ┌────┐   │  │   │
│  │  │ │Web │ │Web │ │Web ││  │ │API │ │API │ │API ││  │ │SQL │ │SQL │   │  │   │
│  │  │ │VM1 │ │VM2 │ │VM3 ││  │ │VM1 │ │VM2 │ │VM3 ││  │ │Pri │ │Sec │   │  │   │
│  │  │ └────┘ └────┘ └────┘│  │ └────┘ └────┘ └────┘│  │ └────┘ └────┘   │  │   │
│  │  │                      │  │                      │  │                  │  │   │
│  │  │    [NSG-Frontend]    │  │    [NSG-Backend]     │  │  [NSG-Database]  │  │   │
│  │  └──────────────────────┘  └──────────────────────┘  └──────────────────┘  │   │
│  │                                                                              │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                        INFRASTRUCTURE SUBNETS                                │   │
│  │                                                                              │   │
│  │  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────┐  │   │
│  │  │   GatewaySubnet      │  │ AzureBastionSubnet   │  │AzureFirewallSubnet│ │   │
│  │  │   10.0.255.0/27      │  │   10.0.254.0/26      │  │   10.0.253.0/26  │  │   │
│  │  │   (27 usable)        │  │   (59 usable)        │  │   (59 usable)    │  │   │
│  │  │                      │  │                      │  │                  │  │   │
│  │  │ ┌────────────────┐  │  │ ┌────────────────┐   │  │ ┌──────────────┐ │  │   │
│  │  │ │ VPN Gateway    │  │  │ │ Azure Bastion  │   │  │ │Azure Firewall│ │  │   │
│  │  │ │ or             │  │  │ │                │   │  │ │              │ │  │   │
│  │  │ │ ExpressRoute GW│  │  │ │ Secure RDP/SSH │   │  │ │  Inspection  │ │  │   │
│  │  │ └────────────────┘  │  │ └────────────────┘   │  │ └──────────────┘ │  │   │
│  │  │                      │  │                      │  │                  │  │   │
│  │  │  ⚠️ No NSG allowed   │  │  Name MUST be exact  │  │ Name MUST be    │  │   │
│  │  └──────────────────────┘  └──────────────────────┘  │ exact           │  │   │
│  │                                                       └──────────────────┘  │   │
│  │  ┌──────────────────────┐  ┌──────────────────────┐                         │   │
│  │  │ RouteServerSubnet    │  │snet-webapp-integration│                        │   │
│  │  │   10.0.252.0/27      │  │   10.0.10.0/24       │                         │   │
│  │  │   (27 usable)        │  │   (251 usable)       │                         │   │
│  │  │                      │  │                      │                         │   │
│  │  │ ┌────────────────┐  │  │ [Delegated to        │                         │   │
│  │  │ │ Route Server   │  │  │  Microsoft.Web/      │                         │   │
│  │  │ │                │  │  │  serverFarms]        │                         │   │
│  │  │ └────────────────┘  │  │                      │                         │   │
│  │  └──────────────────────┘  └──────────────────────┘                         │   │
│  └──────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### IP Address Reservation in Subnets

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    AZURE RESERVED IP ADDRESSES IN EVERY SUBNET                       │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   Example Subnet: 10.0.1.0/24 (256 addresses total)                                 │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │  RESERVED BY AZURE (5 addresses - CANNOT be assigned to resources)          │  │
│   │                                                                              │  │
│   │  ┌─────────────┬───────────────────────────────────────────────────────┐   │  │
│   │  │ IP Address  │ Purpose                                                │   │  │
│   │  ├─────────────┼───────────────────────────────────────────────────────┤   │  │
│   │  │ 10.0.1.0    │ Network address (identifies the subnet)               │   │  │
│   │  │ 10.0.1.1    │ Default gateway (first-hop router)                    │   │  │
│   │  │ 10.0.1.2    │ Azure DNS mapping (maps to Azure-provided DNS)        │   │  │
│   │  │ 10.0.1.3    │ Azure DNS mapping (secondary)                         │   │  │
│   │  │ 10.0.1.255  │ Network broadcast address                             │   │  │
│   │  └─────────────┴───────────────────────────────────────────────────────┘   │  │
│   │                                                                              │  │
│   │  USABLE FOR RESOURCES: 10.0.1.4 through 10.0.1.254 = 251 addresses          │  │
│   │                                                                              │  │
│   └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   ⚠️  EXAM FORMULA: Usable IPs = 2^(32-prefix) - 5                                 │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │  QUICK REFERENCE TABLE                                                       │  │
│   │                                                                              │  │
│   │  Subnet Size │ Total IPs │ Reserved │ Usable │ Common Use                   │  │
│   │  ────────────┼───────────┼──────────┼────────┼──────────────────────────── │  │
│   │  /30         │     4     │    5     │   ❌   │ Not usable in Azure          │  │
│   │  /29         │     8     │    5     │    3   │ Smallest possible subnet     │  │
│   │  /28         │    16     │    5     │   11   │ Small test environments      │  │
│   │  /27         │    32     │    5     │   27   │ GatewaySubnet minimum        │  │
│   │  /26         │    64     │    5     │   59   │ Bastion/Firewall subnets     │  │
│   │  /25         │   128     │    5     │  123   │ Medium workloads             │  │
│   │  /24         │   256     │    5     │  251   │ Standard workload subnet     │  │
│   │  /23         │   512     │    5     │  507   │ Large deployments            │  │
│   │  /22         │  1,024    │    5     │ 1,019  │ AKS clusters                 │  │
│   │  /16         │ 65,536    │    5     │65,531  │ Large enterprise VNet        │  │
│   │                                                                              │  │
│   └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Special Subnet Requirements

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        SPECIAL SUBNET REQUIREMENTS                                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ⚠️  EXAM CRITICAL: These subnet names are EXACT and case-sensitive!              │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │  Subnet Name                    │ Min Size │ Notes                          │  │
│   │  ──────────────────────────────┼──────────┼───────────────────────────────│  │
│   │  GatewaySubnet                  │ /29      │ For VPN/ExpressRoute GW        │  │
│   │                                 │ (/27 rec)│ ⚠️ NSGs NOT allowed            │  │
│   │  ──────────────────────────────┼──────────┼───────────────────────────────│  │
│   │  AzureBastionSubnet             │ /26      │ For Azure Bastion              │  │
│   │                                 │          │ Must be EXACTLY this name      │  │
│   │  ──────────────────────────────┼──────────┼───────────────────────────────│  │
│   │  AzureFirewallSubnet            │ /26      │ For Azure Firewall             │  │
│   │                                 │          │ Must be EXACTLY this name      │  │
│   │  ──────────────────────────────┼──────────┼───────────────────────────────│  │
│   │  AzureFirewallManagementSubnet  │ /26      │ For Azure Firewall forced      │  │
│   │                                 │          │ tunneling scenarios            │  │
│   │  ──────────────────────────────┼──────────┼───────────────────────────────│  │
│   │  RouteServerSubnet              │ /27      │ For Azure Route Server         │  │
│   │                                 │          │ Must be EXACTLY this name      │  │
│   │  ──────────────────────────────┼──────────┼───────────────────────────────│  │
│   │  AzureApplicationGatewaySubnet  │ /26      │ For Application Gateway v2     │  │
│   │                                 │ (rec)    │ Name is flexible but dedicated │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Address Space Planning

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                          IP ADDRESS SPACE PLANNING                                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   SUPPORTED RFC 1918 PRIVATE ADDRESS RANGES:                                        │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │  Range              │ CIDR          │ Total Addresses │ Common Use          │  │
│   │  ───────────────────┼───────────────┼─────────────────┼─────────────────── │  │
│   │  10.0.0.0-          │ 10.0.0.0/8    │ 16,777,216      │ Large enterprises  │  │
│   │  10.255.255.255     │               │                 │ Hub-spoke designs  │  │
│   │  ───────────────────┼───────────────┼─────────────────┼─────────────────── │  │
│   │  172.16.0.0-        │ 172.16.0.0/12 │ 1,048,576       │ Medium deployments │  │
│   │  172.31.255.255     │               │                 │                    │  │
│   │  ───────────────────┼───────────────┼─────────────────┼─────────────────── │  │
│   │  192.168.0.0-       │ 192.168.0.0/16│ 65,536          │ Small deployments  │  │
│   │  192.168.255.255    │               │                 │ Lab/Test           │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   ALSO SUPPORTED (CGNAT Range):                                                     │
│   • 100.64.0.0/10 (4,194,304 addresses)                                             │
│                                                                                      │
│   ❌ UNSUPPORTED RANGES:                                                            │
│   • 224.0.0.0/4 (Multicast)                                                         │
│   • 255.255.255.255/32 (Broadcast)                                                  │
│   • 127.0.0.0/8 (Loopback)                                                          │
│   • 169.254.0.0/16 (Link-local APIPA)                                               │
│   • 168.63.129.16/32 (Azure internal DNS/health probe)                              │
│                                                                                      │
│   HUB-SPOKE IP ALLOCATION EXAMPLE:                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                                                                              │  │
│   │   Hub VNet:        10.0.0.0/16      │  Spoke 1:     10.1.0.0/16             │  │
│   │   ├─ snet-fw       10.0.0.0/26      │  ├─ snet-app  10.1.1.0/24             │  │
│   │   ├─ snet-bastion  10.0.1.0/26      │  ├─ snet-db   10.1.2.0/24             │  │
│   │   ├─ GatewaySubnet 10.0.255.0/27    │  └─ snet-mgmt 10.1.3.0/24             │  │
│   │   └─ snet-mgmt     10.0.2.0/24      │                                       │  │
│   │                                      │  Spoke 2:     10.2.0.0/16             │  │
│   │   On-Prem:         192.168.0.0/16   │  ├─ snet-web  10.2.1.0/24             │  │
│   │                                      │  └─ snet-api  10.2.2.0/24             │  │
│   │                                                                              │  │
│   │   ⚠️ Rule: VNet address spaces must NOT overlap with peered VNets           │  │
│   │      or on-premises networks!                                                │  │
│   │                                                                              │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Configuration Best Practices

### Create a VNet with Multiple Subnets

```powershell
# Variables
$rgName = "rg-networking-prod"
$location = "eastus"
$vnetName = "vnet-hub-eus-001"
$vnetAddressSpace = "10.0.0.0/16"

# Create Resource Group
New-AzResourceGroup -Name $rgName -Location $location

# Define subnet configurations
$subnets = @()

# Application subnets
$subnets += New-AzVirtualNetworkSubnetConfig `
    -Name "snet-frontend" `
    -AddressPrefix "10.0.1.0/24"

$subnets += New-AzVirtualNetworkSubnetConfig `
    -Name "snet-backend" `
    -AddressPrefix "10.0.2.0/24"

$subnets += New-AzVirtualNetworkSubnetConfig `
    -Name "snet-database" `
    -AddressPrefix "10.0.3.0/24"

# Infrastructure subnets (with EXACT names)
$subnets += New-AzVirtualNetworkSubnetConfig `
    -Name "GatewaySubnet" `
    -AddressPrefix "10.0.255.0/27"  # /27 recommended for VPN

$subnets += New-AzVirtualNetworkSubnetConfig `
    -Name "AzureBastionSubnet" `
    -AddressPrefix "10.0.254.0/26"  # /26 required

$subnets += New-AzVirtualNetworkSubnetConfig `
    -Name "AzureFirewallSubnet" `
    -AddressPrefix "10.0.253.0/26"  # /26 required

# Create the VNet with all subnets
$vnet = New-AzVirtualNetwork `
    -Name $vnetName `
    -ResourceGroupName $rgName `
    -Location $location `
    -AddressPrefix $vnetAddressSpace `
    -Subnet $subnets

Write-Host "VNet created: $($vnet.Name)"
Write-Host "Address Space: $($vnet.AddressSpace.AddressPrefixes)"
Write-Host "Subnets:"
$vnet.Subnets | ForEach-Object { 
    Write-Host "  - $($_.Name): $($_.AddressPrefix)" 
}
```

### Add Multiple Address Spaces to Existing VNet

```powershell
# Get existing VNet
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName

# Add additional address space
$vnet.AddressSpace.AddressPrefixes.Add("10.100.0.0/16")
$vnet | Set-AzVirtualNetwork

# Verify
Write-Host "Updated Address Spaces:"
$vnet.AddressSpace.AddressPrefixes | ForEach-Object { Write-Host "  - $_" }
```

### Add Subnet to Existing VNet

```powershell
# Get VNet
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName

# Add new subnet
Add-AzVirtualNetworkSubnetConfig `
    -Name "snet-aks" `
    -VirtualNetwork $vnet `
    -AddressPrefix "10.0.10.0/22"  # 1019 usable for AKS

# Apply changes
$vnet | Set-AzVirtualNetwork

Write-Host "Subnet added: snet-aks (10.0.10.0/22)"
```

### Create Subnet with Delegation

```powershell
# Get VNet
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName

# Create delegation for App Service VNet Integration
$delegation = New-AzDelegation `
    -Name "delegation-webapp" `
    -ServiceName "Microsoft.Web/serverFarms"

# Add subnet with delegation
Add-AzVirtualNetworkSubnetConfig `
    -Name "snet-webapp-integration" `
    -VirtualNetwork $vnet `
    -AddressPrefix "10.0.20.0/24" `
    -Delegation $delegation

$vnet | Set-AzVirtualNetwork

Write-Host "Delegated subnet created for App Service integration"
```

### Create Public IP Address (Standard SKU)

```powershell
# Create zone-redundant Standard public IP
$publicIp = New-AzPublicIpAddress `
    -Name "pip-appgw-prod-001" `
    -ResourceGroupName $rgName `
    -Location $location `
    -Sku "Standard" `
    -AllocationMethod "Static" `
    -Zone 1, 2, 3 `
    -DomainNameLabel "myapp-prod"

Write-Host "Public IP created: $($publicIp.IpAddress)"
Write-Host "FQDN: $($publicIp.DnsSettings.Fqdn)"
```

### Create Public IP Prefix

```powershell
# Create /28 prefix (16 contiguous public IPs)
$ipPrefix = New-AzPublicIpPrefix `
    -Name "ippre-nat-prod" `
    -ResourceGroupName $rgName `
    -Location $location `
    -PrefixLength 28 `
    -Sku "Standard" `
    -Zone 1, 2, 3

Write-Host "Public IP Prefix created: $($ipPrefix.IPPrefix)"

# Create individual public IPs from the prefix
for ($i = 1; $i -le 3; $i++) {
    New-AzPublicIpAddress `
        -Name "pip-from-prefix-00$i" `
        -ResourceGroupName $rgName `
        -Location $location `
        -Sku "Standard" `
        -AllocationMethod "Static" `
        -PublicIpPrefix $ipPrefix
    
    Write-Host "Created: pip-from-prefix-00$i"
}
```

### Assign Static Private IP to VM NIC

```powershell
# Get the VM's network interface
$nic = Get-AzNetworkInterface -Name "vm-web-001-nic" -ResourceGroupName $rgName

# Change from Dynamic to Static
$nic.IpConfigurations[0].PrivateIpAllocationMethod = "Static"
$nic.IpConfigurations[0].PrivateIpAddress = "10.0.1.10"

# Apply changes
$nic | Set-AzNetworkInterface

Write-Host "Static IP assigned: 10.0.1.10"
```

### Verify VNet and Subnet Configuration

```powershell
# Get VNet details
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName

# Display comprehensive info
Write-Host "VNet: $($vnet.Name)"
Write-Host "Location: $($vnet.Location)"
Write-Host "Address Spaces:"
$vnet.AddressSpace.AddressPrefixes | ForEach-Object { Write-Host "  - $_" }
Write-Host ""
Write-Host "Subnets:"
$vnet.Subnets | ForEach-Object {
    $usable = [math]::Pow(2, 32 - [int]($_.AddressPrefix.Split('/')[1])) - 5
    Write-Host "  - $($_.Name)"
    Write-Host "    Address: $($_.AddressPrefix)"
    Write-Host "    Usable IPs: $usable"
    if ($_.Delegations) {
        Write-Host "    Delegation: $($_.Delegations[0].ServiceName)"
    }
    Write-Host ""
}
```

---

## 4. Comparison Tables

### Public IP SKU Comparison

| Feature | Basic SKU | Standard SKU |
|---------|-----------|--------------|
| **Allocation** | Dynamic or Static | Static only |
| **Availability Zones** | ❌ Not supported | ✅ Zone-redundant or Zonal |
| **Security** | Open by default | Secure by default (NSG required) |
| **Routing** | Basic | Global (cross-region LB support) |
| **Redundancy** | Single instance | Zone-redundant by default |
| **Load Balancer** | Basic LB | Standard LB |
| **Future** | Being retired | Recommended for production |
| **Price** | Lower | Higher (but more features) |

### Private IP Allocation Methods

| Method | Behavior | Best For |
|--------|----------|----------|
| **Dynamic** | Assigned from DHCP lease, can change on VM stop/deallocate | General workloads, non-critical |
| **Static** | Reserved in subnet, never changes | DNS servers, Domain Controllers, Load Balancers, Apps needing fixed IP |

### Subnet Delegation Options

| Service | Delegation Namespace | Dedicated Subnet? |
|---------|---------------------|-------------------|
| App Service VNet Integration | Microsoft.Web/serverFarms | No |
| Azure Container Instances | Microsoft.ContainerInstance/containerGroups | No |
| SQL Managed Instance | Microsoft.Sql/managedInstances | Yes (dedicated) |
| Azure NetApp Files | Microsoft.NetApp/volumes | Yes (dedicated) |
| API Management | Microsoft.ApiManagement/service | No |
| Azure Databricks | Microsoft.Databricks/workspaces | No |
| HDInsight | Microsoft.HDInsight/clusters | No |

### Service Endpoint vs Private Endpoint

| Aspect | Service Endpoint | Private Endpoint |
|--------|-----------------|------------------|
| **Connectivity** | Over Microsoft backbone | Private IP in your VNet |
| **Source IP** | VNet source IP (private) | Private IP |
| **DNS** | Public DNS | Private DNS zone required |
| **On-Premises Access** | Requires additional config | Works via VPN/ExpressRoute |
| **Cost** | Free | Per-hour + data processing |
| **Security** | Service firewall rules | NSGs, more granular |
| **Scope** | Regional | Can be cross-region |

---

## 5. Exam Tips & Gotchas

### Critical Points to Memorize

1. **5 Reserved IPs per subnet** — Network (.0), Gateway (.1), DNS (.2 and .3), Broadcast (last)

2. **Subnet naming is EXACT** — GatewaySubnet, AzureBastionSubnet, AzureFirewallSubnet (case-sensitive)

3. **Standard SKU is secure by default** — No inbound traffic until NSG rules allow it

4. **GatewaySubnet has NO NSG** — NSGs are not supported on GatewaySubnet

5. **VNet is regional** — A VNet cannot span multiple regions (use peering)

6. **Address spaces cannot overlap** — With peered VNets or on-premises networks

7. **Subnet cannot be resized with resources** — Must remove all resources first

8. **Minimum subnet is /29** — Gives only 3 usable IPs (5 reserved from 8)

9. **/26 required for Bastion and Firewall** — Don't confuse with /27 for Gateway

10. **Delegation is one-to-one** — One delegation per subnet, one subnet per delegation (for dedicated services)

### Common Exam Scenarios

| Scenario | Answer |
|----------|--------|
| "Need 50 usable IP addresses" | Use /26 (59 usable) — /27 only gives 27 |
| "Which IP is the default gateway?" | Always .1 (e.g., 10.0.1.1) |
| "Deploy Azure Bastion" | Create AzureBastionSubnet with /26 minimum |
| "Deploy VPN Gateway" | Create GatewaySubnet with /27 or larger |
| "VMs can't communicate between subnets" | Check NSG rules — VNet traffic allowed by default |
| "Cannot add address space to peered VNet" | Disconnect peering, add space, reconnect |
| "Basic public IP with Standard LB" | Not compatible — Standard LB requires Standard PIP |
| "Need zone-redundant public IP" | Use Standard SKU |

### Common Mistakes to Avoid

1. **Using Basic public IP for production** — Always use Standard for zone redundancy and security
2. **Applying NSG to GatewaySubnet** — Not supported, will fail
3. **Overlapping address spaces** — Breaks peering and hybrid connectivity
4. **Wrong subnet names** — "Gatewaysubnet" ≠ "GatewaySubnet"
5. **Undersizing subnets** — Always plan for growth; can't resize easily
6. **Forgetting 5 reserved IPs** — /28 gives 11 usable, not 16
7. **Using Dynamic IP for DNS servers** — Always use Static for infrastructure

### Key Limits to Remember

| Resource | Limit |
|----------|-------|
| VNets per subscription per region | 1,000 |
| Subnets per VNet | 3,000 |
| Address spaces per VNet | 100 |
| Private IPs per NIC | 256 |
| Public IPs per subscription | 1,000 (default) |
| NICs per VM | Depends on VM size |
| VNet peerings per VNet | 500 |

---

## 6. Hands-On Lab Suggestions

### Lab 1: Create Hub-Spoke VNet Topology

```powershell
# Create Hub VNet
$hubSubnets = @()
$hubSubnets += New-AzVirtualNetworkSubnetConfig -Name "AzureFirewallSubnet" -AddressPrefix "10.0.0.0/26"
$hubSubnets += New-AzVirtualNetworkSubnetConfig -Name "AzureBastionSubnet" -AddressPrefix "10.0.1.0/26"
$hubSubnets += New-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -AddressPrefix "10.0.255.0/27"
$hubSubnets += New-AzVirtualNetworkSubnetConfig -Name "snet-shared" -AddressPrefix "10.0.2.0/24"

$hubVnet = New-AzVirtualNetwork `
    -Name "vnet-hub" `
    -ResourceGroupName "rg-network-lab" `
    -Location "eastus" `
    -AddressPrefix "10.0.0.0/16" `
    -Subnet $hubSubnets

# Create Spoke 1 VNet
$spoke1Subnet = New-AzVirtualNetworkSubnetConfig -Name "snet-workload" -AddressPrefix "10.1.1.0/24"
$spoke1Vnet = New-AzVirtualNetwork `
    -Name "vnet-spoke1" `
    -ResourceGroupName "rg-network-lab" `
    -Location "eastus" `
    -AddressPrefix "10.1.0.0/16" `
    -Subnet $spoke1Subnet

# Create Spoke 2 VNet
$spoke2Subnet = New-AzVirtualNetworkSubnetConfig -Name "snet-workload" -AddressPrefix "10.2.1.0/24"
$spoke2Vnet = New-AzVirtualNetwork `
    -Name "vnet-spoke2" `
    -ResourceGroupName "rg-network-lab" `
    -Location "eastus" `
    -AddressPrefix "10.2.0.0/16" `
    -Subnet $spoke2Subnet

Write-Host "Hub-Spoke topology created"
Write-Host "Hub: 10.0.0.0/16, Spoke1: 10.1.0.0/16, Spoke2: 10.2.0.0/16"
```

### Lab 2: Calculate Usable IPs

```powershell
# Function to calculate usable IPs
function Get-UsableIPs {
    param([string]$CIDR)
    $prefix = [int]($CIDR.Split('/')[1])
    $total = [math]::Pow(2, 32 - $prefix)
    $usable = $total - 5
    
    return [PSCustomObject]@{
        CIDR = $CIDR
        TotalIPs = $total
        Reserved = 5
        Usable = $usable
    }
}

# Test various subnet sizes
@("/29", "/28", "/27", "/26", "/25", "/24", "/23", "/22") | ForEach-Object {
    Get-UsableIPs -CIDR "10.0.0.0$_"
} | Format-Table -AutoSize
```

### Lab 3: Verify Subnet Delegation

```powershell
# Create subnet with delegation
$vnet = Get-AzVirtualNetwork -Name "vnet-lab" -ResourceGroupName "rg-network-lab"

$delegation = New-AzDelegation -Name "webapp-delegation" -ServiceName "Microsoft.Web/serverFarms"

Add-AzVirtualNetworkSubnetConfig `
    -Name "snet-webapp" `
    -VirtualNetwork $vnet `
    -AddressPrefix "10.0.50.0/24" `
    -Delegation $delegation

$vnet | Set-AzVirtualNetwork

# Verify delegation
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "snet-webapp" -VirtualNetwork $vnet
Write-Host "Subnet: $($subnet.Name)"
Write-Host "Delegation: $($subnet.Delegations[0].ServiceName)"
```

---

## 7. Cross-Service Relationships

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         VNET INTEGRATION MAP                                         │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    RESOURCES THAT DEPLOY INTO VNETS                         │   │
│   │                                                                             │   │
│   │  Virtual Machines      → Deploy NIC into subnet                            │   │
│   │  VMSS                   → Deploy NICs into subnet(s)                       │   │
│   │  AKS                    → Nodes and pods get IPs from subnet               │   │
│   │  Application Gateway   → Requires dedicated subnet                        │   │
│   │  Azure Firewall        → Requires AzureFirewallSubnet                     │   │
│   │  Azure Bastion         → Requires AzureBastionSubnet                      │   │
│   │  VPN Gateway           → Requires GatewaySubnet                           │   │
│   │  ExpressRoute Gateway  → Requires GatewaySubnet                           │   │
│   │  Load Balancer (Internal) → Gets private IP from subnet                   │   │
│   │  Private Endpoints     → Get private IP from subnet                       │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    SERVICES THAT CONNECT TO VNETS                           │   │
│   │                                                                             │   │
│   │  App Service           → VNet Integration via delegated subnet             │   │
│   │  Azure Functions       → VNet Integration (Premium plan)                   │   │
│   │  Azure Container       → ACI in VNet via delegation                        │   │
│   │    Instances                                                               │   │
│   │  SQL Managed Instance  → Requires dedicated delegated subnet              │   │
│   │  Azure NetApp Files    → Requires dedicated delegated subnet              │   │
│   │  API Management        → VNet integration (internal/external)             │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    VNET CONNECTIVITY OPTIONS                                │   │
│   │                                                                             │   │
│   │  VNet Peering          → Connect VNets (same or different regions)         │   │
│   │  VPN Gateway           → Connect to on-premises via IPsec                  │   │
│   │  ExpressRoute          → Private connection to on-premises                 │   │
│   │  Virtual WAN           → Managed hub for branch/VNet connectivity          │   │
│   │  Service Endpoints     → Secure path to Azure PaaS                         │   │
│   │  Private Endpoints     → Private IP for Azure PaaS in VNet                 │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## BYOIP (Bring Your Own IP) / Custom IP Prefix

> **Exam Relevance**: The AZ-700 study guide explicitly lists "plan and implement public IP addressing, including BYOIP public IP addresses" under core networking. BYOIP lets you bring your own public IP ranges into Azure.

### What Is BYOIP?

BYOIP allows you to bring your own **public IP address ranges** (IPv4 or IPv6) into Azure and use them as Azure Public IP resources. Azure advertises these ranges from Microsoft's global network (AS 8075).

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     BYOIP Onboarding Process                            │
│                                                                         │
│   Phase 1: VALIDATION          Phase 2: PROVISION       Phase 3: USE   │
│   ┌──────────────────┐        ┌──────────────────┐    ┌──────────────┐ │
│   │ 1. Create ROA     │        │ 4. Create Custom │    │ 7. Create    │ │
│   │    at RIR         │        │    IP Prefix in  │    │    Public IP │ │
│   │    (Origin AS     │───────▶│    Azure         │───▶│    from      │ │
│   │     8075)         │        │                  │    │    prefix    │ │
│   │                   │        │ 5. Provision     │    │              │ │
│   │ 2. Create signed  │        │    (~30 min)     │    │ 8. Assign   │ │
│   │    message with   │        │                  │    │    to Azure  │ │
│   │    RPKI cert      │        │ 6. Commission    │    │    resources │ │
│   │                   │        │    (advertise)   │    │              │ │
│   │ 3. Validate       │        │                  │    │              │ │
│   │    ownership      │        │                  │    │              │ │
│   └──────────────────┘        └──────────────────┘    └──────────────┘ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Key Characteristics

| Property | Detail |
|----------|--------|
| **Minimum Prefix Size** | IPv4: **/24**, IPv6: **/48** |
| **ROA Requirement** | Route Origin Authorization at your RIR, Origin AS = **8075** |
| **RPKI** | Signed message required to prove ownership |
| **Provisioning Time** | ~30 minutes |
| **Scope Types** | **Global** (advertised from all Azure regions) or **Regional** (single region) |
| **Supported RIRs** | ARIN, RIPE, APNIC, AFRINIC, LACNIC |
| **Azure Advertising** | Microsoft advertises your prefix via BGP AS 8075 |
| **IP Type** | Creates Standard SKU Public IPs |

### Three-Phase Onboarding Process

#### Phase 1: Validation (at your RIR)

```powershell
# At your RIR (e.g., ARIN, RIPE):
# 1. Create ROA (Route Origin Authorization)
#    - Prefix: your IP range (e.g., 203.0.113.0/24)
#    - Origin AS: 8075 (Microsoft)
#    - Max Length: /24 (or more specific)

# 2. Generate a signed message using your RPKI certificate
#    This proves you own the IP range
#    Format: subscription-id|serial-number
#    Sign with your X.509 certificate from the RIR

# 3. Prepare the signed message for Azure CLI/PowerShell
$signedMessage = "base64-encoded-signed-message"
```

#### Phase 2: Provision in Azure

```powershell
# Step 1: Create a Custom IP Prefix resource (Global)
$prefix = New-AzCustomIpPrefix -Name "myByoipPrefix" `
    -ResourceGroupName "MyRG" `
    -Location "eastus2" `
    -Cidr "203.0.113.0/24" `
    -SignedMessage $signedMessage `
    -AuthorizationMessage "subscription-guid|serial-number" `
    -CustomIpPrefixParent $null  # null for global prefix

# Step 2: Wait for provisioning (~30 minutes)
# Check status:
Get-AzCustomIpPrefix -Name "myByoipPrefix" -ResourceGroupName "MyRG" | 
    Select-Object Name, ProvisioningState, CommissionedState

# ProvisioningState transitions: Provisioning → Provisioned
# CommissionedState: Decommissioned → Commissioning → Commissioned

# Step 3: Commission the prefix (start advertising from Azure)
Update-AzCustomIpPrefix -Name "myByoipPrefix" -ResourceGroupName "MyRG" `
    -Commission
# This tells Azure to begin advertising the prefix via BGP (AS 8075)
```

#### Phase 3: Create Public IPs from the Prefix

```powershell
# Create a Public IP Prefix (carve out a range)
$pipPrefix = New-AzPublicIpPrefix -Name "myByoipPublicPrefix" `
    -ResourceGroupName "MyRG" `
    -Location "eastus2" `
    -PrefixLength 28 `
    -CustomIpPrefix $prefix

# Create individual Public IPs from the BYOIP range
$publicIp = New-AzPublicIpAddress -Name "myByoipPublicIP" `
    -ResourceGroupName "MyRG" `
    -Location "eastus2" `
    -AllocationMethod Static `
    -Sku Standard `
    -PublicIpPrefix $pipPrefix

# Assign to a resource (e.g., Load Balancer frontend)
# The public IP now uses YOUR IP range, advertised by Microsoft
```

### Global vs Regional Custom IP Prefix

| Feature | Global Custom IP Prefix | Regional Custom IP Prefix |
|---------|------------------------|--------------------------|
| **Scope** | Advertised from ALL Azure regions | Single Azure region |
| **Use Case** | Anycast, multi-region services | Regional workloads |
| **Minimum Size** | /24 (IPv4) / /48 (IPv6) | /28 (derived from global parent) |
| **Parent-Child** | Parent prefix | Child of a global prefix |
| **Advertisement** | Global BGP from all Microsoft PoPs | Regional BGP |

### Exam Tips — BYOIP

> [!warning] Critical Exam Points
> 1. **Minimum /24 for IPv4** — Cannot bring a range smaller than /24
> 2. **ROA must specify AS 8075** — Microsoft's ASN, NOT your own
> 3. **RPKI signed message required** — Proves IP ownership cryptographically
> 4. **~30 minutes provisioning** — Not instant
> 5. **Commission = start advertising** — Decommission to stop advertising
> 6. **Standard SKU only** — BYOIP creates Standard SKU Public IPs
> 7. **Cannot use with Basic SKU** — No Basic PIP support
> 8. **Three phases**: Validation (RIR) → Provision (Azure) → Commission (BGP advertise)
> 9. **Global prefix is parent** → Regional prefixes are children carved from it
> 10. **If exam asks "how to use existing public IPs in Azure"** → Answer is BYOIP / Custom IP Prefix

---

## Quick Reference Card

| Item | Value/Requirement |
|------|-------------------|
| **Reserved IPs per subnet** | 5 (.0, .1, .2, .3, last) |
| **Minimum subnet** | /29 (3 usable) |
| **GatewaySubnet size** | /27 minimum recommended |
| **Bastion/Firewall subnet** | /26 minimum required |
| **Standard PIP** | Secure by default, zone-redundant |
| **VNet scope** | Regional, subscription-bound |
| **Max subnets per VNet** | 3,000 |
| **Max address spaces** | 100 per VNet |
| **Peering limit** | 500 per VNet |

---

## Architecture Diagram File

📂 Open [VNet_Subnets_Architecture.drawio](VNet_Subnets_Architecture.drawio) in VS Code with the Draw.io Integration extension.

---

## Additional Resources

- [Azure Virtual Network Documentation](https://learn.microsoft.com/en-us/azure/virtual-network/)
- [Plan Virtual Networks](https://learn.microsoft.com/en-us/azure/virtual-network/virtual-network-vnet-plan-design-arm)
- [IP Addressing](https://learn.microsoft.com/en-us/azure/virtual-network/ip-services/)
- [Subnet Delegation](https://learn.microsoft.com/en-us/azure/virtual-network/subnet-delegation-overview)
