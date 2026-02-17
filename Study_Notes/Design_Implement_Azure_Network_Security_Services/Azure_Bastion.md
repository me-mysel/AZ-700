---
tags:
  - AZ-700
  - azure/networking
  - azure/security
  - domain/network-security
  - bastion
  - remote-access
  - rdp
  - ssh
  - jumpbox
  - nsg-bastion
aliases:
  - Azure Bastion
  - Bastion Host
  - AzureBastionSubnet
created: 2025-01-01
updated: 2026-02-07
---

# Azure Bastion

> [!info] Related Notes
> - [[NSG_ASG_Firewall]] — NSG rules required for Bastion subnet
> - [[VNet_Subnets_IP_Addressing]] — AzureBastionSubnet sizing and naming
> - [[Azure_Firewall_and_Firewall_Manager]] — Complementary perimeter security
> - [[VNet_Peering_Routing]] — Bastion access to peered VNets
> - [[Microsoft_Defender_for_Cloud_Networking]] — JIT VM Access integration
> - [[Private_Endpoints]] — Private-only Bastion deployment (Premium)
> - [[Virtual_WAN]] — Bastion in Virtual WAN topology

---

## 1. Key Concepts & Definitions

### What is Azure Bastion?

Azure Bastion is a **fully managed PaaS service** that provides secure and seamless **RDP and SSH connectivity** to virtual machines directly through the Azure portal (or native client) over TLS. It eliminates the need to expose VMs to the public internet via public IP addresses, jump servers, or inbound NSG rules on ports 3389/22.

**Key Characteristics:**
- **Browser-based access** — HTML5 web client in the Azure portal; no client software needed
- **Over TLS (port 443)** — All sessions traverse a TLS tunnel, firewall-friendly
- **No public IP on VMs** — VMs remain private; Bastion acts as the secure gateway
- **Integrated with Azure platform** — Deployed into your VNet, managed by Azure
- **No agent required** — Works with any Windows/Linux VM regardless of guest OS agent

### Core Terminology

| Term | Definition |
|------|-----------|
| **AzureBastionSubnet** | Dedicated subnet (exact name required) where Bastion is deployed. Minimum **/26** size |
| **Bastion Host** | The managed Bastion resource deployed into the AzureBastionSubnet |
| **Scale Units** | Instances that handle concurrent sessions. Each unit = 20 RDP or 40 SSH sessions |
| **Native Client** | Using local SSH/RDP client (not browser) via `az network bastion` CLI. Standard+ SKU only |
| **Shareable Links** | URL-based VM access without Azure portal. Standard+ SKU only |
| **IP-based Connection** | Connect to VMs by IP address (not just Azure resource). Enables peered/on-prem VMs |
| **Session Recording** | Record Bastion sessions for compliance audit trails. **Premium SKU only** |
| **Private-only Deployment** | Bastion without a public IP address. **Premium SKU only** |

### How Azure Bastion Works

1. User navigates to the Azure portal → VM blade → **Connect** → **Bastion**
2. User enters credentials (username/password, SSH key, or Kerberos)
3. Azure Bastion initiates an **RDP/SSH session over TLS (port 443)** from the AzureBastionSubnet to the target VM's private IP
4. The VM **never needs a public IP** — Bastion reaches it over private networking
5. Session is streamed back to the user's browser as HTML5

> **⚠️ Critical Exam Point**: Bastion connects to VMs using their **private IP address** over ports **3389 (RDP)** and **22 (SSH)**. Traffic between Bastion and the VM stays within the VNet (or peered VNet).

---

## 2. SKU Tiers

Azure Bastion offers **four SKU tiers**:

