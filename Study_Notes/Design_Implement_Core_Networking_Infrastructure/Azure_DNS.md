---
tags:
  - AZ-700
  - azure/networking
  - domain/core-networking
  - dns
  - private-dns-zone
  - public-dns-zone
  - dns-resolver
  - name-resolution
  - conditional-forwarding
aliases:
  - Azure DNS
  - Private DNS Zone
  - DNS Resolver
created: 2025-01-01
updated: 2026-02-07
---

# Azure DNS

> [!info] Related Notes
> - [[VNet_Subnets_IP_Addressing]] — VNet fundamentals and address spaces
> - [[Private_Endpoints]] — Private DNS zones for privatelink resolution
> - [[VPN_Gateway]] — Hybrid DNS (on-premises ↔ Azure)
> - [[ExpressRoute]] — DNS resolution over private peering
> - [[Virtual_WAN]] — DNS settings in Virtual WAN hubs

## Overview

Azure DNS provides name resolution services using Microsoft Azure infrastructure. It supports both public DNS zones (internet-facing) and private DNS zones (VNet-internal resolution).

### Key Components

| Component | Description |
|-----------|-------------|
| **Public DNS Zone** | Hosts DNS records for internet-resolvable domains |
| **Private DNS Zone** | Provides name resolution within VNets |
| **Azure DNS Resolver** | Enables conditional forwarding and hybrid DNS |
| **168.63.129.16** | Azure's internal recursive resolver |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           Azure DNS Architecture                                  │
│                                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                              INTERNET                                        │ │
│  │                                  │                                           │ │
│  │                    ┌─────────────▼─────────────┐                            │ │
│  │                    │    Public DNS Zone        │                            │ │
│  │                    │    contoso.com            │                            │ │
│  │                    │                           │                            │ │
│  │                    │  A: www → 52.x.x.x        │                            │ │
│  │                    │  MX: mail → mx.contoso... │                            │ │
│  │                    └───────────────────────────┘                            │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                         Azure Virtual Networks                               │ │
│  │                                                                              │ │
│  │  ┌────────────────────┐              ┌────────────────────┐                 │ │
│  │  │   VNet-Hub         │              │   VNet-Spoke       │                 │ │
│  │  │   10.0.0.0/16      │◄────Link────►│   10.1.0.0/16      │                 │ │
│  │  │                    │              │                    │                 │ │
│  │  │  ┌──────────────┐  │              │  ┌──────────────┐  │                 │ │
│  │  │  │ DNS Resolver │  │              │  │    VM        │  │                 │ │
│  │  │  │  Inbound EP  │  │              │  │  Queries:    │  │                 │ │
│  │  │  │  10.0.0.4    │  │              │  │ 168.63.129.16│  │                 │ │
│  │  │  │  Outbound EP │  │              │  └──────────────┘  │                 │ │
│  │  │  │  10.0.1.4    │  │              │                    │                 │ │
│  │  │  └──────────────┘  │              │                    │                 │ │
│  │  └────────────────────┘              └────────────────────┘                 │ │
│  │           │                                    │                            │ │
│  │           │                                    │                            │ │
│  │           ▼────────────────────────────────────▼                            │ │
│  │  ┌─────────────────────────────────────────────────┐                        │ │
│  │  │           Private DNS Zone                      │                        │ │
│  │  │           privatelink.blob.core.windows.net     │                        │ │
│  │  │                                                 │                        │ │
│  │  │   A: storageaccount → 10.0.2.5 (Private EP)     │                        │ │
│  │  └─────────────────────────────────────────────────┘                        │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                   │
│  ┌──────────────────────────────────────────────────────────────────────────┐    │
│  │                     ON-PREMISES NETWORK                                   │    │
│  │                                                                           │    │
│  │   ┌────────────┐        VPN/ExpressRoute        ┌────────────┐           │    │
│  │   │ On-prem    │◄──────────────────────────────►│ VPN        │           │    │
│  │   │ DNS Server │                                │ Gateway    │           │    │
│  │   │ 192.168.1.5│                                │            │           │    │
│  │   └────────────┘                                └────────────┘           │    │
│  │         │                                                                │    │
│  │         └─── Conditional Forwarder to Azure DNS Resolver Inbound EP      │    │
│  │              (10.0.0.4) for *.azure.local                                │    │
│  └──────────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Public DNS Zones

