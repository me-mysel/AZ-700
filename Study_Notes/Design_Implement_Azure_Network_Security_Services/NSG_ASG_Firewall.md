---
tags:
  - AZ-700
  - azure/networking
  - azure/security
  - domain/network-security
  - nsg
  - asg
  - network-security-group
  - application-security-group
  - flow-logs
  - ip-flow-verify
  - bastion
  - security-rules
aliases:
  - NSG
  - ASG
  - Network Security Group
  - Application Security Group
created: 2025-01-01
updated: 2026-02-07
---

# Azure Network Security Services - AZ-700 Study Notes

> [!info] Related Notes
> - [[Azure_Firewall_and_Firewall_Manager]] — Centralized L3-L7 firewall (vs NSG L3/L4)
> - [[WAF]] — Web Application Firewall for L7 protection
> - [[Azure_Virtual_Network_Manager]] — Security admin rules override NSGs
> - [[Network_Watcher]] — NSG diagnostics, flow logs, IP flow verify
> - [[Microsoft_Defender_for_Cloud_Networking]] — Adaptive Network Hardening for NSGs
> - [[Application_Gateway]] — NSG requirements on AppGW subnet
> - [[VNet_Subnets_IP_Addressing]] — NSG association at subnet/NIC level

## Overview

Azure network security is implemented through multiple services operating at different layers, each with distinct capabilities and limitations. The AZ-700 exam tests not just your knowledge of what each service does, but your ability to select the correct service for complex, multi-constraint scenarios and understand how they interact when deployed together.

### Security Services at a Glance

| Service | Layer | Scope | Statefulness | Use Case |
| --- | --- | --- | --- | --- |
| **NSG** | L3/L4 | Subnet/NIC | Stateful | Basic traffic filtering |
| **ASG** | L3/L4 | Application group | N/A (NSG helper) | Group VMs logically |
| **Azure Firewall** | L3-L7 | VNet/Subscription | Stateful | Centralized, advanced filtering |
| **DDoS Protection** | L3/L4 | VNet/Public IP | N/A | Volumetric attack protection |
| **WAF** | L7 | App Gateway/Front Door | N/A | Web application protection |

---

## Network Security Groups (NSG) - Deep Dive

NSGs are stateful packet filters that evaluate traffic based on the 5-tuple: source IP, source port, destination IP, destination port, and protocol. Understanding the nuances of how NSGs process traffic is critical because exam scenarios often involve subtle misconfigurations.

### Statefulness: What It Really Means

NSGs are **stateful**, which means when you allow inbound traffic on port 443, the return traffic is automatically allowed regardless of outbound rules. However, this statefulness has important implications that are frequently tested:

**Scenario 1: Asymmetric Routing Breaks Statefulness**
If traffic arrives through one path but returns through another (common in hub-spoke with multiple NVAs), the NSG on the return path sees the traffic as a *new* connection, not a response. This happens because each NSG instance maintains its own state table. In architectures with load-balanced NVAs, you must ensure symmetric routing or the return traffic will be blocked by the NSG expecting a SYN packet but receiving an ACK.

**Scenario 2: Timeout Considerations**
NSG stateful connections have timeouts. TCP idle timeout is 4 minutes by default. If your application holds connections open longer without traffic (common with database connection pools), the NSG will drop the connection silently. The VM will think the connection is alive while the NSG has already removed it from the state table. Solutions include TCP keepalives or adjusting application timeout behaviors.

### NSG Association: Subnet vs NIC - The Compounding Effect

This is one of the most misunderstood concepts. When NSGs are attached to **both** a subnet and a NIC:

**Inbound Traffic Flow:**
1. Traffic arrives at the subnet
2. Subnet NSG evaluates → must ALLOW
3. Traffic reaches the NIC
4. NIC NSG evaluates → must ALSO ALLOW
5. Traffic reaches the VM

**The critical insight:** Both NSGs operate independently. If subnet NSG allows ports 80,443 and NIC NSG only allows port 22, the effective allowed inbound ports are **NONE** for web traffic and **port 22** only (if subnet also allows 22).

**Outbound Traffic Flow (reversed order):**
1. Traffic leaves the VM
2. NIC NSG evaluates → must ALLOW
3. Traffic reaches the subnet
4. Subnet NSG evaluates → must ALSO ALLOW
5. Traffic exits the subnet

**Exam Trap:** A question might describe a scenario where a VM cannot reach the internet despite the subnet NSG allowing outbound internet traffic. The answer is often that the NIC-level NSG is blocking it, or vice versa.

### The "VirtualNetwork" Service Tag - Deeper Than You Think

The `VirtualNetwork` service tag doesn't just mean "this VNet's address space." It includes:

