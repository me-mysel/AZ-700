---
tags:
  - AZ-700
  - azure/networking
  - domain/core-networking
  - vnet-peering
  - global-peering
  - gateway-transit
  - udr
  - routing
  - service-chaining
  - hub-spoke
aliases:
  - VNet Peering
  - User-Defined Routes
  - UDR
created: 2025-01-01
updated: 2026-02-07
---

# VNet Peering & Routing

> [!info] Related Notes
> - [[VNet_Subnets_IP_Addressing]] — VNet address spaces and subnets
> - [[Azure_Route_Server]] — Dynamic route exchange with NVAs via BGP
> - [[Azure_Virtual_Network_Manager]] — Automated hub-spoke and mesh topologies
> - [[VPN_Gateway]] — Gateway transit for peered VNets
> - [[ExpressRoute]] — Gateway transit for ExpressRoute
> - [[Azure_Firewall_and_Firewall_Manager]] — Service chaining through firewall

## Overview

VNet peering enables direct connectivity between Azure Virtual Networks using Microsoft's backbone infrastructure. Combined with User-Defined Routes (UDRs), you can design sophisticated network topologies for enterprise scenarios.

### Key Concepts

| Concept | Description |
|---------|-------------|
| **VNet Peering** | Low-latency, high-bandwidth connection between VNets |
| **Global Peering** | Peering across Azure regions |
| **Gateway Transit** | Share VPN/ExpressRoute gateway across peered VNets |
| **UDR** | User-Defined Routes to override default routing |
| **Service Chaining** | Route traffic through NVA or firewall |

---

## Architecture Diagram: Hub-Spoke Topology

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         HUB-SPOKE NETWORK TOPOLOGY                                   │
│                                                                                      │
│    ON-PREMISES                           AZURE (Hub Region)                         │
│    ┌──────────────┐                                                                 │
│    │              │                      ┌─────────────────────────────────────┐    │
│    │  Corporate   │    VPN/ExpressRoute  │           HUB VNET                  │    │
│    │  Network     │◄─────────────────────┤           10.0.0.0/16               │    │
│    │              │                      │                                      │    │
│    │  192.168.0.0 │                      │   ┌───────────────────────────┐     │    │
│    │     /16      │                      │   │    GatewaySubnet          │     │    │
│    └──────────────┘                      │   │    10.0.255.0/27          │     │    │
│                                          │   │    ┌────────────────┐     │     │    │
│                                          │   │    │  VPN Gateway   │     │     │    │
│                                          │   │    │  (Gateway      │     │     │    │
│                                          │   │    │   Transit)     │     │     │    │
│                                          │   │    └────────────────┘     │     │    │
│                                          │   └───────────────────────────┘     │    │
│                                          │                                      │    │
│                                          │   ┌───────────────────────────┐     │    │
│                                          │   │    AzureFirewallSubnet    │     │    │
│                                          │   │    10.0.1.0/26            │     │    │
│                                          │   │    ┌────────────────┐     │     │    │
│                                          │   │    │ Azure Firewall │     │     │    │
│                                          │   │    │  10.0.1.4      │     │     │    │
│                                          │   │    └────────────────┘     │     │    │
│                                          │   └───────────────────────────┘     │    │
│                                          │                                      │    │
│                                          │   ┌───────────────────────────┐     │    │
│                                          │   │    SharedServices         │     │    │
│                                          │   │    10.0.2.0/24            │     │    │
│                                          │   │    - DNS Servers          │     │    │
│                                          │   │    - Domain Controllers   │     │    │
│                                          │   └───────────────────────────┘     │    │
│                                          └─────────────────────────────────────┘    │
│                                                         │                            │
│                              ┌──────────────────────────┼──────────────────────────┐ │
│                              │                          │                          │ │
│                         (Peering)                  (Peering)                  (Peering)
│                              │                          │                          │ │
│                              ▼                          ▼                          ▼ │
│    ┌─────────────────────────────┐  ┌─────────────────────────────┐  ┌────────────────────┐
│    │      SPOKE 1 VNET           │  │      SPOKE 2 VNET           │  │   SPOKE 3 VNET     │
│    │      10.1.0.0/16            │  │      10.2.0.0/16            │  │   10.3.0.0/16      │
│    │      (Production)           │  │      (Development)          │  │   (DMZ)            │
│    │                             │  │                             │  │                    │
│    │  ┌─────────┐ ┌─────────┐   │  │  ┌─────────┐ ┌─────────┐   │  │  ┌─────────┐       │
│    │  │   VM    │ │   VM    │   │  │  │   VM    │ │   VM    │   │  │  │  NVA    │       │
│    │  │  Web    │ │  App    │   │  │  │  Dev    │ │  Test   │   │  │  │         │       │
│    │  └─────────┘ └─────────┘   │  │  └─────────┘ └─────────┘   │  │  └─────────┘       │
│    │                             │  │                             │  │                    │
│    │  UDR: 0.0.0.0/0 → 10.0.1.4 │  │  UDR: 0.0.0.0/0 → 10.0.1.4 │  │                    │
│    │       (via Azure Firewall)  │  │       (via Azure Firewall)  │  │                    │
│    └─────────────────────────────┘  └─────────────────────────────┘  └────────────────────┘
│                                                                                      │
│    ┌─────────────────────────────────────────────────────────────────────────────┐  │
│    │                    ROUTING FLOW EXAMPLE                                      │  │
│    │                                                                              │  │
│    │   Spoke1 VM (10.1.1.5) → Internet                                           │  │
│    │         │                                                                    │  │
│    │         ├─1─► UDR matches 0.0.0.0/0 → Next Hop: 10.0.1.4                    │  │
│    │         │                                                                    │  │
│    │         ├─2─► Traffic sent to Azure Firewall via peering                     │  │
│    │         │                                                                    │  │
│    │         └─3─► Firewall inspects, applies rules, forwards to internet         │  │
│    │                                                                              │  │
│    └─────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## VNet Peering

