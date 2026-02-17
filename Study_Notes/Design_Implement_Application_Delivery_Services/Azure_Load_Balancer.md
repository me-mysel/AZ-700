---
tags:
  - AZ-700
  - azure/networking
  - domain/app-delivery
  - load-balancer
  - layer4
  - standard-lb
  - ha-ports
  - snat
  - health-probe
  - inbound-nat
  - gateway-lb
  - cross-region-lb
aliases:
  - Azure Load Balancer
  - ALB
  - Standard Load Balancer
created: 2025-01-01
updated: 2026-02-07
---

# Azure Load Balancer

> [!info] Related Notes
> - [[Application_Gateway]] — Layer 7 load balancing (vs L4 Load Balancer)
> - [[Traffic_Manager]] — DNS-based global load balancing
> - [[Azure_Front_Door]] — Global L7 load balancing
> - [[NAT_Gateway]] — Outbound SNAT comparison
> - [[Private_Link_Service]] — Standard LB required for Private Link Service
> - [[NSG_ASG_Firewall]] — NSG rules with load-balanced traffic

## Overview

Azure Load Balancer is a Layer 4 (TCP/UDP) load balancer that distributes incoming traffic among healthy VMs. It provides high availability and network performance for applications.

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Frontend IP** | Public or private IP that receives traffic |
| **Backend Pool** | VMs or VMSS instances receiving traffic |
| **Health Probe** | Monitors backend instance health |
| **Load Balancing Rule** | Maps frontend to backend + probe |
| **Inbound NAT Rule** | Direct traffic to specific VM (port forwarding) |
| **Outbound Rule** | Controls SNAT for outbound traffic |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      Azure Load Balancer Architecture                            │
│                                                                                  │
│                              INTERNET                                            │
│                                  │                                               │
│                                  ▼                                               │
│                    ┌─────────────────────────────┐                              │
│                    │       PUBLIC LOAD BALANCER   │                              │
│                    │                              │                              │
│                    │  Frontend IP: 52.x.x.x       │                              │
│                    │  (Standard SKU, Static)      │                              │
│                    │                              │                              │
│                    │  ┌────────────────────────┐  │                              │
│                    │  │  Load Balancing Rules  │  │                              │
│                    │  │  • HTTP (80) → Pool    │  │                              │
│                    │  │  • HTTPS (443) → Pool  │  │                              │
│                    │  └────────────────────────┘  │                              │
│                    │                              │                              │
│                    │  ┌────────────────────────┐  │                              │
│                    │  │     Health Probes      │  │                              │
│                    │  │  • TCP 80 every 5s     │  │                              │
│                    │  │  • HTTP /health 200 OK │  │                              │
│                    │  └────────────────────────┘  │                              │
│                    └──────────────┬───────────────┘                              │
│                                   │                                              │
│  ┌────────────────────────────────┼────────────────────────────────────────────┐│
│  │                     BACKEND POOL (Availability Zone Spread)                 ││
│  │                                                                             ││
│  │   Zone 1              Zone 2              Zone 3                            ││
│  │  ┌─────────┐        ┌─────────┐        ┌─────────┐                         ││
│  │  │  VM 1   │        │  VM 2   │        │  VM 3   │                         ││
│  │  │10.0.1.4 │        │10.0.1.5 │        │10.0.1.6 │                         ││
│  │  │  ✓ OK   │        │  ✓ OK   │        │  ✗ Down │                         ││
│  │  └─────────┘        └─────────┘        └─────────┘                         ││
│  │       ▲                  ▲                                                  ││
│  │       │                  │                                                  ││
│  │       └──────────────────┴─── Traffic distributed only to healthy VMs      ││
│  │                                                                             ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                      INTERNAL LOAD BALANCER                                  ││
│  │                                                                             ││
│  │   Frontend IP: 10.0.2.100 (Private)                                        ││
│  │                    │                                                        ││
│  │                    ▼                                                        ││
│  │   ┌──────────┐  ┌──────────┐  ┌──────────┐                                 ││
│  │   │ App VM 1 │  │ App VM 2 │  │ App VM 3 │  ← Backend App Tier             ││
│  │   └──────────┘  └──────────┘  └──────────┘                                 ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Load Balancer SKUs