| Feature | Developer | Basic | Standard | Premium |
|---------|-----------|-------|----------|---------|
| **Cost** | Free | Per hour + data | Per hour + data | Per hour + data |
| **Requires AzureBastionSubnet** | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| **Requires Public IP** | ❌ No | ✅ Yes | ✅ Yes | ❌ Optional |
| **Dedicated Host** | ❌ Shared infra | ✅ Yes | ✅ Yes | ✅ Yes |
| **VNet Peering Support** | ❌ | ✅ | ✅ | ✅ |
| **Concurrent Connections** | 1 VM only | 2 instances (fixed) | 2-50 instances (scalable) | 2-50 instances (scalable) |
| **Max RDP Sessions** | 1 | 40 | Up to 1,000 | Up to 1,000 |
| **Max SSH Sessions** | 1 | 80 | Up to 2,000 | Up to 2,000 |
| **Connect via Browser** | ✅ | ✅ | ✅ | ✅ |
| **Native Client (SSH/RDP)** | ❌ | ❌ | ✅ | ✅ |
| **File Transfer (upload/download)** | ❌ | ❌ | ✅ | ✅ |
| **Shareable Links** | ❌ | ❌ | ✅ | ✅ |
| **IP-based Connections** | ❌ | ❌ | ✅ | ✅ |
| **Custom Ports** | ❌ | ❌ | ✅ | ✅ |
| **Connect to Linux via RDP** | ❌ | ❌ | ✅ | ✅ |
| **Connect to Windows via SSH** | ❌ | ❌ | ✅ | ✅ |
| **Kerberos Authentication** | ✅ | ✅ | ✅ | ✅ |
| **Session Recording** | ❌ | ❌ | ❌ | ✅ |
| **Private-only (no public IP)** | ❌ | ❌ | ❌ | ✅ |
| **Availability Zones** | ✅ (shared) | ✅ | ✅ | ✅ |

> **⚠️ Exam Tip**: The cost difference between Standard and Premium is marginal — Microsoft recommends **Premium for production**. Developer SKU is **not** suitable for production (shared infrastructure, no peering, single VM).

### SKU Decision Framework

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     BASTION SKU DECISION TREE                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Is this dev/test only?                                                    │
│        │                                                                     │
│   ┌────┴────┐                                                               │
│  YES       NO                                                               │
│   │         │                                                                │
│   ▼         ▼                                                                │
│ DEVELOPER  Need session recording or private-only deployment?               │
│ (Free)          │                                                            │
│           ┌─────┴─────┐                                                     │
│          YES          NO                                                     │
│           │            │                                                     │
│           ▼            ▼                                                     │
│       PREMIUM     Need native client, shareable links, or >40 RDP?          │
│                        │                                                     │
│                  ┌─────┴─────┐                                              │
│                 YES          NO                                              │
│                  │            │                                              │
│                  ▼            ▼                                              │
│              STANDARD      BASIC                                            │
│              (2-50 inst)   (2 instances, fixed)                              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Architecture Overview