### Regional vs Global Peering

| Feature | Regional Peering | Global Peering |
|---------|------------------|----------------|
| **Latency** | Lowest (same region) | Higher (cross-region) |
| **Bandwidth** | Full backbone bandwidth | Full backbone bandwidth |
| **Cost** | Ingress/Egress charges | Higher egress charges |
| **Use Case** | Multi-tier apps | Disaster recovery, geo-distribution |
| **Basic Load Balancer** | ✅ Supported | ❌ Not supported |
| **Standard Load Balancer** | ✅ Supported | ✅ Supported |

### Non-Transitive Nature

> **⚡ EXAM TIP**: VNet peering is **NOT transitive** by default!

```
┌─────────────────────────────────────────────────────────────────┐
│               NON-TRANSITIVE PEERING                             │
│                                                                  │
│   VNet-A ◄─────Peering─────► VNet-B ◄─────Peering─────► VNet-C  │
│                                                                  │
│   ❌ VNet-A CANNOT directly communicate with VNet-C              │
│                                                                  │
│   Solutions:                                                     │
│   1. Create direct peering between VNet-A and VNet-C            │
│   2. Use hub-spoke with NVA/Firewall (service chaining)         │
│   3. Use Azure Virtual WAN                                       │
└─────────────────────────────────────────────────────────────────┘
```

### Peering Configuration Options

| Setting | Description |
|---------|-------------|
| **Allow virtual network access** | Enable IP connectivity between peered VNets |
| **Allow forwarded traffic** | Accept traffic that didn't originate from peered VNet |
| **Allow gateway transit** | Let peered VNet use this VNet's gateway |
| **Use remote gateways** | Use the peered VNet's gateway |

### Peering State

| State | Meaning |
|-------|---------|
| **Initiated** | First side of peering created, waiting for reciprocal |
| **Connected** | Both sides configured, peering active |
| **Disconnected** | One side deleted or modified |

---

## Gateway Transit

Gateway transit allows spoke VNets to use the hub VNet's VPN or ExpressRoute gateway.