### SKU Comparison

| Feature | Basic | Standard |
|---------|-------|----------|
| **Backend Pool Size** | Up to 300 | Up to 1,000 |
| **Health Probes** | TCP, HTTP | TCP, HTTP, HTTPS |
| **Availability Zones** | ❌ | ✅ Zone-redundant & Zonal |
| **SLA** | None | 99.99% |
| **Secure by Default** | Open | Closed (NSG required) |
| **Outbound Rules** | ❌ | ✅ |
| **HA Ports** | ❌ | ✅ |
| **Global Load Balancing** | ❌ | ✅ (Cross-region) |
| **Multiple Frontends** | ❌ | ✅ |
| **Diagnostics** | Limited | Full (metrics, logs) |
| **Cost** | Free | Per hour + data |

**⚠️ Basic SKU is being retired - use Standard for all new deployments**

### Public vs Internal

| Type | Frontend IP | Use Case |
|------|-------------|----------|
| **Public** | Public IP | Internet-facing applications |
| **Internal** | Private IP | Internal multi-tier apps, hybrid |
| **Both** | Public + Private | Internet + internal access |

---

## Distribution Modes

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Load Balancer Distribution Modes                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   5-TUPLE HASH (Default)                                                │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │  Hash: Source IP + Source Port + Dest IP + Dest Port + Protocol  │  │
│   │                                                                   │  │
│   │  → Different connections from same client may hit different VMs  │  │
│   │  → Best for stateless applications                               │  │
│   │  → Maximum distribution                                          │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│   SOURCE IP AFFINITY (Session Persistence)                              │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │  2-Tuple: Source IP + Dest IP                                    │  │
│   │  3-Tuple: Source IP + Dest IP + Protocol                         │  │
│   │                                                                   │  │
│   │  → Same client always hits same VM                               │  │
│   │  → Use for: RDP, stateful apps, session-based                    │  │
│   │  → Set: SessionPersistence = "SourceIP" or "SourceIPProtocol"    │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Configuration Best Practices

### Create Public Load Balancer

```powershell
# Create resource group
New-AzResourceGroup -Name "rg-lb-lab" -Location "uksouth"

# Create public IP for Load Balancer
$pip = New-AzPublicIpAddress `
    -Name "pip-lb-frontend" `
    -ResourceGroupName "rg-lb-lab" `
    -Location "uksouth" `
    -Sku "Standard" `
    -AllocationMethod "Static" `
    -Zone 1, 2, 3  # Zone-redundant

# Create frontend IP configuration
$feConfig = New-AzLoadBalancerFrontendIpConfig `
    -Name "fe-public" `
    -PublicIpAddress $pip

# Create backend pool
$bePool = New-AzLoadBalancerBackendAddressPoolConfig -Name "be-pool-web"

# Create health probe
$probe = New-AzLoadBalancerProbeConfig `
    -Name "probe-http" `
    -Protocol "Http" `
    -Port 80 `
    -RequestPath "/health" `
    -IntervalInSeconds 5 `
    -ProbeCount 2

# Create load balancing rule
$lbRule = New-AzLoadBalancerRuleConfig `
    -Name "rule-http" `
    -FrontendIpConfiguration $feConfig `
    -BackendAddressPool $bePool `
    -Probe $probe `
    -Protocol "Tcp" `
    -FrontendPort 80 `
    -BackendPort 80 `
    -EnableFloatingIP $false `
    -IdleTimeoutInMinutes 4 `
    -LoadDistribution "Default"  # 5-tuple hash

# Create Load Balancer
$lb = New-AzLoadBalancer `
    -Name "lb-web-prod" `
    -ResourceGroupName "rg-lb-lab" `
    -Location "uksouth" `
    -Sku "Standard" `
    -FrontendIpConfiguration $feConfig `
    -BackendAddressPool $bePool `
    -Probe $probe `
    -LoadBalancingRule $lbRule
```

