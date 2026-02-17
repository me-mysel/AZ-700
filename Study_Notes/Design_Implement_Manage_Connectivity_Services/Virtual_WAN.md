---
tags:
  - AZ-700
  - azure/networking
  - domain/connectivity
  - virtual-wan
  - vwan
  - virtual-hub
  - routing-intent
  - secured-hub
  - any-to-any
  - scale-units
aliases:
  - Virtual WAN
  - vWAN
  - Azure Virtual WAN
created: 2025-01-01
updated: 2026-02-07
---

# Azure Virtual WAN

> [!info] Related Notes
> - [[VPN_Gateway]] — VPN connections to Virtual WAN hubs
> - [[ExpressRoute]] — ExpressRoute connections to Virtual WAN hubs
> - [[Azure_Firewall_and_Firewall_Manager]] — Secured virtual hubs (Firewall Manager)
> - [[VNet_Peering_Routing]] — Traditional hub-spoke vs Virtual WAN
> - [[Azure_Route_Server]] — Alternative for smaller deployments
> - [[Point_to_Site_VPN]] — User VPN (P2S) in Virtual WAN

## AZ-700 Exam Domain: Design and Implement Connectivity Services (20-25%)

---

## 1. Key Concepts & Definitions

### What is Azure Virtual WAN?

**Azure Virtual WAN** is a comprehensive networking service that brings together many networking, security, and routing functionalities into a single operational interface. It provides optimized and automated branch-to-branch connectivity through Azure's global backbone network, enabling organizations to build large-scale, globally distributed network architectures with minimal configuration complexity.

Virtual WAN acts as a **hub for your hubs** — it's a global resource that contains one or more Virtual Hubs deployed across different Azure regions. These hubs automatically mesh together, providing any-to-any transit connectivity without the need for complex peering configurations or user-defined routes.

### Core Components

| Term | Definition |
|------|------------|
| **Virtual WAN** | Top-level global resource containing hubs, connections, and configurations. One per organization is typical. |
| **Virtual Hub** | Microsoft-managed VNet serving as the central connectivity point. Requires **/24 minimum** address space. You cannot deploy your own resources into this VNet. |
| **Hub VNet Connection** | Connects spoke VNets to a Virtual Hub. Replaces traditional VNet peering in hub-spoke architectures. |
| **VPN Site** | Definition of a branch office location for S2S VPN, including device IP, address space, and BGP settings. |
| **VPN Connection** | The actual IPsec/IKE tunnel between the hub's VPN gateway and a VPN Site. |
| **ExpressRoute Connection** | Links an ExpressRoute circuit to the hub's ExpressRoute gateway. |
| **Secured Virtual Hub** | A Virtual Hub with Azure Firewall or third-party security provider deployed. Managed via Azure Firewall Manager. |
| **Routing Intent** | Simplified routing configuration that automatically routes internet and/or private traffic through a security solution in the hub. |
| **Hub-to-Hub Connection** | Automatic connectivity between Virtual Hubs within the same Virtual WAN (Standard SKU only). |
| **Route Table** | Contains routes that determine how traffic is forwarded. Default and custom route tables are supported. |
| **Labels** | Grouping mechanism for route tables to simplify propagation configuration. |

### Virtual WAN SKUs — **Critical for Exam!**

Azure Virtual WAN offers two SKUs with dramatically different capabilities. **Understanding the SKU differences is essential for the AZ-700 exam.**

| Feature | Basic | Standard |
|---------|-------|----------|
| **Site-to-Site VPN** | ✅ (10 sites maximum) | ✅ (up to 1,000 sites) |
| **Point-to-Site VPN** | ❌ Not supported | ✅ Full support |
| **ExpressRoute** | ❌ Not supported | ✅ Full support |
| **VNet-to-VNet Transit** | ❌ Not supported | ✅ Automatic |
| **Hub-to-Hub Transit** | ❌ Not supported | ✅ Automatic |
| **Branch-to-Branch Transit** | ❌ Not supported | ✅ Automatic |
| **Azure Firewall in Hub** | ❌ Not supported | ✅ Secured Virtual Hub |
| **NVA in Hub** | ❌ Not supported | ✅ SD-WAN integration |
| **Custom Routing** | ❌ Limited | ✅ Full flexibility |
| **Routing Intent** | ❌ Not supported | ✅ Full support |

**⚠️ Critical Exam Point: Basic SKU only supports Site-to-Site VPN with a maximum of 10 sites and NO transit connectivity. It is essentially useless for production deployments. Always choose Standard SKU unless you have an extremely simple, small-scale S2S-only requirement.**

**⚠️ Important: You CANNOT upgrade from Basic to Standard SKU. If you deploy Basic and later need Standard features, you must delete and recreate the entire Virtual WAN.**

---

## 2. Architecture Overview

### Global Transit Architecture

Virtual WAN implements a **global transit network architecture** where the Virtual WAN hub acts as the central transit point for all connectivity. This eliminates the need for full-mesh connectivity between sites and dramatically simplifies network topology.

