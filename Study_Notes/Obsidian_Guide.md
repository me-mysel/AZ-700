---
tags:
  - AZ-700
  - obsidian
  - workflow
  - guide
aliases:
  - Obsidian Guide
  - Obsidian Workflow
created: 2026-02-07
updated: 2026-02-07
---

# Obsidian Workflow Guide — AZ-700 Second Brain

> [!tip] This guide shows how to use these study notes as an Obsidian vault for
> efficient AZ-700 exam preparation.

---

## 1. Open the Vault

Open `Study_Notes` as an Obsidian vault:

**File → Open folder as vault → select `C:\Users\victorgue\Learning\Certs\AZ-700\Study_Notes`**

Obsidian will immediately index all YAML frontmatter, tags, aliases, and `[[wiki links]]`.

---

## 2. Vault Structure

```
Study_Notes/                              ← Obsidian vault root
│
├── README.md                             ← 📋 Map of Content (#moc #index)
├── Obsidian_Guide.md                     ← 📖 This file
├── az_700_prompt.md                      ← 🤖 Prompt template for generating notes
│
├── Domain 1: Design_Implement_Core_Networking_Infrastructure/    (25-30%)
│   ├── VNet_Subnets_IP_Addressing.md
│   ├── Azure_DNS.md
│   ├── VNet_Peering_Routing.md
│   ├── Azure_Route_Server.md
│   ├── Azure_Virtual_Network_Manager.md
│   ├── NAT_Gateway.md
│   ├── Network_Watcher.md
│   ├── DDoS_Protection.md
│   └── Microsoft_Defender_for_Cloud_Networking.md
│
├── Domain 2: Design_Implement_Manage_Connectivity_Services/      (20-25%)
│   ├── VPN_Gateway.md
│   ├── Point_to_Site_VPN.md
│   ├── ExpressRoute.md
│   └── Virtual_WAN.md
│
├── Domain 3: Design_Implement_Application_Delivery_Services/     (15-20%)
│   ├── Azure_Load_Balancer.md
│   ├── Traffic_Manager.md
│   ├── Application_Gateway.md
│   └── Azure_Front_Door.md
│
├── Domain 4: Design_Implement_Private_Access_to_Azure_Services/  (10-15%)
│   ├── Private_Endpoints.md
│   ├── Private_Link_Service.md
│   └── Service_Endpoints.md
│
└── Domain 5: Design_Implement_Azure_Network_Security_Services/   (15-20%)
    ├── NSG_ASG_Firewall.md
    ├── Azure_Firewall_and_Firewall_Manager.md
    └── WAF.md
```

---

## 3. Tag Taxonomy

Every note uses a consistent tag hierarchy. Use the **Tags pane** (left sidebar) to browse:

### Top-Level Tags

| Tag | Scope | Count |
|---|---|---|
| `#AZ-700` | Every note in the vault | 20 |
| `#azure/networking` | All networking topics | 20 |
| `#azure/security` | Security-focused notes | 4 |
| `#study-guide` | Index and reference files | 2 |

### Domain Tags

| Tag | Exam Domain | Weight |
|---|---|---|
| `#domain/core-networking` | Design and implement core networking infrastructure | 25-30% |
| `#domain/connectivity` | Design, implement, and manage connectivity services | 20-25% |
| `#domain/app-delivery` | Design and implement application delivery services | 15-20% |
| `#domain/private-access` | Design and implement private access to Azure services | 10-15% |
| `#domain/network-security` | Design and implement Azure network security services | 15-20% |

### Topic Tags (Examples)

| Tag | Notes |
|---|---|
| `#vnet-peering` | VNet_Peering_Routing |
| `#bgp` | Azure_Route_Server, VPN_Gateway |
| `#waf` | WAF |
| `#expressroute` | ExpressRoute |
| `#private-endpoint` | Private_Endpoints |
| `#nsg` | NSG_ASG_Firewall |
| `#ddos` | DDoS_Protection |
| `#monitoring` | Network_Watcher, Microsoft_Defender_for_Cloud_Networking |