### Create Internal Load Balancer

```powershell
# Get subnet for internal LB
$vnet = Get-AzVirtualNetwork -Name "vnet-prod" -ResourceGroupName "rg-networking"
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "snet-app" -VirtualNetwork $vnet

# Create internal frontend IP
$feConfigInternal = New-AzLoadBalancerFrontendIpConfig `
    -Name "fe-internal" `
    -PrivateIpAddress "10.0.2.100" `
    -SubnetId $subnet.Id

# Create internal Load Balancer
$ilb = New-AzLoadBalancer `
    -Name "ilb-app-tier" `
    -ResourceGroupName "rg-lb-lab" `
    -Location "uksouth" `
    -Sku "Standard" `
    -FrontendIpConfiguration $feConfigInternal `
    -BackendAddressPool $bePool `
    -Probe $probe `
    -LoadBalancingRule $lbRule
```

### Configure Outbound Rules (SNAT)

```powershell
# Create outbound rule for explicit SNAT control
$outboundRule = New-AzLoadBalancerOutboundRuleConfig `
    -Name "outbound-rule" `
    -FrontendIpConfiguration $feConfig `
    -BackendAddressPool $bePool `
    -Protocol "All" `
    -IdleTimeoutInMinutes 4 `
    -AllocatedOutboundPort 10000  # SNAT ports per instance

# Add to existing Load Balancer
$lb = Get-AzLoadBalancer -Name "lb-web-prod" -ResourceGroupName "rg-lb-lab"
$lb | Add-AzLoadBalancerOutboundRuleConfig `
    -Name "outbound-rule" `
    -FrontendIpConfiguration $lb.FrontendIpConfigurations[0] `
    -BackendAddressPool $lb.BackendAddressPools[0] `
    -Protocol "All" `
    -AllocatedOutboundPort 10000
$lb | Set-AzLoadBalancer
```

### Configure HA Ports (Internal LB)

```powershell
# HA Ports - load balance ALL protocols on ALL ports
$haPortRule = New-AzLoadBalancerRuleConfig `
    -Name "rule-ha-ports" `
    -FrontendIpConfiguration $feConfigInternal `
    -BackendAddressPool $bePool `
    -Probe $probe `
    -Protocol "All" `
    -FrontendPort 0 `
    -BackendPort 0 `
    -EnableFloatingIP $true  # Required for HA Ports

# Use case: NVA (firewalls), SQL Always On, any protocol
```

---

## Gateway Load Balancer (Deep Dive)

Gateway Load Balancer is a **separate SKU** of Azure Load Balancer designed for **transparent insertion of Network Virtual Appliances (NVAs)** into the network path. It provides **bump-in-the-wire** functionality where all traffic is inspected by NVAs before reaching the application — without requiring UDRs or complex routing.