```
                                    ┌─────────────────────┐
                                    │     Virtual WAN     │
                                    │   (Global Resource) │
                                    └──────────┬──────────┘
                                               │
            ┌──────────────────────────────────┼──────────────────────────────────┐
            │                                  │                                  │
            ▼                                  ▼                                  ▼
┌───────────────────────┐       ┌───────────────────────┐       ┌───────────────────────┐
│    VIRTUAL HUB        │       │    VIRTUAL HUB        │       │    VIRTUAL HUB        │
│     West Europe       │◄─────►│      East US          │◄─────►│    Southeast Asia     │
│    10.1.0.0/24        │ Auto  │    10.2.0.0/24        │ Auto  │    10.3.0.0/24        │
├───────────────────────┤Transit├───────────────────────┤Transit├───────────────────────┤
│ ┌─────┐ ┌─────┐ ┌───┐ │       │ ┌─────┐ ┌─────┐ ┌───┐ │       │ ┌─────┐ ┌─────┐ ┌───┐ │
│ │ VPN │ │ ER  │ │P2S│ │       │ │ VPN │ │ FW  │ │P2S│ │       │ │ VPN │ │ ER  │ │NVA│ │
│ │ GW  │ │ GW  │ │GW │ │       │ │ GW  │ │     │ │GW │ │       │ │ GW  │ │ GW  │ │   │ │
│ └─────┘ └─────┘ └───┘ │       │ └─────┘ └─────┘ └───┘ │       │ └─────┘ └─────┘ └───┘ │
└───────────┬───────────┘       └───────────┬───────────┘       └───────────┬───────────┘
            │                               │                               │
     ┌──────┴──────┐                 ┌──────┴──────┐                 ┌──────┴──────┐
     │             │                 │             │                 │             │
     ▼             ▼                 ▼             ▼                 ▼             ▼
┌─────────┐  ┌─────────┐       ┌─────────┐  ┌─────────┐       ┌─────────┐  ┌─────────┐
│  Spoke  │  │ Branch  │       │  Spoke  │  │  P2S    │       │  Spoke  │  │ Branch  │
│  VNets  │  │ Offices │       │  VNets  │  │  Users  │       │  VNets  │  │ Offices │
│ (EU)    │  │ (EU)    │       │ (US)    │  │         │       │ (Asia)  │  │ (Asia)  │
└─────────┘  └─────────┘       └─────────┘  └─────────┘       └─────────┘  └─────────┘
```

### Virtual Hub Internal Architecture

Each Virtual Hub is a Microsoft-managed virtual network with a specific address space (minimum /24). You cannot deploy custom resources into this VNet — it's fully managed by Azure. The hub contains various gateways and services:

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           VIRTUAL HUB (10.1.0.0/24)                                  │
│                         Microsoft-Managed Infrastructure                             │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌───────────────┐  │
│   │   S2S VPN       │  │  ExpressRoute   │  │   P2S VPN       │  │    Azure      │  │
│   │   Gateway       │  │   Gateway       │  │   Gateway       │  │   Firewall    │  │
│   │                 │  │                 │  │                 │  │   (Optional)  │  │
│   │ Scale: 1-20     │  │ Scale: 1-10     │  │ Scale: 1-20     │  │  Std/Premium  │  │
│   │ 500Mbps-20Gbps  │  │ 2Gbps-10Gbps    │  │ 500-10K users   │  │               │  │
│   └─────────────────┘  └─────────────────┘  └─────────────────┘  └───────────────┘  │
│                                                                                      │
│   ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────────────┐ │
│   │   Third-Party   │  │    Hub Router   │  │           Route Tables              │ │
│   │      NVA        │  │   (Automatic)   │  │  • Default Route Table              │ │
│   │   (SD-WAN)      │  │                 │  │  • Custom Route Tables              │ │
│   │                 │  │  BGP AS: 65515  │  │  • Labels for grouping              │ │
│   └─────────────────┘  └─────────────────┘  └─────────────────────────────────────┘ │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Gateway Scale Units — Throughput and Capacity

Gateway scale units determine the throughput and connection capacity of each gateway type. **Understanding scale units is critical for sizing and exam questions.**

#### VPN Gateway Scale Units

| Scale Units | Aggregate Throughput | Max S2S Tunnels | Max S2S Connections | Max P2S Connections |
|-------------|---------------------|-----------------|---------------------|---------------------|
| 1 | 500 Mbps | 250 | 250 | 500 |
| 2 | 1 Gbps | 500 | 500 | 500 |
| 3 | 1.5 Gbps | 500 | 500 | 500 |
| 4 | 2 Gbps | 500 | 500 | 500 |
| 5 | 2.5 Gbps | 500 | 500 | 500 |
| 6 | 3 Gbps | 500 | 500 | 500 |
| 7 | 3.5 Gbps | 500 | 500 | 500 |
| 8 | 4 Gbps | 500 | 500 | 500 |
| 9 | 4.5 Gbps | 500 | 500 | 500 |
| 10 | 5 Gbps | 500 | 500 | 5,000 |
| 20 | 20 Gbps | 1,000 | 1,000 | 10,000 |

**Key Formula**: 1 VPN scale unit = 500 Mbps throughput

#### ExpressRoute Gateway Scale Units