### Dedicated Deployment (Basic/Standard/Premium)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Azure Bastion Architecture                                 │
│                                                                              │
│   USER (Browser or Native Client)                                            │
│           │                                                                  │
│           │ TLS (Port 443)                                                   │
│           ▼                                                                  │
│   ┌───────────────────────────────────────────────────────────────────────┐  │
│   │                          Azure Virtual Network                         │  │
│   │                          10.0.0.0/16                                   │  │
│   │                                                                        │  │
│   │   ┌─────────────────────────────────────┐                              │  │
│   │   │   AzureBastionSubnet (10.0.1.0/26) │                              │  │
│   │   │                                     │                              │  │
│   │   │   ┌─────────────────────────────┐  │                              │  │
│   │   │   │   Azure Bastion Host        │  │                              │  │
│   │   │   │   (Managed PaaS Service)    │  │                              │  │
│   │   │   │                             │  │                              │  │
│   │   │   │   Public IP: x.x.x.x       │  │                              │  │
│   │   │   │   (Standard, Static)        │  │                              │  │
│   │   │   │                             │  │                              │  │
│   │   │   │   Scale Units: 2-50         │  │                              │  │
│   │   │   └──────────┬──────────────────┘  │                              │  │
│   │   └──────────────┼─────────────────────┘                              │  │
│   │                  │                                                     │  │
│   │                  │ Private IP (RDP:3389 / SSH:22)                      │  │
│   │                  ▼                                                     │  │
│   │   ┌──────────────────────────────────────────────────────────────┐    │  │
│   │   │   Workload Subnets                                            │    │  │
│   │   │                                                               │    │  │
│   │   │   ┌──────────┐   ┌──────────┐   ┌──────────┐                │    │  │
│   │   │   │  VM 1    │   │  VM 2    │   │  VM 3    │                │    │  │
│   │   │   │ 10.0.2.4 │   │ 10.0.2.5 │   │ 10.0.3.4 │                │    │  │
│   │   │   │ No Pub IP│   │ No Pub IP│   │ No Pub IP│                │    │  │
│   │   │   └──────────┘   └──────────┘   └──────────┘                │    │  │
│   │   └──────────────────────────────────────────────────────────────┘    │  │
│   └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│   Also reaches VMs in PEERED VNets (Basic/Standard/Premium)                  │
│   IP-based connections to on-prem VMs (Standard/Premium)                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Private-Only Deployment (Premium SKU)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                 Private-Only Bastion (Premium SKU)                            │
│                                                                              │
│   On-Premises Network                                                        │
│   ┌─────────────────────┐                                                   │
│   │   Admin Workstation  │───── ExpressRoute / S2S VPN ─────┐               │
│   └─────────────────────┘                                    │               │
│                                                               ▼               │
│   ┌───────────────────────────────────────────────────────────────────────┐  │
│   │                          Hub VNet                                      │  │
│   │                                                                        │  │
│   │   ┌─────────────────────────────────────┐                              │  │
│   │   │   AzureBastionSubnet (10.0.1.0/26) │                              │  │
│   │   │                                     │                              │  │
│   │   │   Azure Bastion (Premium)           │                              │  │
│   │   │   ❌ No Public IP                    │                              │  │
│   │   │   ✅ Private access only             │                              │  │
│   │   └─────────────────────────────────────┘                              │  │
│   │                  │                                                     │  │
│   │                  │ VNet Peering                                        │  │
│   │                  ▼                                                     │  │
│   │   ┌──────────────────────┐   ┌──────────────────────┐                 │  │
│   │   │    Spoke VNet 1      │   │    Spoke VNet 2      │                 │  │
│   │   │    (Workload VMs)    │   │    (Workload VMs)    │                 │  │
│   │   └──────────────────────┘   └──────────────────────┘                 │  │
│   └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
│   Use case: Highly regulated environments with ExpressRoute                  │
│   No internet exposure at all                                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. NSG Configuration for Azure Bastion

> **⚠️ CRITICAL EXAM TOPIC**: "Configure an NSG for remote server administration, including Azure Bastion" is an explicit exam objective. You **MUST** know all required NSG rules.

### NSG Rules for AzureBastionSubnet

If you apply an NSG to the AzureBastionSubnet, you **MUST** include ALL of the following rules. Omitting any rule blocks Bastion from receiving updates and creates security vulnerabilities.

#### Inbound Rules

| Priority | Name | Source | Source Port | Destination | Dest Port | Protocol | Action | Purpose |
|----------|------|--------|-------------|-------------|-----------|----------|--------|---------|
| 100 | AllowHttpsInbound | **Internet** | * | * | **443** | TCP | Allow | User connections to Bastion |
| 110 | AllowGatewayManagerInbound | **GatewayManager** | * | * | **443** | TCP | Allow | Control plane connectivity |
| 120 | AllowAzureLoadBalancerInbound | **AzureLoadBalancer** | * | * | **443** | TCP | Allow | Health probes |
| 130 | AllowBastionHostCommunication | **VirtualNetwork** | * | **VirtualNetwork** | **8080, 5701** | Any | Allow | Data plane (internal Bastion components) |

#### Outbound Rules