### How Gateway Load Balancer Works

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Gateway Load Balancer Architecture                         │
│                                                                              │
│   INTERNET                                                                   │
│       │                                                                      │
│       ▼                                                                      │
│   ┌──────────────────────────────────────────┐                              │
│   │  Consumer: Standard Public LB (or PIP)   │                              │
│   │  Frontend chained → Gateway LB           │                              │
│   └──────────────┬───────────────────────────┘                              │
│                  │ VXLAN Encapsulated                                        │
│                  ▼                                                           │
│   ┌──────────────────────────────────────────┐   ← Provider VNet            │
│   │        Gateway Load Balancer              │     (can be different        │
│   │        (HA Ports rule)                    │      subscription/tenant)    │
│   │              │                            │                              │
│   │     ┌────────┼────────┐                  │                              │
│   │     ▼        ▼        ▼                  │                              │
│   │  ┌──────┐ ┌──────┐ ┌──────┐             │                              │
│   │  │ NVA1 │ │ NVA2 │ │ NVA3 │  Backend    │                              │
│   │  │(FW)  │ │(FW)  │ │(FW)  │  Pool       │                              │
│   │  └──────┘ └──────┘ └──────┘             │                              │
│   └──────────────┬───────────────────────────┘                              │
│                  │ Traffic returns via same path                             │
│                  │ (flow symmetry guaranteed)                                │
│                  ▼                                                           │
│   ┌──────────────────────────────────────────┐   ← Consumer VNet            │
│   │        Application VMs                    │                              │
│   │   ┌──────┐  ┌──────┐  ┌──────┐          │                              │
│   │   │ VM 1 │  │ VM 2 │  │ VM 3 │          │                              │
│   │   └──────┘  └──────┘  └──────┘          │                              │
│   └──────────────────────────────────────────┘                              │
│                                                                              │
│   ✅ VXLAN encapsulation (preserves original packet headers)                 │
│   ✅ Flow symmetry (same NVA for inbound + outbound)                        │
│   ✅ No UDRs needed on consumer VNet                                         │
│   ✅ Cross-tenant chaining supported                                         │
│   ❌ VNet peering NOT required between provider and consumer                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Chaining** | Linking a Standard Public LB or VM NIC IP configuration to a Gateway LB frontend |
| **Consumer** | The Standard LB or VM public IP that chains to the Gateway LB |
| **Provider** | The Gateway LB + NVA backend pool |
| **VXLAN** | Encapsulation protocol used between consumer and provider resources |
| **Flow Symmetry** | Same NVA instance handles both directions of a flow |
| **Flow Stickiness** | Traffic sticks to a specific NVA backend instance |

### Gateway LB vs Traditional NVA HA (Dual LB Sandwich)

| Feature | Gateway Load Balancer | Dual LB Sandwich (Internal + Public LB) |
|---------|----------------------|------------------------------------------|
| **UDRs required** | ❌ No | ✅ Yes (complex) |
| **VNet peering required** | ❌ No | ✅ Yes |
| **Flow symmetry** | ✅ Built-in | ⚠️ Must configure carefully |
| **Cross-tenant** | ✅ Yes | ❌ No |
| **Protocol** | VXLAN | Standard IP routing |
| **Management overhead** | Low | High |
| **Source IP preserved** | ✅ Yes | ✅ Yes |

### Configure Gateway Load Balancer

```powershell
# Create Gateway Load Balancer
$gwlbFrontend = New-AzLoadBalancerFrontendIpConfig `
    -Name "gwlb-frontend" `
    -PrivateIpAddress "10.10.0.100" `
    -SubnetId $nvaSubnet.Id

$gwlbBackendPool = New-AzLoadBalancerBackendAddressPoolConfig `
    -Name "gwlb-backend-nva" `
    -TunnelInterface @(
        @{ Identifier = 800; Type = "Internal"; Protocol = "VXLAN"; Port = 10800 },
        @{ Identifier = 801; Type = "External"; Protocol = "VXLAN"; Port = 10801 }
    )

$gwlbProbe = New-AzLoadBalancerProbeConfig `
    -Name "gwlb-probe" `
    -Protocol Tcp `
    -Port 8080 `
    -IntervalInSeconds 5 `
    -ProbeCount 2

$gwlbRule = New-AzLoadBalancerRuleConfig `
    -Name "gwlb-rule-ha" `
    -Protocol All `
    -FrontendPort 0 `
    -BackendPort 0 `
    -FrontendIpConfiguration $gwlbFrontend `
    -BackendAddressPool $gwlbBackendPool `
    -Probe $gwlbProbe

