---
tags:
  - AZ-700
  - azure/networking
  - azure/security
  - domain/network-security
  - azure-firewall
  - firewall-manager
  - dnat
  - network-rules
  - application-rules
  - firewall-policy
  - secured-virtual-hub
  - threat-intelligence
  - idps
  - firewall-skus
aliases:
  - Azure Firewall
  - Firewall Manager
  - Azure Firewall Manager
created: 2025-01-01
updated: 2026-02-07
---

# Azure Firewall and Firewall Manager

> [!info] Related Notes
> - [[NSG_ASG_Firewall]] — NSG vs Azure Firewall comparison
> - [[WAF]] — WAF for L7 web app protection (complementary to Firewall)
> - [[Virtual_WAN]] — Secured virtual hubs with Firewall Manager
> - [[VNet_Peering_Routing]] — UDRs to route traffic through Firewall
> - [[Azure_Route_Server]] — NVA integration scenarios
> - [[NAT_Gateway]] — Outbound SNAT through Firewall vs NAT Gateway
> - [[DDoS_Protection]] — Defense in depth with Firewall

## AZ-700 Exam Domain: Design and Implement Azure Network Security Services (15-20%)

---

## 1. Key Concepts & Definitions

### Azure Firewall
Azure Firewall is a **cloud-native, stateful firewall-as-a-service** with built-in high availability and unrestricted cloud scalability. It provides centralized network and application-level protection across VNets.

**Core Terminology:**

| Term | Definition |
|------|------------|
| **DNAT Rule** | Destination NAT - translates inbound traffic to private IPs (inbound access) |
| **Network Rule** | Layer 3/4 filtering based on source/destination IP, port, protocol |
| **Application Rule** | Layer 7 filtering using FQDNs (HTTP/HTTPS/MSSQL) |
| **Threat Intelligence** | Blocks traffic to/from known malicious IPs and domains |
| **IDPS** | Intrusion Detection and Prevention System (Premium SKU) |
| **TLS Inspection** | Decrypts and inspects HTTPS traffic (Premium SKU) |
| **SNAT** | Source NAT - outbound traffic uses firewall's public IP(s) |
| **Firewall Policy** | Reusable rule collection that can be shared across firewalls |

### Azure Firewall SKUs

| SKU | Use Case | Key Features |
|-----|----------|--------------|
| **Basic** | SMB with <250 Mbps throughput | Fixed scale, threat intel alerts only |
| **Standard** | Production workloads | L3-L7 filtering, threat intel, FQDN filtering, 30 Gbps |
| **Premium** | Highly sensitive workloads | TLS inspection, IDPS, URL filtering, web categories, 100 Gbps |

**Critical Exam Point**: **Basic SKU does NOT support forced tunneling or DNS proxy**.

### Azure Firewall Manager
A **central security management service** for cloud-based security perimeters. It provides:
- **Centralized policy management** across multiple firewalls
- **Secured Virtual Hub** integration (Virtual WAN)
- **Third-party SECaaS** provider integration
- **DDoS Protection Plan** association

**Key Concepts:**

| Term | Definition |
|------|------------|
| **Firewall Policy** | Hierarchical rule structure (parent/child inheritance) |
| **Secured Virtual Hub** | Virtual WAN hub with Azure Firewall deployed |
| **Hub VNet** | Traditional hub-spoke with standalone Azure Firewall |
| **Security Partner Provider** | Third-party SECaaS (Zscaler, Check Point, iboss) |

---

## 2. Architecture Overview

### Azure Firewall Hub-Spoke Architecture

