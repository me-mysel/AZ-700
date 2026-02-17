---
tags:
  - AZ-700
  - azure/networking
  - domain/core-networking
  - nat-gateway
  - snat
  - outbound-connectivity
  - public-ip
  - port-exhaustion
aliases:
  - NAT Gateway
  - Azure NAT Gateway
created: 2025-01-01
updated: 2026-02-07
---

# Azure NAT Gateway

> [!info] Related Notes
> - [[VNet_Subnets_IP_Addressing]] — Subnet association for NAT Gateway
> - [[Azure_Load_Balancer]] — SNAT comparison (NAT GW vs LB outbound rules)
> - [[Azure_Firewall_and_Firewall_Manager]] — Forced tunneling + outbound SNAT
> - [[DDoS_Protection]] — NAT Gateway public IPs and DDoS

## AZ-700 Exam Domain: Design and Implement Core Networking Infrastructure (25-30%)

---

## 1. Key Concepts & Definitions

### What is Azure NAT Gateway?

**Azure NAT Gateway** is a fully managed, highly resilient Network Address Translation (NAT) service that provides **outbound-only** internet connectivity for virtual machines and other resources in Azure virtual network subnets. It enables resources without public IP addresses to access the internet while presenting a predictable, static set of public IP addresses to external destinations.

NAT Gateway solves several critical challenges in cloud networking:
- **SNAT port exhaustion** — provides significantly more SNAT ports than Load Balancer (64,512 per IP vs ~1,024)
- **Predictable outbound IPs** — external services can allowlist specific IP addresses
- **Simplified architecture** — no need for individual public IPs on VMs
- **Security** — VMs have no inbound exposure from the internet

### How NAT Gateway Works

When a VM in a NAT Gateway-associated subnet initiates an outbound connection to the internet:

1. The VM sends traffic to the default route (0.0.0.0/0)
2. NAT Gateway intercepts the traffic
3. Source IP is translated from the VM's private IP to NAT Gateway's public IP
4. A SNAT port is allocated from the pool (64,512 ports per public IP)
5. Return traffic is translated back to the VM's private IP
6. Connection tracking maintains state for the duration of the connection

### Core Terminology

| Term | Definition |
|------|------------|
| **NAT Gateway** | Managed, zone-resilient service providing outbound internet connectivity via SNAT |
| **SNAT** | Source Network Address Translation — translates private source IPs to public IPs |
| **SNAT Port** | Ephemeral port used to uniquely identify outbound connections (64,512 per public IP) |
| **Public IP** | Standard SKU static public IP associated with NAT Gateway (1-16 IPs supported) |
| **Public IP Prefix** | Contiguous range of public IPs (/28 to /31) for predictable IP allocation |
| **Idle Timeout** | Time before idle connections are closed (configurable 4-120 minutes, default 4) |
| **Subnet Association** | NAT Gateway is associated at subnet level, not VNet level |

### NAT Gateway Specifications

| Specification | Value |
|---------------|-------|
| **SKU** | Standard (only option) |
| **SNAT Ports per Public IP** | 64,512 |
| **Maximum Public IPs** | 16 |
| **Maximum SNAT Ports (16 IPs)** | 1,032,192 |
| **Idle Timeout Range** | 4-120 minutes |
| **Supported Protocols** | TCP, UDP |
| **Zone Resilience** | Yes (when using zone-redundant IPs) |
| **Availability Zones** | Can be zonal or zone-redundant |
| **Throughput** | Up to 50 Gbps |
| **Connections per Public IP** | ~1M concurrent flows |

---

## 2. Architecture Overview