| Priority | Name | Source | Source Port | Destination | Dest Port | Protocol | Action | Purpose |
|----------|------|--------|-------------|-------------|-----------|----------|--------|---------|
| 100 | AllowSshRdpOutbound | * | * | **VirtualNetwork** | **22, 3389** | Any | Allow | Connect to target VMs |
| 110 | AllowAzureCloudOutbound | * | * | **AzureCloud** | **443** | TCP | Allow | Azure management |
| 120 | AllowBastionCommunication | **VirtualNetwork** | * | **VirtualNetwork** | **8080, 5701** | Any | Allow | Data plane (internal) |
| 130 | AllowHttpOutbound | * | * | **Internet** | **80** | TCP | Allow | Certificate validation |

> **⚠️ Exam Gotcha**: If using **custom ports** (Standard/Premium), the outbound rule to VirtualNetwork must include those custom ports, not just 22 and 3389.

### NSG Rules for Target VM Subnets

| Priority | Name | Source | Dest Port | Protocol | Action | Purpose |
|----------|------|--------|-----------|----------|--------|---------|
| 100 | AllowBastionInbound | **AzureBastionSubnet CIDR** (e.g., 10.0.1.0/26) | **22, 3389** | TCP | Allow | Allow Bastion to reach VMs |

> **⚠️ Key Point**: You do NOT need to allow inbound from the Internet on ports 3389/22 on the VM subnet. Only allow from the Bastion subnet CIDR.

---

## 5. Configuration Best Practices

### Deploy Azure Bastion (PowerShell)

```powershell
# Create resource group
New-AzResourceGroup -Name "rg-bastion-lab" -Location "uksouth"

# Create VNet with AzureBastionSubnet
$bastionSubnet = New-AzVirtualNetworkSubnetConfig `
    -Name "AzureBastionSubnet" `
    -AddressPrefix "10.0.1.0/26"

$workloadSubnet = New-AzVirtualNetworkSubnetConfig `
    -Name "snet-workload" `
    -AddressPrefix "10.0.2.0/24"

$vnet = New-AzVirtualNetwork `
    -Name "vnet-bastion-lab" `
    -ResourceGroupName "rg-bastion-lab" `
    -Location "uksouth" `
    -AddressPrefix "10.0.0.0/16" `
    -Subnet $bastionSubnet, $workloadSubnet

# Create public IP for Bastion (Standard SKU, Static)
$bastionPip = New-AzPublicIpAddress `
    -Name "pip-bastion" `
    -ResourceGroupName "rg-bastion-lab" `
    -Location "uksouth" `
    -Sku "Standard" `
    -AllocationMethod "Static"

# Deploy Azure Bastion (Standard SKU)
$bastion = New-AzBastion `
    -Name "bastion-prod" `
    -ResourceGroupName "rg-bastion-lab" `
    -VirtualNetworkId $vnet.Id `
    -PublicIpAddressId $bastionPip.Id `
    -Sku "Standard" `
    -ScaleUnit 2
```

### Configure NSG for AzureBastionSubnet

```powershell
# Create NSG with required Bastion rules
$nsg = New-AzNetworkSecurityGroup `
    -Name "nsg-bastion" `
    -ResourceGroupName "rg-bastion-lab" `
    -Location "uksouth"

# --- INBOUND RULES ---
# Allow HTTPS from Internet (user connections)
$nsg | Add-AzNetworkSecurityRuleConfig `
    -Name "AllowHttpsInbound" `
    -Priority 100 -Direction Inbound -Access Allow `
    -Protocol Tcp `
    -SourceAddressPrefix "Internet" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 443

# Allow GatewayManager (control plane)
$nsg | Add-AzNetworkSecurityRuleConfig `
    -Name "AllowGatewayManagerInbound" `
    -Priority 110 -Direction Inbound -Access Allow `
    -Protocol Tcp `
    -SourceAddressPrefix "GatewayManager" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 443