```
                                    ┌─────────────────────┐
                                    │      Internet       │
                                    └──────────┬──────────┘
                                               │
                                    ┌──────────▼──────────┐
                                    │    Public IP(s)     │
                                    │  (Up to 250 IPs)    │
                                    └──────────┬──────────┘
                                               │
┌──────────────────────────────────────────────▼──────────────────────────────────────────────┐
│                                        HUB VNET                                              │
│  ┌────────────────────────────────────────────────────────────────────────────────────┐     │
│  │                          AzureFirewallSubnet (/26 minimum)                         │     │
│  │  ┌──────────────────────────────────────────────────────────────────────────────┐  │     │
│  │  │                           AZURE FIREWALL                                      │  │     │
│  │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │  │     │
│  │  │  │ DNAT Rules  │  │Network Rules│  │  App Rules  │  │ Threat Intelligence │  │  │     │
│  │  │  │ (Priority 1)│  │ (Priority 2)│  │ (Priority 3)│  │    + IDPS (Prem)    │  │  │     │
│  │  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────────┘  │  │     │
│  │  └──────────────────────────────────────────────────────────────────────────────┘  │     │
│  └────────────────────────────────────────────────────────────────────────────────────┘     │
│                                               │                                              │
│  ┌────────────────────────────────────────────┴────────────────────────────────────────┐    │
│  │                    AzureFirewallManagementSubnet (/26) - Forced Tunneling           │    │
│  └─────────────────────────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────────────────────────────┘
           │                              │                              │
           │ VNet Peering                 │ VNet Peering                 │ VNet Peering
           ▼                              ▼                              ▼
┌──────────────────────┐     ┌──────────────────────┐     ┌──────────────────────┐
│     SPOKE VNET 1     │     │     SPOKE VNET 2     │     │     SPOKE VNET 3     │
│   ┌──────────────┐   │     │   ┌──────────────┐   │     │   ┌──────────────┐   │
│   │  Web Tier    │   │     │   │  App Tier    │   │     │   │  Data Tier   │   │
│   │   Subnet     │   │     │   │   Subnet     │   │     │   │   Subnet     │   │
│   └──────────────┘   │     │   └──────────────┘   │     │   └──────────────┘   │
│   UDR: 0.0.0.0/0     │     │   UDR: 0.0.0.0/0     │     │   UDR: 0.0.0.0/0     │
│   → Firewall IP      │     │   → Firewall IP      │     │   → Firewall IP      │
└──────────────────────┘     └──────────────────────┘     └──────────────────────┘
```

### Rule Processing Order

```
┌─────────────────────────────────────────────────────────────────┐
│                    RULE PROCESSING ORDER                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   1. ┌─────────────────────────────────────────────────────┐    │
│      │  DNAT Rules (Inbound) - Processed FIRST             │    │
│      │  • Translates destination before other rules        │    │
│      └─────────────────────────────────────────────────────┘    │
│                              ▼                                   │
│   2. ┌─────────────────────────────────────────────────────┐    │
│      │  Network Rules (L3/L4)                              │    │
│      │  • IP addresses, ports, protocols                   │    │
│      │  • Processed by PRIORITY (lowest number first)      │    │
│      └─────────────────────────────────────────────────────┘    │
│                              ▼                                   │
│   3. ┌─────────────────────────────────────────────────────┐    │
│      │  Application Rules (L7)                             │    │
│      │  • FQDNs, URL filtering, web categories             │    │
│      │  • Only if NO network rule match                    │    │
│      └─────────────────────────────────────────────────────┘    │
│                              ▼                                   │
│   4. ┌─────────────────────────────────────────────────────┐    │
│      │  Infrastructure Rules (Implicit)                    │    │
│      │  • Azure platform FQDNs allowed by default          │    │
│      │  • Can be disabled per rule collection              │    │
│      └─────────────────────────────────────────────────────┘    │
│                              ▼                                   │
│   5. ┌─────────────────────────────────────────────────────┐    │
│      │  DEFAULT DENY - All traffic blocked                 │    │
│      └─────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Architecture Diagram File

📂 Open [Azure_Firewall_Architecture.drawio](Azure_Firewall_Architecture.drawio) in VS Code with the Draw.io Integration extension.

---

## 3. Configuration Best Practices

### Deploy Azure Firewall with PowerShell

```powershell
# Variables
$rgName = "rg-firewall-prod"
$location = "eastus"
$vnetName = "vnet-hub"
$fwName = "fw-hub-prod"
$fwPolicyName = "fwpolicy-prod"