### NAT Gateway in a VNet

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              NAT GATEWAY ARCHITECTURE                                │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│                                    INTERNET                                          │
│                                        │                                             │
│                         ┌──────────────┴──────────────┐                             │
│                         │  External Destination       │                             │
│                         │  (API, Updates, etc.)       │                             │
│                         │  Sees: 52.x.x.x (NAT IP)    │                             │
│                         └──────────────┬──────────────┘                             │
│                                        │                                             │
│                         ┌──────────────▼──────────────┐                             │
│                         │        NAT GATEWAY          │                             │
│                         │                             │                             │
│                         │  Public IP: 52.x.x.x       │                             │
│                         │  -OR-                       │                             │
│                         │  Public IP Prefix:          │                             │
│                         │  52.x.x.0/28 (16 IPs)       │                             │
│                         │                             │                             │
│                         │  SNAT Ports: 64,512/IP      │                             │
│                         │  Idle Timeout: 4-120 min    │                             │
│                         │  Throughput: Up to 50 Gbps  │                             │
│                         └──────────────┬──────────────┘                             │
│                                        │                                             │
│  ┌─────────────────────────────────────┴─────────────────────────────────────────┐  │
│  │                        VIRTUAL NETWORK: 10.0.0.0/16                            │  │
│  │                                                                                │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐  │  │
│  │  │         SUBNET: 10.0.1.0/24 (NAT Gateway Associated)                    │  │  │
│  │  │                                                                          │  │  │
│  │  │   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌────────────────────┐   │  │  │
│  │  │   │   VM1    │   │   VM2    │   │   VM3    │   │   VMSS (10 VMs)    │   │  │  │
│  │  │   │  No PIP  │   │  No PIP  │   │  No PIP  │   │      No PIPs       │   │  │  │
│  │  │   │10.0.1.10 │   │10.0.1.11 │   │10.0.1.12 │   │  10.0.1.20-29      │   │  │  │
│  │  │   └──────────┘   └──────────┘   └──────────┘   └────────────────────┘   │  │  │
│  │  │                                                                          │  │  │
│  │  │   ALL outbound traffic → NAT Gateway → Internet (same public IP)        │  │  │
│  │  │                                                                          │  │  │
│  │  └─────────────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                                │  │
│  │  ┌─────────────────────────────────────────────────────────────────────────┐  │  │
│  │  │         SUBNET: 10.0.2.0/24 (No NAT Gateway)                            │  │  │
│  │  │                                                                          │  │  │
│  │  │   ┌──────────────┐   ┌───────────────────────────────────────────────┐  │  │  │
│  │  │   │     VM4      │   │                 Options:                       │  │  │  │
│  │  │   │   Has PIP    │   │  • Uses VM's own public IP                    │  │  │  │
│  │  │   │  52.y.y.y    │   │  • Uses Load Balancer SNAT (if backend pool)  │  │  │  │
│  │  │   └──────────────┘   │  • Default outbound access (DEPRECATED)       │  │  │  │
│  │  │                      └───────────────────────────────────────────────┘  │  │  │
│  │  │                                                                          │  │  │
│  │  └─────────────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                                │  │
│  └────────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### NAT Gateway Precedence (Critical for Exam!)