### Overview

Public DNS zones host DNS records for domains accessible from the internet. Azure DNS provides authoritative name servers.

### Supported Record Types

| Record | Purpose | Example |
|--------|---------|---------|
| **A** | IPv4 address | www → 203.0.113.10 |
| **AAAA** | IPv6 address | www → 2001:db8::1 |
| **CNAME** | Canonical name (alias) | blog → www.contoso.com |
| **MX** | Mail exchange | @ → mail.contoso.com |
| **TXT** | Text verification | SPF, DKIM, domain validation |
| **NS** | Name server | Delegated to Azure |
| **SOA** | Start of authority | Auto-created |
| **SRV** | Service location | _sip._tcp → sipserver |
| **CAA** | Certificate Authority Authorization | Restrict CA issuers |
| **PTR** | Reverse lookup | 10.113.0.203 → www.contoso.com |

### Alias Records (Azure-Specific)

> **⚡ EXAM TIP**: Alias records automatically update when target resource IP changes!

| Feature | Standard Record | Alias Record |
|---------|-----------------|--------------|
| Point to Azure resource | ❌ Manual IP | ✅ Resource reference |
| Traffic Manager integration | ❌ | ✅ Direct reference |
| Zone apex support | ❌ CNAME not allowed | ✅ A/AAAA alias works |
| Auto-update on IP change | ❌ | ✅ |

Supported targets for Alias Records:
- Public IP address
- Traffic Manager profile
- Azure CDN endpoint
- Another DNS record in same zone

---

## Private DNS Zones

### Overview

Private DNS zones provide name resolution for resources within Azure VNets without exposing records to the internet.

### Key Characteristics

```
┌────────────────────────────────────────────────────────────────┐
│                   Private DNS Zone Features                     │
├────────────────────────────────────────────────────────────────┤
│ ✓ Automatic VM registration (optional)                          │
│ ✓ Works across VNets (when linked)                             │
│ ✓ Supports split-horizon DNS                                    │
│ ✓ No custom DNS server required                                 │
│ ✓ Supports all record types except NS at zone apex              │
│ ✗ Cannot be queried from internet                               │
│ ✗ NS records not supported at zone apex                         │
└────────────────────────────────────────────────────────────────┘
```

### VNet Links

| Link Type | Auto-Registration | Use Case |
|-----------|-------------------|----------|
| **Registration VNet** | ✅ Enabled | Hub VNet where VMs auto-register |
| **Resolution VNet** | ❌ Disabled | Spoke VNets that can resolve records |

> **⚡ EXAM TIP**: A Private DNS zone can have only **ONE registration VNet** per zone, but **multiple resolution VNets**!

### Common Private DNS Zones for Azure Services

| Service | Private DNS Zone |
|---------|-----------------|
| **Storage Blob** | privatelink.blob.core.windows.net |
| **Storage File** | privatelink.file.core.windows.net |
| **Azure SQL** | privatelink.database.windows.net |
| **Cosmos DB** | privatelink.documents.azure.com |
| **Key Vault** | privatelink.vaultcore.azure.net |
| **Azure Web Apps** | privatelink.azurewebsites.net |
| **ACR** | privatelink.azurecr.io |
| **Event Hubs** | privatelink.servicebus.windows.net |

---

## DNS Resolution (168.63.129.16)

### Azure-Provided DNS

The IP **168.63.129.16** is Azure's virtual public IP for the recursive resolver.

```
┌─────────────────────────────────────────────────────────────┐
│                    DNS Resolution Flow                       │
│                                                              │
│   VM (10.0.1.4)                                             │
│       │                                                      │
│       │ Query: vm2.internal.contoso.com                     │
│       ▼                                                      │
│   168.63.129.16 (Azure DNS)                                 │
│       │                                                      │
│       ├──► Private DNS Zone linked?                         │
│       │         │                                            │
│       │         ├── YES → Return private zone record         │
│       │         │                                            │
│       │         └── NO → Forward to public DNS              │
│       │                                                      │
│       └──► Custom DNS configured?                           │
│                 │                                            │
│                 └── YES → Forward to custom DNS server       │
└─────────────────────────────────────────────────────────────┘
```

### 168.63.129.16 Functions

