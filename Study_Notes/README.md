---
tags:
  - AZ-700
  - azure/networking
  - study-guide
  - index
  - moc
aliases:
  - AZ-700 Study Notes Index
  - AZ-700 MOC
created: 2025-01-01
updated: 2026-02-07
---

# AZ-700 Study Notes

## Designing and Implementing Microsoft Azure Networking Solutions

Study notes for the AZ-700 certification exam, organized to match the official
[Skills at a glance](https://learn.microsoft.com/en-gb/credentials/certifications/resources/study-guides/az-700#skills-at-a-glance)
from the exam study guide (January 21, 2026 revision).

---

## Folder Structure

```
Study_Notes/
│
├── 1. Design_Implement_Core_Networking_Infrastructure/      (25-30%)
│   ├── VNet_Subnets_IP_Addressing.md
│   ├── Azure_DNS.md
│   ├── VNet_Peering_Routing.md
│   ├── Azure_Route_Server.md
│   ├── Azure_Route_Server_Architecture.drawio
│   ├── Azure_Virtual_Network_Manager.md
│   ├── NAT_Gateway.md
│   ├── NAT_Gateway_Architecture.drawio
│   ├── Network_Watcher.md
│   ├── DDoS_Protection.md
│   ├── Microsoft_Defender_for_Cloud_Networking.md
│   └── Azure_Monitor_Network_Insights.md
│
├── 2. Design_Implement_Manage_Connectivity_Services/        (20-25%)
│   ├── VPN_Gateway.md
│   ├── Point_to_Site_VPN.md
│   ├── ExpressRoute.md
│   ├── Virtual_WAN.md
│   └── Virtual_WAN_Architecture.drawio
│
├── 3. Design_Implement_Application_Delivery_Services/       (15-20%)
│   ├── Azure_Load_Balancer.md
│   ├── Traffic_Manager.md
│   ├── Application_Gateway.md
│   ├── Azure_Front_Door.md
│   └── diagrams/
│       ├── Application_Gateway.drawio
│       └── Traffic_Manager.drawio
│
├── 4. Design_Implement_Private_Access_to_Azure_Services/    (10-15%)
│   ├── Private_Endpoints.md
│   ├── Private_Link_Service.md
│   └── Service_Endpoints.md
│
├── 5. Design_Implement_Azure_Network_Security_Services/     (15-20%)
│   ├── NSG_ASG_Firewall.md
│   ├── Azure_Firewall_and_Firewall_Manager.md
│   ├── Azure_Firewall_Architecture.drawio
│   ├── WAF.md
│   └── Azure_Bastion.md
│
├── az_700_prompt.md
└── README.md
```

---

## Study Notes by Domain

### 1. Design and implement core networking infrastructure (25-30%)

| Official Sub-section | Notes File | Key Concepts |
|---|---|---|
| Design and implement IP addressing | [VNet_Subnets_IP_Addressing.md](Design_Implement_Core_Networking_Infrastructure/VNet_Subnets_IP_Addressing.md) | Network segmentation, address spaces, subnetting for services, subnet delegation, public IP prefixes, BYOIP / Custom IP Prefix |
| Design and implement name resolution | [Azure_DNS.md](Design_Implement_Core_Networking_Infrastructure/Azure_DNS.md) | VNet DNS settings, public/private DNS zones, Private Resolver, zone linking |
| Design and implement VNet connectivity and routing | [VNet_Peering_Routing.md](Design_Implement_Core_Networking_Infrastructure/VNet_Peering_Routing.md) | Service chaining, gateway transit, VNet peering, UDRs, forced tunneling |
| Design and implement VNet connectivity and routing | [Azure_Route_Server.md](Design_Implement_Core_Networking_Infrastructure/Azure_Route_Server.md) | BGP with NVAs, route injection, branch-to-branch |
| Design and implement VNet connectivity and routing | [Azure_Virtual_Network_Manager.md](Design_Implement_Core_Networking_Infrastructure/Azure_Virtual_Network_Manager.md) | Connectivity configs, security admin rules, network groups |
| Design and implement VNet connectivity and routing | [NAT_Gateway.md](Design_Implement_Core_Networking_Infrastructure/NAT_Gateway.md) | Outbound SNAT, public IP association, forced tunneling |
| Monitor networks | [Network_Watcher.md](Design_Implement_Core_Networking_Infrastructure/Network_Watcher.md) | Diagnostics, flow logs, connection monitor, topology, packet capture |
| Monitor networks | [DDoS_Protection.md](Design_Implement_Core_Networking_Infrastructure/DDoS_Protection.md) | DDoS Network Protection, DDoS IP Protection, adaptive tuning, alerts |
| Monitor networks | [Microsoft_Defender_for_Cloud_Networking.md](Design_Implement_Core_Networking_Infrastructure/Microsoft_Defender_for_Cloud_Networking.md) | Secure Score, Attack Path Analysis, Cloud Security Explorer, Adaptive Network Hardening, JIT VM Access |
| Monitor networks | [Azure_Monitor_Network_Insights.md](Design_Implement_Core_Networking_Infrastructure/Azure_Monitor_Network_Insights.md) | Network Topology, Health & Metrics, Connectivity Monitor, Traffic Analytics, NSG Flow Logs, KQL |

### 2. Design, implement, and manage connectivity services (20-25%)

| Official Sub-section | Notes File | Key Concepts |
|---|---|---|
| Site-to-site VPN connection | [VPN_Gateway.md](Design_Implement_Manage_Connectivity_Services/VPN_Gateway.md) | S2S/VNet-to-VNet, SKUs, Active-Active, BGP, IPsec/IKE policies, local network gateway, Azure Extended Network |
| Point-to-site VPN connection | [Point_to_Site_VPN.md](Design_Implement_Manage_Connectivity_Services/Point_to_Site_VPN.md) | Tunnel types (OpenVPN/IKEv2/SSTP), Entra ID auth, RADIUS, Always On VPN, Azure Network Adapter (WAC) |
| Azure ExpressRoute | [ExpressRoute.md](Design_Implement_Manage_Connectivity_Services/ExpressRoute.md) | Local/Standard/Premium SKUs, Direct vs Provider, Global Reach, FastPath, private & Microsoft peering, BFD, MACsec encryption, IPsec over ER |
| Azure Virtual WAN architecture | [Virtual_WAN.md](Design_Implement_Manage_Connectivity_Services/Virtual_WAN.md) | Hub architecture, Basic vs Standard SKU, hub routing, scale units, NVA integration |

### 3. Design and implement application delivery services (15-20%)

| Official Sub-section | Notes File | Key Concepts |
|---|---|---|
| Azure Load Balancer and Traffic Manager | [Azure_Load_Balancer.md](Design_Implement_Application_Delivery_Services/Azure_Load_Balancer.md) | Standard vs Basic, HA ports, distribution modes, SNAT, Gateway LB deep dive, Cross-Region LB, inbound NAT rules |
| Azure Load Balancer and Traffic Manager | [Traffic_Manager.md](Design_Implement_Application_Delivery_Services/Traffic_Manager.md) | DNS-based routing, routing methods (priority/weighted/geographic/performance), endpoint monitoring |
| Azure Application Gateway | [Application_Gateway.md](Design_Implement_Application_Delivery_Services/Application_Gateway.md) | v2 SKU, WAF modes, SSL termination, path-based routing, multi-site, rewrite sets |
| Azure Front Door | [Azure_Front_Door.md](Design_Implement_Application_Delivery_Services/Azure_Front_Door.md) | Global L7 load balancing, WAF, caching, Private Link origins, rules engine |

### 4. Design and implement private access to Azure services (10-15%)

| Official Sub-section | Notes File | Key Concepts |
|---|---|---|
| Azure Private Link service and private endpoints | [Private_Endpoints.md](Design_Implement_Private_Access_to_Azure_Services/Private_Endpoints.md) | Planning, access control, DNS integration (privatelink zones) |
| Azure Private Link service and private endpoints | [Private_Link_Service.md](Design_Implement_Private_Access_to_Azure_Services/Private_Link_Service.md) | Exposing your own service, NAT IP, approval workflow, on-premises integration |
| Service endpoints | [Service_Endpoints.md](Design_Implement_Private_Access_to_Azure_Services/Service_Endpoints.md) | When to use, service endpoint policies, access configuration |

### 5. Design and implement Azure network security services (15-20%)

| Official Sub-section | Notes File | Key Concepts |
|---|---|---|
| Implement and manage NSGs | [NSG_ASG_Firewall.md](Design_Implement_Azure_Network_Security_Services/NSG_ASG_Firewall.md) | NSG rules, ASGs, flow logs, IP flow verify, Bastion NSG config |
| Azure Firewall and Firewall Manager | [Azure_Firewall_and_Firewall_Manager.md](Design_Implement_Azure_Network_Security_Services/Azure_Firewall_and_Firewall_Manager.md) | SKUs (Basic/Standard/Premium), DNAT/network/application rules, Firewall Manager policies, secured virtual hubs |
| Web Application Firewall (WAF) | [WAF.md](Design_Implement_Azure_Network_Security_Services/WAF.md) | DRS vs CRS rule sets, Detection/Prevention modes, WAF policy (global/per-site/per-URI), custom rules, exclusions, rate limiting, bot protection |
| NSG / Bastion / remote access | [Azure_Bastion.md](Design_Implement_Azure_Network_Security_Services/Azure_Bastion.md) | SKU tiers (Developer/Basic/Standard/Premium), NSG rules for Bastion, native client, VNet peering deployment, private-only |

---

## Coverage Status

| # | Domain (official name) | Weight | Notes |
|---|---|---|---|
| 1 | Design and implement core networking infrastructure | 25-30% | Covered |
| 2 | Design, implement, and manage connectivity services | 20-25% | Covered |
| 3 | Design and implement application delivery services | 15-20% | Covered |
| 4 | Design and implement private access to Azure services | 10-15% | Covered |
| 5 | Design and implement Azure network security services | 15-20% | Covered (WAF.md + Azure_Bastion.md added) |

### Gaps / Future Work

- **Azure Virtual Network Manager security admin rules**: Deeper coverage of deny-always / allow-always admin rules in hub-spoke topologies

### Recently Filled Gaps (This Session)

| Gap | Resolution | Notes |
|-----|-----------|-------|
| Azure Bastion deep dive | Created [Azure_Bastion.md](Design_Implement_Azure_Network_Security_Services/Azure_Bastion.md) | 4 SKU tiers, full NSG rules, native client, VNet peering |
| Azure Monitor Network Insights | Created [Azure_Monitor_Network_Insights.md](Design_Implement_Core_Networking_Infrastructure/Azure_Monitor_Network_Insights.md) | Five pillars, KQL queries, data flow architecture |
| Gateway Load Balancer | Deep dive added to [Azure_Load_Balancer.md](Design_Implement_Application_Delivery_Services/Azure_Load_Balancer.md) | VXLAN, chaining, provider/consumer model |
| Cross-Region (Global) Load Balancer | Deep dive added to [Azure_Load_Balancer.md](Design_Implement_Application_Delivery_Services/Azure_Load_Balancer.md) | Home regions, 7 limitations, failover behavior |
| Azure Extended Network | Section added to [VPN_Gateway.md](Design_Implement_Manage_Connectivity_Services/VPN_Gateway.md) | VXLAN L2 stretch, 250 IP limit, WAC |
| Azure Network Adapter | Section added to [Point_to_Site_VPN.md](Design_Implement_Manage_Connectivity_Services/Point_to_Site_VPN.md) | WAC one-click P2S, cert auth, VpnGw1 |
| BFD on ExpressRoute | Deep dive added to [ExpressRoute.md](Design_Implement_Manage_Connectivity_Services/ExpressRoute.md) | 300ms intervals, pre/post-Aug 2018, Cisco config |
| Encryption over ExpressRoute | Deep dive added to [ExpressRoute.md](Design_Implement_Manage_Connectivity_Services/ExpressRoute.md) | MACsec (L2, Direct), IPsec overlay (L3, standard) |
| BYOIP / Custom IP Prefix | Section added to [VNet_Subnets_IP_Addressing.md](Design_Implement_Core_Networking_Infrastructure/VNet_Subnets_IP_Addressing.md) | ROA, RPKI, 3-phase onboarding, /24 minimum |

---

## 📊 Dataview Dashboards

> [!tip] Install the **Dataview** community plugin to render these live tables.
> Settings → Community plugins → Browse → search "Dataview" → Install → Enable

### All Study Notes

```dataview
TABLE
  aliases AS "Aliases",
  join(filter(tags, (t) => startswith(t, "domain/")), ", ") AS "Domain",
  updated AS "Updated"
FROM #AZ-700
WHERE file.name != "README" AND file.name != "Obsidian_Guide" AND file.name != "az_700_prompt"
SORT file.folder ASC, file.name ASC
```

### Notes by Domain (Note Count & Link Density)

```dataview
TABLE WITHOUT ID
  Domain AS "Domain",
  length(rows) AS "Notes",
  sum(map(rows, (r) => length(r.file.outlinks))) AS "Total Outlinks"
FROM #AZ-700
WHERE file.name != "README" AND file.name != "Obsidian_Guide" AND file.name != "az_700_prompt"
FLATTEN choice(
  contains(file.tags, "#domain/core-networking"), "1 — Core Networking (25-30%)",
  choice(
    contains(file.tags, "#domain/connectivity"), "2 — Connectivity (20-25%)",
    choice(
      contains(file.tags, "#domain/app-delivery"), "3 — App Delivery (15-20%)",
      choice(
        contains(file.tags, "#domain/private-access"), "4 — Private Access (10-15%)",
        choice(
          contains(file.tags, "#domain/network-security"), "5 — Network Security (15-20%)",
          "Other"
        )
      )
    )
  )
) AS Domain
GROUP BY Domain
SORT Domain ASC
```

### Most Connected Notes (Study Priority)

```dataview
TABLE
  length(file.inlinks) AS "Inbound Links",
  length(file.outlinks) AS "Outbound Links",
  length(file.inlinks) + length(file.outlinks) AS "Total Connections"
FROM #AZ-700
WHERE file.name != "README" AND file.name != "Obsidian_Guide" AND file.name != "az_700_prompt"
SORT (length(file.inlinks) + length(file.outlinks)) DESC
LIMIT 10
```

### Security Cluster

```dataview
TABLE
  join(filter(tags, (t) => !startswith(t, "AZ-700") AND !startswith(t, "azure/") AND !startswith(t, "domain/")), ", ") AS "Topic Tags"
FROM #azure/security
SORT file.name ASC
```

### Recently Updated

```dataview
LIST
FROM #AZ-700
WHERE updated >= date("2026-02-01")
SORT updated DESC
```

---

## Quick Links

- [Official AZ-700 Study Guide (Jan 2026)](https://learn.microsoft.com/en-gb/credentials/certifications/resources/study-guides/az-700)
- [Microsoft Learn: AZ-700 Learning Path](https://learn.microsoft.com/en-us/training/paths/design-implement-microsoft-azure-networking-solutions-az-700/)
- [Free Practice Assessment](https://learn.microsoft.com/en-us/credentials/certifications/exams/az-700/practice/assessment?assessment-type=practice&assessmentId=70)
- [Azure Networking Documentation](https://learn.microsoft.com/en-us/azure/networking/)

---

*Last Updated: February 2026*