When multiple outbound options exist, NAT Gateway takes precedence:

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                        OUTBOUND CONNECTIVITY PRECEDENCE                              │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   PRIORITY ORDER (Highest to Lowest):                                               │
│                                                                                      │
│   1. ┌─────────────────────────────────────────────────────────────────────────┐   │
│      │  NAT GATEWAY (if associated with subnet)                                │   │
│      │  • ALWAYS wins for outbound traffic                                     │   │
│      │  • Overrides VM public IPs for outbound                                 │   │
│      │  • Overrides Load Balancer SNAT rules                                   │   │
│      └─────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                            │
│                                        ▼                                            │
│   2. ┌─────────────────────────────────────────────────────────────────────────┐   │
│      │  VM INSTANCE-LEVEL PUBLIC IP                                            │   │
│      │  • Used if no NAT Gateway                                               │   │
│      │  • VM uses its own public IP for outbound                              │   │
│      └─────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                            │
│                                        ▼                                            │
│   3. ┌─────────────────────────────────────────────────────────────────────────┐   │
│      │  LOAD BALANCER OUTBOUND RULES / SNAT                                    │   │
│      │  • Used if VM is in LB backend pool                                     │   │
│      │  • Default: ~1,024 SNAT ports per VM                                    │   │
│      └─────────────────────────────────────────────────────────────────────────┘   │
│                                        │                                            │
│                                        ▼                                            │
│   4. ┌─────────────────────────────────────────────────────────────────────────┐   │
│      │  DEFAULT OUTBOUND ACCESS (⚠️ DEPRECATED - Will be retired!)            │   │
│      │  • Unpredictable public IP assigned by Azure                            │   │
│      │  • Do NOT rely on this for production                                   │   │
│      └─────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ⚠️  CRITICAL EXAM POINT:                                                         │
│   If NAT Gateway is associated, it ALWAYS handles outbound traffic,                │
│   even if the VM has its own public IP (VM PIP is used for INBOUND only)          │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### SNAT Port Allocation

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                            SNAT PORT ALLOCATION                                      │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   NAT Gateway with 1 Public IP:                                                     │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │  Total SNAT Ports: 64,512                                                    │  │
│   │                                                                              │  │
│   │  Dynamic allocation based on demand:                                         │  │
│   │  • No pre-allocation per VM                                                  │  │
│   │  • Ports assigned on-demand                                                  │  │
│   │  • Supports ~64,000 concurrent connections to unique destinations           │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   NAT Gateway with Public IP Prefix (/28 = 16 IPs):                                │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │  Total SNAT Ports: 16 × 64,512 = 1,032,192                                  │  │
│   │                                                                              │  │
│   │  Benefits:                                                                   │  │
│   │  • Massive scale for high-volume workloads                                  │  │
│   │  • Contiguous IP range for firewall allowlisting                           │  │
│   │  • Supports millions of concurrent connections                              │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   Comparison with Load Balancer:                                                    │
│   ┌────────────────────────┬─────────────────────────────────────────────────────┐ │
│   │ NAT Gateway            │ 64,512 ports per IP (dynamic, shared pool)         │ │
│   │ Load Balancer (default)│ ~1,024 ports per backend VM (static allocation)    │ │
│   │ Load Balancer (manual) │ Up to 64,000 ports per VM (with outbound rules)    │ │
│   └────────────────────────┴─────────────────────────────────────────────────────┘ │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Configuration Best Practices

### Create NAT Gateway with Single Public IP

```powershell
# Variables
$rgName = "rg-networking-prod"
$location = "eastus"
$vnetName = "vnet-prod"
$subnetName = "snet-backend"
$natGwName = "natgw-backend"

# Create Resource Group
New-AzResourceGroup -Name $rgName -Location $location

# Create Public IP for NAT Gateway (MUST be Standard SKU, Static)
$publicIp = New-AzPublicIpAddress `
    -Name "$natGwName-pip" `
    -ResourceGroupName $rgName `
    -Location $location `
    -Sku "Standard" `
    -AllocationMethod "Static" `
    -Zone 1, 2, 3  # Zone-redundant for high availability

Write-Host "Public IP created: $($publicIp.IpAddress)"

# Create NAT Gateway
$natGateway = New-AzNatGateway `
    -Name $natGwName `
    -ResourceGroupName $rgName `
    -Location $location `
    -PublicIpAddress $publicIp `
    -IdleTimeoutInMinutes 10 `
    -Sku "Standard"

Write-Host "NAT Gateway created: $($natGateway.Name)"

# Create VNet and Subnet (or get existing)
$subnetConfig = New-AzVirtualNetworkSubnetConfig `
    -Name $subnetName `
    -AddressPrefix "10.0.1.0/24" `
    -NatGateway $natGateway  # Associate during creation

$vnet = New-AzVirtualNetwork `
    -Name $vnetName `
    -ResourceGroupName $rgName `
    -Location $location `
    -AddressPrefix "10.0.0.0/16" `
    -Subnet $subnetConfig

Write-Host "VNet created with NAT Gateway associated to subnet"
```

### Associate NAT Gateway with Existing Subnet

```powershell
# Get existing VNet and Subnet
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet

# Get NAT Gateway
$natGateway = Get-AzNatGateway -Name $natGwName -ResourceGroupName $rgName

# Associate NAT Gateway with Subnet
$subnet.NatGateway = $natGateway
$vnet | Set-AzVirtualNetwork

Write-Host "NAT Gateway associated with subnet: $subnetName"
```

### Create NAT Gateway with Public IP Prefix (High Scale)

