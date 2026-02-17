---
tags:
  - AZ-700
  - azure/networking
  - domain/core-networking
  - route-server
  - bgp
  - nva
  - dynamic-routing
  - branch-to-branch
  - route-injection
aliases:
  - Azure Route Server
  - ARS
created: 2025-01-01
updated: 2026-02-07
---

# Azure Route Server

> [!info] Related Notes
> - [[VNet_Peering_Routing]] — UDRs and static routing (Route Server replaces manual UDRs)
> - [[VPN_Gateway]] — Branch-to-branch transit via Route Server + VPN GW
> - [[ExpressRoute]] — Route Server enables ExpressRoute ↔ NVA route exchange
> - [[Virtual_WAN]] — Alternative to Route Server for large-scale hub routing
> - [[Azure_Firewall_and_Firewall_Manager]] — NVA use case with Route Server

## AZ-700 Exam Domain: Design and Implement Core Networking Infrastructure (25-30%)

---

## 1. Key Concepts & Definitions

### What is Azure Route Server?

**Azure Route Server** is a fully managed service that enables dynamic route exchange between your Network Virtual Appliances (NVAs) and Azure Virtual Network using the Border Gateway Protocol (BGP). It acts as a route reflector, facilitating automatic route advertisement and learning without the need to manually configure and maintain User-Defined Routes (UDRs).

### Why Route Server Matters

In traditional Azure networking, when you deploy NVAs (firewalls, SD-WAN appliances, routers), you must create and maintain UDRs to direct traffic through these appliances. This creates significant operational overhead:

- **Manual route management** — every network change requires UDR updates
- **No dynamic route learning** — NVAs can't advertise routes they learn
- **Complex hybrid connectivity** — difficult to integrate VPN, ExpressRoute, and NVA routes
- **Limited scalability** — UDRs have limits and don't scale well

**Azure Route Server solves these challenges** by providing a central BGP route reflector that:
- Learns routes from NVAs via BGP
- Propagates routes to VNets and subnets automatically
- Enables transit between VPN Gateway, ExpressRoute, and NVAs (branch-to-branch)
- Eliminates the need for manual UDR management in many scenarios

### Core Terminology

| Term | Definition |
|------|------------|
| **Route Server** | Managed Azure service that enables BGP route exchange between NVAs and Azure VNets |
| **BGP (Border Gateway Protocol)** | Dynamic routing protocol used to exchange route information between autonomous systems |
| **ASN (Autonomous System Number)** | Unique identifier for a network in BGP (Route Server uses fixed ASN 65515) |
| **BGP Peer** | A network device (NVA) that establishes BGP session with Route Server |
| **Route Propagation** | Automatic distribution of learned routes to VNet subnets |
| **Branch-to-Branch** | Feature enabling transit between VPN Gateway, ExpressRoute Gateway, and NVAs |
| **RouteServerSubnet** | Dedicated subnet (minimum /27) required for Route Server deployment |
| **Control Plane** | Route Server operates only on control plane (route advertisement), not data plane (actual traffic) |

### Route Server Specifications

| Specification | Value |
|---------------|-------|
| **ASN** | 65515 (fixed, cannot be changed) |
| **Required Subnet** | RouteServerSubnet, minimum /27 (32 IPs) |
| **Maximum BGP Peers** | 8 NVAs per Route Server |
| **Maximum Routes** | 10,000 routes from all peers combined |
| **Public IP** | Required (Standard SKU, Static) |
| **High Availability** | Zone-redundant deployment available |
| **SKU** | Standard (only option) |
| **Protocols** | BGP (IPv4 routes only, IPv6 preview) |