```
┌─────────────────────────────────────────────────────────────────┐
│                    GATEWAY TRANSIT                               │
│                                                                  │
│   HUB VNET (with VPN Gateway)                                   │
│   ┌──────────────────────────────────────────┐                  │
│   │                                          │                  │
│   │   Setting: "Allow gateway transit" = ON  │                  │
│   │                                          │                  │
│   │   ┌────────────────┐                     │                  │
│   │   │  VPN Gateway   │◄────── To On-Prem   │                  │
│   │   └────────────────┘                     │                  │
│   └──────────────────────────────────────────┘                  │
│              │                                                   │
│         (Peering)                                               │
│              │                                                   │
│              ▼                                                   │
│   SPOKE VNET (no gateway)                                       │
│   ┌──────────────────────────────────────────┐                  │
│   │                                          │                  │
│   │   Setting: "Use remote gateways" = ON    │                  │
│   │                                          │                  │
│   │   ┌────────────────┐                     │                  │
│   │   │      VM        │────► Can reach      │                  │
│   │   │                │      on-premises    │                  │
│   │   └────────────────┘      via hub GW     │                  │
│   └──────────────────────────────────────────┘                  │
└─────────────────────────────────────────────────────────────────┘
```

### Gateway Transit Requirements

| Hub VNet | Spoke VNet |
|----------|------------|
| Must have VPN/ExpressRoute gateway deployed | Cannot have own gateway |
| Enable "Allow gateway transit" | Enable "Use remote gateways" |
| Gateway must be deployed before enabling | Peering must exist first |

---

## User-Defined Routes (UDRs)

### Route Table Basics

UDRs override Azure's system routes to control traffic flow.

### Route Types and Priority

```
┌─────────────────────────────────────────────────────────────────┐
│                   ROUTE SELECTION PRIORITY                       │
│                   (Longest Prefix Match)                         │
│                                                                  │
│   1. User-Defined Routes (UDR)                                   │
│         ↓                                                        │
│   2. BGP Routes (from VPN/ExpressRoute)                         │
│         ↓                                                        │
│   3. System Routes                                               │
│                                                                  │
│   Within same source: Longest prefix match wins                  │
│   Example: 10.0.0.0/24 beats 10.0.0.0/16 for traffic to         │
│            10.0.0.50                                             │
└─────────────────────────────────────────────────────────────────┘
```

### Next Hop Types

| Next Hop Type | Description | Use Case |
|---------------|-------------|----------|
| **Virtual network gateway** | Route to VPN/ExpressRoute gateway | On-prem connectivity |
| **Virtual network** | Route within VNet | Keep traffic in VNet |
| **Internet** | Route to internet | Direct internet access |
| **Virtual appliance** | Route to NVA IP address | Firewall, inspection |
| **None** | Drop traffic (black hole) | Block specific routes |

### System Routes (Default)

| Prefix | Next Hop | Notes |
|--------|----------|-------|
| VNet address space | Virtual network | Intra-VNet traffic |
| 0.0.0.0/0 | Internet | Default internet route |
| 10.0.0.0/8 | None | RFC 1918, dropped unless VNet uses it |
| 172.16.0.0/12 | None | RFC 1918, dropped unless VNet uses it |
| 192.168.0.0/16 | None | RFC 1918, dropped unless VNet uses it |
| 100.64.0.0/10 | None | CGNAT range |

---

## Service Chaining

Service chaining routes traffic through an NVA (Network Virtual Appliance) or Azure Firewall for inspection.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        SERVICE CHAINING                                  │
│                                                                          │
│   ┌─────────────────┐                      ┌─────────────────┐          │
│   │   SOURCE VM     │                      │   DESTINATION   │          │
│   │   10.1.1.5      │                      │   10.2.1.5      │          │
│   │   (Spoke 1)     │                      │   (Spoke 2)     │          │
│   └────────┬────────┘                      └────────▲────────┘          │
│            │                                        │                    │
│            │ 1. Outbound to 10.2.1.5               │ 4. Forward to      │
│            │    UDR: 10.2.0.0/16 → 10.0.1.4       │    destination      │
│            │                                        │                    │
│            ▼                                        │                    │
│   ┌─────────────────────────────────────────────────────────┐           │
│   │                    HUB VNET                              │           │
│   │                                                          │           │
│   │   ┌───────────────────────────────────────────────┐     │           │
│   │   │           AZURE FIREWALL / NVA                │     │           │
│   │   │           10.0.1.4                            │     │           │
│   │   │                                               │     │           │
│   │   │   2. Receive traffic                          │     │           │
│   │   │   3. Inspect, log, apply rules                │     │           │
│   │   │   4. Forward if allowed                       │─────┘           │
│   │   │                                               │                 │
│   │   │   ⚠️ IP Forwarding must be ENABLED            │                 │
│   │   └───────────────────────────────────────────────┘                 │
│   │                                                                      │
│   │   UDR on Firewall Subnet (for return traffic):                      │
│   │   • 10.1.0.0/16 → Virtual network                                   │
│   │   • 10.2.0.0/16 → Virtual network                                   │
│   └──────────────────────────────────────────────────────────────────────┘
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Key Service Chaining Requirements