| Function | Description |
|----------|-------------|
| **DNS Resolution** | Recursive resolver for Azure resources |
| **Health Probes** | Load balancer health probes originate from this IP |
| **VM Extension Communication** | Agent communication with Azure fabric |
| **DHCP** | Dynamic IP assignment |

> ⚠️ **IMPORTANT**: Never block 168.63.129.16 in NSGs or firewalls - it breaks Azure functionality!

---

## Azure Private Resolver

### Overview

Azure DNS Private Resolver enables DNS resolution between Azure and on-premises, and between VNets using different DNS configurations.

### Components

```
┌─────────────────────────────────────────────────────────────────┐
│                  Azure DNS Private Resolver                      │
│                                                                  │
│  ┌──────────────────────┐      ┌──────────────────────┐         │
│  │   Inbound Endpoint   │      │   Outbound Endpoint  │         │
│  │                      │      │                      │         │
│  │   - Receives DNS     │      │   - Forwards DNS     │         │
│  │     queries from     │      │     queries to       │         │
│  │     on-premises      │      │     on-premises      │         │
│  │                      │      │     or other DNS     │         │
│  │   - Has private IP   │      │                      │         │
│  │     in VNet          │      │   - Uses forwarding  │         │
│  │                      │      │     rulesets         │         │
│  │   - /28 subnet min   │      │                      │         │
│  │                      │      │   - /28 subnet min   │         │
│  └──────────────────────┘      └──────────────────────┘         │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   Forwarding Ruleset                      │   │
│  │                                                           │   │
│  │   Rule 1: *.onprem.contoso.com → 192.168.1.5 (on-prem)   │   │
│  │   Rule 2: *.azure.local → 168.63.129.16 (Azure DNS)      │   │
│  │   Rule 3: *.partner.com → 10.10.10.5 (partner DNS)       │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Endpoint Requirements

| Endpoint | Subnet Size | Purpose |
|----------|-------------|---------|
| **Inbound** | /28 minimum (dedicated) | Receive queries from external sources |
| **Outbound** | /28 minimum (dedicated) | Forward queries to external DNS |

### Forwarding Rulesets

- Collection of DNS forwarding rules
- Can be linked to multiple VNets
- Each rule specifies domain and target DNS servers
- More specific rules take precedence

---

## Hybrid DNS Scenarios

### Scenario 1: Azure VMs Resolve On-Premises Names

```
┌─────────────────────────────────────────────────────────────────┐
│  Azure VM needs to resolve: server.onprem.contoso.com           │
│                                                                  │
│  Flow:                                                           │
│  1. VM queries 168.63.129.16                                    │
│  2. Azure DNS checks forwarding ruleset                          │
│  3. Rule matches *.onprem.contoso.com                           │
│  4. Query forwarded via Outbound Endpoint                        │
│  5. On-premises DNS responds                                     │
│  6. Response returned to VM                                      │
└─────────────────────────────────────────────────────────────────┘
```

### Scenario 2: On-Premises Resolves Azure Private Endpoints

```
┌─────────────────────────────────────────────────────────────────┐
│  On-prem client needs to resolve: storage.blob.core.windows.net │
│  (Should resolve to Private Endpoint IP, not public IP)         │
│                                                                  │
│  Flow:                                                           │
│  1. Client queries on-prem DNS (192.168.1.5)                    │
│  2. On-prem DNS has conditional forwarder for                    │
│     *.blob.core.windows.net → Azure DNS Resolver Inbound EP     │
│  3. Query sent to Inbound Endpoint (10.0.0.4)                   │
│  4. Azure DNS checks Private DNS Zone                            │
│  5. Returns Private Endpoint IP (10.0.2.5)                       │
│  6. Client connects to storage via private IP                    │
└─────────────────────────────────────────────────────────────────┘
```

### Scenario 3: Split-Horizon DNS

```
┌─────────────────────────────────────────────────────────────────┐
│           Split-Horizon DNS Configuration                        │
│                                                                  │
│   Query: app.contoso.com                                        │
│                                                                  │
│   ┌─────────────────┐    ┌─────────────────┐                    │
│   │ From Internet   │    │ From Azure VNet │                    │
│   │                 │    │                 │                    │
│   │ Resolves to:    │    │ Resolves to:    │                    │
│   │ 52.x.x.x        │    │ 10.0.1.5        │                    │
│   │ (Public IP)     │    │ (Private IP)    │                    │
│   │                 │    │                 │                    │
│   │ via Public      │    │ via Private     │                    │
│   │ DNS Zone        │    │ DNS Zone        │                    │
│   └─────────────────┘    └─────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## PowerShell Examples