---

## 4. Tag-Based Search

In the **Tags pane** (left sidebar), you'll see a nested hierarchy:

```
#AZ-700 (20)
#azure
  /networking (20)
  /security (4)
#domain
  /core-networking (9)
  /connectivity (4)
  /app-delivery (4)
  /private-access (3)
  /network-security (3)
#vnet-peering (1)
#bgp (1)
#waf (1)
...
```

Click any tag to instantly filter all notes containing it. For example, clicking
`#bgp` shows `Azure_Route_Server.md`, `VPN_Gateway.md`, and `VNet_Peering_Routing.md`.

---

## 5. Wiki Link Navigation

Every note has a `> [!info] Related Notes` callout with `[[bidirectional links]]`
to conceptually related notes. For example, in `Application_Gateway.md`:

```markdown
> [!info] Related Notes
> - [[WAF]] — Dedicated WAF deep-dive (CRS/DRS rule sets, policies, exclusions)
> - [[Azure_Front_Door]] — Global L7 alternative with edge WAF
> - [[NSG_ASG_Firewall]] — NSG rules on AppGW subnet (GatewayManager ports)
```

- **Click** `[[WAF]]` to jump straight to the WAF notes
- The **Backlinks panel** on WAF will show every note that references it
- `Ctrl+Click` opens in a new pane for side-by-side study

---

## 6. Quick Switcher (`Ctrl+O`)

Type an **alias** to jump to notes fast. Aliases are defined in each note's frontmatter:

| You Type | Opens |
|---|---|
| `AppGW` | Application_Gateway.md |
| `P2S VPN` | Point_to_Site_VPN.md |
| `AVNM` | Azure_Virtual_Network_Manager.md |
| `ER` | ExpressRoute.md |
| `ALB` | Azure_Load_Balancer.md |
| `vWAN` | Virtual_WAN.md |
| `NAT Gateway` | NAT_Gateway.md |
| `AFD` | Azure_Front_Door.md |
| `WAF` | WAF.md |
| `S2S VPN` | VPN_Gateway.md |
| `ARS` | Azure_Route_Server.md |
| `Secure Score` | Microsoft_Defender_for_Cloud_Networking.md |

---

## 7. Graph View (`Ctrl+G`)

Open Graph View to see all notes and their connections visualized.

### Useful Graph Filters

| Filter | What You See |
|---|---|
| `tag:#domain/connectivity` | Only the 4 connectivity notes and their links |
| `tag:#waf` | WAF note + all notes linking to it |
| `tag:#azure/security` | NSG, Firewall, WAF, Defender cluster |
| `tag:#domain/core-networking` | Only Domain 1 notes |
| `path:Design_Implement_Core` | Only files in the Core Networking folder |

### Graph Color Groups (Suggested Settings)

Configure in Graph View → Settings → Groups:

| Color | Query | Purpose |
|---|---|---|
| 🔵 Blue | `tag:#domain/core-networking` | Core networking notes |
| 🟢 Green | `tag:#domain/connectivity` | Connectivity notes |
| 🟡 Yellow | `tag:#domain/app-delivery` | App delivery notes |
| 🟠 Orange | `tag:#domain/private-access` | Private access notes |
| 🔴 Red | `tag:#domain/network-security` | Security notes |
| ⭐ Gold | `tag:#moc` | Map of Content (README) |

---

## 8. Exam Prep Workflow Example

Studying **"Design a WAF deployment"** (Domain 5.3):

```
1. Open [[WAF]] via Quick Switcher (Ctrl+O, type "WAF")
2. Read the WAF note — see Related Notes callout
3. Click [[Application_Gateway]] to review AppGW-specific WAF config
4. Click [[Azure_Front_Door]] to compare Front Door WAF differences
5. Click [[DDoS_Protection]] for defense-in-depth context
6. Press Ctrl+G → filter tag:#azure/security to see the security cluster
7. In Search (Ctrl+Shift+F), type tag:#waf to find every mention
```

### Spaced Repetition Study Pattern