$gwlb = New-AzLoadBalancer `
    -Name "gwlb-nva" `
    -ResourceGroupName "rg-nva" `
    -Location "uksouth" `
    -Sku "Gateway" `
    -FrontendIpConfiguration $gwlbFrontend `
    -BackendAddressPool $gwlbBackendPool `
    -Probe $gwlbProbe `
    -LoadBalancingRule $gwlbRule

# Chain consumer LB frontend to Gateway LB
$consumerLb = Get-AzLoadBalancer -Name "lb-web-prod" -ResourceGroupName "rg-web"
$consumerFrontend = $consumerLb.FrontendIpConfigurations[0]
$consumerFrontend.GatewayLoadBalancerId = $gwlb.FrontendIpConfigurations[0].Id
$consumerLb | Set-AzLoadBalancer
```

> **⚠️ Exam Key**: Gateway LB frontend IP **cannot** be used as a next hop in UDRs. It **must** be chained/referenced by a consumer resource (Standard Public LB or Standard NIC IP configuration).

---

## Cross-Region (Global) Load Balancer (Deep Dive)

Azure Standard Load Balancer supports **global load balancing** for geo-redundant HA scenarios. A global load balancer sits in front of regional load balancers and provides:

- **Static anycast global IP** — Same IP worldwide
- **Geo-proximity routing** — Closest region automatically
- **Instant failover** — Health probes detect regional failure in ~5 seconds
- **Client IP preservation** — Backend sees original source IP

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Cross-Region (Global) Load Balancer                        │
│                                                                              │
│                    ┌──────────────────────────────┐                          │
│                    │   Global Load Balancer        │                          │
│                    │   (Standard SKU, Global Tier) │                          │
│                    │                                │                          │
│                    │   Static Anycast IP: x.x.x.x  │                          │
│                    │   Backend: Regional LBs        │                          │
│                    └───────────┬──────────────────┘                          │
│                                │                                             │
│               ┌────────────────┼────────────────┐                           │
│               ▼                ▼                 ▼                           │
│   ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐              │
│   │ Regional LB 1   │ │ Regional LB 2   │ │ Regional LB 3   │              │
│   │ West US          │ │ North Europe    │ │ Southeast Asia  │              │
│   │ ┌─────┐ ┌─────┐│ │ ┌─────┐ ┌─────┐│ │ ┌─────┐ ┌─────┐│              │
│   │ │VM 1 │ │VM 2 ││ │ │VM 3 │ │VM 4 ││ │ │VM 5 │ │VM 6 ││              │
│   │ └─────┘ └─────┘│ │ └─────┘ └─────┘│ │ └─────┘ └─────┘│              │
│   └─────────────────┘ └─────────────────┘ └─────────────────┘              │
│                                                                              │
│   ✅ Traffic from Seattle → West US regional LB (closest region)             │
│   ✅ If West US fails → North Europe (next closest healthy region)           │
│   ✅ Health probe every 5 seconds per regional LB                            │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Characteristics

| Feature | Detail |
|---------|--------|
| **SKU** | Standard SKU with **Global tier** |
| **Frontend** | **Public only** — internal not supported |
| **Backend** | Regional Standard Load Balancers (any public Azure region) |
| **Routing** | Geo-proximity (closest participating region) |
| **Failover** | ~5 seconds (health probe interval) |
| **IP type** | Static anycast |
| **Client IP** | Preserved |

### Limitations

1. **Global frontend is public only** — No internal global LB
2. **Backend must be regional Standard LBs** — Cannot chain to Basic LB or internal LB
3. **NAT64 not supported** — Frontend and backend must match IP version (v4 or v6)
4. **UDP port 3 not supported** on global LB
5. **Outbound rules not supported** on global LB — Use outbound rules on regional LB or NAT Gateway
6. **Cannot upgrade** regional LB to global tier — Must create new global tier LB
7. **Backend port must equal frontend port** of the regional LB load balancing rules

### Home Regions (Where Global LB Can Be Deployed)

Central US, East Asia, East US 2, North Europe, Southeast Asia, UK South, West Europe, West US

> **⚠️ Exam Tip**: The **home region** is where the global LB resource is created, but it doesn't affect routing. If the home region goes down, traffic continues to flow.

---

## Exam Tips & Gotchas

### Critical Points (Commonly Tested)

- **Standard SKU is secure by default** — NSG required to allow traffic
- **Basic SKU has no SLA** — don't use for production
- **HA Ports = Internal LB only** — load balance all ports/protocols
- **Floating IP for DSR** — direct server return, backend sees original client IP
- **Outbound rules for SNAT control** — allocate specific ports per instance
- **Zone-redundant requires Standard SKU** — survives zone failure
- **Health probe down = no traffic** — all instances unhealthy = all get traffic

### Exam Scenarios

| Scenario | Solution |
|----------|----------|
| Load balance NVA (all traffic) | Internal LB with HA Ports + Floating IP |
| Session stickiness for web app | Source IP affinity (2-tuple or 3-tuple) |
| SNAT port exhaustion | Outbound rule with more allocated ports, or NAT Gateway |
| RDP to specific VM behind LB | Inbound NAT rule (port forwarding) |
| Cross-region failover | Global Load Balancer (Standard SKU) |
| Internal multi-tier app | Internal Load Balancer |
| Backend VMs can't reach internet | Add outbound rule or NAT Gateway |

### Common Gotchas

1. **NSG required for Standard SKU** — even after creating LB, no traffic flows without NSG
2. **Backend pool VMs need same VNet** — can't span VNets (use Global LB for cross-region)
3. **Health probe port must be open** — NSG must allow probe traffic
4. **Floating IP changes backend behavior** — loopback interface needed on VM
5. **Basic and Standard don't mix** — all resources must be same SKU

---

## Comparison Tables

### Load Balancer vs Other Services

| Feature | Azure LB | Traffic Manager | App Gateway | Front Door |
|---------|----------|-----------------|-------------|------------|
| **Layer** | 4 (TCP/UDP) | DNS | 7 (HTTP/S) | 7 (HTTP/S) |
| **Scope** | Regional | Global | Regional | Global |
| **Protocol** | Any TCP/UDP | DNS only | HTTP/HTTPS | HTTP/HTTPS |
| **SSL Offload** | ❌ | ❌ | ✅ | ✅ |
| **WAF** | ❌ | ❌ | ✅ | ✅ |
| **URL Routing** | ❌ | ❌ | ✅ | ✅ |
| **Session Affinity** | Source IP | ❌ | Cookie | Cookie |
| **Health Checks** | TCP/HTTP | HTTP/HTTPS/TCP | HTTP/HTTPS | HTTP/HTTPS |

### When to Use What

| Requirement | Use |
|-------------|-----|
| TCP/UDP load balancing | Azure Load Balancer |
| HTTP/HTTPS with SSL offload | Application Gateway |
| DNS-based global distribution | Traffic Manager |
| Global HTTP with edge caching | Azure Front Door |
| Internal app tier balancing | Internal Load Balancer |
| NVA high availability | LB with HA Ports |

---

## Hands-On Lab Suggestions

### Lab: Create Multi-Tier Application with Load Balancers

```powershell
# 1. Create VNet with web and app subnets
$webSubnet = New-AzVirtualNetworkSubnetConfig -Name "snet-web" -AddressPrefix "10.0.1.0/24"
$appSubnet = New-AzVirtualNetworkSubnetConfig -Name "snet-app" -AddressPrefix "10.0.2.0/24"