1. **The VNet's address space** - All defined address prefixes
2. **Peered VNet address spaces** - Even if peering is one-way, the addresses are included
3. **On-premises address spaces** - Connected via VPN Gateway or ExpressRoute
4. **Azure-defined addresses** - Including 168.63.129.16 (Azure platform) and 169.254.169.254 (metadata service)

**Complex Scenario:** Company has VNet-A (10.0.0.0/16) peered with VNet-B (10.1.0.0/16), and VPN to on-premises (192.168.0.0/16). A VM in VNet-A has an NSG rule "Deny VirtualNetwork Inbound" at priority 100, and "Allow 10.0.0.0/16 Inbound" at priority 200. Can VMs within VNet-A communicate?

**Answer:** NO. Even though 10.0.0.0/16 is explicitly allowed at priority 200, the "Deny VirtualNetwork" at priority 100 matches first (lower priority number = higher precedence). Since 10.0.0.0/16 is part of VirtualNetwork, the deny rule matches first.

### Effective Security Rules - How Azure Actually Evaluates

When troubleshooting, understanding the effective security rules is essential. Azure computes effective rules by:

1. Starting with default rules (priority 65000-65500)
2. Adding custom rules
3. Processing in priority order (100-4096 for custom rules)
4. First match wins (no further evaluation)

**Exam Scenario:** You have these rules:
- Priority 100: Allow TCP 80 from Internet
- Priority 200: Deny TCP 80 from 203.0.113.50
- Priority 300: Allow TCP 80 from 203.0.113.0/24

Traffic from 203.0.113.50 to port 80 is... **ALLOWED**. Why? Priority 100 matches first (Internet includes 203.0.113.50). The deny rule at 200 is never evaluated.

**Fix:** To deny specific IPs while allowing others, the deny rule must have a LOWER priority number (higher precedence) than the allow rule.

### NSG Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      NSG FLOW AND PROCESSING                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│                           INBOUND TRAFFIC                                        │
│                               │                                                  │
│                               ▼                                                  │
│   ┌───────────────────────────────────────────────────────────────────────────┐ │
│   │                    SUBNET NSG (if attached)                                │ │
│   │                                                                            │ │
│   │   Rules evaluated by priority (lowest number = highest priority)          │ │
│   │   First match wins → Allow or Deny                                        │ │
│   │                                                                            │ │
│   │   Priority 100: Allow HTTP from Internet                                  │ │
│   │   Priority 200: Allow HTTPS from 10.0.0.0/8                               │ │
│   │   Priority 300: Deny all from 192.168.1.0/24                              │ │
│   │   ...                                                                      │ │
│   │   Priority 65000: Allow VNet inbound (default)                            │ │
│   │   Priority 65001: Allow LB inbound (default)                              │ │
│   │   Priority 65500: Deny all inbound (default)                              │ │
│   └───────────────────────────────────────────────────────────────────────────┘ │
│                               │                                                  │
│                               ▼                                                  │
│   ┌───────────────────────────────────────────────────────────────────────────┐ │
│   │                      NIC NSG (if attached)                                 │ │
│   │                                                                            │ │
│   │   Same rule processing as subnet NSG                                      │ │
│   │   BOTH subnet and NIC NSGs must allow for traffic to reach VM            │ │
│   └───────────────────────────────────────────────────────────────────────────┘ │
│                               │                                                  │
│                               ▼                                                  │
│                            VM/Resource                                           │
│                                                                                  │
│   ⚠️ IMPORTANT: Traffic must be allowed by BOTH NSGs (if both exist)           │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Default NSG Rules

| Priority | Name | Source | Destination | Action |
| --- | --- | --- | --- | --- |
| **Inbound** |  |  |  |  |
| 65000 | AllowVNetInBound | VirtualNetwork | VirtualNetwork | Allow |
| 65001 | AllowAzureLoadBalancerInBound | AzureLoadBalancer | Any | Allow |
| 65500 | DenyAllInBound | Any | Any | Deny |
| **Outbound** |  |  |  |  |
| 65000 | AllowVNetOutBound | VirtualNetwork | VirtualNetwork | Allow |
| 65001 | AllowInternetOutBound | Any | Internet | Allow |
| 65500 | DenyAllOutBound | Any | Any | Deny |

### Service Tags (Must Know!)

| Tag | Description |
| --- | --- |
| **VirtualNetwork** | VNet address space + peered VNets + on-prem (VPN/ER) |
| **AzureLoadBalancer** | Azure infrastructure LB |
| **Internet** | Anything outside VNet address space |
| **AzureCloud** | All Azure datacenter IPs |
| **AzureCloud.RegionName** | Azure IPs in specific region |
| **Storage** | Azure Storage IPs |
| **Sql** | Azure SQL IPs |
| **AzureTrafficManager** | Traffic Manager probe IPs |
| **GatewayManager** | VPN/ExpressRoute Gateway management |

---

