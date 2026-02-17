---
tags:
  - AZ-700
  - azure/networking
  - domain/connectivity
  - expressroute
  - private-peering
  - microsoft-peering
  - global-reach
  - fastpath
  - expressroute-direct
  - high-availability
  - hybrid-connectivity
aliases:
  - ExpressRoute
  - Azure ExpressRoute
  - ER
created: 2025-01-01
updated: 2026-02-07
---

# Azure ExpressRoute - AZ-700 Study Notes

> [!info] Related Notes
> - [[VPN_Gateway]] — VPN as backup/coexistence with ExpressRoute
> - [[Virtual_WAN]] — ExpressRoute in Virtual WAN hubs
> - [[Azure_Route_Server]] — Route exchange between ExpressRoute and NVAs
> - [[VNet_Peering_Routing]] — Gateway transit for ExpressRoute across peered VNets
> - [[Azure_DNS]] — DNS resolution over ExpressRoute private peering
> - [[Private_Endpoints]] — Private endpoint access over ExpressRoute

## Table of Contents
- [Overview and Benefits](#overview-and-benefits)
- [ExpressRoute SKUs](#expressroute-skus)
- [Connectivity Models](#connectivity-models)
- [Peering Types](#peering-types)
- [ExpressRoute Gateway SKUs](#expressroute-gateway-skus)
- [Global Reach](#global-reach)
- [FastPath](#fastpath)
- [Redundancy and High Availability](#redundancy-and-high-availability)
- [ExpressRoute vs VPN Gateway](#expressroute-vs-vpn-gateway)
- [PowerShell Examples](#powershell-examples)
- [Exam Tips](#exam-tips)

---

## Overview and Benefits

### What is ExpressRoute?

Azure ExpressRoute enables you to create **private connections** between Azure datacenters and infrastructure on your premises or in a colocation environment. ExpressRoute connections **do NOT go over the public Internet**, providing more reliability, faster speeds, consistent latencies, and higher security.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        ExpressRoute Architecture                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   On-Premises                    Provider Edge           Microsoft Edge      │
│   ┌─────────┐                    ┌─────────┐            ┌─────────────┐     │
│   │ Customer│     Layer 2/3      │  PE     │  Private   │   MSEE      │     │
│   │ Router  │◄──────────────────►│ Router  │◄──────────►│  (Primary)  │     │
│   │         │                    │         │            │             │     │
│   └────┬────┘                    └────┬────┘            └──────┬──────┘     │
│        │                              │                        │            │
│        │                              │                        ▼            │
│        │                              │                 ┌─────────────┐     │
│        │                              │                 │   Azure     │     │
│   ┌────┴────┐                    ┌────┴────┐           │   VNets     │     │
│   │ Customer│     Layer 2/3      │  PE     │  Private   │             │     │
│   │ Router  │◄──────────────────►│ Router  │◄──────────►│   MSEE      │     │
│   │(Standby)│                    │(Standby)│            │ (Secondary) │     │
│   └─────────┘                    └─────────┘            └─────────────┘     │
│                                                                              │
│   MSEE = Microsoft Enterprise Edge Router                                   │
│   PE = Provider Edge Router                                                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Benefits

| Benefit | Description |
|---------|-------------|
| **Private Connectivity** | Traffic does not traverse the public Internet |
| **Reliability** | Built-in redundancy with 99.95% SLA |
| **Speed** | Bandwidth from 50 Mbps to 100 Gbps |
| **Low Latency** | Consistent, predictable latency |
| **Security** | No exposure to Internet-based threats |
| **Global Reach** | Connect to Microsoft cloud services worldwide |
| **QoS Support** | Quality of Service for voice/video traffic |

### ExpressRoute Components

1. **ExpressRoute Circuit** - Logical connection between on-premises and Microsoft
2. **ExpressRoute Gateway** - VNet gateway that connects VNets to the circuit
3. **Peerings** - BGP sessions for routing (Private and Microsoft)
4. **Connection** - Links the gateway to the circuit

---

## ExpressRoute SKUs

### Circuit SKU Comparison

| Feature | Local | Standard | Premium |
|---------|-------|----------|---------|
| **Bandwidth Options** | 1, 2, 5, 10 Gbps | 50 Mbps - 10 Gbps | 50 Mbps - 10 Gbps |
| **Geopolitical Region Access** | Local region only | Same geopolitical region | Global (all regions) |
| **VNet Links** | Unlimited | 10 | 100 |
| **Route Prefixes (Private Peering)** | Unlimited | 4,000 | 10,000 |
| **Route Prefixes (Microsoft Peering)** | 200 | 200 | 200 |
| **Microsoft 365 Access** | ❌ No | ❌ No | ✅ Yes |
| **Global Reach** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Metered Data** | Unlimited outbound | Metered | Metered |
| **Use Case** | High bandwidth, local | Regional connectivity | Global enterprise |

### Bandwidth Options

```
┌───────────────────────────────────────────────────────────────────┐
│                    ExpressRoute Bandwidth Tiers                    │
├───────────────────────────────────────────────────────────────────┤
│                                                                    │
│   Standard/Premium:                                                │
│   ├── 50 Mbps                                                     │
│   ├── 100 Mbps                                                    │
│   ├── 200 Mbps                                                    │
│   ├── 500 Mbps                                                    │
│   ├── 1 Gbps                                                      │
│   ├── 2 Gbps                                                      │
│   ├── 5 Gbps                                                      │
│   └── 10 Gbps                                                     │
│                                                                    │
│   Local SKU:                                                       │
│   ├── 1 Gbps                                                      │
│   ├── 2 Gbps                                                      │
│   ├── 5 Gbps                                                      │
│   └── 10 Gbps                                                     │
│                                                                    │
│   ExpressRoute Direct:                                             │
│   ├── 10 Gbps                                                     │
│   └── 100 Gbps                                                    │
│                                                                    │
└───────────────────────────────────────────────────────────────────┘
```

### SKU Selection Guide

| Scenario | Recommended SKU |
|----------|-----------------|
| High-bandwidth workloads in same metro area | **Local** |
| Connect to VNets in same geopolitical region | **Standard** |
| Global connectivity across regions | **Premium** |
| Microsoft 365 connectivity required | **Premium** |
| More than 10 VNet connections needed | **Premium** |

> 💡 **Note**: You can upgrade from Standard to Premium without downtime, but cannot downgrade.

---

## Connectivity Models

### 1. CloudExchange Co-location

Connect through a provider's exchange at a colocation facility.

```
┌────────────────────────────────────────────────────────────────────┐
│                    CloudExchange Co-location                        │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌──────────────┐     ┌─────────────────┐     ┌───────────────┐  │
│   │  On-Premises │     │   Colocation    │     │    Azure      │  │
│   │  Network     │     │   Facility      │     │               │  │
│   │              │     │                 │     │               │  │
│   │  ┌────────┐  │     │  ┌───────────┐  │     │  ┌─────────┐  │  │
│   │  │ Router │──┼─────┼──│ Provider  │──┼─────┼──│  MSEE   │  │  │
│   │  └────────┘  │     │  │ Exchange  │  │     │  └─────────┘  │  │
│   │              │     │  └───────────┘  │     │               │  │
│   └──────────────┘     └─────────────────┘     └───────────────┘  │
│                                                                     │
│   Example Providers: Equinix, Megaport, CoreSite                   │
└────────────────────────────────────────────────────────────────────┘
```

**Characteristics:**
- Layer 2 or managed Layer 3 connectivity
- Ideal for enterprises already in colocation facilities
- Quick provisioning through exchange portal

### 2. Point-to-Point Ethernet Connection

Dedicated fiber connection from your premises to Azure.

```
┌────────────────────────────────────────────────────────────────────┐
│                    Point-to-Point Ethernet                          │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌──────────────┐                              ┌───────────────┐  │
│   │  On-Premises │                              │    Azure      │  │
│   │  Datacenter  │     Dedicated Fiber          │               │  │
│   │              │     ════════════════════════ │               │  │
│   │  ┌────────┐  │                              │  ┌─────────┐  │  │
│   │  │ Router │──┼──────────────────────────────┼──│  MSEE   │  │  │
│   │  └────────┘  │                              │  └─────────┘  │  │
│   │              │                              │               │  │
│   └──────────────┘                              └───────────────┘  │
│                                                                     │
│   Example Providers: AT&T, Verizon, British Telecom                │
└────────────────────────────────────────────────────────────────────┘
```

**Characteristics:**
- Layer 2 or managed Layer 3 connectivity
- Dedicated link, not shared with other customers
- Higher cost but more control

### 3. Any-to-Any (IPVPN) Connection

Integrate Azure into your existing WAN using MPLS.

```
┌────────────────────────────────────────────────────────────────────┐
│                    Any-to-Any (IPVPN/MPLS)                          │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌─────────┐          ┌─────────────────────┐     ┌───────────┐  │
│   │ Branch  │          │                     │     │   Azure   │  │
│   │ Office  │──────────┤                     │     │           │  │
│   └─────────┘          │                     │     │           │  │
│                        │     Provider        │     │ ┌───────┐ │  │
│   ┌─────────┐          │     MPLS/IP         │─────┼─│ MSEE  │ │  │
│   │  HQ     │──────────┤     Network         │     │ └───────┘ │  │
│   │         │          │                     │     │           │  │
│   └─────────┘          │                     │     │           │  │
│                        │                     │     │           │  │
│   ┌─────────┐          │                     │     └───────────┘  │
│   │ Remote  │──────────┤                     │                    │
│   │ Site    │          └─────────────────────┘                    │
│   └─────────┘                                                      │
│                                                                     │
│   Azure becomes another "branch" on your WAN                       │
└────────────────────────────────────────────────────────────────────┘
```

**Characteristics:**
- Azure integrated into existing WAN
- Any-to-any connectivity between all sites
- Provider manages routing

### 4. ExpressRoute Direct

Direct 10 Gbps or 100 Gbps physical connection to Microsoft.

```
┌────────────────────────────────────────────────────────────────────┐
│                      ExpressRoute Direct                            │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌──────────────┐                              ┌───────────────┐  │
│   │  Customer    │        Direct Physical       │  Microsoft    │  │
│   │  Network     │        Fiber Connection      │  Peering      │  │
│   │              │                              │  Location     │  │
│   │  ┌────────┐  │     10G or 100G Port Pair    │               │  │
│   │  │ Router │──┼══════════════════════════════┼──│  MSEE    │  │  │
│   │  │        │──┼══════════════════════════════┼──│  (Pair)  │  │  │
│   │  └────────┘  │     (Primary + Secondary)    │               │  │
│   │              │                              │               │  │
│   └──────────────┘                              └───────────────┘  │
│                                                                     │
│   Features:                                                         │
│   • Direct connection bypassing service provider                   │
│   • Create multiple circuits on same port pair                     │
│   • Support for Local, Standard, and Premium SKUs                  │
│   • MACsec encryption at Layer 2                                   │
└────────────────────────────────────────────────────────────────────┘
```

**Characteristics:**
- Bypass service providers entirely
- 10 Gbps or 100 Gbps port pairs
- Multiple circuits on same physical connection
- MACsec encryption support
- Ideal for massive data ingestion scenarios

### Connectivity Models Comparison

| Model | Layer | Bandwidth | Best For |
|-------|-------|-----------|----------|
| **CloudExchange** | L2/L3 | 50 Mbps - 10 Gbps | Colocation customers |
| **Point-to-Point** | L2/L3 | 50 Mbps - 10 Gbps | Dedicated connectivity |
| **Any-to-Any** | L3 | 50 Mbps - 10 Gbps | Existing MPLS WAN |
| **ExpressRoute Direct** | L2 | 10/100 Gbps | High bandwidth, MACsec |

---

## Peering Types

ExpressRoute supports two peering types through BGP sessions:

```
┌────────────────────────────────────────────────────────────────────┐
│                    ExpressRoute Peering Types                       │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   On-Premises Network                     Azure                     │
│   ┌──────────────────┐                   ┌──────────────────────┐  │
│   │                  │                   │                      │  │
│   │  ┌────────────┐  │   Private         │  ┌────────────────┐  │  │
│   │  │ Servers    │──┼───Peering─────────┼──│ Virtual       │  │  │
│   │  │ VMs        │  │   10.x.x.x        │  │ Networks      │  │  │
│   │  └────────────┘  │                   │  │ (VNets)       │  │  │
│   │                  │                   │  └────────────────┘  │  │
│   │  ┌────────────┐  │                   │                      │  │
│   │  │ Users      │  │   Microsoft       │  ┌────────────────┐  │  │
│   │  │ Clients    │──┼───Peering─────────┼──│ Microsoft 365  │  │  │
│   │  │            │  │   Public IPs      │  │ Dynamics 365   │  │  │
│   │  └────────────┘  │                   │  │ Azure PaaS     │  │  │
│   │                  │                   │  └────────────────┘  │  │
│   └──────────────────┘                   └──────────────────────┘  │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

### Private Peering

| Aspect | Details |
|--------|---------|
| **Purpose** | Connect to Azure VNets (IaaS resources) |
| **Address Space** | Private IP addresses (RFC 1918) |
| **Route Limits** | 4,000 (Standard) / 10,000 (Premium) |
| **Bidirectional** | Yes - on-premises can reach Azure and vice versa |
| **NAT Required** | No |
| **Default** | Enabled when you connect VNets |

**Private Peering Configuration:**
- Customer subnet: /30 or /126 for BGP session (e.g., 10.0.0.0/30)
- Primary link: Uses first /30
- Secondary link: Uses second /30
- VLAN ID: Required for traffic tagging

### Microsoft Peering

| Aspect | Details |
|--------|---------|
| **Purpose** | Connect to Microsoft 365, Dynamics 365, Azure PaaS (public endpoints) |
| **Address Space** | Public IP addresses (owned by you or NAT) |
| **Route Limits** | 200 prefixes |
| **Services** | Microsoft 365, Azure Storage, Azure SQL, etc. |
| **NAT Required** | Yes - must NAT to public IPs you own |
| **Route Filters** | Required to select which services to access |

**Microsoft Peering Requirements:**
1. Public IP addresses for NAT (owned or allocated by provider)
2. Routing registry (IRR) registration
3. Autonomous System Number (ASN)
4. Route filters to select BGP communities

```
┌────────────────────────────────────────────────────────────────────┐
│              Microsoft Peering with Route Filters                   │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   On-Premises                         Microsoft Services            │
│   ┌─────────────┐                    ┌──────────────────────────┐  │
│   │             │                    │  ┌─────────────────────┐ │  │
│   │  ┌───────┐  │   Route Filter     │  │ Azure Storage       │ │  │
│   │  │ NAT   │  │   ┌──────────┐     │  │ (12076:5001)        │ │  │
│   │  │Device │──┼───│ Allow:   │─────┼─►│                     │ │  │
│   │  │       │  │   │ Storage  │     │  └─────────────────────┘ │  │
│   │  └───────┘  │   │ SQL      │     │  ┌─────────────────────┐ │  │
│   │             │   │ Exchange │     │  │ Azure SQL           │ │  │
│   │ Public IPs: │   └──────────┘     │  │ (12076:5050)        │ │  │
│   │ 203.0.113.x │                    │  └─────────────────────┘ │  │
│   └─────────────┘                    │  ┌─────────────────────┐ │  │
│                                      │  │ Exchange Online     │ │  │
│                                      │  │ (12076:5100)        │ │  │
│                                      │  └─────────────────────┘ │  │
│                                      └──────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

### BGP Community Values for Route Filters

| Service | BGP Community |
|---------|---------------|
| Exchange Online | 12076:5100 |
| SharePoint Online | 12076:5200 |
| Skype for Business | 12076:5300 |
| Azure Active Directory | 12076:5400 |
| Other Microsoft 365 | 12076:5000 |
| Azure Storage | 12076:5001 |
| Azure SQL | 12076:5050 |

### Peering Comparison Table

| Feature | Private Peering | Microsoft Peering |
|---------|-----------------|-------------------|
| **Target Services** | Azure VNets (IaaS) | Microsoft 365, Azure PaaS |
| **IP Addresses** | Private (RFC 1918) | Public IPs |
| **NAT Required** | No | Yes |
| **Route Filters** | Not required | Required |
| **Gateway Needed** | Yes (ER Gateway) | No |
| **Typical Use** | VM connectivity | SaaS access |

> ⚠️ **Important**: Azure Public Peering is **deprecated**. Use Microsoft Peering for PaaS services.

---

## ExpressRoute Gateway SKUs

### Gateway SKU Comparison

| SKU | Max Circuits | Max Connections | Throughput | FastPath | Zone Redundant |
|-----|--------------|-----------------|------------|----------|----------------|
| **Standard** | 4 | 16 | 1 Gbps | ❌ | ❌ |
| **HighPerformance** | 8 | 16 | 2 Gbps | ❌ | ❌ |
| **UltraPerformance** | 16 | 16 | 10 Gbps | ✅ | ❌ |
| **ErGw1Az** | 4 | 16 | 1 Gbps | ❌ | ✅ |
| **ErGw2Az** | 8 | 16 | 2 Gbps | ❌ | ✅ |
| **ErGw3Az** | 16 | 16 | 10 Gbps | ✅ | ✅ |
| **ErGwScale** | 16 | 40 | 40 Gbps | ✅ | ✅ |

```
┌────────────────────────────────────────────────────────────────────┐
│                 Gateway SKU Selection Guide                         │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Need Zone Redundancy?                                            │
│         │                                                          │
│    ┌────┴────┐                                                     │
│   Yes       No                                                     │
│    │         │                                                     │
│    ▼         ▼                                                     │
│  ErGw*Az   Standard/High/Ultra                                     │
│    │                                                               │
│    ├── ErGw1Az  (1 Gbps)  - Basic HA                              │
│    ├── ErGw2Az  (2 Gbps)  - Better throughput                     │
│    ├── ErGw3Az  (10 Gbps) - High throughput + FastPath            │
│    └── ErGwScale (40 Gbps) - Maximum scale                        │
│                                                                     │
│   FastPath Required?                                               │
│   └── Only: UltraPerformance, ErGw3Az, ErGwScale                  │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

### Gateway Deployment Considerations

| Consideration | Recommendation |
|---------------|----------------|
| **Production workloads** | Use Az SKUs for zone redundancy |
| **High bandwidth needs** | ErGw3Az or ErGwScale |
| **Cost sensitive** | Standard or ErGw1Az |
| **Multiple circuits** | HighPerformance+ or ErGw2Az+ |
| **FastPath required** | UltraPerformance, ErGw3Az, or ErGwScale |

### Gateway Subnet Requirements

- Subnet name must be **GatewaySubnet**
- Minimum size: **/27** (recommended /27 or larger)
- Cannot have NSGs on GatewaySubnet
- Cannot have route tables with 0.0.0.0/0 route to NVA

---

## Global Reach

ExpressRoute Global Reach connects your on-premises networks together through the Microsoft backbone network.

```
┌────────────────────────────────────────────────────────────────────┐
│                    ExpressRoute Global Reach                        │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Site A (London)                         Site B (New York)        │
│   ┌─────────────┐                         ┌─────────────┐          │
│   │ On-Premises │                         │ On-Premises │          │
│   │ Network     │                         │ Network     │          │
│   │  10.1.0.0   │                         │  10.2.0.0   │          │
│   └──────┬──────┘                         └──────┬──────┘          │
│          │                                       │                  │
│          ▼                                       ▼                  │
│   ┌─────────────┐                         ┌─────────────┐          │
│   │ ExpressRoute│                         │ ExpressRoute│          │
│   │ Circuit 1   │                         │ Circuit 2   │          │
│   │ (London)    │                         │ (New York)  │          │
│   └──────┬──────┘                         └──────┬──────┘          │
│          │                                       │                  │
│          │      ┌─────────────────────┐          │                  │
│          └──────┤  Microsoft Global   ├──────────┘                  │
│                 │  Backbone Network   │                             │
│                 │                     │                             │
│                 │  Global Reach       │                             │
│                 │  Connection         │                             │
│                 └─────────────────────┘                             │
│                                                                     │
│   Traffic Flow: Site A ──► ER Circuit 1 ──► Microsoft ──►          │
│                 ER Circuit 2 ──► Site B                             │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

### Global Reach Use Cases

| Scenario | Description |
|----------|-------------|
| **Disaster Recovery** | Replicate data between sites via Microsoft backbone |
| **Branch Connectivity** | Connect global offices without separate WAN |
| **Data Transfer** | Move large datasets between regions efficiently |
| **Hybrid Applications** | Applications spanning multiple on-premises sites |

### Global Reach Requirements & Limitations

| Requirement | Details |
|-------------|---------|
| **SKU** | Standard or Premium (Local also supported) |
| **ASN** | Must be different for each circuit if customer-managed |
| **IP Addresses** | /29 subnet for Global Reach link (non-overlapping) |
| **Region Support** | Not available in all regions (check availability) |

### Regions Without Global Reach
- China
- Government regions (partial support)
- Some newer regions (verify current availability)

---

## FastPath

FastPath improves data path performance by sending traffic directly to VMs, bypassing the gateway.

```
┌────────────────────────────────────────────────────────────────────┐
│                    Without FastPath (Normal)                        │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   On-Premises        ExpressRoute         VNet                      │
│   ┌─────────┐       ┌───────────┐       ┌───────────────────────┐  │
│   │         │       │   MSEE    │       │   ┌───────────────┐   │  │
│   │ Server  │──────►│           │──────►│   │ ER Gateway    │   │  │
│   │         │       └───────────┘       │   │ (data path)   │   │  │
│   └─────────┘                           │   └───────┬───────┘   │  │
│                                         │           │           │  │
│                                         │           ▼           │  │
│                                         │   ┌───────────────┐   │  │
│                                         │   │     VM        │   │  │
│                                         │   └───────────────┘   │  │
│                                         └───────────────────────┘  │
│                                                                     │
├────────────────────────────────────────────────────────────────────┤
│                    With FastPath                                    │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   On-Premises        ExpressRoute         VNet                      │
│   ┌─────────┐       ┌───────────┐       ┌───────────────────────┐  │
│   │         │       │   MSEE    │       │   ┌───────────────┐   │  │
│   │ Server  │──────►│           │───┐   │   │ ER Gateway    │   │  │
│   │         │       └───────────┘   │   │   │ (control only)│   │  │
│   └─────────┘                       │   │   └───────────────┘   │  │
│                                     │   │                       │  │
│                                     │   │   ┌───────────────┐   │  │
│                                     └───┼──►│     VM        │   │  │
│                                         │   └───────────────┘   │  │
│                         (Direct path    └───────────────────────┘  │
│                          bypasses                                  │
│                          gateway)                                  │
└────────────────────────────────────────────────────────────────────┘
```

### FastPath Requirements

| Requirement | Details |
|-------------|---------|
| **Gateway SKUs** | UltraPerformance, ErGw3Az, or ErGwScale only |
| **Circuit Bandwidth** | Any bandwidth |
| **Configuration** | Enabled per connection |

### FastPath Limitations

| Limitation | Description |
|------------|-------------|
| **Private Link** | Traffic to Private Endpoints goes through gateway |
| **VNet Peering** | Traffic to peered VNets goes through gateway |
| **Basic Load Balancer** | Not supported with FastPath |
| **UDRs** | Custom routes on GatewaySubnet not honored for FastPath traffic |

### When to Use FastPath

| Scenario | Recommendation |
|----------|----------------|
| **Latency-sensitive workloads** | ✅ Enable FastPath |
| **High throughput requirements** | ✅ Enable FastPath |
| **Private Endpoints in use** | ⚠️ FastPath won't help (traffic uses gateway) |
| **Standard gateway SKU** | ❌ Cannot use FastPath |

---

## Redundancy and High Availability

### Built-in Redundancy

ExpressRoute circuits include automatic redundancy:

```
┌────────────────────────────────────────────────────────────────────┐
│                    ExpressRoute Redundancy                          │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   ┌──────────────────────────────────────────────────────────────┐ │
│   │                    Single Circuit Design                      │ │
│   │                                                               │ │
│   │   On-Premises     Provider Edge      Microsoft Edge  Azure   │ │
│   │   ┌─────────┐     ┌─────────┐       ┌─────────┐    ┌──────┐ │ │
│   │   │ Router  │═════│ PE-1    │═══════│ MSEE-1  │════│      │ │ │
│   │   │         │     │         │       │(Primary)│    │ VNet │ │ │
│   │   │         │     └─────────┘       └─────────┘    │      │ │ │
│   │   │         │     ┌─────────┐       ┌─────────┐    │      │ │ │
│   │   │         │═════│ PE-2    │═══════│ MSEE-2  │════│      │ │ │
│   │   │         │     │         │       │(Second) │    │      │ │ │
│   │   └─────────┘     └─────────┘       └─────────┘    └──────┘ │ │
│   │                                                               │ │
│   │   SLA: 99.95%                                                │ │
│   └──────────────────────────────────────────────────────────────┘ │
│                                                                     │
│   ┌──────────────────────────────────────────────────────────────┐ │
│   │                    Dual Circuit Design (HA)                   │ │
│   │                                                               │ │
│   │   Location 1                              Location 2          │ │
│   │   ┌─────────┐    ┌─────────────────────┐  ┌─────────┐        │ │
│   │   │Circuit 1│    │                     │  │Circuit 2│        │ │
│   │   │ (MSEE)  │════│    Azure VNet       │══│ (MSEE)  │        │ │
│   │   └────┬────┘    │    ┌───────────┐    │  └────┬────┘        │ │
│   │        │         │    │ ER Gateway│    │       │             │ │
│   │        └─────────┼────│ (Zone HA) │────┼───────┘             │ │
│   │                  │    └───────────┘    │                     │ │
│   │                  │         ║           │                     │ │
│   │                  │    ┌────╨─────┐     │                     │ │
│   │                  │    │   VMs    │     │                     │ │
│   │                  │    └──────────┘     │                     │ │
│   │                  └─────────────────────┘                     │ │
│   │                                                               │ │
│   │   SLA: 99.99%                                                │ │
│   └──────────────────────────────────────────────────────────────┘ │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

### High Availability Patterns

| Pattern | Description | SLA |
|---------|-------------|-----|
| **Single Circuit** | Two paths (primary/secondary) | 99.95% |
| **Dual Circuit (same metro)** | Two circuits at same location | 99.95% |
| **Dual Circuit (different metro)** | Two circuits at different locations | 99.99% |
| **Zone-Redundant Gateway** | ErGw*Az SKUs | Survives zone failure |

### Best Practices for HA

1. **Use Zone-Redundant Gateways**
   - Deploy ErGw1Az, ErGw2Az, or ErGw3Az
   - Protects against availability zone failures

2. **Deploy Circuits at Different Peering Locations**
   ```
   Circuit 1: London    ──┐
                         ├──► Both connect to same VNet
   Circuit 2: Amsterdam ──┘
   ```

3. **Use Active-Active Connections**
   - Configure BGP with equal AS path length
   - Traffic load-balances across both circuits

4. **Implement Site-to-Site VPN Backup**
   ```
   Primary:   ExpressRoute (Private Peering)
   Backup:    Site-to-Site VPN over Internet
   Failover:  Automatic via BGP weights
   ```

### ExpressRoute + VPN Coexistence

```
┌────────────────────────────────────────────────────────────────────┐
│            ExpressRoute with VPN Backup Architecture                │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   On-Premises                                Azure VNet             │
│   ┌───────────────┐                         ┌───────────────────┐  │
│   │               │                         │                   │  │
│   │  ┌─────────┐  │   ExpressRoute          │  ┌─────────────┐  │  │
│   │  │ER Router│══╪══(Primary - BGP AS      ═══│ER Gateway   │  │  │
│   │  │         │  │   weight lower)         │  │             │  │  │
│   │  └─────────┘  │                         │  └─────────────┘  │  │
│   │               │                         │                   │  │
│   │  ┌─────────┐  │   IPsec VPN             │  ┌─────────────┐  │  │
│   │  │VPN      │──╪──(Backup - BGP AS  ─────┼──│VPN Gateway  │  │  │
│   │  │Device   │  │   weight higher)        │  │             │  │  │
│   │  └─────────┘  │                         │  └─────────────┘  │  │
│   │               │                         │                   │  │
│   └───────────────┘                         └───────────────────┘  │
│                                                                     │
│   BGP Configuration:                                               │
│   - ExpressRoute: AS Path prepend LESS (preferred)                │
│   - VPN Gateway:  AS Path prepend MORE (backup)                   │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

---

## ExpressRoute vs VPN Gateway

### Comparison Table

| Feature | ExpressRoute | VPN Gateway |
|---------|--------------|-------------|
| **Connection Type** | Private (MPLS/Direct) | Public Internet (IPsec) |
| **Max Bandwidth** | 100 Gbps | 10 Gbps |
| **Latency** | Predictable, low | Variable |
| **SLA** | 99.95% - 99.99% | 99.9% - 99.95% |
| **Setup Time** | Days to weeks | Minutes to hours |
| **Cost** | Higher | Lower |
| **Security** | Private network | Encrypted tunnel |
| **Microsoft 365 Access** | Yes (Premium) | No |
| **Redundancy** | Built-in dual path | Active-active config |
| **Global Reach** | Yes | Via Virtual WAN |
| **Use Case** | Enterprise, high bandwidth | SMB, backup link |

### Decision Matrix

```
┌────────────────────────────────────────────────────────────────────┐
│                    Connectivity Decision Matrix                     │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Requirement Analysis:                                            │
│                                                                     │
│   ┌─────────────────────────────────────────────────────────────┐  │
│   │  Bandwidth > 10 Gbps?  ──YES──►  ExpressRoute Direct        │  │
│   └─────────────┬───────────────────────────────────────────────┘  │
│                 NO                                                  │
│                 │                                                   │
│   ┌─────────────▼───────────────────────────────────────────────┐  │
│   │  Predictable latency required?  ──YES──►  ExpressRoute      │  │
│   └─────────────┬───────────────────────────────────────────────┘  │
│                 NO                                                  │
│                 │                                                   │
│   ┌─────────────▼───────────────────────────────────────────────┐  │
│   │  Microsoft 365 private connectivity?  ──YES──►  ER Premium  │  │
│   └─────────────┬───────────────────────────────────────────────┘  │
│                 NO                                                  │
│                 │                                                   │
│   ┌─────────────▼───────────────────────────────────────────────┐  │
│   │  Budget constrained?  ──YES──►  VPN Gateway                 │  │
│   └─────────────┬───────────────────────────────────────────────┘  │
│                 NO                                                  │
│                 │                                                   │
│   ┌─────────────▼───────────────────────────────────────────────┐  │
│   │  Quick setup needed?  ──YES──►  VPN Gateway                 │  │
│   │                       ──NO───►  Consider both based on need │  │
│   └─────────────────────────────────────────────────────────────┘  │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

### Hybrid Scenarios

| Scenario | Recommended Solution |
|----------|---------------------|
| Large enterprise, global presence | ExpressRoute Premium + Global Reach |
| SMB with limited budget | VPN Gateway |
| High availability requirement | ExpressRoute + VPN backup |
| Massive data migration | ExpressRoute Direct |
| Branch office connectivity | VPN or ExpressRoute with Any-to-Any |
| Microsoft 365 private access | ExpressRoute Premium with Microsoft Peering |

---

## PowerShell Examples

### Create ExpressRoute Circuit

```powershell
# Variables
$resourceGroup = "rg-expressroute-lab"
$location = "uksouth"
$circuitName = "er-circuit-london"
$providerName = "Equinix"
$peeringLocation = "London"
$bandwidthInMbps = 1000
$sku = "Standard"
$tier = "MeteredData"

# Create Resource Group
New-AzResourceGroup -Name $resourceGroup -Location $location

# Create ExpressRoute Circuit
$circuit = New-AzExpressRouteCircuit `
    -ResourceGroupName $resourceGroup `
    -Name $circuitName `
    -Location $location `
    -ServiceProviderName $providerName `
    -PeeringLocation $peeringLocation `
    -BandwidthInMbps $bandwidthInMbps `
    -SkuFamily $tier `
    -SkuTier $sku

# Get Service Key (share with provider)
$circuit.ServiceKey
```

### Configure Private Peering

```powershell
# Get the circuit
$circuit = Get-AzExpressRouteCircuit `
    -ResourceGroupName $resourceGroup `
    -Name $circuitName

# Add Private Peering
Add-AzExpressRouteCircuitPeeringConfig `
    -Name "AzurePrivatePeering" `
    -ExpressRouteCircuit $circuit `
    -PeeringType AzurePrivatePeering `
    -PeerASN 65001 `
    -PrimaryPeerAddressPrefix "10.0.0.0/30" `
    -SecondaryPeerAddressPrefix "10.0.0.4/30" `
    -VlanId 100

# Update the circuit
Set-AzExpressRouteCircuit -ExpressRouteCircuit $circuit

# Verify peering status
Get-AzExpressRouteCircuitPeeringConfig `
    -ExpressRouteCircuit $circuit `
    -Name "AzurePrivatePeering"
```

### Create ExpressRoute Gateway

```powershell
# Create Gateway Subnet
$vnet = Get-AzVirtualNetwork -Name "vnet-hub" -ResourceGroupName $resourceGroup
Add-AzVirtualNetworkSubnetConfig `
    -Name "GatewaySubnet" `
    -VirtualNetwork $vnet `
    -AddressPrefix "10.0.255.0/27"
$vnet | Set-AzVirtualNetwork

# Create Public IP for Gateway
$gwpip = New-AzPublicIpAddress `
    -Name "pip-er-gateway" `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -AllocationMethod Static `
    -Sku Standard `
    -Zone 1,2,3

# Get Gateway Subnet
$vnet = Get-AzVirtualNetwork -Name "vnet-hub" -ResourceGroupName $resourceGroup
$gwsubnet = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet

# Create Gateway IP Configuration
$gwipconfig = New-AzVirtualNetworkGatewayIpConfig `
    -Name "gwipconfig" `
    -SubnetId $gwsubnet.Id `
    -PublicIpAddressId $gwpip.Id

# Create ExpressRoute Gateway (Zone Redundant)
$ergw = New-AzVirtualNetworkGateway `
    -Name "er-gateway" `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -IpConfigurations $gwipconfig `
    -GatewayType ExpressRoute `
    -GatewaySku ErGw2Az
```

### Connect Gateway to Circuit

```powershell
# Get the circuit
$circuit = Get-AzExpressRouteCircuit `
    -ResourceGroupName $resourceGroup `
    -Name $circuitName

# Get the gateway
$gateway = Get-AzVirtualNetworkGateway `
    -Name "er-gateway" `
    -ResourceGroupName $resourceGroup

# Create the connection
New-AzVirtualNetworkGatewayConnection `
    -Name "connection-to-onprem" `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -VirtualNetworkGateway1 $gateway `
    -PeerId $circuit.Id `
    -ConnectionType ExpressRoute `
    -AuthorizationKey $authKey  # If connecting to circuit in different subscription
```

### Enable FastPath

```powershell
# Get existing connection
$connection = Get-AzVirtualNetworkGatewayConnection `
    -Name "connection-to-onprem" `
    -ResourceGroupName $resourceGroup

# Enable FastPath
$connection.ExpressRouteGatewayBypass = $true
Set-AzVirtualNetworkGatewayConnection -VirtualNetworkGatewayConnection $connection
```

### Configure Global Reach

```powershell
# Get both circuits
$circuit1 = Get-AzExpressRouteCircuit `
    -ResourceGroupName $resourceGroup `
    -Name "er-circuit-london"

$circuit2 = Get-AzExpressRouteCircuit `
    -ResourceGroupName "rg-expressroute-us" `
    -Name "er-circuit-newyork"

# Get the peering from circuit 1
$peering = Get-AzExpressRouteCircuitPeeringConfig `
    -ExpressRouteCircuit $circuit1 `
    -Name "AzurePrivatePeering"

# Add Global Reach connection
Add-AzExpressRouteCircuitConnectionConfig `
    -Name "globalreach-london-newyork" `
    -ExpressRouteCircuit $circuit1 `
    -PeerExpressRouteCircuitPeering $circuit2.Peerings[0].Id `
    -AddressPrefix "172.16.0.0/29" `
    -AuthorizationKey $circuit2AuthKey  # If in different subscription

# Update the circuit
Set-AzExpressRouteCircuit -ExpressRouteCircuit $circuit1
```

### Create Route Filter for Microsoft Peering

```powershell
# Create Route Filter
$routeFilter = New-AzRouteFilter `
    -Name "rf-microsoft-services" `
    -ResourceGroupName $resourceGroup `
    -Location $location

# Add rule for Azure Storage
Add-AzRouteFilterRuleConfig `
    -Name "AllowAzureStorage" `
    -RouteFilter $routeFilter `
    -Access Allow `
    -RouteFilterRuleType Community `
    -CommunityList "12076:5001"

# Add rule for Exchange Online
Add-AzRouteFilterRuleConfig `
    -Name "AllowExchangeOnline" `
    -RouteFilter $routeFilter `
    -Access Allow `
    -RouteFilterRuleType Community `
    -CommunityList "12076:5100"

# Update route filter
Set-AzRouteFilter -RouteFilter $routeFilter

# Associate with Microsoft Peering
$circuit = Get-AzExpressRouteCircuit -ResourceGroupName $resourceGroup -Name $circuitName

Set-AzExpressRouteCircuitPeeringConfig `
    -Name MicrosoftPeering `
    -ExpressRouteCircuit $circuit `
    -PeeringType MicrosoftPeering `
    -PeerASN 65001 `
    -PrimaryPeerAddressPrefix "203.0.113.0/30" `
    -SecondaryPeerAddressPrefix "203.0.113.4/30" `
    -VlanId 200 `
    -MicrosoftConfigAdvertisedPublicPrefixes "203.0.113.8/30" `
    -MicrosoftConfigCustomerAsn 65001 `
    -MicrosoftConfigRoutingRegistryName ARIN `
    -RouteFilterId $routeFilter.Id

Set-AzExpressRouteCircuit -ExpressRouteCircuit $circuit
```

### Monitor ExpressRoute

```powershell
# Get circuit metrics
$circuit = Get-AzExpressRouteCircuit -ResourceGroupName $resourceGroup -Name $circuitName

# Check circuit provisioning state
$circuit.ServiceProviderProvisioningState
$circuit.CircuitProvisioningState

# Get ARP table
Get-AzExpressRouteCircuitARPTable `
    -ResourceGroupName $resourceGroup `
    -ExpressRouteCircuitName $circuitName `
    -PeeringType AzurePrivatePeering `
    -DevicePath Primary

# Get route table
Get-AzExpressRouteCircuitRouteTable `
    -ResourceGroupName $resourceGroup `
    -ExpressRouteCircuitName $circuitName `
    -PeeringType AzurePrivatePeering `
    -DevicePath Primary

# Get circuit stats
Get-AzExpressRouteCircuitStats `
    -ResourceGroupName $resourceGroup `
    -ExpressRouteCircuitName $circuitName `
    -PeeringType AzurePrivatePeering
```

---

## AZ-700 Exam Tips & Gotchas

### ExpressRoute vs VPN Gateway Quick Comparison

| Factor | ExpressRoute | VPN Gateway |
| --- | --- | --- |
| **Path** | Private (no Internet) | Public Internet |
| **Max Bandwidth** | 100 Gbps (Direct) | 10 Gbps |
| **Latency** | Consistent, low | Variable |
| **Encryption** | Optional (MACsec) | IPsec built-in |
| **Setup Time** | Days/weeks | Minutes |
| **Cost** | Higher | Lower |
| **SLA** | 99.95% (single), 99.99% (dual) | 99.9% - 99.95% |
| **Use Case** | Production, mission-critical | Dev/test, backup |

### Exam Decision Tree

```text
┌─────────────────────────────────────────────────────────────────────────┐
│           EXPRESSROUTE CONFIGURATION DECISION TREE                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   Need to connect Azure VNets to on-premises?                           │
│                        │                                                 │
│              ┌─────────┴─────────┐                                      │
│             YES                 NO → Use VNet Peering or VPN            │
│              │                                                          │
│              ▼                                                          │
│   Need consistent low latency OR >10 Gbps?                             │
│              │                                                          │
│         ┌────┴────┐                                                    │
│        YES       NO → Consider VPN Gateway (cheaper)                   │
│         │                                                              │
│         ▼                                                              │
│   Need >10 Gbps OR MACsec encryption?                                  │
│         │                                                              │
│    ┌────┴────┐                                                         │
│   YES       NO → Standard/Premium Circuit with Provider                │
│    │                                                                   │
│    ▼                                                                   │
│   ExpressRoute Direct (10G or 100G ports)                             │
│                                                                         │
│   CIRCUIT SKU SELECTION:                                               │
│   • Local SKU: Same metro, unlimited egress data                       │
│   • Standard: Same geopolitical region, ≤10 VNets                      │
│   • Premium: Global, >10 VNets, Microsoft 365 access                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Key Points to Remember

> 📝 **Circuit SKUs**
> - **Local**: Same metro, unlimited egress, 1-10 Gbps only
> - **Standard**: Same geopolitical region, 10 VNet links
> - **Premium**: Global connectivity, 100 VNet links, Microsoft 365

> 📝 **Gateway SKUs**
> - FastPath requires: **UltraPerformance**, **ErGw3Az**, or **ErGwScale**
> - Zone-redundant: **ErGw1Az**, **ErGw2Az**, **ErGw3Az**, **ErGwScale**
> - GatewaySubnet minimum size: **/27**

> 📝 **Peering Types**
> - **Private Peering**: Azure VNets (private IPs)
> - **Microsoft Peering**: Microsoft 365, Azure PaaS (public IPs, NAT required)
> - Azure Public Peering is **DEPRECATED**

> 📝 **Global Reach**
> - Connects on-premises sites through Microsoft backbone
> - Requires **/29** address space for the connection
> - Not available in all regions (China excluded)

> 📝 **FastPath**
> - Bypasses gateway for VM traffic (improves latency)
> - Does NOT work for: Private Endpoints, VNet peering traffic, Basic LB
> - Only on UltraPerformance, ErGw3Az, ErGwScale

### Gotchas That Appear on Exams

1. **Local SKU = Same metro only** - Can't connect to other regions, but unlimited outbound
2. **Microsoft Peering needs NAT** - On-prem IPs must be NAT'd to public IPs
3. **FastPath doesn't help Private Endpoints** - PE traffic still goes through gateway
4. **Standard → Premium is upgrade-in-place** - No downtime required
5. **Premium → Standard requires deleting VNet links** - If you have >10 links
6. **Global Reach needs /29 subnet** - For the inter-circuit connection
7. **BFD not enabled by default** - Enable for faster failover detection
8. **Gateway subnet cannot have NSG** - Will break ExpressRoute

### Common Exam Scenarios

| Scenario | Answer |
| --- | --- |
| Need Microsoft 365 over ExpressRoute | **Premium SKU + Microsoft Peering** |
| Connect two on-premises sites via Azure | **Global Reach** |
| Reduce latency to Azure VMs | **FastPath** |
| 99.99% SLA requirement | **Two circuits at different peering locations** |
| Connect >10 VNets | **Premium SKU** |
| High bandwidth data migration | **ExpressRoute Direct** |
| Layer 2 encryption requirement | **ExpressRoute Direct with MACsec** |
| Backup connectivity for ExpressRoute | **Site-to-Site VPN with BGP** |

### Important Limits

| Resource | Limit |
| --- | --- |
| VNet links per Standard circuit | 10 |
| VNet links per Premium circuit | 100 |
| Routes per Private Peering (Standard) | 4,000 |
| Routes per Private Peering (Premium) | 10,000 |
| Routes per Microsoft Peering | 200 |
| Circuits per ExpressRoute Gateway | 4-16 (depends on SKU) |

### Troubleshooting Tips

1. **Circuit not provisioning?**
   - Check provider provisioning state
   - Verify service key shared with provider
   - Confirm peering location matches provider

2. **No connectivity after setup?**
   - Verify BGP session is established (check ARP tables)
   - Confirm VLAN IDs match on both sides
   - Check that routes are being advertised

3. **Intermittent connectivity?**
   - Check BFD (Bidirectional Forwarding Detection) status
   - Review circuit health metrics in Azure Monitor
   - Verify both primary and secondary paths are active

### Quick Reference Commands

```powershell
# Check circuit status
Get-AzExpressRouteCircuit -Name $name -ResourceGroupName $rg | Select-Object Name, CircuitProvisioningState, ServiceProviderProvisioningState

# View peering configuration
Get-AzExpressRouteCircuitPeeringConfig -ExpressRouteCircuit $circuit

# Check gateway connections
Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $rg

# View learned routes from ExpressRoute
Get-AzExpressRouteCircuitRouteTable -ResourceGroupName $rg -ExpressRouteCircuitName $name -PeeringType AzurePrivatePeering -DevicePath Primary
```

---

## BFD (Bidirectional Forwarding Detection) Deep Dive

> **Exam Relevance**: The AZ-700 study guide specifically lists "configure BFD" under ExpressRoute. BFD provides **subsecond failover detection** compared to BGP's default 3-minute detection time.

### Why BFD Matters

Without BFD, failover relies solely on BGP keepalives:
- BGP keepalive interval: **60 seconds**
- BGP hold time: **180 seconds (3 minutes)**
- With BFD: **Subsecond detection** (typically 300ms × 3 = ~1 second)

```
WITHOUT BFD (BGP-only failover):
┌──────────┐         Link Failure         ┌──────────┐
│  CE/PE   │──────────── ✕ ───────────────│   MSEE   │
│ Router   │                               │          │
│          │  BGP Hold Timer: 180 seconds  │          │
│          │  ⚠ 3 minutes to detect!       │          │
└──────────┘                               └──────────┘

WITH BFD (subsecond failover):
┌──────────┐         Link Failure         ┌──────────┐
│  CE/PE   │──────────── ✕ ───────────────│   MSEE   │
│ Router   │                               │          │
│          │  BFD Interval: 300ms × 3      │          │
│          │  ✅ ~1 second to detect!       │          │
│          │  BFD notifies BGP → fast      │          │
│          │     convergence               │          │
└──────────┘                               └──────────┘
```

### MSEE BFD Configuration

| Parameter | Value |
|-----------|-------|
| **BFD Interval** | 300 ms |
| **Multiplier** | 3 (failover after 3 missed = 900ms) |
| **BFD Mode** | Asynchronous |
| **Supported Peerings** | Private Peering, Microsoft Peering |
| **Default State (new circuits)** | ✅ Enabled by default (circuits created after August 1, 2018) |
| **Pre-August 2018 circuits** | ❌ Must manually enable by resetting the peering |

### Enabling BFD on Pre-August 2018 Circuits

```powershell
# For circuits created BEFORE August 1, 2018:
# BFD must be enabled by RESETTING the peering (brief connectivity disruption)

# Step 1: Get the circuit
$circuit = Get-AzExpressRouteCircuit -Name "MyERCircuit" -ResourceGroupName "MyRG"

# Step 2: Get peering config
$peering = Get-AzExpressRouteCircuitPeeringConfig -ExpressRouteCircuit $circuit -Name "AzurePrivatePeering"

# Step 3: Remove and re-add the peering to enable BFD
Remove-AzExpressRouteCircuitPeeringConfig -ExpressRouteCircuit $circuit -Name "AzurePrivatePeering"
Set-AzExpressRouteCircuit -ExpressRouteCircuit $circuit

# Step 4: Re-add peering (BFD will be enabled by default on re-creation)
Add-AzExpressRouteCircuitPeeringConfig -ExpressRouteCircuit $circuit `
    -Name "AzurePrivatePeering" `
    -PeeringType AzurePrivatePeering `
    -PeerASN 65001 `
    -PrimaryPeerAddressPrefix "10.0.0.0/30" `
    -SecondaryPeerAddressPrefix "10.0.0.4/30" `
    -VlanId 200
Set-AzExpressRouteCircuit -ExpressRouteCircuit $circuit
```

### On-Premises Router BFD Configuration (Cisco IOS XE Example)

```
! Enable BFD on the interface facing the MSEE
interface GigabitEthernet0/0/0
 bfd interval 300 min_rx 300 multiplier 3

! Bind BGP neighbor to BFD
router bgp 65001
 neighbor 10.0.0.2 fall-over bfd

! Verify BFD session
show bfd neighbors
show bfd neighbors detail
```

### Exam Tips — BFD

> [!warning] Critical Exam Points
> 1. **New circuits (post Aug 2018) = BFD ON by default** — no action needed
> 2. **Old circuits = must RESET peering** — brief disruption to enable BFD
> 3. **MSEE interval = 300ms, multiplier = 3** — detection in ~1 second
> 4. **Both sides must support BFD** — configure on-prem CE/PE router too
> 5. **BFD works on both Private and Microsoft Peering** — but most scenarios focus on Private Peering
> 6. **BFD does NOT replace BGP** — it supplements BGP by providing fast link failure notification

---

## Encryption over ExpressRoute Deep Dive

> **Exam Relevance**: The AZ-700 study guide lists "configure encryption over ExpressRoute" as an explicit skill. There are **two encryption options**: MACsec (Layer 2) for ExpressRoute Direct, and IPsec VPN overlay (Layer 3) for standard circuits.

### Encryption Options Comparison

| Feature | MACsec (Layer 2) | IPsec VPN Overlay (Layer 3) |
|---------|------------------|-----------------------------|
| **Requires** | ExpressRoute Direct | Standard ExpressRoute circuit |
| **Encryption Scope** | Edge router ↔ MSEE link | End-to-end (on-prem ↔ Azure VMs) |
| **Protocol** | IEEE 802.1AE (MACsec) | IPsec (IKEv2) |
| **Throughput** | Line rate (10/100 Gbps) | Limited by VPN Gateway SKU |
| **Layer** | Layer 2 (data link) | Layer 3 (network) |
| **Setup Complexity** | Moderate (key exchange) | Higher (VPN over ER config) |
| **Cost Impact** | Only Direct port fees | VPN Gateway cost added |

### Option 1: MACsec on ExpressRoute Direct

MACsec encrypts traffic between your edge router and MSEE at **Layer 2**. Only available on **ExpressRoute Direct** ports.

```
┌──────────────┐     MACsec-encrypted link     ┌──────────────┐
│  Your Edge   │◄──────────────────────────────►│     MSEE     │
│  Router      │   IEEE 802.1AE                 │              │
│              │   Cipher: GcmAes128/GcmAes256  │              │
│  (CAK/CKN    │   XPN: Extended Packet Number  │              │
│   configured)│                                │              │
└──────────────┘                                └──────────────┘
```

#### MACsec Configuration

```powershell
# Step 1: Configure MACsec on ExpressRoute Direct
$erDirect = Get-AzExpressRoutePort -Name "MyERDirect" -ResourceGroupName "MyRG"

# Step 2: Set MACsec configuration
# CAK = Connectivity Association Key (pre-shared)
# CKN = Connectivity Association Key Name
$erDirect.Links[0].MacSecConfig.CakSecretIdentifier = "https://mykeyvault.vault.azure.net/secrets/cak-primary"
$erDirect.Links[0].MacSecConfig.CknSecretIdentifier = "https://mykeyvault.vault.azure.net/secrets/ckn-primary"
$erDirect.Links[0].MacSecConfig.Cipher = "GcmAes256"  # or GcmAes128
$erDirect.Links[0].MacSecConfig.SciState = "Enabled"   # Enable SCI tag

# Repeat for secondary link
$erDirect.Links[1].MacSecConfig.CakSecretIdentifier = "https://mykeyvault.vault.azure.net/secrets/cak-secondary"
$erDirect.Links[1].MacSecConfig.CknSecretIdentifier = "https://mykeyvault.vault.azure.net/secrets/ckn-secondary"
$erDirect.Links[1].MacSecConfig.Cipher = "GcmAes256"

# Step 3: Apply configuration
Set-AzExpressRoutePort -ExpressRoutePort $erDirect

# Important: Store CAK/CKN in Azure Key Vault
# The ExpressRoute Direct resource needs Key Vault Reader access
```

#### MACsec Key Points

- **Cipher options**: `GcmAes128` or `GcmAes256`
- **XPN (Extended Packet Numbering)**: Prevents packet number rollover on high-speed links
- **SCI (Secure Channel Identifier)**: Tag to identify MACsec traffic
- **Key Vault integration**: CAK and CKN stored in Azure Key Vault, referenced by secret URI
- **Managed identity**: ExpressRoute Direct uses managed identity to access Key Vault

### Option 2: IPsec VPN over ExpressRoute (Standard Circuits)

For standard ExpressRoute circuits (not Direct), you can create an **IPsec VPN tunnel over the ExpressRoute private peering** for end-to-end encryption.

```
┌──────────────┐    IPsec tunnel over ExpressRoute    ┌──────────────┐
│  On-Prem     │◄────────────────────────────────────►│  VPN Gateway │
│  VPN Device  │   ┌─────────────────────────────┐    │  in Azure    │
│              │   │  ExpressRoute Circuit         │    │              │
│              │───│   (Private Peering)           │───│              │
│              │   │  ┌───────────────────────┐   │    │              │
│              │   │  │ IPsec tunnel (inside)  │   │    │              │
│              │   │  └───────────────────────┘   │    │              │
│              │   └─────────────────────────────┘    │              │
└──────────────┘                                       └──────────────┘
```

#### Configuration Steps

```powershell
# Step 1: Ensure ExpressRoute circuit has Private Peering configured
# Step 2: Create VPN Gateway in the SAME VNet as the ExpressRoute Gateway
#         (coexistence scenario - both gateways in same VNet)

# Create VPN Gateway (must be in GatewaySubnet alongside ER gateway)
$gwSubnet = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet
$gwPIP = New-AzPublicIpAddress -Name "vpn-gw-pip" -ResourceGroupName $rg -Location $location -AllocationMethod Static -Sku Standard
$gwConfig = New-AzVirtualNetworkGatewayIpConfig -Name "vpnGwConfig" -SubnetId $gwSubnet.Id -PublicIpAddressId $gwPIP.Id

New-AzVirtualNetworkGateway -Name "vpn-gw" -ResourceGroupName $rg -Location $location `
    -GatewayType Vpn -VpnType RouteBased -GatewaySku VpnGw1 `
    -IpConfigurations $gwConfig -EnableBgp $true -Asn 65515

# Step 3: Create Local Network Gateway pointing to on-prem VPN device
# Use the BGP peer IP from ExpressRoute private peering
New-AzLocalNetworkGateway -Name "onprem-lng" -ResourceGroupName $rg -Location $location `
    -GatewayIpAddress "10.0.0.1" -BgpPeeringAddress "10.0.0.1" -Asn 65001

# Step 4: Create VPN connection with IPsec
New-AzVirtualNetworkGatewayConnection -Name "vpn-over-er" -ResourceGroupName $rg -Location $location `
    -VirtualNetworkGateway1 $vpnGw -LocalNetworkGateway2 $lng `
    -ConnectionType IPsec -SharedKey "YourPreSharedKey" `
    -EnableBgp $true -UsePolicyBasedTrafficSelectors $false
```

### Exam Tips — ExpressRoute Encryption

> [!warning] Critical Exam Points
> 1. **MACsec = ExpressRoute Direct ONLY** — Standard circuits cannot use MACsec
> 2. **MACsec encrypts router-to-MSEE** — NOT end-to-end to Azure VMs
> 3. **IPsec over ExpressRoute = end-to-end** — But limited by VPN Gateway throughput
> 4. **Coexistence**: VPN Gateway + ExpressRoute Gateway can coexist in the same VNet
> 5. **Key Vault required for MACsec** — CAK/CKN stored as Key Vault secrets
> 6. **MACsec cipher options**: GcmAes128 or GcmAes256
> 7. **IPsec over ExpressRoute uses Private Peering** — Traffic stays on the private path

---

## Draw.io Diagrams

Save as `.drawio` file and open in VS Code with Draw.io extension:

### ExpressRoute Architecture

```xml
<mxfile host="app.diagrams.net">
  <diagram name="ExpressRoute" id="er-arch">
    <mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1169" pageHeight="827" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <mxCell id="onprem" value="On-Premises&#xa;Data Center" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;" vertex="1" parent="1">
          <mxGeometry x="40" y="180" width="120" height="80" as="geometry" />
        </mxCell>
        <mxCell id="ce" value="Customer&#xa;Edge Router" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#ffe6cc;strokeColor=#d79b00;" vertex="1" parent="1">
          <mxGeometry x="200" y="180" width="100" height="80" as="geometry" />
        </mxCell>
        <mxCell id="provider" value="Connectivity&#xa;Provider&#xa;(AT&T, Equinix)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="1">
          <mxGeometry x="340" y="160" width="120" height="120" as="geometry" />
        </mxCell>
        <mxCell id="msee" value="MSEE&#xa;(Microsoft&#xa;Enterprise Edge)&#xa;Primary + Secondary" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
          <mxGeometry x="520" y="160" width="140" height="120" as="geometry" />
        </mxCell>
        <mxCell id="ergw" value="ExpressRoute&#xa;Gateway" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="720" y="120" width="100" height="60" as="geometry" />
        </mxCell>
        <mxCell id="vnet" value="Azure VNet&#xa;10.0.0.0/16" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="860" y="120" width="100" height="60" as="geometry" />
        </mxCell>
        <mxCell id="m365" value="Microsoft 365&#xa;Dynamics 365" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;" vertex="1" parent="1">
          <mxGeometry x="720" y="260" width="100" height="60" as="geometry" />
        </mxCell>
        <mxCell id="private" value="Private&#xa;Peering" style="text;html=1;strokeColor=none;fillColor=none;align=center;fontStyle=1" vertex="1" parent="1">
          <mxGeometry x="640" y="100" width="60" height="20" as="geometry" />
        </mxCell>
        <mxCell id="microsoft" value="Microsoft&#xa;Peering" style="text;html=1;strokeColor=none;fillColor=none;align=center;fontStyle=1" vertex="1" parent="1">
          <mxGeometry x="640" y="280" width="60" height="20" as="geometry" />
        </mxCell>
        <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="onprem" target="ce">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e2" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="ce" target="provider">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e3" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;strokeWidth=2;strokeColor=#0000FF;" edge="1" parent="1" source="provider" target="msee">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e4" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="msee" target="ergw">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e5" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="ergw" target="vnet">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e6" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;dashed=1;" edge="1" parent="1" source="msee" target="m365">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

### ExpressRoute Global Reach

```xml
<mxfile host="app.diagrams.net">
  <diagram name="Global Reach" id="gr-arch">
    <mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1169" pageHeight="827" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <mxCell id="site1" value="Site A&#xa;(New York)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;" vertex="1" parent="1">
          <mxGeometry x="80" y="120" width="120" height="60" as="geometry" />
        </mxCell>
        <mxCell id="circuit1" value="ER Circuit 1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
          <mxGeometry x="280" y="120" width="100" height="60" as="geometry" />
        </mxCell>
        <mxCell id="azure" value="Microsoft&#xa;Global Network" style="ellipse;shape=cloud;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="440" y="140" width="160" height="100" as="geometry" />
        </mxCell>
        <mxCell id="circuit2" value="ER Circuit 2" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
          <mxGeometry x="660" y="120" width="100" height="60" as="geometry" />
        </mxCell>
        <mxCell id="site2" value="Site B&#xa;(London)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;" vertex="1" parent="1">
          <mxGeometry x="840" y="120" width="120" height="60" as="geometry" />
        </mxCell>
        <mxCell id="gr" value="Global Reach&#xa;(Site-to-Site via Azure)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;fontStyle=1" vertex="1" parent="1">
          <mxGeometry x="440" y="300" width="160" height="50" as="geometry" />
        </mxCell>
        <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="site1" target="circuit1">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e2" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="circuit1" target="azure">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e3" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="azure" target="circuit2">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e4" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="circuit2" target="site2">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e5" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;dashed=1;strokeWidth=2;strokeColor=#FF6600;" edge="1" parent="1" source="site1" target="gr">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e6" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;dashed=1;strokeWidth=2;strokeColor=#FF6600;" edge="1" parent="1" source="gr" target="site2">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```

---

## Additional Resources

- [ExpressRoute Documentation](https://docs.microsoft.com/azure/expressroute/)
- [ExpressRoute FAQ](https://docs.microsoft.com/azure/expressroute/expressroute-faqs)
- [ExpressRoute Partners](https://docs.microsoft.com/azure/expressroute/expressroute-locations-providers)
- [ExpressRoute Monitoring](https://docs.microsoft.com/azure/expressroute/expressroute-monitoring-metrics-alerts)

---

*Last Updated: January 2026*
*AZ-700: Designing and Implementing Microsoft Azure Networking Solutions*