```
Day 1:  #domain/core-networking    (25-30% of exam)
Day 2:  #domain/connectivity       (20-25% of exam)
Day 3:  #domain/app-delivery       (15-20% of exam)
Day 4:  #domain/private-access     (10-15% of exam)
Day 5:  #domain/network-security   (15-20% of exam)
Day 6:  Review weakest domain (use Graph View to explore connections)
Day 7:  Cross-domain scenarios (follow [[wiki links]] across domains)
```

---

## 9. Global Search (`Ctrl+Shift+F`)

### Useful Search Queries

| Query | Purpose |
|---|---|
| `tag:#AZ-700` | All study notes |
| `tag:#bgp` | Everything related to BGP |
| `"exam tip"` OR `"exam gotcha"` | All exam tips across notes |
| `tag:#waf tag:#domain/network-security` | WAF in security context |
| `"Premium"` | All mentions of Premium SKU/tier |
| `"Standard vs"` OR `"comparison"` | All comparison tables |
| `path:Design_Implement_Core "UDR"` | UDR mentions in core networking |

---

## 10. Dataview Plugin (Optional Power-Up)

Install the **Dataview** community plugin for live dashboards.

### All Notes Dashboard

Add this to your `README.md`:

~~~markdown
```dataview
TABLE aliases AS "Aliases", updated AS "Last Updated"
FROM #AZ-700
SORT updated DESC
```
~~~

This renders a live table of all notes sorted by last update date.

### Notes by Domain

~~~markdown
```dataview
TABLE length(file.inlinks) AS "Inbound Links", length(file.outlinks) AS "Outbound Links"
FROM #domain/core-networking
SORT file.name ASC
```
~~~

### Recently Updated

~~~markdown
```dataview
LIST
FROM #AZ-700
WHERE updated >= date("2026-01-01")
SORT updated DESC
```
~~~

### Security Cluster

~~~markdown
```dataview
TABLE tags AS "Tags"
FROM #azure/security
SORT file.name ASC
```
~~~

---

## 11. Recommended Obsidian Settings

### Core Settings

| Setting | Value | Why |
|---|---|---|
| **Default location for new notes** | Same folder as current file | Keeps domain organization |
| **New link format** | Shortest path when possible | Cleaner `[[links]]` |
| **Use [[Wikilinks]]** | ON | Standard Obsidian linking |
| **Detect all file extensions** | ON | Sees `.drawio` files too |
| **Strict line breaks** | OFF | Better markdown rendering |

### Recommended Community Plugins

| Plugin | Purpose |
|---|---|
| **Dataview** | Live queries and dashboards from frontmatter |
| **Calendar** | Track daily study sessions |
| **Excalidraw** | Draw network diagrams inline |
| **Spaced Repetition** | Flashcards from your notes |
| **Outliner** | Better list editing for study notes |
| **Tag Wrangler** | Rename/merge tags across the vault |

---

## 12. Frontmatter Reference

Every note in this vault uses this YAML frontmatter structure:

```yaml
---
tags:
  - AZ-700                    # Always present
  - azure/networking          # Nested tag for Azure networking
  - domain/core-networking    # Exam domain tag
  - specific-topic            # Topic-specific tags
aliases:
  - Short Name                # For Quick Switcher
  - Acronym                   # Common abbreviations
created: 2025-01-01           # When the note was created
updated: 2026-02-07           # Last update date
---
```

### Tag Rules

- **Always tag** `#AZ-700` and `#azure/networking` on every note
- **One domain tag** per note (e.g., `#domain/core-networking`)
- **Topic tags** should be kebab-case: `#vnet-peering`, `#bgp`, `#ssl-termination`
- **Nested tags** use `/`: `#azure/networking`, `#domain/connectivity`
- **Cross-cutting concerns** get extra tags: `#azure/security` for security-related notes

---

## Related Notes

> [!info] Key Entry Points
> - [[README]] — Map of Content with all domains and coverage status
> - [[az_700_prompt]] — Prompt template for generating new study notes