| Scale Units | Throughput | Max ER Circuits |
|-------------|-----------|-----------------|
| 1 | 2 Gbps | 4 |
| 2 | 4 Gbps | 8 |
| 3 | 6 Gbps | 12 |
| 4 | 8 Gbps | 16 |
| 5 | 10 Gbps | 16 |
| 10 | 10 Gbps | 16 |

**Key Formula**: 1 ER scale unit = 2 Gbps throughput (up to 10 Gbps maximum)

---

## 3. Connectivity Types Deep Dive

### Site-to-Site VPN Connectivity

S2S VPN connects branch offices to the Virtual Hub using IPsec/IKE tunnels over the public internet.

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│                        SITE-TO-SITE VPN ARCHITECTURE                               │
├───────────────────────────────────────────────────────────────────────────────────┤
│                                                                                    │
│   BRANCH OFFICE                           VIRTUAL HUB                             │
│   ┌─────────────────┐                    ┌─────────────────────────────┐          │
│   │  VPN Device     │                    │      S2S VPN Gateway        │          │
│   │  (Cisco, etc.)  │                    │                             │          │
│   │                 │   IPsec Tunnel     │   ┌─────────┐ ┌─────────┐   │          │
│   │  Public IP:     │◄──────────────────►│   │Instance │ │Instance │   │          │
│   │  203.0.113.1    │   (IKEv2/IKEv1)    │   │   0     │ │   1     │   │          │
│   │                 │                    │   └─────────┘ └─────────┘   │          │
│   │  BGP ASN:       │   BGP Peering      │      Active-Active          │          │
│   │  65010          │◄──────────────────►│      BGP ASN: 65515         │          │
│   └─────────────────┘                    └─────────────────────────────┘          │
│                                                                                    │
│   VPN Site Definition includes:                                                    │
│   • Device IP address (public IP of on-premises VPN device)                       │
│   • Address space (on-premises network ranges)                                     │
│   • BGP settings (ASN, peering IP) - recommended for dynamic routing              │
│   • Device vendor/model (for configuration download)                              │
│   • Link information (speed, provider name)                                        │
│                                                                                    │
└───────────────────────────────────────────────────────────────────────────────────┘
```

**BGP is strongly recommended** for S2S VPN connections because:
- Automatic route propagation when networks change
- Supports multiple links with automatic failover
- Required for certain scenarios like VPN + ExpressRoute coexistence

### ExpressRoute Connectivity

ExpressRoute provides private, dedicated connectivity from on-premises to Azure without traversing the public internet.

```
┌───────────────────────────────────────────────────────────────────────────────────┐
│                      EXPRESSROUTE CONNECTIVITY                                     │
├───────────────────────────────────────────────────────────────────────────────────┤
│                                                                                    │
│   ON-PREMISES           CONNECTIVITY PROVIDER           VIRTUAL HUB              │
│   ┌─────────────┐      ┌─────────────────────┐      ┌─────────────────┐          │
│   │   Data      │      │     Provider        │      │   ExpressRoute  │          │
│   │   Center    │──────│     Network         │──────│   Gateway       │          │
│   │             │      │   (MPLS/Ethernet)   │      │                 │          │
│   │   Router    │      │                     │      │   Scale: 1-10   │          │
│   │   (BGP)     │      │   ER Circuit        │      │   2-10 Gbps     │          │
│   └─────────────┘      └─────────────────────┘      └─────────────────┘          │
│                                                                                    │
│   Peering Types:                                                                   │
│   • Azure Private Peering - Access to VNets (required for Virtual WAN)            │
│   • Microsoft Peering - Access to Microsoft 365 and Azure public services         │
│                                                                                    │
│   ⚠️  Only Private Peering is used with Virtual WAN ExpressRoute Gateway         │
│                                                                                    │
└───────────────────────────────────────────────────────────────────────────────────┘
```

### Point-to-Site VPN (User VPN)

P2S VPN enables remote users to connect securely to Azure resources.

| Feature | Description |
|---------|-------------|
| **Protocols** | OpenVPN (TCP 443), IKEv2 |
| **Authentication** | Azure AD, RADIUS, Certificate-based |
| **Client Support** | Windows, macOS, Linux, iOS, Android |
| **Scale** | Up to 10,000 concurrent connections (20 scale units) |

### VNet Connections

VNet connections attach spoke VNets to the Virtual Hub, replacing traditional VNet peering.

**Important Restrictions:**
- A VNet can only be connected to ONE hub at a time
- A VNet CANNOT be both peered to another VNet AND connected to a hub (choose one topology)
- VNet address space cannot overlap with hub address space or other connected VNets

---

## 4. Routing Deep Dive

### Hub Routing Architecture

Virtual WAN uses a built-in routing service that automatically manages route propagation between connections. This eliminates the need for user-defined routes (UDRs) in most scenarios.

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                           HUB ROUTING ARCHITECTURE                                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ROUTE TABLES                               CONNECTIONS                            │
│   ┌─────────────────────────────┐           ┌─────────────────────────────┐        │
│   │    defaultRouteTable        │           │  VNet Connection 1          │        │
│   │    (Built-in)               │◄─────────►│  • Associated: default      │        │
│   │                             │           │  • Propagating: default     │        │
│   │    Routes:                  │           └─────────────────────────────┘        │
│   │    • 10.1.0.0/16 → VNet1    │                                                  │
│   │    • 10.2.0.0/16 → VNet2    │           ┌─────────────────────────────┐        │
│   │    • 192.168.0.0/16 → VPN   │           │  VPN Connection             │        │
│   │    • 172.16.0.0/16 → ER     │◄─────────►│  • Associated: default      │        │
│   │                             │           │  • Propagating: default     │        │
│   └─────────────────────────────┘           └─────────────────────────────┘        │
│                                                                                      │
│   ┌─────────────────────────────┐           ┌─────────────────────────────┐        │
│   │    RT_Isolated              │           │  Isolated VNet Connection   │        │
│   │    (Custom)                 │◄─────────►│  • Associated: RT_Isolated  │        │
│   │                             │           │  • Propagating: none        │        │
│   │    Routes:                  │           └─────────────────────────────┘        │
│   │    • 10.100.0.0/16 → Shared │                                                  │
│   │    (Only shared services)   │                                                  │
│   └─────────────────────────────┘                                                  │
│                                                                                      │
│   KEY CONCEPTS:                                                                      │
│   • Association: Which route table a connection USES for routing decisions          │
│   • Propagation: Which route tables LEARN about this connection's routes           │
│   • Labels: Group route tables for bulk propagation (e.g., "default", "none")      │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Routing Intent (Simplified Security Routing)

**Routing Intent** is a game-changer for secured hubs. Instead of manually configuring route tables and static routes, you simply specify policies:

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              ROUTING INTENT                                          │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   WITHOUT ROUTING INTENT:              WITH ROUTING INTENT:                         │
│   ┌─────────────────────────┐         ┌─────────────────────────┐                  │
│   │ Manual configuration:   │         │ Simple policy:          │                  │
│   │ • Create route tables   │         │                         │                  │
│   │ • Add static routes     │   →     │ ☑ Internet Traffic      │                  │
│   │ • Configure associations│         │   → Azure Firewall      │                  │
│   │ • Set up propagations   │         │                         │                  │
│   │ • Test and validate     │         │ ☑ Private Traffic       │                  │
│   └─────────────────────────┘         │   → Azure Firewall      │                  │
│                                        └─────────────────────────┘                  │
│                                                                                      │
│   Routing Intent Policies:                                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │ INTERNET TRAFFIC POLICY                                                      │  │
│   │ • Automatically routes 0.0.0.0/0 through the security solution              │  │
│   │ • Applies to all connections with EnableInternetSecurity = true             │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │ PRIVATE TRAFFIC POLICY                                                       │  │
│   │ • Automatically routes RFC1918 ranges (10.0.0.0/8, 172.16.0.0/12,           │  │
│   │   192.168.0.0/16) through the security solution                              │  │
│   │ • Enables inter-hub and inter-branch inspection                              │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   ⚠️  Routing Intent requires Azure Firewall or supported NVA deployed in hub      │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 5. Configuration Best Practices

### Deploy Virtual WAN and Hub

```powershell
# Variables
$rgName = "rg-vwan-prod"
$location = "eastus"
$vwanName = "vwan-contoso-global"
$hubName = "hub-eastus"
$hubAddressPrefix = "10.1.0.0/24"