# Allow Azure Load Balancer (health probes)
$nsg | Add-AzNetworkSecurityRuleConfig `
    -Name "AllowAzureLoadBalancerInbound" `
    -Priority 120 -Direction Inbound -Access Allow `
    -Protocol Tcp `
    -SourceAddressPrefix "AzureLoadBalancer" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "*" `
    -DestinationPortRange 443

# Allow Bastion data plane communication
$nsg | Add-AzNetworkSecurityRuleConfig `
    -Name "AllowBastionHostCommunication" `
    -Priority 130 -Direction Inbound -Access Allow `
    -Protocol "*" `
    -SourceAddressPrefix "VirtualNetwork" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "VirtualNetwork" `
    -DestinationPortRange @("8080", "5701")

# --- OUTBOUND RULES ---
# Allow SSH/RDP to VNet (target VMs)
$nsg | Add-AzNetworkSecurityRuleConfig `
    -Name "AllowSshRdpOutbound" `
    -Priority 100 -Direction Outbound -Access Allow `
    -Protocol "*" `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "VirtualNetwork" `
    -DestinationPortRange @("22", "3389")

# Allow outbound to Azure Cloud
$nsg | Add-AzNetworkSecurityRuleConfig `
    -Name "AllowAzureCloudOutbound" `
    -Priority 110 -Direction Outbound -Access Allow `
    -Protocol Tcp `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "AzureCloud" `
    -DestinationPortRange 443

# Allow Bastion data plane outbound
$nsg | Add-AzNetworkSecurityRuleConfig `
    -Name "AllowBastionCommunicationOutbound" `
    -Priority 120 -Direction Outbound -Access Allow `
    -Protocol "*" `
    -SourceAddressPrefix "VirtualNetwork" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "VirtualNetwork" `
    -DestinationPortRange @("8080", "5701")

# Allow HTTP outbound (certificate validation)
$nsg | Add-AzNetworkSecurityRuleConfig `
    -Name "AllowHttpOutbound" `
    -Priority 130 -Direction Outbound -Access Allow `
    -Protocol Tcp `
    -SourceAddressPrefix "*" `
    -SourcePortRange "*" `
    -DestinationAddressPrefix "Internet" `
    -DestinationPortRange 80

$nsg | Set-AzNetworkSecurityGroup

# Associate NSG with Bastion subnet
$vnet = Get-AzVirtualNetwork -Name "vnet-bastion-lab" -ResourceGroupName "rg-bastion-lab"
$bastionSubnet = Get-AzVirtualNetworkSubnetConfig -Name "AzureBastionSubnet" -VirtualNetwork $vnet
$bastionSubnet.NetworkSecurityGroup = $nsg
$vnet | Set-AzVirtualNetwork
```

### Connect via Native Client (Standard/Premium)

```powershell
# Connect using native RDP client
az network bastion rdp `
    --name "bastion-prod" `
    --resource-group "rg-bastion-lab" `
    --target-resource-id "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachines/{vm}"

# Connect using native SSH client
az network bastion ssh `
    --name "bastion-prod" `
    --resource-group "rg-bastion-lab" `
    --target-resource-id "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachines/{vm}" `
    --auth-type "ssh-key" `
    --ssh-key "~/.ssh/id_rsa"

# Connect by IP address (IP-based connection, Standard/Premium)
az network bastion ssh `
    --name "bastion-prod" `
    --resource-group "rg-bastion-lab" `
    --target-ip-address "10.0.2.5" `
    --auth-type "password" `
    --username "azureuser"
```

---

## 6. Bastion with VNet Peering (Centralized Deployment)