# Create Resource Group
New-AzResourceGroup -Name $rgName -Location $location

# Create Hub VNet with AzureFirewallSubnet (MUST be /26 or larger)
$fwSubnet = New-AzVirtualNetworkSubnetConfig -Name "AzureFirewallSubnet" -AddressPrefix "10.0.1.0/26"
$vnet = New-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgName `
    -Location $location -AddressPrefix "10.0.0.0/16" -Subnet $fwSubnet

# Create Public IP for Firewall
$fwPip = New-AzPublicIpAddress -Name "$fwName-pip" -ResourceGroupName $rgName `
    -Location $location -AllocationMethod Static -Sku Standard

# Create Firewall Policy (Standard SKU)
$fwPolicy = New-AzFirewallPolicy -Name $fwPolicyName -ResourceGroupName $rgName `
    -Location $location -ThreatIntelMode "Alert"

# Deploy Azure Firewall (Standard SKU)
$fw = New-AzFirewall -Name $fwName -ResourceGroupName $rgName `
    -Location $location -VirtualNetwork $vnet `
    -PublicIpAddress $fwPip -FirewallPolicyId $fwPolicy.Id

# Get Firewall Private IP for UDR
$fwPrivateIP = $fw.IpConfigurations[0].PrivateIPAddress
Write-Host "Firewall Private IP: $fwPrivateIP"
```

### Create Firewall Policy Rules

```powershell
# Create Application Rule Collection
$appRule = New-AzFirewallPolicyApplicationRule -Name "Allow-Microsoft" `
    -SourceAddress "10.0.0.0/16" `
    -TargetFqdn "*.microsoft.com", "*.azure.com" `
    -Protocol "Https:443"

$appRuleCollection = New-AzFirewallPolicyFilterRuleCollection `
    -Name "AppRules-Allow-Web" `
    -Priority 200 `
    -ActionType "Allow" `
    -Rule $appRule

# Create Network Rule Collection
$netRule = New-AzFirewallPolicyNetworkRule -Name "Allow-DNS" `
    -SourceAddress "10.0.0.0/16" `
    -DestinationAddress "168.63.129.16" `
    -DestinationPort "53" `
    -Protocol "UDP"

$netRuleCollection = New-AzFirewallPolicyFilterRuleCollection `
    -Name "NetRules-Allow-DNS" `
    -Priority 100 `
    -ActionType "Allow" `
    -Rule $netRule

# Create DNAT Rule for inbound RDP
$dnatRule = New-AzFirewallPolicyNatRule -Name "DNAT-RDP-VM1" `
    -SourceAddress "*" `
    -DestinationAddress $fwPip.IpAddress `
    -DestinationPort "3389" `
    -Protocol "TCP" `
    -TranslatedAddress "10.0.2.4" `
    -TranslatedPort "3389"

$dnatRuleCollection = New-AzFirewallPolicyNatRuleCollection `
    -Name "DNAT-Inbound" `
    -Priority 100 `
    -ActionType "DNAT" `
    -Rule $dnatRule

# Create Rule Collection Group
$rcg = New-AzFirewallPolicyRuleCollectionGroup -Name "DefaultRuleCollectionGroup" `
    -Priority 100 `
    -FirewallPolicyName $fwPolicyName `
    -ResourceGroupName $rgName `
    -RuleCollection $dnatRuleCollection, $netRuleCollection, $appRuleCollection
```

### Configure User-Defined Route (UDR)

```powershell
# Create Route Table
$routeTable = New-AzRouteTable -Name "rt-spoke-to-fw" `
    -ResourceGroupName $rgName -Location $location

# Add default route to firewall
Add-AzRouteConfig -Name "ToFirewall" -RouteTable $routeTable `
    -AddressPrefix "0.0.0.0/0" `
    -NextHopType "VirtualAppliance" `
    -NextHopIpAddress $fwPrivateIP | Set-AzRouteTable