# Create Resource Group
New-AzResourceGroup -Name $rgName -Location $location

# Create Virtual WAN (ALWAYS use Standard for production)
$vwan = New-AzVirtualWan -ResourceGroupName $rgName `
    -Name $vwanName `
    -Location $location `
    -VirtualWANType "Standard" `
    -AllowBranchToBranchTraffic $true `
    -AllowVnetToVnetTraffic $true

Write-Host "Virtual WAN created: $($vwan.Name)"

# Create Virtual Hub (takes 10-30 minutes to provision)
$hub = New-AzVirtualHub -ResourceGroupName $rgName `
    -Name $hubName `
    -VirtualWan $vwan `
    -Location $location `
    -AddressPrefix $hubAddressPrefix

# Wait for hub provisioning
Write-Host "Waiting for hub provisioning (this takes 10-30 minutes)..."
do {
    Start-Sleep -Seconds 60
    $hub = Get-AzVirtualHub -ResourceGroupName $rgName -Name $hubName
    Write-Host "Hub state: $($hub.ProvisioningState)"
} while ($hub.ProvisioningState -ne "Succeeded")

Write-Host "Virtual Hub provisioned successfully!"
```

### Create VPN Gateway in Hub

```powershell
# Create VPN Gateway with 2 scale units (1 Gbps throughput)
# Scale units: 1 = 500 Mbps, 2 = 1 Gbps, ... 20 = 20 Gbps
$vpnGw = New-AzVpnGateway -ResourceGroupName $rgName `
    -Name "vpngw-$hubName" `
    -VirtualHub $hub `
    -VpnGatewayScaleUnit 2