$vnet = New-AzVirtualNetwork `
    -Name "vnet-multitier" `
    -ResourceGroupName "rg-lb-lab" `
    -Location "uksouth" `
    -AddressPrefix "10.0.0.0/16" `
    -Subnet $webSubnet, $appSubnet

# 2. Create Public LB for web tier
# (Use commands from above)

# 3. Create Internal LB for app tier
# Frontend: 10.0.2.100

# 4. Create NSG allowing traffic
$nsg = New-AzNetworkSecurityGroup -Name "nsg-web" -ResourceGroupName "rg-lb-lab" -Location "uksouth"

$nsg | Add-AzNetworkSecurityRuleConfig `
    -Name "Allow-HTTP" `
    -Priority 100 `
    -Direction "Inbound" `
    -Access "Allow" `
    -Protocol "Tcp" `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 80

$nsg | Add-AzNetworkSecurityRuleConfig `
    -Name "Allow-LB-Probe" `
    -Priority 110 `
    -Direction "Inbound" `
    -Access "Allow" `
    -Protocol "Tcp" `
    -SourceAddressPrefix "AzureLoadBalancer" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange "*"

$nsg | Set-AzNetworkSecurityGroup

# 5. Associate NSG with subnet
Set-AzVirtualNetworkSubnetConfig `
    -VirtualNetwork $vnet `
    -Name "snet-web" `
    -AddressPrefix "10.0.1.0/24" `
    -NetworkSecurityGroup $nsg

$vnet | Set-AzVirtualNetwork

# 6. Add VMs to backend pools
# 7. Test load balancing
```