### Create Public DNS Zone

```powershell
# Create public DNS zone
$zone = New-AzDnsZone `
    -Name "contoso.com" `
    -ResourceGroupName "rg-dns-prod" `
    -ZoneType Public

# Add A record
New-AzDnsRecordSet `
    -Name "www" `
    -RecordType A `
    -ZoneName "contoso.com" `
    -ResourceGroupName "rg-dns-prod" `
    -Ttl 3600 `
    -DnsRecords (New-AzDnsRecordConfig -IPv4Address "203.0.113.10")

# Add CNAME record
New-AzDnsRecordSet `
    -Name "blog" `
    -RecordType CNAME `
    -ZoneName "contoso.com" `
    -ResourceGroupName "rg-dns-prod" `
    -Ttl 3600 `
    -DnsRecords (New-AzDnsRecordConfig -Cname "www.contoso.com")

# Add Alias record pointing to Public IP
$pip = Get-AzPublicIpAddress -Name "pip-webapp-prod" -ResourceGroupName "rg-web-prod"

New-AzDnsRecordSet `
    -Name "@" `
    -RecordType A `
    -ZoneName "contoso.com" `
    -ResourceGroupName "rg-dns-prod" `
    -TargetResourceId $pip.Id

# Get name servers for domain registration
Get-AzDnsZone -Name "contoso.com" -ResourceGroupName "rg-dns-prod" | 
    Select-Object -ExpandProperty NameServers
```

### Create Private DNS Zone with VNet Link

```powershell
# Create private DNS zone
$privateZone = New-AzPrivateDnsZone `
    -Name "internal.contoso.com" `
    -ResourceGroupName "rg-dns-prod"

# Get VNet
$vnet = Get-AzVirtualNetwork -Name "vnet-hub-prod" -ResourceGroupName "rg-networking-prod"

# Create registration link (auto-registration enabled)
New-AzPrivateDnsVirtualNetworkLink `
    -Name "link-hub-registration" `
    -ResourceGroupName "rg-dns-prod" `
    -ZoneName "internal.contoso.com" `
    -VirtualNetworkId $vnet.Id `
    -EnableRegistration $true

# Create resolution-only link for spoke VNet
$spokeVnet = Get-AzVirtualNetwork -Name "vnet-spoke-prod" -ResourceGroupName "rg-networking-prod"

New-AzPrivateDnsVirtualNetworkLink `
    -Name "link-spoke-resolution" `
    -ResourceGroupName "rg-dns-prod" `
    -ZoneName "internal.contoso.com" `
    -VirtualNetworkId $spokeVnet.Id `
    -EnableRegistration $false

# Add A record to private zone
New-AzPrivateDnsRecordSet `
    -Name "sqlserver" `
    -RecordType A `
    -ZoneName "internal.contoso.com" `
    -ResourceGroupName "rg-dns-prod" `
    -Ttl 3600 `
    -PrivateDnsRecords (New-AzPrivateDnsRecordConfig -IPv4Address "10.0.2.10")
```

### Create Azure DNS Private Resolver

```powershell
# Create DNS Private Resolver
$resolver = New-AzDnsResolver `
    -Name "dnspr-hub-prod" `
    -ResourceGroupName "rg-dns-prod" `
    -Location "uksouth" `
    -VirtualNetworkId $vnet.Id

# Create Inbound Endpoint
$inboundSubnet = Get-AzVirtualNetworkSubnetConfig -Name "snet-dns-inbound" -VirtualNetwork $vnet

New-AzDnsResolverInboundEndpoint `
    -Name "inbound-endpoint" `
    -DnsResolverName "dnspr-hub-prod" `
    -ResourceGroupName "rg-dns-prod" `
    -Location "uksouth" `
    -IpConfiguration @{
        PrivateIpAllocationMethod = "Dynamic"
        SubnetId = $inboundSubnet.Id
    }

# Create Outbound Endpoint
$outboundSubnet = Get-AzVirtualNetworkSubnetConfig -Name "snet-dns-outbound" -VirtualNetwork $vnet