# Associate with spoke subnet
$spokeVnet = Get-AzVirtualNetwork -Name "vnet-spoke1" -ResourceGroupName $rgName
Set-AzVirtualNetworkSubnetConfig -Name "snet-workload" `
    -VirtualNetwork $spokeVnet `
    -AddressPrefix "10.1.0.0/24" `
    -RouteTable $routeTable | Set-AzVirtualNetwork
```

### Enable Forced Tunneling

```powershell
# Requires AzureFirewallManagementSubnet (/26 minimum)
$mgmtSubnet = New-AzVirtualNetworkSubnetConfig -Name "AzureFirewallManagementSubnet" `
    -AddressPrefix "10.0.2.0/26"

# Create Management Public IP
$mgmtPip = New-AzPublicIpAddress -Name "$fwName-mgmt-pip" `
    -ResourceGroupName $rgName -Location $location `
    -AllocationMethod Static -Sku Standard

# Deploy with Forced Tunneling
$fw = New-AzFirewall -Name $fwName -ResourceGroupName $rgName `
    -Location $location -VirtualNetwork $vnet `
    -PublicIpAddress $fwPip `
    -ManagementPublicIpAddress $mgmtPip `
    -FirewallPolicyId $fwPolicy.Id
```

---

## 4. Comparison Tables

### Azure Firewall SKU Comparison

| Feature | Basic | Standard | Premium |
|---------|-------|----------|---------|
| **Throughput** | Up to 250 Mbps | Up to 30 Gbps | Up to 100 Gbps |
| **Availability Zones** | ❌ | ✅ | ✅ |
| **Threat Intelligence** | Alert only | Alert & Deny | Alert & Deny |
| **FQDN Filtering** | ✅ | ✅ | ✅ |
| **FQDN Tags** | ✅ | ✅ | ✅ |
| **Web Categories** | ❌ | ❌ | ✅ |
| **IDPS** | ❌ | ❌ | ✅ |
| **TLS Inspection** | ❌ | ❌ | ✅ |
| **URL Filtering** | ❌ | ❌ | ✅ |
| **Forced Tunneling** | ❌ | ✅ | ✅ |
| **DNS Proxy** | ❌ | ✅ | ✅ |
| **Multiple Public IPs** | ❌ | ✅ (250 max) | ✅ (250 max) |

### Azure Firewall vs NSG vs NVA

| Aspect | Azure Firewall | NSG | NVA |
|--------|----------------|-----|-----|
| **Layer** | L3-L7 | L3-L4 | L3-L7+ |
| **Stateful** | ✅ | ✅ | ✅ |
| **FQDN Filtering** | ✅ | ❌ | Varies |
| **TLS Inspection** | Premium only | ❌ | ✅ |
| **Threat Intelligence** | ✅ | ❌ | Varies |
| **High Availability** | Built-in | N/A | Manual |
| **Scaling** | Automatic | N/A | Manual |
| **Cost** | Higher | Free | Varies |
| **Management** | Firewall Manager | Portal/CLI | Vendor console |
| **Use Case** | Centralized perimeter | Subnet/NIC filtering | Advanced features |

### Hub VNet vs Secured Virtual Hub

| Aspect | Hub VNet (Traditional) | Secured Virtual Hub |
|--------|------------------------|---------------------|
| **Underlying Service** | Standard VNet | Virtual WAN Hub |
| **Management** | Manual peering | Automated connectivity |
| **Routing** | UDRs required | Intent-based routing |
| **Branch Connectivity** | VPN Gateway separate | Integrated VPN/ER |
| **Multi-Hub** | Complex | Built-in |
| **Best For** | Simple hub-spoke | Global WAN, multi-region |

---

## 5. Exam Tips & Gotchas

### Critical Points (Memorize These!)

- **AzureFirewallSubnet must be /26 or larger** — no other resources can be deployed in this subnet
- **Forced tunneling requires AzureFirewallManagementSubnet (/26)** and a separate management public IP
- **Rule processing order: DNAT → Network → Application** — network rules are checked before application rules
- **DNAT rules automatically create corresponding network rules** — no need to duplicate
- **Application rules only support HTTP (80), HTTPS (443), and MSSQL (1433)**
- **Basic SKU cannot use Forced Tunneling or DNS Proxy**
- **Premium SKU required for TLS inspection and IDPS**
- **Firewall Policy inheritance**: child policies can add rules but cannot override parent deny rules
- **DNS Proxy must be enabled for FQDN filtering in network rules** to work correctly
- **Threat Intelligence modes**: Off, Alert only, Alert and deny (default is Alert)
- **Up to 250 public IPs** can be associated with a single Azure Firewall
- **SNAT port exhaustion**: use multiple public IPs for high-volume outbound scenarios

### Common Exam Scenarios

1. **"Traffic to *.microsoft.com is blocked"**
   - Check if DNS Proxy is enabled (required for FQDN in network rules)
   - Verify application rule priority

2. **"Need to inspect HTTPS traffic for compliance"**
   - Requires **Premium SKU** with TLS Inspection
   - Need to deploy CA certificate to clients

3. **"Internet-bound traffic must go through on-premises firewall"**
   - Configure **Forced Tunneling**
   - Requires AzureFirewallManagementSubnet

4. **"Centrally manage firewall rules across subscriptions"**
   - Use **Azure Firewall Manager** with Firewall Policies
   - Leverage parent/child policy inheritance

5. **"Allow Azure Backup but deny all other internet"**
   - Use **FQDN Tags** (e.g., AzureBackup) in application rules
   - FQDN tags automatically include all required endpoints

---

## 6. Hands-On Lab Suggestions

### Lab 1: Deploy Azure Firewall in Hub-Spoke Topology
1. Create hub VNet with AzureFirewallSubnet
2. Deploy Azure Firewall (Standard SKU)
3. Create spoke VNet with workload VM
4. Configure VNet peering (hub ↔ spoke)
5. Create UDR to route traffic through firewall
6. Test outbound connectivity (should be blocked)
7. Add application rule to allow *.microsoft.com
8. Verify connectivity works

### Lab 2: Configure DNAT for Inbound Access
```powershell
# Create DNAT rule to allow SSH to internal VM
$dnatRule = New-AzFirewallPolicyNatRule -Name "DNAT-SSH" `
    -SourceAddress "*" `
    -DestinationAddress "<firewall-public-ip>" `
    -DestinationPort "22" `
    -Protocol "TCP" `
    -TranslatedAddress "<internal-vm-ip>" `
    -TranslatedPort "22"