```powershell
# Create Public IP Prefix (/28 = 16 contiguous IPs)
$publicIpPrefix = New-AzPublicIpPrefix `
    -Name "$natGwName-prefix" `
    -ResourceGroupName $rgName `
    -Location $location `
    -PrefixLength 28 `
    -Sku "Standard" `
    -Zone 1, 2, 3

Write-Host "Public IP Prefix created: $($publicIpPrefix.IPPrefix)"
Write-Host "Available IPs: 16 (SNAT Ports: 1,032,192)"

# Create NAT Gateway with Prefix
$natGatewayHighScale = New-AzNatGateway `
    -Name "$natGwName-highscale" `
    -ResourceGroupName $rgName `
    -Location $location `
    -PublicIpPrefix $publicIpPrefix `
    -IdleTimeoutInMinutes 30 `
    -Sku "Standard"

Write-Host "High-scale NAT Gateway created with IP Prefix"
```

### Configure Multiple Public IPs on NAT Gateway

```powershell
# Create additional public IPs
$pip1 = New-AzPublicIpAddress -Name "natgw-pip-1" -ResourceGroupName $rgName `
    -Location $location -Sku "Standard" -AllocationMethod "Static" -Zone 1,2,3

$pip2 = New-AzPublicIpAddress -Name "natgw-pip-2" -ResourceGroupName $rgName `
    -Location $location -Sku "Standard" -AllocationMethod "Static" -Zone 1,2,3

$pip3 = New-AzPublicIpAddress -Name "natgw-pip-3" -ResourceGroupName $rgName `
    -Location $location -Sku "Standard" -AllocationMethod "Static" -Zone 1,2,3

# Create NAT Gateway with multiple public IPs
$natGatewayMultiIp = New-AzNatGateway `
    -Name "natgw-multi-ip" `
    -ResourceGroupName $rgName `
    -Location $location `
    -PublicIpAddress @($pip1, $pip2, $pip3) `
    -IdleTimeoutInMinutes 10 `
    -Sku "Standard"

Write-Host "NAT Gateway created with 3 public IPs"
Write-Host "Total SNAT Ports: $(3 * 64512)"
```

### Verify NAT Gateway Configuration

```powershell
# Get NAT Gateway details
$natGw = Get-AzNatGateway -Name $natGwName -ResourceGroupName $rgName

# Display configuration
Write-Host "NAT Gateway: $($natGw.Name)"
Write-Host "Idle Timeout: $($natGw.IdleTimeoutInMinutes) minutes"
Write-Host "Public IPs:"
foreach ($pip in $natGw.PublicIpAddresses) {
    $ip = Get-AzPublicIpAddress -ResourceGroupName $rgName | Where-Object { $_.Id -eq $pip.Id }
    Write-Host "  - $($ip.IpAddress)"
}

# Find subnets using this NAT Gateway
$vnets = Get-AzVirtualNetwork -ResourceGroupName $rgName
foreach ($vnet in $vnets) {
    foreach ($subnet in $vnet.Subnets) {
        if ($subnet.NatGateway.Id -eq $natGw.Id) {
            Write-Host "Associated Subnet: $($vnet.Name)/$($subnet.Name)"
        }
    }
}
```

### Test Outbound Connectivity from VM

```powershell
# Run from VM to verify NAT Gateway is being used
# PowerShell on Windows VM:
Invoke-RestMethod -Uri "https://api.ipify.org?format=json"

# Bash on Linux VM:
# curl https://api.ipify.org?format=json