Deploy Bastion in a **hub VNet** and use it to access VMs in peered **spoke VNets**:

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    Centralized Bastion via VNet Peering                       │
│                                                                               │
│   ┌────────────────────────┐                                                 │
│   │      Hub VNet          │                                                 │
│   │      10.0.0.0/16       │                                                 │
│   │                        │                                                 │
│   │  ┌──────────────────┐  │                                                 │
│   │  │ AzureBastionSubnet│  │                                                 │
│   │  │   Azure Bastion   │  │                                                 │
│   │  └────────┬─────────┘  │                                                 │
│   └───────────┼────────────┘                                                 │
│               │                                                              │
│       ┌───────┼───────┐                                                      │
│       │               │    VNet Peering                                       │
│       ▼               ▼                                                      │
│   ┌──────────┐   ┌──────────┐                                               │
│   │Spoke VNet│   │Spoke VNet│                                               │
│   │10.1.0.0  │   │10.2.0.0  │                                               │
│   │  VM1     │   │  VM2     │                                               │
│   │  VM3     │   │  VM4     │                                               │
│   └──────────┘   └──────────┘                                               │
│                                                                               │
│   ✅ Bastion reaches VMs in peered VNets (Basic/Standard/Premium)            │
│   ❌ Developer SKU does NOT support peering                                   │
└──────────────────────────────────────────────────────────────────────────────┘
```

> **⚠️ Exam Key**: Bastion connects to peered VNets **without gateway transit**. It only needs standard VNet peering. The peering must allow traffic forwarding.

---

## 7. Bastion in Virtual WAN

- Azure Bastion **cannot** be deployed inside a Virtual WAN hub
- Deploy Bastion in a **spoke VNet** connected to the Virtual WAN hub
- Must use **Standard or Premium SKU** with **IP-based connection** enabled
- The IP-based connection allows reaching VMs across the Virtual WAN topology

---

## 8. Comparison Tables

### Bastion vs Other Remote Access Methods

| Feature | Azure Bastion | Public IP on VM | JIT VM Access | VPN (P2S/S2S) |
|---------|--------------|-----------------|---------------|---------------|
| **VM Public IP needed** | ❌ No | ✅ Yes | ✅ Yes (temporary) | ❌ No |
| **Port 3389/22 exposed** | ❌ No | ✅ Yes | ✅ Temporarily | ❌ No |
| **Client software** | Browser (or native) | RDP/SSH client | RDP/SSH client | VPN client |
| **TLS encrypted** | ✅ Yes (443) | ❌ No (native protocol) | ❌ No | ✅ Yes (IPsec/TLS) |
| **Per-session security** | ✅ Yes | ❌ No | ✅ Yes (time-limited) | ❌ (always-on tunnel) |
| **Audit trails** | ✅ (Premium: recording) | ❌ Limited | ✅ Defender logs | ❌ Limited |
| **Cost** | Per hour + data | Free (Public IP cost) | Free (Defender plan) | VPN GW cost |
| **Brute-force risk** | ❌ None | ✅ High | ⚠️ Low (time-limited) | ❌ None |
| **Works with peered VNets** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |

### Bastion SKU Quick Reference

| Decision Factor | Developer | Basic | Standard | Premium |
|-----------------|-----------|-------|----------|---------|
| **Best for** | Dev/test | Small production | Most production | Regulated/compliance |
| **Max concurrent RDP** | 1 | 40 | 1,000 | 1,000 |
| **Scaling** | N/A | Fixed (2) | Manual (2-50) | Manual (2-50) |
| **Private-only** | ❌ | ❌ | ❌ | ✅ |
| **Session recording** | ❌ | ❌ | ❌ | ✅ |
| **Native client** | ❌ | ❌ | ✅ | ✅ |

---

## 9. Exam Tips & Gotchas

### Critical Points (Commonly Tested)

1. **Subnet name MUST be exactly `AzureBastionSubnet`** — case-sensitive, no alternatives
2. **Minimum subnet size is /26** — not /27 or /28; /26 supports host scaling
3. **Public IP must be Standard SKU, Static** — Basic SKU public IP does NOT work
4. **NSG rules are ALL-OR-NOTHING** — if you apply an NSG to AzureBastionSubnet, you must include ALL required rules; missing any rule breaks Bastion
5. **Ports 8080 and 5701** are for **internal Bastion data plane** — NOT user-facing, but required in NSG
6. **GatewayManager service tag** must be allowed inbound on port 443 (control plane)
7. **Port 80 outbound to Internet** required for certificate validation and shareable links
8. **Developer SKU uses shared infrastructure** — NOT for production, only 1 VM at a time
9. **Session recording = Premium only** — commonly tested differentiator
10. **Private-only = Premium only** — no public IP deployment for high-security environments

### Exam Scenarios

| Scenario | Answer |
|----------|--------|
| *"Secure RDP access to VMs without public IPs"* | **Azure Bastion** |
| *"Compliance requires session recording for all admin access"* | **Azure Bastion Premium SKU** |
| *"No internet exposure at all for management plane"* | **Bastion Premium with private-only deployment** over ExpressRoute |
| *"Centralized jump host for hub-spoke topology"* | **Deploy Bastion in hub VNet** with peering to spokes |
| *"NSG for Bastion subnet — which ports?"* | Inbound: 443 (Internet, GatewayManager, ALB), 8080/5701 (VNet). Outbound: 22/3389 (VNet), 443 (AzureCloud), 8080/5701 (VNet), 80 (Internet) |
| *"Connect to on-premises VM via Bastion"* | **Standard/Premium SKU with IP-based connection** over VPN/ExpressRoute |
| *"100 concurrent RDP sessions needed"* | **Standard or Premium** with 5+ scale units (each unit = 20 RDP sessions) |
| *"Bastion in Virtual WAN?"* | Deploy in spoke VNet (not hub), Standard/Premium with IP-based connection |

### Common Gotchas

1. **NSG on AzureBastionSubnet blocks updates** — if you misconfigure NSG, Bastion can't receive platform updates and becomes vulnerable
2. **Don't open 3389/22 on the Internet for AzureBastionSubnet** — only 443 from Internet
3. **Bastion + Azure Firewall** — can coexist in same VNet but in different subnets
4. **No UDR support on AzureBastionSubnet** — UDRs to route Bastion traffic through Azure Firewall are **not supported** (use NSGs instead)
5. **File transfer only with Standard/Premium** — Basic SKU cannot upload/download files
6. **Scale units matter** — each scale unit = 20 RDP or 40 SSH concurrent sessions; default is 2 units
7. **Kerberos authentication works on all SKUs** — but domain controller must be in same VNet as Bastion

---

## 10. Hands-On Lab Suggestions

### Lab 1: Deploy Bastion and Configure NSG

**Objective**: Deploy Azure Bastion with proper NSG rules and test connectivity

```powershell
# 1. Create resource group
New-AzResourceGroup -Name "rg-bastion-lab" -Location "uksouth"