```
- Test SSH access via firewall public IP
- Review logs in Log Analytics

### Lab 3: Implement Hierarchical Policies with Firewall Manager
1. Create parent policy with baseline rules (deny all, allow Azure services)
2. Create child policy inheriting from parent
3. Add workload-specific rules to child
4. Deploy firewall using child policy
5. Test that parent deny rules cannot be overridden

### Lab 4: Enable Diagnostic Logging
```powershell
# Enable diagnostics to Log Analytics
$fw = Get-AzFirewall -Name $fwName -ResourceGroupName $rgName
$workspace = Get-AzOperationalInsightsWorkspace -Name "law-firewall" -ResourceGroupName $rgName

Set-AzDiagnosticSetting -ResourceId $fw.Id `
    -WorkspaceId $workspace.ResourceId `
    -Enabled $true `
    -Category "AzureFirewallApplicationRule", "AzureFirewallNetworkRule", "AzureFirewallDnsProxy"
```

### Lab 5: Test IDPS (Premium SKU)
1. Deploy Premium Azure Firewall
2. Enable IDPS in Alert mode
3. Generate test malicious traffic (EICAR test file)
4. Review IDPS alerts in Log Analytics
5. Switch to Deny mode and verify blocking

---

## 7. Cross-Service Relationships

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         AZURE FIREWALL INTEGRATIONS                              │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   ┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐   │
│   │  Azure Monitor  │◄───────►│  AZURE FIREWALL │◄───────►│   Azure DNS     │   │
│   │  (Logs/Metrics) │         │                 │         │  (DNS Proxy)    │   │
│   └─────────────────┘         └────────┬────────┘         └─────────────────┘   │
│                                        │                                         │
│          ┌─────────────────────────────┼─────────────────────────────┐          │
│          │                             │                             │          │
│          ▼                             ▼                             ▼          │
│   ┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐   │
│   │ Firewall Policy │         │  Virtual WAN    │         │  VNet Peering   │   │
│   │ (Firewall Mgr)  │         │ (Secured Hub)   │         │  (Hub-Spoke)    │   │
│   └─────────────────┘         └─────────────────┘         └─────────────────┘   │
│                                                                                  │
│          ┌─────────────────────────────────────────────────────────┐            │
│          │                  COMPLEMENTS                             │            │
│          ├─────────────────────────────────────────────────────────┤            │
│          │  • NSGs - Subnet/NIC-level microsegmentation            │            │
│          │  • WAF (App Gateway/Front Door) - Web app protection    │            │
│          │  • DDoS Protection - Volumetric attack mitigation       │            │
│          │  • Private Endpoints - Secure PaaS access               │            │
│          │  • Azure Bastion - Secure VM management                 │            │
│          └─────────────────────────────────────────────────────────┘            │
│                                                                                  │
│          ┌─────────────────────────────────────────────────────────┐            │
│          │                  TRAFFIC FLOW                            │            │
│          ├─────────────────────────────────────────────────────────┤            │
│          │  • Route Server - Injects routes from NVAs              │            │
│          │  • ExpressRoute - Hybrid connectivity filtering         │            │
│          │  • VPN Gateway - Branch office traffic inspection       │            │
│          │  • NAT Gateway - Outbound SNAT (alternative)            │            │
│          └─────────────────────────────────────────────────────────┘            │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Key Integration Points