1. **IP Forwarding**: Must be enabled on NVA's NIC
2. **UDRs**: Configure on source subnets pointing to NVA
3. **NVA Configuration**: Firewall rules, NAT, inspection
4. **Peering Settings**: "Allow forwarded traffic" enabled

---

## PowerShell Examples

### Create VNet Peering

```powershell
# Variables
$resourceGroup = "rg-networking-prod"
$hubVnetName = "vnet-hub-prod"
$spokeVnetName = "vnet-spoke1-prod"

# Get VNets
$hubVnet = Get-AzVirtualNetwork -Name $hubVnetName -ResourceGroupName $resourceGroup
$spokeVnet = Get-AzVirtualNetwork -Name $spokeVnetName -ResourceGroupName $resourceGroup

# Create peering from Hub to Spoke (with gateway transit)
Add-AzVirtualNetworkPeering `
    -Name "peer-hub-to-spoke1" `
    -VirtualNetwork $hubVnet `
    -RemoteVirtualNetworkId $spokeVnet.Id `
    -AllowForwardedTraffic `
    -AllowGatewayTransit

# Create peering from Spoke to Hub (use remote gateway)
Add-AzVirtualNetworkPeering `
    -Name "peer-spoke1-to-hub" `
    -VirtualNetwork $spokeVnet `
    -RemoteVirtualNetworkId $hubVnet.Id `
    -AllowForwardedTraffic `
    -UseRemoteGateways

# Verify peering status
Get-AzVirtualNetworkPeering `
    -VirtualNetworkName $hubVnetName `
    -ResourceGroupName $resourceGroup | 
    Select-Object Name, PeeringState, AllowGatewayTransit
```

### Create Global Peering

```powershell
# Cross-region peering
$vnetUKSouth = Get-AzVirtualNetwork -Name "vnet-hub-uks" -ResourceGroupName "rg-networking-uks"
$vnetEastUS = Get-AzVirtualNetwork -Name "vnet-dr-eus" -ResourceGroupName "rg-networking-eus"

# Hub (UK South) to DR (East US)
Add-AzVirtualNetworkPeering `
    -Name "peer-uks-to-eus" `
    -VirtualNetwork $vnetUKSouth `
    -RemoteVirtualNetworkId $vnetEastUS.Id `
    -AllowForwardedTraffic

# DR (East US) to Hub (UK South)
Add-AzVirtualNetworkPeering `
    -Name "peer-eus-to-uks" `
    -VirtualNetwork $vnetEastUS `
    -RemoteVirtualNetworkId $vnetUKSouth.Id `
    -AllowForwardedTraffic
```

### Create Route Table with UDRs

```powershell
# Create route table
$routeTable = New-AzRouteTable `
    -Name "rt-spoke-to-firewall" `
    -ResourceGroupName $resourceGroup `
    -Location "uksouth" `
    -DisableBgpRoutePropagation

# Add route to force traffic through firewall
Add-AzRouteConfig `
    -Name "route-to-internet" `
    -RouteTable $routeTable `
    -AddressPrefix "0.0.0.0/0" `
    -NextHopType "VirtualAppliance" `
    -NextHopIpAddress "10.0.1.4" | Set-AzRouteTable