# The returned IP should match your NAT Gateway's public IP
```

---

## 4. Comparison Tables

### NAT Gateway vs Other Outbound Options

| Feature | NAT Gateway | VM Public IP | Load Balancer SNAT | Default Outbound |
|---------|-------------|--------------|-------------------|------------------|
| **Predictable IP** | ✅ Yes (static) | ✅ Yes (static) | ✅ Yes (LB frontend) | ❌ No (dynamic) |
| **SNAT Ports** | 64,512 per IP | N/A | ~1,024 default/VM | Limited |
| **Max SNAT Ports** | 1,032,192 (16 IPs) | N/A | 64,000 per VM (manual) | Unknown |
| **Zone Resilience** | ✅ Yes | Zonal only | Depends on SKU | N/A |
| **Idle Timeout** | 4-120 min (configurable) | 4 min (fixed) | 4-30 min | 4 min |
| **Inbound Support** | ❌ No | ✅ Yes | ✅ Yes | ❌ No |
| **Cost** | Per hour + data | Per IP/month | Included with LB | Free (deprecated) |
| **Management** | Simple | Per-VM | Per-LB | None |
| **Best For** | Outbound-only workloads | Inbound + outbound | Load-balanced apps | Legacy only |

### SNAT Port Comparison

| Configuration | SNAT Ports Available | Notes |
|--------------|---------------------|-------|
| NAT Gateway (1 IP) | 64,512 | Dynamic pool, shared |
| NAT Gateway (16 IPs) | 1,032,192 | Maximum configuration |
| Load Balancer (default) | ~1,024 per VM | Based on pool size |
| Load Balancer (manual outbound rules) | Up to 64,000 per VM | Requires configuration |
| VM with Public IP | N/A (no SNAT) | Direct routing |

### Public IP vs Public IP Prefix

| Aspect | Individual Public IPs | Public IP Prefix |
|--------|----------------------|------------------|
| **Allocation** | One at a time | Contiguous block |
| **Sizes Available** | N/A | /31, /30, /29, /28 |
| **Firewall Rules** | Multiple entries | Single CIDR entry |
| **IP Predictability** | Only the assigned IP | Known range |
| **Max IPs per NAT GW** | 16 individual | Prefix size (up to 16) |
| **Best For** | Small deployments | Enterprise, compliance |

---

## 5. Exam Tips & Gotchas

### Critical Points to Memorize

1. **NAT Gateway ALWAYS takes precedence** — If a subnet has NAT Gateway associated, all outbound traffic uses NAT Gateway, even if VMs have their own public IPs (VM PIPs still work for inbound)

2. **64,512 SNAT ports per public IP** — This is the key number for capacity planning questions

3. **Outbound only** — NAT Gateway provides NO inbound connectivity. Use Load Balancer, Application Gateway, or VM public IPs for inbound

4. **Standard SKU public IPs required** — NAT Gateway does NOT work with Basic SKU public IPs

5. **Subnet-level association** — NAT Gateway is associated with subnets, not VNets. Multiple subnets can share one NAT Gateway

6. **Zone-redundant by default** — When using zone-redundant public IPs, NAT Gateway survives availability zone failures

7. **Idle timeout: 4-120 minutes** — Configurable, default is 4 minutes. Increase for long-running connections

8. **Cannot use with Basic Load Balancer** — NAT Gateway requires Standard SKU resources throughout

9. **TCP and UDP only** — NAT Gateway supports TCP and UDP protocols (ICMP has limitations)

10. **Default outbound access is deprecated** — Microsoft recommends explicit outbound connectivity via NAT Gateway, Load Balancer outbound rules, or VM public IPs

### Common Exam Scenarios

| Scenario | Solution |
|----------|----------|
| "VMs need predictable outbound IP for third-party API allowlisting" | NAT Gateway with static public IP |
| "Experiencing SNAT port exhaustion on Load Balancer" | Add NAT Gateway (64,512 vs 1,024 ports) |
| "Multiple subnets need same outbound IP" | Associate same NAT Gateway with multiple subnets |
| "Need both inbound AND outbound on same IP" | Use Load Balancer (NAT Gateway is outbound-only) |
| "Getting 'default outbound access deprecated' warning" | Implement NAT Gateway or LB outbound rules |
| "High-volume batch jobs exhausting SNAT ports" | NAT Gateway with Public IP Prefix (16 IPs) |
| "VMs have public IPs but need different outbound IP" | Add NAT Gateway (overrides VM PIP for outbound) |
| "Zone failure causing outbound connectivity issues" | NAT Gateway with zone-redundant public IPs |

### Common Mistakes to Avoid

1. **Trying to use NAT Gateway for inbound** — It's outbound-only; use LB or VM PIPs for inbound

2. **Using Basic SKU public IPs** — NAT Gateway requires Standard SKU

3. **Forgetting to associate with subnet** — Creating NAT Gateway doesn't automatically associate it

4. **Expecting per-VM port allocation** — NAT Gateway uses a shared dynamic pool, not per-VM allocation

5. **Not considering idle timeout** — Default 4 minutes may drop long-idle connections; increase if needed

6. **Mixing with Basic Load Balancer** — Not compatible; use Standard Load Balancer only

### Key Limits to Remember

| Resource | Limit |
|----------|-------|
| Public IPs per NAT Gateway | 16 |
| SNAT ports per public IP | 64,512 |
| Max SNAT ports (16 IPs) | 1,032,192 |
| Idle timeout range | 4-120 minutes |
| Throughput | Up to 50 Gbps |
| Connections per public IP | ~1 million |

---

## 6. Hands-On Lab Suggestions

### Lab 1: Basic NAT Gateway Deployment

**Objective**: Deploy NAT Gateway and verify outbound connectivity

```powershell
# Step 1: Create resource group
New-AzResourceGroup -Name "rg-nat-lab" -Location "eastus"