# 2. Create VNet with AzureBastionSubnet + workload subnet
# (Use commands from Configuration section)

# 3. Deploy a Windows VM without public IP
$cred = Get-Credential -Message "Enter VM credentials"
New-AzVM `
    -ResourceGroupName "rg-bastion-lab" `
    -Name "vm-test" `
    -Location "uksouth" `
    -VirtualNetworkName "vnet-bastion-lab" `
    -SubnetName "snet-workload" `
    -Credential $cred `
    -Size "Standard_B2s" `
    -PublicIpSku $null  # No public IP!

# 4. Deploy Azure Bastion (Standard SKU)
# (Use commands from Configuration section)

# 5. Configure NSG on AzureBastionSubnet
# (Use NSG commands from Configuration section)

# 6. Test: Connect to VM via Azure Portal → VM blade → Connect → Bastion
# 7. Test: Verify VM has NO public IP but is accessible via Bastion
# 8. Test: Remove one NSG rule and observe Bastion behavior
```

### Lab 2: Centralized Bastion with Hub-Spoke

```powershell
# 1. Create hub VNet with AzureBastionSubnet
# 2. Create spoke VNet with workload subnet
# 3. Create VNet peering between hub and spoke (allow forwarded traffic)
# 4. Deploy Bastion in hub VNet
# 5. Deploy VM in spoke VNet (no public IP)
# 6. Test: Connect to spoke VM through hub Bastion
# 7. Verify peering settings required for Bastion to reach spoke VMs
```

### Lab 3: Native Client Connection

```powershell
# Requires: Standard or Premium SKU, Azure CLI