---

## Cross-Service Relationships

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Load Balancer Integration                                 │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        Azure Load Balancer                              │ │
│  │                                                                         │ │
│  │   Backend ─────────► VMs, VMSS, IP addresses                           │ │
│  │   Frontend ────────► Public IP (Standard), Private IP                  │ │
│  │   Outbound ────────► NAT Gateway (preferred for SNAT)                  │ │
│  │                                                                         │ │
│  │   Monitoring ──────► Azure Monitor (metrics, diagnostics)              │ │
│  │              ──────► Log Analytics (resource logs)                     │ │
│  │                                                                         │ │
│  │   Security ────────► NSG (required for Standard SKU)                   │ │
│  │           ────────► DDoS Protection                                    │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  Common Architectures:                                                      │
│  • Internet → Public LB → Web VMs → Internal LB → App VMs → DB            │
│  • Internet → Public LB → NVA (HA Ports) → Spoke VNets                    │
│  • Cross-region: Global LB → Regional LBs → VMs                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## AZ-700 Exam Tips & Gotchas

### Decision Matrix: Which Load Balancer to Use?

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    LOAD BALANCING DECISION TREE                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   Is traffic HTTP/HTTPS (Layer 7)?                                              │
│                │                                                                 │
│        ┌───────┴───────┐                                                        │
│        │               │                                                        │
│       YES             NO (TCP/UDP Layer 4)                                      │
│        │               │                                                        │
│        ▼               ▼                                                        │
│   Need global         Use AZURE LOAD BALANCER                                   │
│   distribution?       │                                                         │
│        │              ├── Public LB: Internet-facing                            │
│   ┌────┴────┐        ├── Internal LB: Multi-tier apps                          │
│   │         │        └── HA Ports: NVA/Firewall scenarios                       │
│  YES       NO                                                                   │
│   │         │                                                                   │
│   ▼         ▼                                                                   │
│ AZURE     APPLICATION                                                           │
│ FRONT     GATEWAY                                                               │
│ DOOR      (Regional)                                                            │
│                                                                                  │
│   Need DNS-only routing (no proxy)?                                             │
│   → Use TRAFFIC MANAGER                                                         │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Frequently Tested Concepts

| Exam Topic | Key Points to Remember |
|------------|------------------------|
| **Basic vs Standard SKU** | Basic = Free but no SLA, retiring. Standard = 99.99% SLA, secure-by-default |
| **NSG Requirement** | Standard SKU is **closed by default** - must allow traffic via NSG |
| **HA Ports** | Only on **Internal** Standard LB, load balances ALL protocols/ports |
| **SNAT Exhaustion** | Use **NAT Gateway** or **Outbound Rules** to solve |
| **Zone Redundancy** | Standard SKU only, deploy frontend across zones |
| **Floating IP** | Required for SQL AlwaysOn, multiple frontends to same backend |
| **Cross-region LB** | Standard SKU, global tier, provides geo-redundant failover |