## Application Security Groups (ASG) - Deep Dive

ASGs are often dismissed as "just a way to group VMs," but their behavior in complex scenarios requires deeper understanding.

### ASG Constraints and Limitations You Must Know

**Regional Constraint:** ASGs must be in the same region as the NICs they're associated with. In a multi-region deployment, you need separate ASGs per region, which means your NSG rules cannot use a single "WebServers" ASG to reference VMs across regions.

**Cross-VNet Constraint:** This is critical - you CANNOT use ASGs in NSG rules where the source and destination ASGs are in different VNets. The ASG must be in the same VNet as the NSG. 

**Exam Scenario:** You have NSG attached to a subnet in VNet-Hub. You want to create a rule allowing traffic from ASG-WebServers (in VNet-Spoke1) to ASG-AppServers (in VNet-Spoke2). **This is NOT possible with ASGs.** You must use IP addresses or CIDR ranges instead.

**Multiple ASG Membership:** A NIC can belong to multiple ASGs, but ALL ASGs must be in the same VNet. This is useful for VMs that serve multiple roles (e.g., a VM that's both a web server and an API server).

### ASG Rule Evaluation Mechanics

When a packet matches multiple ASG-based rules, Azure evaluates based on:

1. **Priority** - Lower number wins, as always
2. **If same priority** - Deny takes precedence over Allow (this is rarely documented but important!)
3. **Specificity doesn't matter** - Unlike traditional firewalls, Azure doesn't consider rule specificity

**Complex Scenario:**
```text
Priority 100: Allow ASG-Web → ASG-Database on 1433
Priority 100: Deny 10.0.1.0/24 → Any on 1433
```

A VM in ASG-Web with IP 10.0.1.5 tries to connect to the database on 1433. What happens? 

**Answer:** Traffic is DENIED. When rules have the same priority, Deny takes precedence. This catches many exam takers who assume the ASG rule would apply.

### When ASGs Don't Work - Common Gotchas

1. **Peered VNet Traffic:** If VM-A in VNet-1 needs to reach VM-B in VNet-2 (peered), and you have an NSG rule using ASGs, the rule won't work because ASGs are VNet-scoped.

2. **On-Premises Traffic:** Traffic from on-premises cannot be filtered using ASGs because on-premises devices can't be ASG members. Use IP-based rules or service tags.

3. **Azure PaaS Services:** You cannot add Azure PaaS services (like App Services or Azure SQL) to ASGs. Use Service Tags for PaaS services.

4. **Load Balancer Backend VMs:** This works, but the ASG rule evaluates based on the VM's IP, not the Load Balancer's frontend IP. A common mistake is creating rules based on the LB IP.

---

## Azure Firewall - Deep Dive

Azure Firewall is far more complex than NSGs, with multiple rule types, processing orders, and deployment considerations that exam scenarios love to test.

### Rule Collection Groups, Collections, and Rules - The Hierarchy

Understanding this hierarchy is essential:

```text
Firewall Policy
└── Rule Collection Group (has priority: 100-65000)
    └── Rule Collection (has priority within group: 100-65000)
        └── Individual Rules (processed in order within collection)
```

**Processing Order:**
1. Rule Collection Groups are processed by priority (lower = first)
2. Within a group, Rule Collections are processed by priority
3. Within a collection, rules are processed in order

**DNAT, Network, and Application Collections are processed differently:**
- DNAT Rule Collections: Processed FIRST (inbound NAT)
- Network Rule Collections: Processed SECOND
- Application Rule Collections: Processed THIRD

**Critical Behavior:** If a Network Rule matches with ALLOW, Application Rules are **NEVER** evaluated for that traffic. This catches many people who expect Application Rules to add additional filtering.

### SNAT Behavior - The Hidden Complexity

Azure Firewall performs SNAT on all outbound traffic by default, replacing the source IP with the firewall's public IP. However:

**Private IP Range SNAT Exception:**
Traffic to RFC 1918 ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16) and RFC 6598 (100.64.0.0/10) is NOT SNATed by default. The original source IP is preserved.

**Exam Scenario:** Spoke VNet (10.1.0.0/16) routes traffic through Azure Firewall to reach Hub VNet (10.0.0.0/16). The destination VM's NSG has a rule "Allow 10.1.0.0/16". Does the traffic work?

**Answer:** YES, because Firewall doesn't SNAT private-to-private traffic. If it did SNAT, the source would appear as the firewall's private IP (10.0.x.x), not 10.1.x.x, and the NSG rule would fail.

**You can change this behavior** by adding custom private ranges in the Firewall settings, forcing SNAT for specific private ranges.

### Forced Tunneling Mode - When and Why

Standard Azure Firewall requires a public IP for management. But what if your security policy prohibits any public IP on the firewall?