# Add route for spoke-to-spoke traffic via firewall
Add-AzRouteConfig `
    -Name "route-to-spoke2" `
    -RouteTable $routeTable `
    -AddressPrefix "10.2.0.0/16" `
    -NextHopType "VirtualAppliance" `
    -NextHopIpAddress "10.0.1.4" | Set-AzRouteTable

# Associate route table with subnet
$spokeVnet = Get-AzVirtualNetwork -Name "vnet-spoke1-prod" -ResourceGroupName $resourceGroup
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "snet-workload" -VirtualNetwork $spokeVnet

Set-AzVirtualNetworkSubnetConfig `
    -Name "snet-workload" `
    -VirtualNetwork $spokeVnet `
    -AddressPrefix $subnet.AddressPrefix `
    -RouteTable $routeTable | Set-AzVirtualNetwork
```

### Enable IP Forwarding on NVA

```powershell
# Get NVA NIC
$nic = Get-AzNetworkInterface -Name "nic-nva-prod" -ResourceGroupName $resourceGroup

# Enable IP forwarding
$nic.EnableIPForwarding = $true
$nic | Set-AzNetworkInterface

# Verify
Get-AzNetworkInterface -Name "nic-nva-prod" -ResourceGroupName $resourceGroup | 
    Select-Object Name, EnableIPForwarding
```

### View Effective Routes

```powershell
# Get effective routes for a NIC
Get-AzEffectiveRouteTable `
    -NetworkInterfaceName "nic-vm-prod" `
    -ResourceGroupName $resourceGroup | 
    Select-Object Source, AddressPrefix, NextHopType, NextHopIpAddress | 
    Format-Table -AutoSize
```

---

## Hub-Spoke Design Patterns

### Pattern 1: Single Hub with Azure Firewall

```
┌────────────────────────────────────────────────────────────────┐
│  Best for: Centralized security, simple management              │
│                                                                 │
│  ┌─────────────┐                                               │
│  │    HUB      │                                               │
│  │  - Firewall │◄─────► Spoke 1 (Prod)                         │
│  │  - Gateway  │◄─────► Spoke 2 (Dev)                          │
│  │  - Bastion  │◄─────► Spoke 3 (Test)                         │
│  └─────────────┘                                               │
│                                                                 │
│  Pros: Simple, centralized policy                              │
│  Cons: Single point of failure, regional                       │
└────────────────────────────────────────────────────────────────┘
```

### Pattern 2: Hub-Spoke with NVA (Third-Party)

```
┌────────────────────────────────────────────────────────────────┐
│  Best for: Existing firewall vendor, advanced features          │
│                                                                 │
│  ┌─────────────────────────┐                                   │
│  │          HUB            │                                   │
│  │  ┌──────────────────┐   │                                   │
│  │  │  NVA (HA Pair)   │   │                                   │
│  │  │  Active/Passive  │   │                                   │
│  │  │  or Active/Active│   │                                   │
│  │  └──────────────────┘   │                                   │
│  │  ┌──────────────────┐   │                                   │
│  │  │  Internal LB     │   │◄────► Spokes                      │
│  │  │  (Frontend for   │   │                                   │
│  │  │   NVA cluster)   │   │                                   │
│  │  └──────────────────┘   │                                   │
│  └─────────────────────────┘                                   │
│                                                                 │
│  UDRs point to Internal LB frontend IP (not individual NVAs)    │
└────────────────────────────────────────────────────────────────┘
```

### Pattern 3: Multi-Region Hub-Spoke

```
┌────────────────────────────────────────────────────────────────┐
│  Best for: Global deployments, disaster recovery                │
│                                                                 │
│  Region 1 (Primary)           Region 2 (DR)                    │
│  ┌─────────────┐              ┌─────────────┐                  │
│  │  Hub-1      │◄──Global────►│  Hub-2      │                  │
│  │             │   Peering    │             │                  │
│  └──────┬──────┘              └──────┬──────┘                  │
│         │                            │                          │
│    ┌────┴────┐                  ┌────┴────┐                     │
│    ▼         ▼                  ▼         ▼                     │
│  Spoke1   Spoke2              Spoke3   Spoke4                   │
│                                                                 │
│  Consider: Azure Virtual WAN for simplified management          │
└────────────────────────────────────────────────────────────────┘
```