$outboundEp = New-AzDnsResolverOutboundEndpoint `
    -Name "outbound-endpoint" `
    -DnsResolverName "dnspr-hub-prod" `
    -ResourceGroupName "rg-dns-prod" `
    -Location "uksouth" `
    -SubnetId $outboundSubnet.Id

# Create Forwarding Ruleset
$ruleset = New-AzDnsForwardingRuleset `
    -Name "ruleset-hybrid" `
    -ResourceGroupName "rg-dns-prod" `
    -Location "uksouth" `
    -DnsResolverOutboundEndpointId $outboundEp.Id

# Add Forwarding Rule for on-premises domain
New-AzDnsForwardingRulesetForwardingRule `
    -Name "rule-onprem" `
    -DnsForwardingRulesetName "ruleset-hybrid" `
    -ResourceGroupName "rg-dns-prod" `
    -DomainName "onprem.contoso.com." `
    -TargetDnsServer @{
        IpAddress = "192.168.1.5"
        Port = 53
    }

# Link ruleset to VNet
New-AzDnsForwardingRulesetVirtualNetworkLink `
    -Name "link-spoke" `
    -DnsForwardingRulesetName "ruleset-hybrid" `
    -ResourceGroupName "rg-dns-prod" `
    -VirtualNetworkId $spokeVnet.Id
```

---

## Exam Tips & Gotchas

### 🎯 High-Priority Topics

1. **168.63.129.16**: Know this IP and its functions (DNS, health probes, DHCP)
2. **Private DNS Zone links**: Registration vs Resolution, limits on registration VNets
3. **Alias records**: When to use (zone apex, auto-update scenarios)
4. **DNS Private Resolver**: Inbound for on-prem → Azure, Outbound for Azure → on-prem

### ⚠️ Common Gotchas

| Scenario | Gotcha |
|----------|--------|
| Zone apex CNAME | Not allowed - use Alias record instead |
| Auto-registration | Only ONE VNet can have registration enabled per zone |
| Private Resolver subnets | Must be dedicated /28 subnets for each endpoint |
| Conditional forwarding | Trailing dot required in domain names (e.g., "contoso.com.") |
| Private endpoint DNS | Must create privatelink.* zones for proper resolution |
| On-prem resolution | On-prem DNS needs conditional forwarder to Inbound Endpoint |

### 📝 Exam Question Patterns

```
Q: "On-premises users can't resolve Azure Private Endpoint addresses. What's missing?"
A: 
   1. Azure DNS Private Resolver with Inbound Endpoint
   2. Conditional forwarder on on-prem DNS to Inbound Endpoint IP
   3. Private DNS zone linked to resolver VNet

Q: "You need to host contoso.com with zone apex pointing to a Public IP that may change. What record type?"
A: Alias record (A type) targeting the Public IP resource

Q: "VMs in spoke VNet can't resolve names from private DNS zone. Zone is linked to hub VNet with registration. What's the issue?"
A: Spoke VNet needs a resolution link (not registration) to the private DNS zone
```

---

## Quick Reference

### DNS Resolution Priority

```
1. Azure Private DNS Zone (if VNet linked)
       ↓
2. Custom DNS servers (if configured on VNet)
       ↓
3. Azure-provided DNS (168.63.129.16)
       ↓
4. Public DNS (if no private zone match)
```

### Private DNS Zone Naming for Private Endpoints

| Service | Zone Name |
|---------|-----------|
| Blob | privatelink.blob.core.windows.net |
| SQL | privatelink.database.windows.net |
| Key Vault | privatelink.vaultcore.azure.net |
| Cosmos DB | privatelink.documents.azure.com |
| ACR | privatelink.azurecr.io |

### Key Azure CLI Commands

```bash
# List DNS zones
az network dns zone list -o table
az network private-dns zone list -o table

# Query DNS zone records
az network dns record-set list -g <rg> -z <zone-name> -o table

# Create Private DNS zone link
az network private-dns link vnet create \
    -g <rg> \
    -z <zone-name> \
    -n <link-name> \
    -v <vnet-id> \
    -e true  # Enable registration
```

---

## Related Topics

- [VNet, Subnets & IP Addressing](VNet_Subnets_IP_Addressing.md)
- [VNet Peering & Routing](VNet_Peering_Routing.md)
- [Private Endpoints](../Design_Implement_Private_Access_to_Azure_Services/)