# Step 2: Create public IP for NAT Gateway
$pip = New-AzPublicIpAddress -Name "natgw-pip" -ResourceGroupName "rg-nat-lab" `
    -Location "eastus" -Sku "Standard" -AllocationMethod "Static" -Zone 1,2,3

# Step 3: Create NAT Gateway
$natGw = New-AzNatGateway -Name "natgw-lab" -ResourceGroupName "rg-nat-lab" `
    -Location "eastus" -PublicIpAddress $pip -IdleTimeoutInMinutes 10

# Step 4: Create VNet with subnet associated to NAT Gateway
$subnetConfig = New-AzVirtualNetworkSubnetConfig -Name "snet-workload" `
    -AddressPrefix "10.0.1.0/24" -NatGateway $natGw

$vnet = New-AzVirtualNetwork -Name "vnet-nat-lab" -ResourceGroupName "rg-nat-lab" `
    -Location "eastus" -AddressPrefix "10.0.0.0/16" -Subnet $subnetConfig

# Step 5: Deploy a test VM (no public IP)
# ... (create VM without PIP in the subnet)

# Step 6: SSH/RDP to VM via Bastion or jump box
# Run: curl https://api.ipify.org
# Verify returned IP matches NAT Gateway's public IP
```

### Lab 2: Compare SNAT Port Exhaustion

**Objective**: Demonstrate NAT Gateway advantage over Load Balancer SNAT

1. Create two subnets: one with NAT Gateway, one using Load Balancer SNAT
2. Deploy VMs in each subnet running a high-connection workload
3. Monitor SNAT port metrics in Azure Monitor
4. Observe how NAT Gateway handles high port demand vs Load Balancer

### Lab 3: NAT Gateway with Public IP Prefix

**Objective**: Deploy high-scale NAT Gateway for enterprise scenarios

```powershell
# Create Public IP Prefix (/28 = 16 IPs)
$prefix = New-AzPublicIpPrefix -Name "natgw-prefix" -ResourceGroupName "rg-nat-lab" `
    -Location "eastus" -PrefixLength 28 -Sku "Standard" -Zone 1,2,3

Write-Host "IP Prefix Range: $($prefix.IPPrefix)"

# Create NAT Gateway with prefix
$natGw = New-AzNatGateway -Name "natgw-highscale" -ResourceGroupName "rg-nat-lab" `
    -Location "eastus" -PublicIpPrefix $prefix -IdleTimeoutInMinutes 30

# Document the IP range for firewall allowlisting
```

### Lab 4: Verify NAT Gateway Precedence

**Objective**: Demonstrate that NAT Gateway overrides VM public IPs for outbound

1. Create NAT Gateway with public IP (e.g., 52.1.1.1)
2. Deploy VM with its own public IP (e.g., 52.2.2.2)
3. Associate NAT Gateway with VM's subnet
4. From VM, check outbound IP: `curl https://api.ipify.org`
5. Verify outbound uses NAT Gateway IP (52.1.1.1), not VM IP
6. Verify inbound to VM still uses VM's public IP (52.2.2.2)

### Lab 5: Monitor NAT Gateway Metrics

**Objective**: Set up monitoring and alerts for NAT Gateway

```powershell
# Enable diagnostic settings
$natGw = Get-AzNatGateway -Name "natgw-lab" -ResourceGroupName "rg-nat-lab"
$workspace = Get-AzOperationalInsightsWorkspace -Name "law-monitoring" -ResourceGroupName "rg-monitoring"

Set-AzDiagnosticSetting -ResourceId $natGw.Id `
    -WorkspaceId $workspace.ResourceId `
    -Enabled $true `
    -Category "DataPathAvailability"