---

## Exam Tips & Gotchas

### 🎯 High-Priority Topics

1. **Non-transitive peering**: VNet A↔B and B↔C does NOT mean A↔C
2. **Gateway transit**: Hub enables "Allow gateway transit", Spoke enables "Use remote gateways"
3. **UDR priority**: Longest prefix match, then UDR > BGP > System
4. **IP Forwarding**: Must be enabled on NVA NIC for service chaining

### ⚠️ Common Gotchas

| Scenario | Gotcha |
|----------|--------|
| Add peering to existing VNet | Cannot overlap address spaces |
| Global peering | Basic Load Balancer not supported |
| Gateway transit | Cannot enable if spoke has own gateway |
| UDR on GatewaySubnet | Be very careful - can break connectivity |
| NVA traffic not flowing | Check IP forwarding on NIC AND OS level |
| Peering shows "Initiated" | Reciprocal peering not yet created |
| Route table not working | Check it's associated with correct subnet |

### 📝 Exam Question Patterns

```
Q: "VNet-A peers with VNet-B, VNet-B peers with VNet-C. Can VNet-A reach VNet-C?"
A: No - peering is not transitive. Need direct peering or hub-spoke with NVA.

Q: "Spoke VNet needs to use hub's VPN gateway. What settings?"
A: Hub: "Allow gateway transit" = Yes
   Spoke: "Use remote gateways" = Yes
   Spoke: Cannot have its own gateway

Q: "Traffic from spoke isn't going through firewall despite UDR. What's wrong?"
A: Check:
   1. Route table associated with correct subnet
   2. UDR has correct next hop IP (firewall private IP)
   3. IP forwarding enabled on firewall NIC
   4. Peering has "Allow forwarded traffic" enabled

Q: "What route wins: UDR 10.0.0.0/16 or BGP 10.0.0.0/24?"
A: BGP 10.0.0.0/24 wins due to longest prefix match (more specific)
```

---

## Quick Reference

### Peering Configuration Matrix

| Scenario | Hub Setting | Spoke Setting |
|----------|-------------|---------------|
| Basic connectivity | Allow VNet access | Allow VNet access |
| Gateway sharing | + Allow gateway transit | + Use remote gateways |
| Service chaining | + Allow forwarded traffic | + Allow forwarded traffic |

### UDR Next Hop Type Reference

| Next Hop | When to Use |
|----------|-------------|
| VirtualAppliance | NVA, Azure Firewall, third-party firewall |
| VirtualNetworkGateway | Force to VPN/ExpressRoute |
| VNetLocal | Keep in VNet (override BGP) |
| Internet | Direct to internet |
| None | Black hole (drop traffic) |

### Key Azure CLI Commands

```bash
# List peerings
az network vnet peering list -g <rg> --vnet-name <vnet> -o table

# Show peering details
az network vnet peering show -g <rg> --vnet-name <vnet> -n <peering-name>

# List route tables
az network route-table list -g <rg> -o table

# Show effective routes for a NIC
az network nic show-effective-route-table -g <rg> -n <nic-name> -o table

# Create UDR
az network route-table route create \
    -g <rg> \
    --route-table-name <rt-name> \
    -n <route-name> \
    --address-prefix 0.0.0.0/0 \
    --next-hop-type VirtualAppliance \
    --next-hop-ip-address 10.0.1.4
```

### Peering Limits

| Resource | Limit |
|----------|-------|
| Peerings per VNet | 500 |
| Address prefixes advertised from Azure to on-prem via ExpressRoute with Global Reach | 4,000 |
| Address prefixes advertised from on-prem to Azure via ExpressRoute private peering | 4,000 |

---

## Related Topics

- [VNet, Subnets & IP Addressing](VNet_Subnets_IP_Addressing.md)
- [Azure DNS](Azure_DNS.md)
- [Azure Firewall](../Design_Implement_Azure_Network_Security_Services/)
- [VPN Gateway](../Design_Implement_Manage_Connectivity_Services/)