# 1. Deploy Bastion Standard SKU
# 2. Enable native client support

# 3. Test RDP via native client
az network bastion rdp `
    --name "bastion-prod" `
    --resource-group "rg-bastion-lab" `
    --target-resource-id "/subscriptions/.../virtualMachines/vm-test"

# 4. Test SSH via native client with key authentication
az network bastion ssh `
    --name "bastion-prod" `
    --resource-group "rg-bastion-lab" `
    --target-resource-id "/subscriptions/.../virtualMachines/vm-linux" `
    --auth-type "ssh-key" `
    --ssh-key "~/.ssh/id_rsa"
```

---

## 11. Cross-Service Relationships

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Azure Bastion Integration Map                             │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        Azure Bastion                                    │ │
│  │                                                                         │ │
│  │   Deployment ──────► VNet (AzureBastionSubnet /26+)                    │ │
│  │              ──────► Public IP (Standard, Static) [except Premium]     │ │
│  │                                                                         │ │
│  │   Security ────────► NSG (required rules for Bastion subnet)           │ │
│  │           ────────► Microsoft Defender for Cloud (JIT complement)      │ │
│  │           ────────► Azure AD / Entra ID (authentication)              │ │
│  │           ────────► Key Vault (SSH private keys)                      │ │
│  │                                                                         │ │
│  │   Connectivity ───► VNet Peering (hub-spoke centralized access)       │ │
│  │               ───► Virtual WAN (spoke VNet, IP-based connection)      │ │
│  │               ───► ExpressRoute/VPN (private-only Premium)            │ │
│  │                                                                         │ │
│  │   Monitoring ─────► Azure Monitor (diagnostic logs)                   │ │
│  │             ─────► Activity Log (connection audit)                    │ │
│  │             ─────► Session Recording (Premium SKU)                    │ │
│  │                                                                         │ │
│  │   Governance ─────► Azure Policy (enforce Bastion deployment)         │ │
│  │             ─────► RBAC (control who can connect)                     │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│   Key Integration Patterns:                                                  │
│   • Hub Bastion + Spoke VMs via VNet Peering (most common enterprise)       │
│   • Bastion + Azure Firewall (coexist, different subnets, no UDR on Bastion)│
│   • Bastion + Defender JIT (complementary: JIT for time-limited, Bastion    │
│     for always-on secure access)                                             │
│   • Premium private-only + ExpressRoute (maximum security)                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Draw.io Diagram

```xml
<mxfile host="app.diagrams.net">
  <diagram name="Azure Bastion" id="bastion-arch">
    <mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1169" pageHeight="827">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <mxCell id="user" value="Admin User&#xa;(Browser / Native Client)" style="shape=actor;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;" vertex="1" parent="1">
          <mxGeometry x="400" y="20" width="120" height="60" as="geometry" />
        </mxCell>
        <mxCell id="bastion" value="Azure Bastion&#xa;(AzureBastionSubnet /26)&#xa;&#xa;TLS Port 443&#xa;Standard/Premium SKU" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="350" y="140" width="220" height="100" as="geometry" />
        </mxCell>
        <mxCell id="vm1" value="Windows VM&#xa;10.0.2.4&#xa;(No Public IP)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
          <mxGeometry x="240" y="320" width="140" height="80" as="geometry" />
        </mxCell>
        <mxCell id="vm2" value="Linux VM&#xa;10.0.2.5&#xa;(No Public IP)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
          <mxGeometry x="540" y="320" width="140" height="80" as="geometry" />
        </mxCell>
        <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;" edge="1" source="user" target="bastion" parent="1">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e2" value="RDP:3389" style="edgeStyle=orthogonalEdgeStyle;" edge="1" source="bastion" target="vm1" parent="1">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e3" value="SSH:22" style="edgeStyle=orthogonalEdgeStyle;" edge="1" source="bastion" target="vm2" parent="1">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```