# Wait for VPN Gateway provisioning (takes 15-30 minutes)
Write-Host "Waiting for VPN Gateway provisioning..."
do {
    Start-Sleep -Seconds 60
    $vpnGw = Get-AzVpnGateway -ResourceGroupName $rgName -Name "vpngw-$hubName"
    Write-Host "VPN Gateway state: $($vpnGw.ProvisioningState)"
} while ($vpnGw.ProvisioningState -ne "Succeeded")

# Get gateway public IPs for branch configuration
Write-Host "VPN Gateway Instance 0 IP: $($vpnGw.IpConfigurations[0].PublicIpAddress)"
Write-Host "VPN Gateway Instance 1 IP: $($vpnGw.IpConfigurations[1].PublicIpAddress)"
```

### Connect Spoke VNet to Hub

```powershell
# Get existing spoke VNet
$spokeVnet = Get-AzVirtualNetwork -Name "vnet-spoke-web" -ResourceGroupName "rg-spoke"

# Create Hub VNet Connection
$hubVnetConnection = New-AzVirtualHubVnetConnection -ResourceGroupName $rgName `
    -VirtualHubName $hubName `
    -Name "conn-spoke-web" `
    -RemoteVirtualNetwork $spokeVnet `
    -EnableInternetSecurity $true  # Route internet traffic through secured hub firewall

Write-Host "VNet connection created: $($hubVnetConnection.Name)"
```

### Configure Site-to-Site VPN (Branch Office)

```powershell
# Create VPN Site Link (represents physical WAN link at branch)
$vpnSiteLink = New-AzVpnSiteLink -Name "link-primary" `
    -IPAddress "203.0.113.1" `
    -LinkProviderName "Contoso-ISP" `
    -LinkSpeedInMbps 100 `
    -BGPAsn 65010 `
    -BGPPeeringAddress "169.254.21.1"

# Create VPN Site (represents the branch office)
$vpnSite = New-AzVpnSite -ResourceGroupName $rgName `
    -Name "site-branch-seattle" `
    -Location $location `
    -VirtualWan $vwan `
    -AddressSpace @("192.168.0.0/16", "172.20.0.0/16") `
    -DeviceModel "Cisco ISR 4331" `
    -DeviceVendor "Cisco" `
    -VpnSiteLink @($vpnSiteLink)

# Create VPN Site Link Connection
$vpnSiteLinkConnection = New-AzVpnSiteLinkConnection -Name "conn-link-primary" `
    -VpnSiteLink $vpnSite.VpnSiteLinks[0] `
    -ConnectionBandwidth 100 `
    -EnableBgp $true `
    -VpnConnectionProtocolType "IKEv2"

# Create VPN Connection to the site
New-AzVpnConnection -ResourceGroupName $rgName `
    -ParentResourceName "vpngw-$hubName" `
    -Name "conn-branch-seattle" `
    -VpnSite $vpnSite `
    -VpnSiteLinkConnection @($vpnSiteLinkConnection)

# Download VPN configuration for branch device
$storageAccount = Get-AzStorageAccount -ResourceGroupName $rgName -Name "stvwanconfig"
$sasUrl = New-AzStorageContainerSASToken -Context $storageAccount.Context `
    -Container "vpnconfig" -Permission "rw" -ExpiryTime (Get-Date).AddHours(1)

Get-AzVirtualWanVpnConfiguration -ResourceGroupName $rgName `
    -Name $vwanName `
    -StorageSasUrl "$($storageAccount.PrimaryEndpoints.Blob)vpnconfig$sasUrl" `
    -VpnSite @($vpnSite)

Write-Host "VPN configuration file generated. Download from storage account."
```

### Deploy ExpressRoute Gateway and Connection

```powershell
# Create ExpressRoute Gateway in Hub (2 scale units = 4 Gbps)
$erGw = New-AzExpressRouteGateway -ResourceGroupName $rgName `
    -Name "ergw-$hubName" `
    -VirtualHub $hub `
    -MinScaleUnits 2 `
    -MaxScaleUnits 4  # Auto-scale between 4-8 Gbps

# Wait for provisioning
Write-Host "Waiting for ExpressRoute Gateway provisioning..."
do {
    Start-Sleep -Seconds 60
    $erGw = Get-AzExpressRouteGateway -ResourceGroupName $rgName -Name "ergw-$hubName"
} while ($erGw.ProvisioningState -ne "Succeeded")

# Get existing ExpressRoute circuit
$circuit = Get-AzExpressRouteCircuit -Name "er-circuit-contoso" -ResourceGroupName "rg-expressroute"

# Connect ExpressRoute circuit to hub
New-AzExpressRouteConnection -ResourceGroupName $rgName `
    -ExpressRouteGatewayName "ergw-$hubName" `
    -Name "conn-er-datacenter" `
    -ExpressRouteCircuitPeeringId $circuit.Peerings[0].Id `
    -RoutingWeight 10  # Lower weight = higher priority
```

### Configure Secured Virtual Hub with Routing Intent

```powershell
# Step 1: Deploy Azure Firewall in hub (via Firewall Manager or PowerShell)
# Note: This is typically done via Azure Firewall Manager portal