### How Route Server Works

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         HOW AZURE ROUTE SERVER WORKS                                 │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   1. NVA ADVERTISES ROUTES                                                          │
│   ┌───────────────┐        BGP Session        ┌───────────────┐                     │
│   │     NVA       │ ─────────────────────────►│ Route Server  │                     │
│   │  ASN: 65002   │  Advertises: 0.0.0.0/0    │  ASN: 65515   │                     │
│   │               │             10.x.x.x/8    │               │                     │
│   └───────────────┘                           └───────────────┘                     │
│                                                                                      │
│   2. ROUTE SERVER REFLECTS ROUTES TO VNET                                           │
│   ┌───────────────┐                           ┌───────────────┐                     │
│   │ Route Server  │ ─────────────────────────►│  VNet Routes  │                     │
│   │               │  Propagates routes to     │  (Effective)  │                     │
│   │               │  all subnets in VNet      │               │                     │
│   └───────────────┘                           └───────────────┘                     │
│                                                                                      │
│   3. VMS AUTOMATICALLY GET ROUTES                                                   │
│   ┌───────────────────────────────────────────────────────────────────────────┐    │
│   │  VM Effective Routes (No UDRs needed!)                                     │    │
│   │                                                                            │    │
│   │  Destination        Next Hop Type      Next Hop Address                   │    │
│   │  ─────────────────  ───────────────    ──────────────────                 │    │
│   │  10.0.0.0/16        VNet               -                                  │    │
│   │  0.0.0.0/0          VirtualAppliance   10.0.2.4 (NVA) ← From Route Server│    │
│   │  192.168.0.0/16     VirtualNetworkGW   -  ← From VPN Gateway             │    │
│   │  10.1.0.0/16        VNetPeering        -  ← Peered VNet                  │    │
│   └───────────────────────────────────────────────────────────────────────────┘    │
│                                                                                      │
│   ⚠️  IMPORTANT: Route Server is CONTROL PLANE only                                │
│       It advertises routes but does NOT forward actual traffic!                     │
│       Traffic still flows: VM → NVA → Destination (based on routes learned)         │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Architecture Overview

### Route Server in Hub-Spoke Topology

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                      AZURE ROUTE SERVER ARCHITECTURE                                 │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│                            ON-PREMISES DATA CENTER                                   │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                                                                             │   │
│   │   ┌──────────────────┐              ┌──────────────────┐                   │   │
│   │   │   Branch Office  │              │   Headquarters   │                   │   │
│   │   │    ASN: 65001    │              │    ASN: 65003    │                   │   │
│   │   │  192.168.1.0/24  │              │  192.168.0.0/24  │                   │   │
│   │   └────────┬─────────┘              └────────┬─────────┘                   │   │
│   │            │ IPsec/BGP                       │ ExpressRoute                │   │
│   │            │                                 │                              │   │
│   └────────────┼─────────────────────────────────┼──────────────────────────────┘   │
│                │                                 │                                   │
│                ▼                                 ▼                                   │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                          AZURE HUB VNET (10.0.0.0/16)                        │  │
│   │                                                                              │  │
│   │  ┌─────────────────┐   ┌─────────────────┐   ┌─────────────────────────┐   │  │
│   │  │   GatewaySubnet │   │RouteServerSubnet│   │      NVA Subnet         │   │  │
│   │  │  10.0.255.0/27  │   │   10.0.1.0/27   │   │     10.0.2.0/24         │   │  │
│   │  │                 │   │                 │   │                          │   │  │
│   │  │ ┌─────────────┐ │   │ ┌─────────────┐ │   │ ┌──────────────────────┐ │   │  │
│   │  │ │VPN Gateway  │ │   │ │Route Server │ │   │ │   SD-WAN / Firewall  │ │   │  │
│   │  │ │             │ │◄─►│ │ ASN: 65515  │ │◄─►│ │   NVA - ASN: 65002   │ │   │  │
│   │  │ │Routes from  │ │BGP│ │             │ │BGP│ │                      │ │   │  │
│   │  │ │Branch:      │ │   │ │ Instances:  │ │   │ │   Advertises:        │ │   │  │
│   │  │ │192.168.1.0/24│ │   │ │ 10.0.1.4   │ │   │ │   0.0.0.0/0          │ │   │  │
│   │  │ └─────────────┘ │   │ │ 10.0.1.5   │ │   │ │   10.100.0.0/16      │ │   │  │
│   │  │                 │   │ └─────────────┘ │   │ └──────────────────────┘ │   │  │
│   │  │ ┌─────────────┐ │   │                 │   │                          │   │  │
│   │  │ │ExpressRoute │ │   │                 │   │                          │   │  │
│   │  │ │ Gateway     │ │◄─►│                 │   │                          │   │  │
│   │  │ │Routes from  │ │BGP│                 │   │                          │   │  │
│   │  │ │HQ:          │ │   │                 │   │                          │   │  │
│   │  │ │192.168.0.0/24│ │   │                 │   │                          │   │  │
│   │  │ └─────────────┘ │   │                 │   │                          │   │  │
│   │  └─────────────────┘   └─────────────────┘   └─────────────────────────┘   │  │
│   │                                                                              │  │
│   │            ╔════════════════════════════════════════════════════════╗       │  │
│   │            ║   EFFECTIVE ROUTES (Automatically Propagated)         ║       │  │
│   │            ║   192.168.0.0/24 → ExpressRoute GW (from HQ)          ║       │  │
│   │            ║   192.168.1.0/24 → VPN Gateway (from Branch)          ║       │  │
│   │            ║   0.0.0.0/0      → NVA 10.0.2.4 (from SD-WAN)         ║       │  │
│   │            ║   10.100.0.0/16  → NVA 10.0.2.4 (from SD-WAN)         ║       │  │
│   │            ╚════════════════════════════════════════════════════════╝       │  │
│   └──────────────────────────────────────────────────────────────────────────────┘  │
│                              │ VNet Peering                                         │
│                              │ (Use Remote Gateway: Enabled)                        │
│                              ▼                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                      SPOKE VNET 1 (10.1.0.0/16)                              │  │
│   │                                                                              │  │
│   │   ┌──────────────────────────────────────────────────────────────────────┐  │  │
│   │   │  EFFECTIVE ROUTES (Propagated via Route Server + Gateway Transit)    │  │  │
│   │   │                                                                       │  │  │
│   │   │  192.168.0.0/24 → Hub ExpressRoute GW   (on-prem HQ)                 │  │  │
│   │   │  192.168.1.0/24 → Hub VPN Gateway       (on-prem Branch)             │  │  │
│   │   │  0.0.0.0/0      → Hub NVA 10.0.2.4      (internet via firewall)      │  │  │
│   │   │  10.0.0.0/16    → VNet Peering          (hub VNet)                   │  │  │
│   │   │  10.2.0.0/16    → VNet Peering          (spoke 2 via hub)            │  │  │
│   │   └──────────────────────────────────────────────────────────────────────┘  │  │
│   │                                                                              │  │
│   │   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐                       │  │
│   │   │    VM1      │   │    VM2      │   │    VM3      │                       │  │
│   │   │  (No UDRs   │   │  (No UDRs   │   │  (No UDRs   │                       │  │
│   │   │   needed!)  │   │   needed!)  │   │   needed!)  │                       │  │
│   │   └─────────────┘   └─────────────┘   └─────────────┘                       │  │
│   └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Branch-to-Branch Transit