| Service | Integration Purpose |
|---------|---------------------|
| **NSG** | Use NSGs for micro-segmentation within subnets; Azure Firewall for perimeter |
| **WAF** | Deploy WAF (App Gateway/Front Door) in front of web apps; Azure Firewall for non-HTTP |
| **DDoS Protection** | Enable on VNet to protect firewall public IPs from volumetric attacks |
| **Azure DNS Private Zones** | Enable DNS Proxy on firewall for private DNS resolution |
| **Private Endpoints** | Route private endpoint traffic through firewall for inspection |
| **Virtual WAN** | Use Secured Virtual Hub for global, automated security |
| **Azure Monitor** | Send logs to Log Analytics for KQL queries and workbooks |
| **Microsoft Sentinel** | SIEM integration for threat detection and response |

---

## Quick Reference Card

| Item | Value/Requirement |
|------|-------------------|
| AzureFirewallSubnet | **/26 minimum**, dedicated subnet |
| AzureFirewallManagementSubnet | /26, required for forced tunneling |
| Max Public IPs | 250 |
| Rule Processing | DNAT → Network → Application |
| App Rule Protocols | HTTP:80, HTTPS:443, MSSQL:1433 |
| Standard Throughput | Up to 30 Gbps |
| Premium Throughput | Up to 100 Gbps |
| TLS Inspection | Premium SKU only |
| IDPS | Premium SKU only |
| DNS Proxy | Standard/Premium only |

---

## Additional Resources

- [Azure Firewall Documentation](https://learn.microsoft.com/en-us/azure/firewall/)
- [Azure Firewall Manager Documentation](https://learn.microsoft.com/en-us/azure/firewall-manager/)
- [Azure Firewall FAQ](https://learn.microsoft.com/en-us/azure/firewall/firewall-faq)
- [Azure Firewall Premium Features](https://learn.microsoft.com/en-us/azure/firewall/premium-features)