# Step 2: Get the hub with firewall deployed
$hub = Get-AzVirtualHub -ResourceGroupName $rgName -Name $hubName

# Verify firewall is deployed
if ($null -eq $hub.AzureFirewall) {
    Write-Error "Azure Firewall must be deployed in the hub first!"
    return
}

# Step 3: Create Routing Intent Policies
$internetPolicy = New-AzRoutingPolicy -Name "InternetTrafficPolicy" `
    -Destination @("Internet") `
    -NextHop $hub.AzureFirewall.Id

$privatePolicy = New-AzRoutingPolicy -Name "PrivateTrafficPolicy" `
    -Destination @("PrivateTraffic") `
    -NextHop $hub.AzureFirewall.Id

# Step 4: Apply Routing Intent
New-AzRoutingIntent -ResourceGroupName $rgName `
    -VirtualHubName $hubName `
    -Name "SecuredHubRoutingIntent" `
    -RoutingPolicy @($internetPolicy, $privatePolicy)

Write-Host "Routing Intent configured. All traffic will flow through Azure Firewall."
```

### Configure Custom Route Tables for VNet Isolation

```powershell
# Create custom route table for isolated workloads
$isolatedRT = New-AzVHubRouteTable -ResourceGroupName $rgName `
    -VirtualHubName $hubName `
    -Name "RT_Isolated" `
    -Label @("isolated")

# Create route table for shared services access
$sharedRoute = New-AzVHubRoute -Name "ToSharedServices" `
    -DestinationType "CIDR" `
    -Destination @("10.100.0.0/16") `
    -NextHopType "ResourceId" `
    -NextHop $sharedServicesConnection.Id

$sharedRT = New-AzVHubRouteTable -ResourceGroupName $rgName `
    -VirtualHubName $hubName `
    -Name "RT_Shared" `
    -Route @($sharedRoute) `
    -Label @("shared")

# Update VNet connection to use isolated routing
$isolatedVnetConn = Get-AzVirtualHubVnetConnection -ResourceGroupName $rgName `
    -VirtualHubName $hubName -Name "conn-spoke-hr"

# Configure: Associated with RT_Isolated, propagates to RT_Shared only
$routingConfig = @{
    AssociatedRouteTable = @{ Id = $isolatedRT.Id }
    PropagatedRouteTables = @{
        Ids = @(@{ Id = $sharedRT.Id })
        Labels = @("shared")
    }
}

Update-AzVirtualHubVnetConnection -ResourceGroupName $rgName `
    -VirtualHubName $hubName `
    -Name "conn-spoke-hr" `
    -RoutingConfiguration $routingConfig