Branch-to-branch enables route exchange between VPN Gateway, ExpressRoute Gateway, and NVAs:

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         BRANCH-TO-BRANCH TRANSIT                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   WITHOUT Branch-to-Branch (Disabled by Default):                                   │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                                                                             │   │
│   │   VPN Gateway ◄─────────► Route Server ◄─────────► ExpressRoute            │   │
│   │       │                        │                        │                   │   │
│   │       │                        │                        │                   │   │
│   │       X ═══════════ NO ROUTE EXCHANGE ════════════ X    │                   │   │
│   │       │                                                 │                   │   │
│   │   Branch Office                                    Headquarters             │   │
│   │   (Cannot reach HQ                                 (Cannot reach            │   │
│   │    via Azure)                                       Branch via Azure)       │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   WITH Branch-to-Branch ENABLED:                                                    │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                                                                             │   │
│   │   VPN Gateway ◄══════════► Route Server ◄══════════► ExpressRoute          │   │
│   │       │               ╔═══════════════════╗              │                  │   │
│   │       │               ║ Routes Exchanged  ║              │                  │   │
│   │       │               ║ Branch ↔ HQ       ║              │                  │   │
│   │       │               ║ Branch ↔ NVA      ║              │                  │   │
│   │       │               ║ HQ ↔ NVA          ║              │                  │   │
│   │       │               ╚═══════════════════╝              │                  │   │
│   │   Branch Office                                    Headquarters             │   │
│   │   192.168.1.0/24  ◄═══════ FULL CONNECTIVITY ═══════►  192.168.0.0/24      │   │
│   │                                                                             │   │
│   │   Also includes NVA routes (0.0.0.0/0, custom routes)                      │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ⚠️  EXAM TIP: Branch-to-branch is DISABLED by default!                           │
│       Must explicitly enable with: -AllowBranchToBranchTraffic $true               │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Route Server BGP Peering Details

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         BGP PEERING CONFIGURATION                                    │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   Route Server Instance IPs (Used for BGP Peering):                                 │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │  Route Server deploys TWO instances for high availability                    │  │
│   │                                                                              │  │
│   │  Instance 1: 10.0.1.4  (Primary)                                            │  │
│   │  Instance 2: 10.0.1.5  (Secondary)                                          │  │
│   │                                                                              │  │
│   │  NVA must peer with BOTH instances for full redundancy                      │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   NVA BGP Configuration (Example - Cisco):                                          │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │  router bgp 65002                                                            │  │
│   │    neighbor 10.0.1.4 remote-as 65515                                        │  │
│   │    neighbor 10.0.1.5 remote-as 65515                                        │  │
│   │    network 0.0.0.0 mask 0.0.0.0                                             │  │
│   │    network 10.100.0.0 mask 255.255.0.0                                      │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   Route Server Azure Config:                                                        │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │  Peer Name: nva-firewall                                                     │  │
│   │  Peer IP: 10.0.2.4 (NVA's IP)                                               │  │
│   │  Peer ASN: 65002 (NVA's ASN - must be different from 65515)                 │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   Route Exchange Flow:                                                              │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                                                                              │  │
│   │   NVA (65002)                Route Server (65515)              VNet          │  │
│   │       │                            │                            │            │  │
│   │       │───── Advertise ───────────►│                            │            │  │
│   │       │      0.0.0.0/0             │                            │            │  │
│   │       │      10.100.0.0/16         │───── Propagate ───────────►│            │  │
│   │       │                            │      Next Hop: 10.0.2.4    │            │  │
│   │       │                            │                            │            │  │
│   │       │◄───── Learn ───────────────│                            │            │  │
│   │       │      10.0.0.0/16 (VNet)    │◄───── VNet Routes ─────────│            │  │
│   │       │      192.168.0.0/24 (ER)   │                            │            │  │
│   │       │                            │                            │            │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Configuration Best Practices

### Create Route Server with PowerShell

```powershell
# Variables
$rgName = "rg-networking-prod"
$location = "eastus"
$vnetName = "vnet-hub"
$rsSubnetName = "RouteServerSubnet"
$rsName = "rs-hub-prod"

# Create Resource Group
New-AzResourceGroup -Name $rgName -Location $location

# Create VNet with RouteServerSubnet
$rsSubnetConfig = New-AzVirtualNetworkSubnetConfig `
    -Name $rsSubnetName `
    -AddressPrefix "10.0.1.0/27"  # Minimum /27 required

$gwSubnetConfig = New-AzVirtualNetworkSubnetConfig `
    -Name "GatewaySubnet" `
    -AddressPrefix "10.0.255.0/27"

$nvaSubnetConfig = New-AzVirtualNetworkSubnetConfig `
    -Name "snet-nva" `
    -AddressPrefix "10.0.2.0/24"

$vnet = New-AzVirtualNetwork `
    -Name $vnetName `
    -ResourceGroupName $rgName `
    -Location $location `
    -AddressPrefix "10.0.0.0/16" `
    -Subnet $rsSubnetConfig, $gwSubnetConfig, $nvaSubnetConfig

Write-Host "VNet created with RouteServerSubnet"

# Create Public IP for Route Server (Standard SKU required)
$rsPip = New-AzPublicIpAddress `
    -Name "$rsName-pip" `
    -ResourceGroupName $rgName `
    -Location $location `
    -Sku "Standard" `
    -AllocationMethod "Static"

Write-Host "Public IP created: $($rsPip.IpAddress)"

# Get RouteServerSubnet
$rsSubnet = Get-AzVirtualNetworkSubnetConfig `
    -Name $rsSubnetName `
    -VirtualNetwork $vnet

# Create Route Server (takes 15-20 minutes)
$routeServer = New-AzRouteServer `
    -Name $rsName `
    -ResourceGroupName $rgName `
    -Location $location `
    -HostedSubnet $rsSubnet.Id `
    -PublicIpAddress $rsPip

Write-Host "Route Server created: $($routeServer.Name)"
Write-Host "Route Server IPs for BGP peering:"
$routeServer.RouteServerIps | ForEach-Object { Write-Host "  - $_" }
```

### Configure BGP Peer (NVA)

```powershell
# Add NVA as BGP peer
# NVA must be deployed and configured for BGP before this step

$nvaIp = "10.0.2.4"      # NVA's private IP
$nvaAsn = 65002          # NVA's ASN (must NOT be 65515)

Add-AzRouteServerPeer `
    -RouteServerName $rsName `
    -ResourceGroupName $rgName `
    -PeerName "nva-firewall" `
    -PeerIp $nvaIp `
    -PeerAsn $nvaAsn

Write-Host "BGP peer added: nva-firewall ($nvaIp, ASN $nvaAsn)"

# List all BGP peers
Get-AzRouteServerPeer `
    -RouteServerName $rsName `
    -ResourceGroupName $rgName | Format-Table Name, PeerIp, PeerAsn

# View routes learned from NVA
$learnedRoutes = Get-AzRouteServerPeerLearnedRoute `
    -RouteServerName $rsName `
    -ResourceGroupName $rgName `
    -PeerName "nva-firewall"

Write-Host "Routes learned from NVA:"
$learnedRoutes | Format-Table LocalAddress, Network, NextHop, AsPath

# View routes advertised to NVA
$advertisedRoutes = Get-AzRouteServerPeerAdvertisedRoute `
    -RouteServerName $rsName `
    -ResourceGroupName $rgName `
    -PeerName "nva-firewall"

Write-Host "Routes advertised to NVA:"
$advertisedRoutes | Format-Table LocalAddress, Network, NextHop, AsPath
```

### Enable Branch-to-Branch Transit

```powershell
# Enable branch-to-branch (VPN ↔ ExpressRoute ↔ NVA route exchange)
Update-AzRouteServer `
    -RouteServerName $rsName `
    -ResourceGroupName $rgName `
    -AllowBranchToBranchTraffic $true

Write-Host "Branch-to-branch traffic enabled"

# Verify setting
$rs = Get-AzRouteServer -Name $rsName -ResourceGroupName $rgName
Write-Host "AllowBranchToBranchTraffic: $($rs.AllowBranchToBranchTraffic)"
```

### Add Multiple NVA Peers (High Availability)

```powershell
# Add primary NVA
Add-AzRouteServerPeer `
    -RouteServerName $rsName `
    -ResourceGroupName $rgName `
    -PeerName "nva-primary" `
    -PeerIp "10.0.2.4" `
    -PeerAsn 65002

# Add secondary NVA (same ASN for HA pair)
Add-AzRouteServerPeer `
    -RouteServerName $rsName `
    -ResourceGroupName $rgName `
    -PeerName "nva-secondary" `
    -PeerIp "10.0.2.5" `
    -PeerAsn 65002

Write-Host "NVA HA pair configured as BGP peers"

# List all peers
Get-AzRouteServerPeer -RouteServerName $rsName -ResourceGroupName $rgName
```

### Remove BGP Peer

```powershell
# Remove NVA peer
Remove-AzRouteServerPeer `
    -RouteServerName $rsName `
    -ResourceGroupName $rgName `
    -PeerName "nva-firewall" `
    -Force

Write-Host "BGP peer removed"
```

### View Route Server Details

```powershell
# Get Route Server details
$rs = Get-AzRouteServer -Name $rsName -ResourceGroupName $rgName

Write-Host "Route Server: $($rs.Name)"
Write-Host "Location: $($rs.Location)"
Write-Host "Provisioning State: $($rs.ProvisioningState)"
Write-Host "ASN: 65515 (fixed)"
Write-Host "Route Server IPs: $($rs.RouteServerIps -join ', ')"
Write-Host "Allow Branch-to-Branch: $($rs.AllowBranchToBranchTraffic)"
Write-Host "Hosted Subnet: $($rs.HostedSubnet)"
```

---

## 4. Comparison Tables

### Route Server vs Manual UDRs

| Aspect | Route Server (BGP) | Manual UDRs |
|--------|-------------------|-------------|
| **Route Management** | Automatic via BGP | Manual creation/updates |
| **Dynamic Updates** | Yes, routes update automatically | No, manual updates required |
| **Scalability** | 10,000 routes from all peers | 400 routes per UDR table |
| **NVA Integration** | Native BGP support | Static next-hop configuration |
| **Branch Connectivity** | Automatic propagation | Manual UDRs per spoke |
| **Operational Overhead** | Low | High |
| **Cost** | Route Server pricing | No additional cost |
| **Best For** | SD-WAN, complex routing, hybrid | Simple, static routing needs |

### Route Server vs Virtual WAN Hub Router

| Feature | Route Server | Virtual WAN Hub Router |
|---------|-------------|----------------------|
| **Deployment Model** | Custom VNet (hub-spoke) | Azure Virtual WAN |
| **BGP Support** | Yes, up to 8 peers | Yes, integrated |
| **Branch-to-Branch** | Manual enable | Built-in |
| **Spoke Connectivity** | VNet peering required | Automatic with VWAN |
| **NVA Support** | Via BGP | Via NVA in spoke |
| **Management** | More flexible | More managed |
| **Use Case** | Custom architectures | Standard VWAN deployments |

### When Route Server Exchanges Routes

| Source | Route Server Action | Destination |
|--------|-------------------|-------------|
| NVA advertises routes via BGP | **Receives** and **Propagates** | VNet effective routes |
| VPN Gateway learns on-prem routes | **Receives** and **Propagates** | NVA (if branch-to-branch enabled) |
| ExpressRoute learns on-prem routes | **Receives** and **Propagates** | NVA (if branch-to-branch enabled) |
| VNet address space | **Advertises** | NVA via BGP |
| Peered VNet address space | **Advertises** (if gateway transit) | NVA via BGP |

---

## 5. Exam Tips & Gotchas

### Critical Points to Memorize

1. **ASN is ALWAYS 65515** — Route Server uses a fixed ASN. NVAs must use a different ASN. If on-prem also uses 65515, change the on-prem ASN (Route Server cannot be changed)

2. **RouteServerSubnet required** — Dedicated subnet named exactly "RouteServerSubnet", minimum /27 (32 addresses)

3. **Maximum 8 BGP peers** — You can peer up to 8 NVAs with a single Route Server

4. **Maximum 10,000 routes** — Combined from all peers; plan accordingly for large environments

5. **Control plane only** — Route Server advertises routes but does NOT forward traffic. Traffic flows VM → NVA based on routes

6. **Branch-to-branch disabled by default** — Must explicitly enable for VPN↔ExpressRoute↔NVA route exchange

7. **Two instances for HA** — Route Server provides two IPs; NVAs should peer with both

8. **VNet peering still required** — Route Server doesn't replace peering; spokes need "Use Remote Gateway" enabled

9. **NVA must support BGP** — Simple NVAs without BGP cannot use Route Server

10. **Standard public IP required** — Route Server needs a Standard SKU, static public IP

### Common Exam Scenarios

| Scenario | Solution |
|----------|----------|
| "SD-WAN NVA needs to advertise routes to Azure VNets" | Deploy Route Server, configure BGP peering with NVA |
| "VPN and ExpressRoute need to exchange routes through Azure" | Enable branch-to-branch on Route Server |
| "Spoke VNets need on-premises routes without maintaining UDRs" | Route Server + VNet peering with gateway transit enabled |
| "NVA advertising 0.0.0.0/0 for internet inspection" | BGP peer NVA with Route Server; routes propagate to VNet |
| "On-premises router using ASN 65515 conflicts with Route Server" | Change on-prem ASN (Route Server ASN is fixed) |
| "Need to peer more than 8 NVAs" | Deploy multiple Route Servers in different VNets |
| "Routes not propagating to spoke VNets" | Enable "Use Remote Gateway" on peering from spoke side |
| "ExpressRoute routes not reaching NVA" | Enable branch-to-branch on Route Server |

### Common Mistakes to Avoid

1. **Forgetting branch-to-branch** — VPN↔ER routes don't exchange without this enabled
2. **Wrong subnet name** — Must be exactly "RouteServerSubnet" (case-sensitive)
3. **Subnet too small** — Must be /27 or larger
4. **Same ASN as Route Server** — NVA cannot use 65515
5. **Expecting data plane forwarding** — Route Server only handles control plane (routes)
6. **Missing gateway transit on peering** — Spoke VNets need "Use Remote Gateway" enabled
7. **Not peering with both Route Server instances** — NVA should peer with both IPs for full HA
8. **Basic SKU public IP** — Route Server requires Standard SKU

### Key Limits to Remember

| Resource | Limit |
|----------|-------|
| Route Server ASN | 65515 (fixed) |
| Subnet name | RouteServerSubnet |
| Minimum subnet size | /27 (32 IPs) |
| Maximum BGP peers | 8 |
| Maximum routes (all peers) | 10,000 |
| Route Server instances | 2 (for HA) |

---

## 6. Hands-On Lab Suggestions

### Lab 1: Deploy Route Server with NVA BGP Peering

**Objective**: Set up Route Server and configure BGP peering with an NVA

```powershell
# Step 1: Create resource group
New-AzResourceGroup -Name "rg-routeserver-lab" -Location "eastus"

# Step 2: Create hub VNet with required subnets
$rsSubnet = New-AzVirtualNetworkSubnetConfig -Name "RouteServerSubnet" -AddressPrefix "10.0.1.0/27"
$nvaSubnet = New-AzVirtualNetworkSubnetConfig -Name "snet-nva" -AddressPrefix "10.0.2.0/24"
$vmSubnet = New-AzVirtualNetworkSubnetConfig -Name "snet-workload" -AddressPrefix "10.0.3.0/24"

$hubVnet = New-AzVirtualNetwork `
    -Name "vnet-hub" `
    -ResourceGroupName "rg-routeserver-lab" `
    -Location "eastus" `
    -AddressPrefix "10.0.0.0/16" `
    -Subnet $rsSubnet, $nvaSubnet, $vmSubnet

# Step 3: Create Public IP for Route Server
$rsPip = New-AzPublicIpAddress `
    -Name "pip-routeserver" `
    -ResourceGroupName "rg-routeserver-lab" `
    -Location "eastus" `
    -Sku "Standard" `
    -AllocationMethod "Static"

# Step 4: Create Route Server
$rsSubnet = Get-AzVirtualNetworkSubnetConfig -Name "RouteServerSubnet" -VirtualNetwork $hubVnet

New-AzRouteServer `
    -Name "rs-hub" `
    -ResourceGroupName "rg-routeserver-lab" `
    -Location "eastus" `
    -HostedSubnet $rsSubnet.Id `
    -PublicIpAddress $rsPip

# Step 5: Get Route Server BGP endpoints
$rs = Get-AzRouteServer -Name "rs-hub" -ResourceGroupName "rg-routeserver-lab"
Write-Host "Configure NVA to peer with these IPs:"
$rs.RouteServerIps | ForEach-Object { Write-Host "  $_" }
Write-Host "Remote ASN: 65515"

# Step 6: Deploy NVA VM (use marketplace image like Cisco CSR or build your own)
# Configure NVA with BGP: neighbor $rs.RouteServerIps[0] remote-as 65515
#                         neighbor $rs.RouteServerIps[1] remote-as 65515

# Step 7: Add NVA as BGP peer (after NVA is configured)
Add-AzRouteServerPeer `
    -RouteServerName "rs-hub" `
    -ResourceGroupName "rg-routeserver-lab" `
    -PeerName "nva-router" `
    -PeerIp "10.0.2.4" `
    -PeerAsn 65001

# Step 8: Verify routes
Get-AzRouteServerPeerLearnedRoute `
    -RouteServerName "rs-hub" `
    -ResourceGroupName "rg-routeserver-lab" `
    -PeerName "nva-router"
```

### Lab 2: Enable Branch-to-Branch Transit

**Objective**: Configure VPN↔ExpressRoute route exchange

```powershell
# Prerequisite: Route Server deployed with VPN Gateway and/or ExpressRoute Gateway in same VNet

# Enable branch-to-branch
Update-AzRouteServer `
    -RouteServerName "rs-hub" `
    -ResourceGroupName "rg-routeserver-lab" `
    -AllowBranchToBranchTraffic $true

# Verify on-prem routes from VPN appear in ExpressRoute learned routes (and vice versa)
```

### Lab 3: Hub-Spoke with Automatic Route Propagation

**Objective**: Verify routes propagate to spoke VNets

```powershell
# Create spoke VNet
$spokeSubnet = New-AzVirtualNetworkSubnetConfig -Name "snet-app" -AddressPrefix "10.1.1.0/24"
$spokeVnet = New-AzVirtualNetwork `
    -Name "vnet-spoke1" `
    -ResourceGroupName "rg-routeserver-lab" `
    -Location "eastus" `
    -AddressPrefix "10.1.0.0/16" `
    -Subnet $spokeSubnet

# Peer hub to spoke (allow gateway transit)
Add-AzVirtualNetworkPeering `
    -Name "hub-to-spoke1" `
    -VirtualNetwork $hubVnet `
    -RemoteVirtualNetworkId $spokeVnet.Id `
    -AllowGatewayTransit $true

# Peer spoke to hub (use remote gateway)
Add-AzVirtualNetworkPeering `
    -Name "spoke1-to-hub" `
    -VirtualNetwork $spokeVnet `
    -RemoteVirtualNetworkId $hubVnet.Id `
    -UseRemoteGateways $true

# Deploy VM in spoke and check effective routes
# Routes from Route Server should appear automatically
```

---

## 7. Cross-Service Relationships

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         ROUTE SERVER INTEGRATION MAP                                 │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    INTEGRATES WITH (BGP PEERING)                            │   │
│   │                                                                             │   │
│   │  VPN Gateway           → Learns on-prem routes, advertises Azure routes    │   │
│   │  ExpressRoute Gateway  → Learns on-prem routes, advertises Azure routes    │   │
│   │  NVAs (SD-WAN, FW)     → Mutual route exchange via BGP                     │   │
│   │  Third-Party Routers   → Any BGP-capable appliance                         │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    PROPAGATES ROUTES TO                                     │   │
│   │                                                                             │   │
│   │  VNet Subnets          → Routes appear in effective routes automatically   │   │
│   │  Peered VNets          → Via gateway transit (requires proper peering)     │   │
│   │  NVAs                  → Via BGP (NVA learns Azure routes)                 │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    DOES NOT INTEGRATE WITH                                  │   │
│   │                                                                             │   │
│   │  Azure Firewall        → Use Azure Firewall's own routing                  │   │
│   │  Application Gateway   → Uses its own subnet routing                       │   │
│   │  Load Balancer         → Not a routing service                             │   │
│   │  Virtual WAN           → Has its own built-in hub router                   │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    COMMON DEPLOYMENT PATTERNS                               │   │
│   │                                                                             │   │
│   │  Pattern 1: SD-WAN Integration                                             │   │
│   │  SD-WAN NVA ◄─── BGP ───► Route Server ───► VNet Routes                    │   │
│   │                                                                             │   │
│   │  Pattern 2: Hybrid Connectivity                                            │   │
│   │  VPN GW ◄─── BGP ───► Route Server ◄─── BGP ───► ExpressRoute GW          │   │
│   │                            │                                               │   │
│   │                            ▼                                               │   │
│   │                    NVA (Firewall) ◄─── BGP ───┘                            │   │
│   │                                                                             │   │
│   │  Pattern 3: Multi-Spoke with Automatic Routing                             │   │
│   │  Hub (Route Server) ──► Spoke 1 (via peering + gateway transit)           │   │
│   │           │        ──► Spoke 2                                             │   │
│   │           │        ──► Spoke N                                             │   │
│   │           ▼                                                                │   │
│   │  All spokes automatically receive on-prem and NVA routes                  │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Quick Reference Card

| Item | Value |
|------|-------|
| **Route Server ASN** | 65515 (fixed, cannot change) |
| **Required Subnet** | RouteServerSubnet (/27 minimum) |
| **Maximum BGP Peers** | 8 NVAs |
| **Maximum Routes** | 10,000 (from all peers) |
| **Branch-to-Branch** | Disabled by default |
| **Route Server Instances** | 2 (for high availability) |
| **Public IP SKU** | Standard (Static) |
| **Deployment Time** | ~15-20 minutes |
| **Data Plane** | ❌ No (control plane only) |
| **VNet Peering** | Still required for spoke connectivity |

---

## Architecture Diagram File

📂 Open [Azure_Route_Server_Architecture.drawio](Azure_Route_Server_Architecture.drawio) in VS Code with the Draw.io Integration extension.

---

## Additional Resources

- [Azure Route Server Documentation](https://learn.microsoft.com/en-us/azure/route-server/)
- [Configure BGP Peering with NVA](https://learn.microsoft.com/en-us/azure/route-server/quickstart-configure-route-server-portal)
- [Route Server FAQ](https://learn.microsoft.com/en-us/azure/route-server/route-server-faq)
- [ExpressRoute and VPN Coexistence with Route Server](https://learn.microsoft.com/en-us/azure/expressroute/expressroute-howto-coexist-resource-manager)
