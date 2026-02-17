---
tags:
  - AZ-700
  - prompt-engineering
  - study-guide
  - template
aliases:
  - AZ-700 Prompt
  - Study Notes Prompt
created: 2025-01-01
updated: 2026-02-07
---

# AZ-700 Study Notes Prompt

Use this prompt with ChatGPT or GitHub Copilot to generate comprehensive study notes for the AZ-700 exam.

---

## The Prompt
V
> **Role**: You are an expert Azure networking instructor and exam preparation specialist helping me study for the **AZ-700: Designing and Implementing Microsoft Azure Networking Solutions** certification.
>
> **Context**: I already have Azure fundamentals knowledge. I need focused, exam-ready study notes (1500-2000 words per topic).
>
> **For each topic I request, create study notes that include:**
>
> 1. **Key Concepts & Definitions** — Core terminology and how the component works
> 2. **Architecture Overview** — Include ASCII diagrams showing data flow and component relationships; also provide draw.io XML snippets I can import into VS Code
> 3. **Configuration Best Practices** — PowerShell commands and recommended settings
> 4. **Comparison Tables** — Side-by-side feature comparisons with related services
> 5. **Exam Tips & Gotchas** — Commonly tested scenarios, tricky questions, and critical points (bold these)
> 6. **Hands-On Lab Suggestions** — Practical PowerShell exercises to reinforce learning
> 7. **Cross-Service Relationships** — How this topic connects to other Azure networking services
>
> **Format**: Markdown with clear headers, bullet points, tables, code blocks, and ASCII diagrams. Bold **critical exam points**.
>
> **File Naming**: `Topic_Name.md` (e.g., `VPN_Gateway.md`, `ExpressRoute.md`)
>
> **Folder Structure** (match notes to these domains):
> - `Design_Implement_Core_Networking_Infrastructure/` (25-30%)
> - `Design_Implement_Manage_Connectivity_Services/` (20-25%)
> - `Design_Implement_Application_Delivery_Services/` (15-20%)
> - `Design_Implement_Private_Access_to_Azure_Services/` (10-15%)
> - `Design_Implement_Azure_Network_Security_Services/` (15-20%)

---

## Exam Skill Domains (Official Microsoft Outline - January 2026)

### Core Networking Infrastructure (25-30%)
- IP addressing, VNets, subnetting, public IP prefixes
- DNS (public/private zones, Private Resolver)
- VNet peering, UDRs, Route Server, NAT Gateway, Azure Virtual Network Manager
- Network monitoring (Network Watcher, Azure Monitor, DDoS Protection, Defender for Cloud)

### Connectivity Services (20-25%)
- Site-to-site VPN (gateway SKUs, policy vs route-based, IPsec/IKE)
- Point-to-site VPN (tunnel types, authentication, Always On VPN)
- ExpressRoute (connectivity models, Global Reach, FastPath, peering types)
- Virtual WAN (hubs, routing, NVA integration)

### Application Delivery Services (15-20%)
- Azure Load Balancer (SKUs, public/internal, NAT rules, SNAT)
- Traffic Manager
- Application Gateway (listeners, health probes, TLS, rewrites)
- Azure Front Door (routing, caching, Private Link origins)

### Private Access to Azure Services (10-15%)
- Private Endpoints & Private Link service
- Service Endpoints & policies
- DNS integration for private access

### Network Security Services (15-20%)
- NSGs and ASGs (rules, flow logs, IP flow verify)
- Azure Bastion
- Azure Firewall & Firewall Manager (SKUs, policies, secure hubs)
- Web Application Firewall (detection/prevention modes, rule sets)

---

## How to Use This Prompt

1. **Copy the prompt above** into ChatGPT or use with GitHub Copilot
2. **Request specific topics**, for example:
   - *"Create study notes for VPN Gateway"*
   - *"Create study notes for Private Endpoints vs Service Endpoints"*
   - *"Create study notes for Azure Firewall"*
3. **Save each response** to the appropriate folder with the naming convention `Topic_Name.md`

---

## Example Requests

```
Create study notes for VPN Gateway
```

```
Create study notes for ExpressRoute
```

```
Create study notes for Private Endpoints and Service Endpoints comparison
```

```
Create study notes for Azure Firewall and Firewall Manager
```

```
Create study notes for Network Security Groups and Application Security Groups
```

---

## Resources

- [Official AZ-700 Study Guide](https://learn.microsoft.com/en-gb/credentials/certifications/resources/study-guides/az-700)
- [Microsoft Learn - AZ-700 Learning Path](https://learn.microsoft.com/en-us/training/paths/design-implement-microsoft-azure-networking-solutions-az-700/)
- [Azure Networking Documentation](https://learn.microsoft.com/en-us/azure/networking/)