# Key metrics to monitor:
# - SNATConnectionCount: Current SNAT connections
# - TotalConnectionCount: Total connections
# - DroppedConnectionCount: Connections dropped (potential exhaustion)
# - ByteCount: Data transferred
# - PacketCount: Packets transferred
```

---

## 7. Cross-Service Relationships

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         NAT GATEWAY INTEGRATION MAP                                  │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    WORKS WITH (COMPLEMENTS)                                 │   │
│   │                                                                             │   │
│   │  Standard Load Balancer  → NAT GW handles outbound, LB handles inbound     │   │
│   │  Application Gateway     → AppGW for web apps, NAT GW for backend egress   │   │
│   │  Azure Firewall          → Can replace NAT GW; provides inspection + NAT   │   │
│   │  Private Endpoints       → No NAT needed for PaaS; NAT GW for internet     │   │
│   │  Network Security Groups → NSGs filter traffic; NAT GW provides egress     │   │
│   │  Virtual Network         → NAT GW associated at subnet level within VNet   │   │
│   │  VMSS                    → NAT GW ideal for VMSS without PIPs              │   │
│   │  AKS                     → NAT GW supported for cluster egress             │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    DOES NOT WORK WITH                                       │   │
│   │                                                                             │   │
│   │  Basic Load Balancer     → Requires Standard SKU resources                 │   │
│   │  Basic Public IPs        → Requires Standard SKU public IPs                │   │
│   │  VPN/ExpressRoute traffic→ NAT GW not used for on-premises traffic         │   │
│   │  Private traffic (VNet)  → NAT GW only for internet-bound traffic          │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    TRAFFIC FLOW DECISION                                    │   │
│   │                                                                             │   │
│   │  Destination: Internet     → Uses NAT Gateway (if associated)              │   │
│   │  Destination: VNet         → Direct routing (no NAT)                       │   │
│   │  Destination: On-premises  → Uses VPN/ExpressRoute (no NAT)                │   │
│   │  Destination: PaaS (PE)    → Uses Private Endpoint (no NAT needed)         │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### When to Use NAT Gateway vs Alternatives

| Use Case | Recommended Solution |
|----------|---------------------|
| Backend VMs need predictable outbound IP | **NAT Gateway** |
| High-volume SNAT (many outbound connections) | **NAT Gateway** with IP Prefix |
| Inbound + outbound on same IP | **Standard Load Balancer** |
| Full traffic inspection + logging | **Azure Firewall** |
| Web application delivery | **Application Gateway** + NAT Gateway for backend |
| PaaS service access | **Private Endpoints** (no NAT needed) |
| Kubernetes egress | **NAT Gateway** or **Azure Firewall** |

---

## Quick Reference Card

| Item | Value |
|------|-------|
| **SNAT Ports per Public IP** | 64,512 |
| **Maximum Public IPs** | 16 |
| **Maximum SNAT Ports** | 1,032,192 (16 IPs × 64,512) |
| **Idle Timeout Range** | 4-120 minutes (default: 4) |
| **Throughput** | Up to 50 Gbps |
| **Protocols Supported** | TCP, UDP |
| **Public IP SKU Required** | Standard (Static) |
| **Inbound Connectivity** | ❌ Not supported (outbound only) |
| **Zone Resilience** | ✅ Yes (with zone-redundant IPs) |
| **Precedence** | Highest (overrides VM PIPs, LB SNAT) |

---

## Architecture Diagram File

📂 Open [NAT_Gateway_Architecture.drawio](NAT_Gateway_Architecture.drawio) in VS Code with the Draw.io Integration extension.

---

## Additional Resources

- [Azure NAT Gateway Documentation](https://learn.microsoft.com/en-us/azure/nat-gateway/)
- [NAT Gateway FAQ](https://learn.microsoft.com/en-us/azure/nat-gateway/faq)
- [Design Virtual Networks with NAT Gateway](https://learn.microsoft.com/en-us/azure/nat-gateway/nat-gateway-resource)
- [Troubleshoot NAT Gateway](https://learn.microsoft.com/en-us/azure/nat-gateway/troubleshoot-nat)
- [NAT Gateway Metrics](https://learn.microsoft.com/en-us/azure/nat-gateway/nat-metrics)