```

---

## 6. Comparison Tables

### Virtual WAN vs Traditional Hub-Spoke Architecture

| Aspect | Virtual WAN | Traditional Hub-Spoke |
|--------|-------------|----------------------|
| **Hub Management** | Microsoft-managed (no VMs to maintain) | Customer-managed VNet with NVAs |
| **Scalability** | Automatic scaling via scale units | Manual (resize VMs/gateways) |
| **Hub-to-Hub Connectivity** | Automatic mesh (Standard SKU) | Manual VNet peering or VPN tunnels |
| **Routing Management** | Built-in route service, automatic propagation | UDRs on every subnet, manual maintenance |
| **Branch Connectivity** | Integrated VPN/ER gateways, configuration download | Separate VPN/ER gateways, manual config |
| **Global Transit** | Built-in via Azure backbone | Complex mesh of peerings/tunnels |
| **Cost Model** | Hub hour + Gateway hour + Data processed | Individual resource costs |
| **NVA Support** | In-hub NVAs (Standard SKU) | Full flexibility, any NVA |
| **BGP Configuration** | Simplified, fixed AS 65515 | Full manual control |
| **Deployment Time** | 10-30 min per hub, 15-30 min per gateway | Faster individual components |
| **Best For** | Large-scale, multi-region, SD-WAN | Simple, single-region, cost-sensitive |

### Connectivity Matrix — Standard SKU

| Source → Destination | Supported | Notes |
|---------------------|-----------|-------|
| VNet ↔ VNet (same hub) | ✅ | Automatic via hub router |
| VNet ↔ VNet (different hubs) | ✅ | Automatic hub-to-hub transit |
| VNet ↔ Branch (VPN) | ✅ | Automatic route propagation |
| VNet ↔ Branch (ExpressRoute) | ✅ | Automatic route propagation |
| Branch ↔ Branch (VPN-VPN) | ✅ | AllowBranchToBranchTraffic setting |
| Branch ↔ Branch (ER-ER) | ✅ | Via hub, Global Reach not required |
| VPN ↔ ExpressRoute Transit | ✅ | Coexist in same hub |
| P2S User ↔ VNet | ✅ | Automatic |
| P2S User ↔ Branch | ✅ | Automatic |
| P2S User ↔ P2S User | ❌ | Not supported |

---

## 7. Exam Tips & Gotchas

### Critical Points to Memorize

1. **Basic SKU only supports S2S VPN with 10 sites maximum** — no P2S, ExpressRoute, or any transit capability. Essentially useless for production.

2. **Cannot upgrade Basic to Standard SKU** — you must delete and recreate the entire Virtual WAN if you need to change SKUs.

3. **Hub address prefix must be /24 minimum** — this is a Microsoft-managed VNet where you cannot deploy custom resources.

4. **Hub deployment takes 10-30 minutes** — gateway deployments add another 15-30 minutes each. Plan for lengthy provisioning times.

5. **BGP AS number is fixed at 65515** — you cannot change the hub's BGP AS number. Plan your on-premises BGP configuration accordingly.

6. **VNet cannot be both peered and hub-connected** — a VNet can connect to a hub OR be peered to other VNets, not both simultaneously.

7. **Routing Intent requires Azure Firewall in the hub** — you cannot enable Routing Intent without a security solution deployed.

8. **Scale units determine throughput**: VPN = 500 Mbps per unit (max 20 = 20 Gbps); ER = 2 Gbps per unit (max 10 Gbps)

9. **Hub-to-hub traffic uses Azure backbone** — not the public internet, providing low-latency global transit.

10. **Maximum limits**: 500 hubs per VWAN, 500 VNet connections per hub, 1,000 S2S tunnels per hub, 10,000 P2S connections per hub.

### Common Exam Scenarios

| Scenario | Solution |
|----------|----------|
| "Connect 50 branches globally with automatic failover" | Virtual WAN Standard + regional hubs + VPN gateways with BGP |
| "Isolate VNets from each other but allow branch access" | Custom route tables with selective propagation |
| "All internet traffic must be inspected by firewall" | Secured Virtual Hub + Routing Intent (Internet policy) |
| "ExpressRoute and VPN should be backup for each other" | Both gateways in same hub; use routing weights to prefer ER |
| "Need SD-WAN integration with Cisco/VMware" | NVA in Virtual Hub feature (Standard SKU required) |
| "Remote users need VPN access to Azure and branches" | P2S VPN Gateway in hub (Standard SKU required) |
| "Branches in Europe shouldn't reach branches in Asia directly" | Custom route tables; don't propagate between regions |

### Key Limits to Remember

| Resource | Limit |
|----------|-------|
| Hubs per Virtual WAN | 500 |
| VNet connections per hub | 500 |
| S2S VPN tunnels per hub | 1,000 |
| P2S concurrent connections per hub | 10,000 |
| ExpressRoute circuits per hub | 16 |
| Hub address prefix minimum | /24 |
| Max VPN gateway scale units | 20 (20 Gbps) |
| Max ER gateway scale units | 10 (10 Gbps) |
| Address spaces per VNet connection | 400 |

---

## 8. Hands-On Lab Suggestions

### Lab 1: Basic Virtual WAN Deployment with Hub-Spoke
**Objective**: Deploy Virtual WAN and connect spoke VNets
1. Create Virtual WAN (Standard SKU) in your subscription
2. Deploy Virtual Hub in East US (10.1.0.0/24)
3. Create two spoke VNets (10.10.0.0/16 and 10.20.0.0/16) with test VMs
4. Connect both spoke VNets to the hub
5. Verify VNet-to-VNet connectivity by pinging between VMs
6. Check effective routes on spoke VM NICs using `Get-AzEffectiveRouteTable`
7. Review hub route table in the portal

### Lab 2: Site-to-Site VPN Configuration
**Objective**: Configure branch connectivity using S2S VPN
1. Create VPN Gateway in hub (2 scale units = 1 Gbps)
2. Create VPN Site representing a simulated branch office
3. Download VPN configuration file from Virtual WAN
4. Deploy Azure VPN Gateway in another VNet to simulate branch (or use actual device)
5. Configure IPsec tunnel using downloaded configuration
6. Enable BGP on both sides
7. Verify BGP routes are learned: `Get-AzVirtualHubRouteTableV2`
8. Test connectivity from "branch" to spoke VNets

### Lab 3: Secured Virtual Hub with Routing Intent
**Objective**: Implement centralized security with Azure Firewall
1. Create Virtual WAN with hub
2. Deploy Azure Firewall in hub via Firewall Manager
3. Create Firewall Policy with rules:
   - Allow rule: Internal traffic (RFC1918)
   - Allow rule: *.microsoft.com (FQDN)
   - Deny rule: All other internet
4. Enable Routing Intent for both Internet and Private traffic
5. Connect spoke VNets with `EnableInternetSecurity = $true`
6. Test traffic flows through firewall (check firewall logs)
7. Review firewall diagnostics in Log Analytics

### Lab 4: Multi-Hub Global Transit
**Objective**: Deploy multi-region topology with automatic transit
1. Create Virtual WAN with two hubs (East US + West Europe)
2. Connect spoke VNets to respective regional hubs
3. Deploy VPN Gateway in East US hub only
4. Create VPN Site and connection for a branch office
5. Verify automatic hub-to-hub route propagation
6. Test that branch can reach VNets in BOTH regions
7. Measure latency between regions
8. Review effective routes showing inter-hub connectivity

### Lab 5: VNet Isolation with Custom Route Tables
**Objective**: Implement workload isolation using custom routing
1. Create three spoke VNets: HR, Finance, Shared Services
2. Create custom route tables: RT_HR, RT_Finance, RT_Shared
3. Configure HR and Finance as isolated (cannot reach each other)
4. Allow both HR and Finance to reach Shared Services only
5. Associate VNet connections with appropriate route tables
6. Configure propagation settings for isolation
7. Test connectivity matrix (HR↔Finance should fail, HR↔Shared should work)

---

## 9. Cross-Service Relationships

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        VIRTUAL WAN INTEGRATION MAP                                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                       CONNECTIVITY SERVICES                                 │   │
│   │                                                                             │   │
│   │  VPN Gateway (S2S)        → IPsec tunnels to branch offices                │   │
│   │  VPN Gateway (P2S)        → Remote user VPN (OpenVPN, IKEv2)               │   │
│   │  ExpressRoute Gateway     → Private dedicated connectivity                  │   │
│   │  VNet Connections         → Replace traditional VNet peering               │   │
│   │  Hub-to-Hub               → Automatic global transit (Standard SKU)        │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                        SECURITY SERVICES                                    │   │
│   │                                                                             │   │
│   │  Azure Firewall           → Secured Virtual Hub, managed via Firewall Mgr  │   │
│   │  Firewall Manager         → Central policy management across hubs          │   │
│   │  Security Partner (SECaaS)→ Zscaler, Check Point, iboss integration       │   │
│   │  DDoS Protection          → Apply to spoke VNets (not hub itself)          │   │
│   │  Routing Intent           → Simplified security routing configuration      │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                        NETWORK SERVICES                                     │   │
│   │                                                                             │   │
│   │  Azure DNS Private Zones  → Link to spoke VNets, works across hub          │   │
│   │  Private Endpoints        → Deploy in spokes; routes propagate to hub      │   │
│   │  NVA in Hub               → SD-WAN (Cisco, VMware, Barracuda, etc.)        │   │
│   │  Route Server             → NOT needed; hub provides BGP routing           │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    MONITORING & MANAGEMENT                                  │   │
│   │                                                                             │   │
│   │  Azure Monitor            → Metrics for hubs, gateways, connections        │   │
│   │  Network Watcher          → Connection troubleshoot, packet capture        │   │
│   │  Log Analytics            → Diagnostic logs for all components             │   │
│   │  Network Insights         → Topology visualization, health dashboard       │   │
│   │  VPN Troubleshoot         → Diagnose S2S/P2S connectivity issues          │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### When to Choose Virtual WAN vs Traditional Hub-Spoke

| Choose Virtual WAN When | Choose Traditional Hub-Spoke When |
|------------------------|-----------------------------------|
| 30+ branch office sites | Fewer than 10 branch sites |
| Multi-region deployment with transit needs | Single region, simple topology |
| Need Microsoft-managed infrastructure | Need full control over hub resources |
| Want simplified routing (Routing Intent) | Need complex custom UDR scenarios |
| Large-scale P2S VPN (10,000+ users) | Small P2S deployment (< 500 users) |
| SD-WAN integration required | No SD-WAN requirement |
| Global presence with automatic failover | Predictable, cost-sensitive workload |
| Prefer operational simplicity | Prefer maximum flexibility |

---

## Quick Reference Card

| Item | Value |
|------|-------|
| **Hub address prefix** | /24 minimum (Microsoft-managed) |
| **Basic SKU capabilities** | S2S VPN only, 10 sites max, NO transit |
| **Standard SKU capabilities** | All features (P2S, ER, transit, firewall, NVA) |
| **VPN scale unit throughput** | 500 Mbps per unit |
| **ER scale unit throughput** | 2 Gbps per unit |
| **Max VPN scale units** | 20 (20 Gbps aggregate) |
| **Max ER scale units** | 10 (10 Gbps aggregate) |
| **Max VNet connections/hub** | 500 |
| **Max S2S tunnels/hub** | 1,000 |
| **Max P2S connections/hub** | 10,000 |
| **Hub BGP AS number** | 65515 (fixed, cannot change) |
| **Hub-to-hub transit** | Automatic (Standard SKU only) |
| **Routing Intent requirement** | Azure Firewall or NVA in hub |
| **Hub deployment time** | 10-30 minutes |
| **Gateway deployment time** | 15-30 minutes |

---

## Architecture Diagram

📂 Open [Virtual_WAN_Architecture.drawio](Virtual_WAN_Architecture.drawio) in VS Code with the Draw.io Integration extension.

---

## Additional Resources

- [Azure Virtual WAN Documentation](https://learn.microsoft.com/en-us/azure/virtual-wan/)
- [Virtual WAN FAQ](https://learn.microsoft.com/en-us/azure/virtual-wan/virtual-wan-faq)
- [Configure Virtual WAN Hub Routing](https://learn.microsoft.com/en-us/azure/virtual-wan/how-to-virtual-hub-routing)
- [Routing Intent and Policies](https://learn.microsoft.com/en-us/azure/virtual-wan/how-to-routing-policies)
- [Virtual WAN Limits](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#virtual-wan-limits)
- [Virtual WAN Pricing](https://azure.microsoft.com/en-us/pricing/details/virtual-wan/)