**Forced Tunneling Mode:**
- Firewall gets NO public IP on the primary interface
- Requires `AzureFirewallManagementSubnet` (separate from `AzureFirewallSubnet`)
- Management traffic routes through a separate public IP on the management subnet
- All USER traffic can be routed through an NVA/VPN (forced tunneling)

**Use Case:** Regulatory requirement that all internet-bound traffic must pass through on-premises security stack. Firewall still needs management connectivity, but user traffic goes on-premises.

**Exam Trap:** Questions might describe forced tunneling requirements without explicitly mentioning the management subnet. Remember: forced tunneling = two subnets (AzureFirewallSubnet + AzureFirewallManagementSubnet).

### Threat Intelligence Modes - The Subtle Differences

Threat Intelligence has three modes:

1. **Off:** No threat intelligence checking
2. **Alert only:** Logs connections to known malicious IPs/domains but allows them
3. **Alert and deny:** Blocks connections to known malicious IPs/domains

**Critical Nuance:** Threat Intelligence operates BEFORE your rules are evaluated. If a packet matches a malicious indicator in "Alert and deny" mode, it's blocked even if you have an explicit Allow rule for that destination.

**Exam Scenario:** Your firewall has "Alert and deny" enabled. You have an explicit Network Rule allowing traffic to 203.0.113.50 (a partner's IP that happens to be on a threat feed due to false positive). Traffic is still blocked.

**Solution:** You must add the IP to the Threat Intelligence allowlist, not just create a firewall rule.

### DNS Configuration - More Complex Than It Appears

Azure Firewall can act as a DNS proxy, which is often required but frequently misconfigured:

**Why DNS Proxy Matters:**
1. Application Rules with FQDNs require the firewall to resolve those FQDNs
2. If clients use their own DNS servers that resolve to different IPs than the firewall sees, rules may not match

**DNS Proxy Behavior:**
- When enabled, firewall listens on port 53
- Clients should use the firewall's private IP as their DNS server
- Firewall resolves using configured DNS servers (Azure DNS or custom)

**Complex Scenario:** VMs use custom DNS server 10.0.5.10. Firewall uses Azure DNS. Application rule allows `*.windows.net`. VM resolves `storage.windows.net` to a Private Endpoint IP (10.0.6.100) via custom DNS. Firewall resolves it to public IP (20.x.x.x). Rule doesn't match because firewall sees different destination.

**Solution:** Either enable DNS proxy and point VMs to firewall, OR use Network Rules with IP addresses instead of Application Rules with FQDNs for Private Endpoint scenarios.

### Azure Firewall Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      HUB-SPOKE WITH AZURE FIREWALL                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│                              INTERNET                                            │
│                                  │                                               │
│                                  ▼                                               │
│   ┌───────────────────────────────────────────────────────────────────────────┐ │
│   │                            HUB VNET                                        │ │
│   │                                                                            │ │
│   │   ┌──────────────────────────────────────────────────────────────────┐   │ │
│   │   │              AzureFirewallSubnet (min /26)                        │   │ │
│   │   │                                                                   │   │ │
│   │   │   ┌─────────────────────────────────────────────────────────┐    │   │ │
│   │   │   │                  AZURE FIREWALL                          │    │   │ │
│   │   │   │                                                          │    │   │ │
│   │   │   │   Public IP: 52.x.x.x                                   │    │   │ │
│   │   │   │   Private IP: 10.0.1.4                                  │    │   │ │
│   │   │   │                                                          │    │   │ │
│   │   │   │   Rules:                                                 │    │   │ │
│   │   │   │   ├── NAT Rules (DNAT for inbound)                      │    │   │ │
│   │   │   │   ├── Network Rules (L3/L4)                             │    │   │ │
│   │   │   │   └── Application Rules (L7 FQDN)                       │    │   │ │
│   │   │   │                                                          │    │   │ │
│   │   │   └─────────────────────────────────────────────────────────┘    │   │ │
│   │   │                                                                   │   │ │
│   │   └──────────────────────────────────────────────────────────────────┘   │ │
│   │                                    │                                      │ │
│   │   ┌──────────────────────────────────────────────────────────────────┐   │ │
│   │   │              GatewaySubnet                                        │   │ │
│   │   │              VPN/ER Gateway                                       │   │ │
│   │   └──────────────────────────────────────────────────────────────────┘   │ │
│   │                                                                            │ │
│   └────────────────────────────────────┬───────────────────────────────────────┘ │
│                                        │                                          │
│              ┌─────────────────────────┼─────────────────────────┐               │
│              │                         │                         │               │
│              ▼                         ▼                         ▼               │
│   ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐          │
│   │   SPOKE 1 VNET   │    │   SPOKE 2 VNET   │    │   SPOKE 3 VNET   │          │
│   │   (Production)   │    │   (Development)  │    │   (DMZ)          │          │
│   │                  │    │                  │    │                  │          │
│   │   UDR: 0.0.0.0/0 │    │   UDR: 0.0.0.0/0 │    │   UDR: 0.0.0.0/0 │          │
│   │   → 10.0.1.4     │    │   → 10.0.1.4     │    │   → 10.0.1.4     │          │
│   │   (via Firewall) │    │   (via Firewall) │    │   (via Firewall) │          │
│   │                  │    │                  │    │                  │          │
│   └──────────────────┘    └──────────────────┘    └──────────────────┘          │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Firewall Rule Processing Order

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      RULE PROCESSING ORDER                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   1. NAT RULES (DNAT - Inbound)                                                 │
│      │                                                                           │
│      │  Translate public IP:port to private IP:port                             │
│      │  Example: 52.x.x.x:443 → 10.0.2.4:443                                   │
│      │                                                                           │
│      ▼                                                                           │
│   2. NETWORK RULES (L3/L4)                                                      │
│      │                                                                           │
│      │  Allow/Deny based on: Source, Dest, Port, Protocol                       │
│      │  Uses IP addresses, IP groups, Service Tags, FQDNs                       │
│      │                                                                           │
│      │  ⚠️ If ALLOW match here, application rules NOT evaluated                │
│      │                                                                           │
│      ▼                                                                           │
│   3. APPLICATION RULES (L7)                                                     │
│      │                                                                           │
│      │  Allow/Deny based on: FQDN, URL (Premium), Web categories (Premium)      │
│      │  Supports wildcards: *.microsoft.com                                     │
│      │                                                                           │
│      │  Only evaluated if no network rule match                                 │
│      │                                                                           │
│      ▼                                                                           │
│   4. DEFAULT: DENY (if no rules match)                                          │
│                                                                                  │
│   ⚠️ EXAM TIP: Network rules evaluated BEFORE application rules                │
│   ⚠️ EXAM TIP: If network rule allows, application rules are SKIPPED          │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### Key Azure Firewall Requirements

| Requirement | Details |
| --- | --- |
| **Subnet Name** | Must be `AzureFirewallSubnet` (exactly!) |
| **Subnet Size** | Minimum `/26` (64 addresses), recommend `/26` |
| **Public IP** | Standard SKU, Static allocation |
| **Deployment** | One firewall per VNet (use Firewall Manager for multiple) |

---

## AZ-700 Exam Scenarios - Complex Problem Solving

The exam tests your ability to solve multi-layered problems. Here are realistic scenarios that combine multiple concepts:

### Scenario 1: Hub-Spoke with Centralized Firewall and Asymmetric Routing

**Setup:** 
- Hub VNet with Azure Firewall (10.0.0.0/16)
- Spoke1 VNet (10.1.0.0/16) peered to Hub
- Spoke2 VNet (10.2.0.0/16) peered to Hub
- UDRs on spoke subnets route 0.0.0.0/0 to Firewall
- VM in Spoke1 needs to reach VM in Spoke2

**Problem:** Spoke-to-spoke traffic works for new connections, but established connections randomly drop.

**Root Cause Analysis:** 
The UDRs only have 0.0.0.0/0 route. When Spoke1-VM (10.1.0.5) initiates connection to Spoke2-VM (10.2.0.5):
1. Outbound: 10.1.0.5 → Firewall → 10.2.0.5 ✓
2. Return: 10.2.0.5 → ??? 

The return traffic to 10.1.0.0/16 matches the VNet peering route (more specific than 0.0.0.0/0), so it goes directly via peering, bypassing the firewall. This is **asymmetric routing** - the firewall sees the SYN but not the SYN-ACK, eventually timing out the connection.

**Solution:** Add UDRs for spoke-to-spoke traffic:
- On Spoke1 subnet: 10.2.0.0/16 → Firewall
- On Spoke2 subnet: 10.1.0.0/16 → Firewall

This ensures symmetric routing through the firewall for both directions.

### Scenario 2: NSG Flow Logs Show Allowed Traffic But Application Fails

**Setup:**
- VM with web application on port 443
- NSG allows TCP 443 from Internet
- Application Gateway in front of VM
- Users report intermittent "connection reset" errors

**Troubleshooting Path:**
1. NSG flow logs show traffic allowed - rules are correct
2. VM-level firewall (Windows/Linux) allows 443 - not the issue
3. Application is running and listening - verified

**Root Cause:** Application Gateway health probes use a different port (or path) than the application. NSG allows 443, but health probes on port 80 or custom path are blocked. App Gateway marks backend as unhealthy, returns 502.

**Solution:** Check Application Gateway health probe configuration. Add NSG rule allowing the probe port/protocol from the Application Gateway subnet.

**Deeper Issue:** The probe source IP is the Application Gateway's private IP, not "Internet." An NSG rule allowing "Internet" won't match internal probes.

### Scenario 3: Azure Firewall Blocking Traffic Despite Allow Rule

**Setup:**
- Azure Firewall Standard with Application Rule: Allow `*.blob.core.windows.net`
- VMs configured to use Azure DNS (168.63.129.16)
- Storage account has Private Endpoint in the VNet
- VMs cannot reach storage

**Analysis:**
1. VM resolves `storageacct.blob.core.windows.net` → Private DNS Zone returns 10.0.5.100 (Private Endpoint IP)
2. Traffic to 10.0.5.100:443 goes to firewall (via UDR)
3. Firewall Application Rule checks FQDN - but this is a Network layer packet (IP address)
4. No Network Rule exists for 10.0.5.100
5. Traffic DENIED

**Why Application Rules Don't Work:**
Application Rules work by intercepting the TLS handshake and extracting the SNI (Server Name Indication). But when the destination is a Private Endpoint, the traffic characteristics differ. Additionally, Application Rules expect the destination to match their FQDN resolution, but Private Endpoints resolve differently.

**Solution Options:**
1. Create Network Rule allowing the spoke subnets to Private Endpoint subnet on 443
2. Bypass firewall for Private Endpoint traffic using UDR with Private Endpoint subnet → VNet Gateway/None
3. Use Firewall DNS proxy and ensure consistent DNS resolution

### Scenario 4: The "Deny All" That Didn't

**Setup:**
- NSG with explicit "DenyAllInbound" rule at priority 4096
- VM still receiving traffic on port 22

**Investigation:**
Priority 4096 is a custom rule. Default rules exist at 65000-65500. What could be allowing traffic at a priority between 4096 and 65000?

**Root Cause:** Another administrator added an allow rule at priority 4090 that the original engineer missed. Azure doesn't prevent overlapping rules.

**Lessons:**
1. Always review ALL rules including those added by others
2. Use Azure Policy to enforce naming conventions and priority ranges
3. Document rule purposes in the description field
4. Use "Effective security rules" in portal to see the combined view

### Scenario 5: Azure Firewall Premium TLS Inspection Breaking Applications

**Setup:**
- Azure Firewall Premium with TLS Inspection enabled
- Internal CA certificate deployed to firewall
- Most HTTPS traffic works fine
- Specific application fails with "certificate error"

**Root Cause:** The application performs certificate pinning - it expects a specific certificate or CA chain. When Azure Firewall intercepts and re-signs the traffic, the certificate chain changes.

**Applications Commonly Affected:**
- Mobile apps with embedded certificates
- Financial applications
- Some Microsoft services (Azure DevOps agents, some Azure SDK calls)
- Applications calling external APIs with certificate pinning

**Solutions:**
1. Add application FQDNs to TLS Inspection bypass list
2. Use Network Rules instead of Application Rules for pinned destinations (no TLS inspection)
3. Contact application vendor to understand certificate requirements

---

## NSG Flow Logs - Deep Dive on Format and Fields

NSG Flow Logs capture metadata about IP traffic flowing through an NSG. Understanding the log format is critical for troubleshooting and appears frequently on AZ-700.

### Flow Log Storage Structure

Flow logs are stored in a storage account with this hierarchy:

```text
insights-logs-networksecuritygroupflowevent/
└── resourceId=/SUBSCRIPTIONS/{subscriptionId}/RESOURCEGROUPS/{resourceGroup}/PROVIDERS/MICROSOFT.NETWORK/NETWORKSECURITYGROUPS/{nsgName}/
    └── y={year}/m={month}/d={day}/h={hour}/m=00/macAddress={macAddress}/
        └── PT1H.json
```

Each file contains 1 hour of flow data, partitioned by the MAC address of the NIC.

### Version 1 vs Version 2 Flow Logs

| Feature | Version 1 | Version 2 |
| --- | --- | --- |
| Flow state tracking | ❌ | ✅ |
| Bytes transferred | ❌ | ✅ |
| Packets transferred | ❌ | ✅ |
| Aggregation intervals | Per-flow event | 1-minute aggregates |
| Cost efficiency | Higher (more records) | Lower (aggregated) |

**Always use Version 2** - it provides flow state and throughput data essential for troubleshooting.

### Flow Tuple Format (Version 2)

Each flow is represented as a comma-separated tuple:

```text
{Unix Timestamp},{Source IP},{Destination IP},{Source Port},{Destination Port},{Protocol},{Traffic Flow},{Traffic Decision},{Flow State},{Packets Sent},{Bytes Sent},{Packets Received},{Bytes Received}
```

### Field-by-Field Breakdown

| Field | Position | Values | Description |
| --- | --- | --- | --- |
| **Unix Timestamp** | 1 | Epoch seconds | When the flow was recorded (UTC) |
| **Source IP** | 2 | IP address | Originating IP of the packet |
| **Destination IP** | 3 | IP address | Target IP of the packet |
| **Source Port** | 4 | 0-65535 | Ephemeral port (usually high number for clients) |
| **Destination Port** | 5 | 0-65535 | Service port (80, 443, 22, 3389, etc.) |
| **Protocol** | 6 | `T` or `U` | **T** = TCP, **U** = UDP |
| **Traffic Flow** | 7 | `I` or `O` | **I** = Inbound, **O** = Outbound |
| **Traffic Decision** | 8 | `A` or `D` | **A** = Allowed, **D** = Denied |
| **Flow State** | 9 | `B`, `C`, `E` | **B** = Begin, **C** = Continuing, **E** = End |
| **Packets Sent** | 10 | Integer | Source → Destination packet count |
| **Bytes Sent** | 11 | Integer | Source → Destination byte count |
| **Packets Received** | 12 | Integer | Destination → Source packet count |
| **Bytes Received** | 13 | Integer | Destination → Source byte count |

### Flow State Deep Dive

The **Flow State** field (Version 2 only) is crucial for understanding connection lifecycle:

| State | Meaning | When Logged |
| --- | --- | --- |
| **B (Begin)** | New flow started | First packet of a new connection |
| **C (Continuing)** | Flow still active | Aggregated every 1 minute for ongoing flows |
| **E (End)** | Flow terminated | Connection closed (FIN/RST) or timed out |

**Exam Insight:** If you see many `B` states without corresponding `E` states, connections might be:
- Still active (long-running)
- Timing out without proper closure
- Being reset by network devices

### Example Flow Log Entry (Decoded)

**Raw tuple:**
```text
1706198400,10.0.1.5,10.0.2.10,49832,443,T,O,A,B,15,1240,12,8520
```

**Decoded:**
| Field | Value | Meaning |
| --- | --- | --- |
| Timestamp | 1706198400 | Jan 25, 2024 12:00:00 UTC |
| Source IP | 10.0.1.5 | VM initiating connection |
| Dest IP | 10.0.2.10 | Target server |
| Source Port | 49832 | Ephemeral client port |
| Dest Port | 443 | HTTPS |
| Protocol | T | TCP |
| Direction | O | Outbound from this NSG's perspective |
| Decision | A | Allowed by NSG |
| State | B | New connection starting |
| Packets Out | 15 | 15 packets sent to destination |
| Bytes Out | 1240 | 1,240 bytes sent |
| Packets In | 12 | 12 packets received back |
| Bytes In | 8520 | 8,520 bytes received |

### JSON Structure in PT1H.json

```json
{
  "records": [
    {
      "time": "2024-01-25T12:00:00.0000000Z",
      "systemId": "guid",
      "macAddress": "00224DABCDEF",
      "category": "NetworkSecurityGroupFlowEvent",
      "resourceId": "/SUBSCRIPTIONS/.../NETWORKSECURITYGROUPS/nsg-web",
      "operationName": "NetworkSecurityGroupFlowEvents",
      "properties": {
        "Version": 2,
        "flows": [
          {
            "rule": "UserRule_Allow-HTTPS",
            "flows": [
              {
                "mac": "00224DABCDEF",
                "flowTuples": [
                  "1706198400,10.0.1.5,10.0.2.10,49832,443,T,O,A,B,15,1240,12,8520",
                  "1706198460,10.0.1.5,10.0.2.10,49832,443,T,O,A,C,45,3720,38,25560"
                ]
              }
            ]
          }
        ]
      }
    }
  ]
}
```

**Key structural elements:**
- **rule**: Which NSG rule matched this flow (critical for troubleshooting)
- **mac**: NIC MAC address (identifies which NIC in multi-NIC VMs)
- **flowTuples**: Array of flow records (multiple tuples per rule match)

### Interpreting Flow Logs for Troubleshooting

**Scenario: Connection attempts failing**

Look for tuples with `D` (Denied) in position 8:
```text
1706198400,203.0.113.50,10.0.1.5,54321,22,T,I,D,B,0,0,0,0
```
This shows: External IP trying SSH (port 22), inbound, **DENIED**, no packets transferred.

**Scenario: Connections timing out**

Look for `B` states with low packet counts and no corresponding `E`:
```text
1706198400,10.0.1.5,10.0.2.10,49832,1433,T,O,A,B,3,180,0,0
```
TCP connection to SQL (1433) started, only SYN packets sent (3), **zero bytes received** - backend not responding.

**Scenario: Asymmetric routing evidence**

Outbound shows traffic leaving:
```text
1706198400,10.0.1.5,10.0.2.10,49832,443,T,O,A,B,15,1240,0,0
```
Packets sent but **zero received** - response is taking a different path back (not through this NSG).

### Traffic Analytics Integration

When Traffic Analytics is enabled on flow logs, Microsoft processes the raw logs and provides:

- **Flow patterns**: Top talkers, denied flows, geographic distribution
- **Security insights**: Malicious IPs, open ports, threat indicators  
- **Bandwidth utilization**: Throughput trends, peak usage times
- **Application categorization**: What applications generate traffic

**Exam Note:** Traffic Analytics requires:
1. NSG Flow Logs enabled (Version 2 recommended)
2. Log Analytics workspace in the same region
3. Network Watcher enabled in the region
4. Processing interval: 10 minutes or 60 minutes (affects cost)

### Common Exam Questions on Flow Logs

| Question Pattern | Answer |
| --- | --- |
| "How to see which rule blocked traffic?" | Check the `rule` field in flow log JSON |
| "Connection works one way but not return" | Look for `A` outbound but `D` inbound (or missing return flows) |
| "How to measure bandwidth usage?" | Enable Version 2 flow logs, check Bytes Sent/Received fields |
| "Flow logs show allowed but app fails" | Traffic passed NSG but blocked elsewhere (host firewall, app not listening) |
| "Reduce flow log storage costs" | Use Version 2 (aggregated), increase retention, use Traffic Analytics for queries |

---

## Advanced Troubleshooting Framework

When exam questions present complex troubleshooting scenarios, use this systematic approach:

### Layer-by-Layer Analysis

```text
Layer 1 (Physical/Platform): Is the VM running? Is the NIC attached?
                ↓
Layer 2 (Data Link): Is the NIC in a connected subnet? 
                ↓
Layer 3 (Network): 
  - NSG at subnet level: Check effective rules
  - NSG at NIC level: Check effective rules  
  - UDR: Does custom route exist that might redirect?
  - Peering: If cross-VNet, is peering established and connected?
                ↓
Layer 4 (Transport):
  - Is the port correct?
  - Is the protocol (TCP/UDP) correct?
  - For UDP: remember it's connectionless, NSG behaves differently
                ↓
Layer 7 (Application):
  - Azure Firewall Application Rules (if traffic passes through)
  - WAF rules (if applicable)
  - Application Gateway path/host routing
```

### Common "It Works From Here But Not There" Scenarios

| Source | Destination | Works? | Common Cause |
| --- | --- | --- | --- |
| Same subnet VM | Target VM | No | NIC NSG blocking, or host firewall |
| Different subnet VM | Target VM | No | Subnet NSG not allowing cross-subnet |
| Peered VNet VM | Target VM | No | Peering allows forwarded traffic disabled, or NSG doesn't include peered range |
| On-premises | Target VM | No | VirtualNetwork tag doesn't resolve on-prem ranges if BGP not propagating |
| Internet | Target VM (via LB) | No | NSG missing AzureLoadBalancer allow for probes |
| Internet | Target VM (via AppGW) | No | AppGW subnet NSG blocking, or backend health probe failing |

---

## Integration with Other Azure Services - Edge Cases

### Private Endpoints and NSG Network Policies

By default, NSG rules don't apply to Private Endpoints. Traffic to Private Endpoints bypasses NSGs. This changed with **Network Policies for Private Endpoints**:

**When Enabled:**
- NSGs can filter traffic TO Private Endpoints
- UDRs can route traffic TO Private Endpoints
- Must be enabled at the subnet level

**Exam Scenario:** Security team requires all traffic to Private Endpoints to be logged. How?

**Answer:** Enable Network Policies on the PE subnet, attach NSG, enable NSG Flow Logs. Without Network Policies enabled, the NSG won't see PE traffic.

### Service Endpoints and NSG Interaction

Service Endpoints add optimal routing to PaaS services but don't change NSG behavior:

**Subtle Point:** When you enable a Service Endpoint for Azure Storage on a subnet, traffic destined for Storage follows the service endpoint route. However, NSG still evaluates the traffic using the **original destination IP** (the Storage public IP), not some special "service endpoint" designation.

**Exam Scenario:** NSG rule denies all outbound to Internet. Service Endpoint for Storage enabled. Can VMs reach Storage?

**Answer:** NO. Even though Service Endpoints use Microsoft backbone (not public internet path), the NSG evaluates against the "Internet" service tag, which includes Azure public IPs. You need an explicit allow rule for the Storage service tag.

---

## Related Resources

- [NSG Documentation](https://docs.microsoft.com/azure/virtual-network/network-security-groups-overview)
- [ASG Documentation](https://docs.microsoft.com/azure/virtual-network/application-security-groups)
- [Azure Firewall Documentation](https://docs.microsoft.com/azure/firewall/overview)
- [NSG Flow Logs](https://docs.microsoft.com/azure/network-watcher/network-watcher-nsg-flow-logging-overview)

---

*Last Updated: January 2026*
*AZ-700: Designing and Implementing Microsoft Azure Networking Solutions*