### Common Exam Scenarios

| Scenario | Answer |
|----------|--------|
| *"Load balance SQL Server AlwaysOn cluster"* | Internal Standard LB + **Floating IP enabled** |
| *"NVA/Firewall HA with all traffic inspection"* | Internal Standard LB + **HA Ports** |
| *"VMs losing outbound internet connectivity"* | Configure **Outbound Rules** or use **NAT Gateway** |
| *"Need to distribute traffic across regions"* | **Cross-region Load Balancer** (Global tier) |
| *"Session must stay on same backend"* | Configure **Source IP Affinity** (session persistence) |
| *"RDP to specific VM through LB"* | Use **Inbound NAT Rule** (port 50001 → VM1:3389) |

### Gotchas to Watch For

1. **Basic SKU cannot be upgraded** - Must delete and recreate as Standard
2. **Standard LB needs NSG** - No NSG = No traffic (secure by default)
3. **HA Ports = Internal only** - Never on public LB
4. **Floating IP = Direct Server Return** - Backend must have frontend IP on loopback
5. **SNAT ports are finite** - 1024 per backend instance, use outbound rules for more

### Troubleshooting Quick Reference

| Symptom | Check First | Likely Fix |
|---------|-------------|------------|
| No traffic reaching VMs | NSG rules | Allow LB probe + traffic ports |
| Health probe failing | Probe config, backend health | Correct port/path, fix application |
| SNAT exhaustion (outbound fails) | Allocated SNAT ports | Add outbound rule or NAT Gateway |
| Uneven distribution | Distribution mode | Switch to 5-tuple hash |
| Single VM overloaded | Session persistence | Disable if not needed |

---

## Draw.io Diagram

```xml
<mxfile host="app.diagrams.net">
  <diagram name="Azure Load Balancer" id="alb-arch">
    <mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1169" pageHeight="827" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <mxCell id="internet" value="Internet" style="ellipse;shape=cloud;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;" vertex="1" parent="1">
          <mxGeometry x="400" y="40" width="120" height="60" as="geometry" />
        </mxCell>
        <mxCell id="publiclb" value="Public Load Balancer&#xa;(Standard SKU)&#xa;&#xa;Frontend: 52.x.x.x&#xa;Rule: HTTP (80)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
          <mxGeometry x="360" y="160" width="200" height="100" as="geometry" />
        </mxCell>
        <mxCell id="webpool" value="Backend Pool - Web Tier" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;verticalAlign=top" vertex="1" parent="1">
          <mxGeometry x="280" y="320" width="360" height="100" as="geometry" />
        </mxCell>
        <mxCell id="vm1" value="VM1&#xa;10.0.1.4" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="1">
          <mxGeometry x="300" y="350" width="80" height="50" as="geometry" />
        </mxCell>
        <mxCell id="vm2" value="VM2&#xa;10.0.1.5" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="1">
          <mxGeometry x="420" y="350" width="80" height="50" as="geometry" />
        </mxCell>
        <mxCell id="vm3" value="VM3&#xa;10.0.1.6" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="1">
          <mxGeometry x="540" y="350" width="80" height="50" as="geometry" />
        </mxCell>
        <mxCell id="internallb" value="Internal Load Balancer&#xa;Frontend: 10.0.2.100" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;" vertex="1" parent="1">
          <mxGeometry x="380" y="480" width="160" height="60" as="geometry" />
        </mxCell>
        <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="internet" target="publiclb">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e2" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="publiclb" target="webpool">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e3" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="webpool" target="internallb">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```
