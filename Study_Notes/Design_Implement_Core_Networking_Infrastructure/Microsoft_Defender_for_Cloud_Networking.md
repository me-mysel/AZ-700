---
tags:
  - AZ-700
  - azure/networking
  - azure/security
  - domain/core-networking
  - defender-for-cloud
  - secure-score
  - attack-path-analysis
  - cloud-security-explorer
  - adaptive-network-hardening
  - jit-vm-access
  - monitoring
aliases:
  - Defender for Cloud
  - Secure Score
  - Attack Path Analysis
created: 2026-02-07
updated: 2026-02-07
---

# Microsoft Defender for Cloud — Network Security

> **AZ-700 Exam Domain 1.4** — Monitor networks (items 5–7)

> [!info] Related Notes
> - [[Network_Watcher]] — Complementary network diagnostics and flow logs
> - [[NSG_ASG_Firewall]] — Adaptive Network Hardening tightens NSG rules
> - [[DDoS_Protection]] — Secure Score recommends DDoS protection
> - [[Private_Endpoints]] — Secure Score checks for public exposure
> - [[Azure_Firewall_and_Firewall_Manager]] — Firewall recommendations in Secure Score

---

## Table of Contents

1. [Overview](#overview)
2. [Secure Score — Network Recommendations](#secure-score--network-recommendations)
3. [Attack Path Analysis — Network Resources](#attack-path-analysis--network-resources)
4. [Cloud Security Explorer — Network Identification](#cloud-security-explorer--network-identification)
5. [Cloud Security Graph](#cloud-security-graph)
6. [Prerequisites and Licensing](#prerequisites-and-licensing)
7. [Adaptive Network Hardening](#adaptive-network-hardening)
8. [Just-In-Time (JIT) VM Access](#just-in-time-jit-vm-access)
9. [Exam Gotchas](#exam-gotchas)

---

## Overview

Microsoft Defender for Cloud provides **Cloud Security Posture Management (CSPM)** and
**Cloud Workload Protection Platform (CWPP)** capabilities. For AZ-700, focus on the
network-related features under the "Monitor networks" objective:

| Feature | What It Does | Plan Required |
|---|---|---|
| **Secure Score** | Aggregates security findings into a single score with actionable recommendations | Free (Foundational CSPM) |
| **Attack Path Analysis** | Discovers exploitable paths through your environment using graph-based analysis | **Defender CSPM** (paid) |
| **Cloud Security Explorer** | Interactive graph queries to find at-risk network resources | **Defender CSPM** (paid) |
| **Adaptive Network Hardening** | ML-based NSG rule tightening recommendations | **Defender for Servers** |
| **JIT VM Access** | Locks down management ports until explicitly requested | **Defender for Servers** |

---

## Secure Score — Network Recommendations

### What Is Secure Score?

Secure Score measures your overall security posture as a **percentage** (0–100%).
It is calculated by aggregating the health of all **security recommendations** across
your subscriptions, grouped by **security controls**.

### Two Scoring Models

| Model | Portal | Key Difference |
|---|---|---|
| **Classic Secure Score** | Azure portal (Defender for Cloud blade) | Control-based grouping; max score per control |
| **Risk-based Cloud Secure Score** | Microsoft Defender portal | Factors in asset exposure, internet exposure, lateral movement risk |

> **Exam tip**: The risk-based model weighs recommendations by actual **exploitability**,
> not just compliance. Questions may distinguish between the two models.

### Network-Specific Recommendations

These are the most common network-related recommendations that affect Secure Score:

| Recommendation | Control | Impact |
|---|---|---|
| Management ports should be closed on VMs | Restrict access to management ports | High |
| Subnets should be associated with an NSG | Restrict access | Medium |
| Internet-facing VMs should have NSGs | Restrict access | High |
| IP Forwarding on VMs should be disabled | Restrict access | Medium |
| Storage accounts should restrict network access | Restrict access | Medium |
| Non-internet-facing VMs should be protected with NSGs | Restrict access | Low |
| Adaptive network hardening recommendations should be applied | Restrict access | Medium |
| DDoS Protection should be enabled | Protect against DDoS | Medium |

### How Remediation Affects Score

```
                      Max Score = 10            Current Score = 4
                      ┌──────────────────┐      ┌──────────┐
Control:              │ Restrict access  │  →   │ 4/10     │
Restrict access       │                  │      │ (6 unhealthy)
to management ports   └──────────────────┘      └──────────┘
                                                     │
                      Fix 3 of 6 resources           │
                                                     ▼
                                                ┌──────────┐
                                                │ 7/10     │
                                                │ (3 unhealthy)
                                                └──────────┘
```

- Fixing **all** unhealthy resources in a control awards the full max score for that control.
- The overall score is the sum of all control scores ÷ total possible score × 100.

### Microsoft Cloud Security Benchmark (MCSB)

The **MCSB** is the default security standard applied to all subscriptions. Network-related
controls in MCSB:

| MCSB Control | Objective |
|---|---|
| **NS-1**: Establish network segmentation boundaries | Subnets, NSGs, service endpoints |
| **NS-2**: Secure cloud services with network controls | Private endpoints, service firewalls |
| **NS-3**: Deploy firewall at the edge | Azure Firewall, WAF |
| **NS-4**: Deploy IDS/IPS | Firewall Premium IDPS |
| **NS-5**: Deploy DDoS protection | DDoS Protection plans |
| **NS-6**: Deploy WAF | Application Gateway WAF, Front Door WAF |
| **NS-7**: Simplify network security configuration | AVNM, Adaptive Network Hardening, Firewall Manager |

---

## Attack Path Analysis — Network Resources

### What Is Attack Path Analysis?

Attack Path Analysis uses the **cloud security graph** and a proprietary algorithm to
discover **exploitable paths** that attackers could use to reach high-impact resources.
It models paths that begin **outside your organization** (internet exposure) and trace
through misconfigurations, vulnerabilities, and overly permissive access.

### How It Works

```
[Internet Entry Point]
        │
        ▼
[Public IP / Open NSG Port]
        │
        ▼
[Vulnerable VM] ──(lateral movement)──► [Key Vault / Storage with secrets]
        │
        ▼
[Managed Identity with high privileges]
        │
        ▼
[Critical Data Store]
```

### Network-Specific Attack Path Scenarios

| Scenario | What Defender Detects |
|---|---|
| Internet-exposed VM with open RDP/SSH | Public IP + NSG allows 0.0.0.0/0 inbound on port 3389/22 |
| VM with known vulnerabilities exposed to internet | CVE + public IP + no NSG restriction |
| Lateral movement via VNet peering | Peered VNet with overly permissive NSGs |
| Storage account reachable from compromised VM | VM in same VNet as storage with service endpoint, no RBAC |
| SQL server exposed via misconfigured NSG | SQL port (1433) open to internet |

### Key Concepts

- **Entry point**: An internet-exposed resource with a weakness (public IP, open port)
- **Lateral movement**: Ability to move from one compromised resource to another
  (VNet peering, managed identity, shared credentials)
- **Target**: High-value asset (Key Vault, database, storage with sensitive data)
- **Risk factors**: CVEs, excessive permissions, missing MFA, public exposure

### Viewing Attack Paths

1. **Defender for Cloud** → **Attack path analysis** blade
2. Each path shows a graph visualization of nodes (resources) and edges (relationships)
3. **Remediation**: Each node in the path includes specific recommendations

---

## Cloud Security Explorer — Network Identification

### What Is Cloud Security Explorer?

Cloud Security Explorer is an **interactive graph query tool** that lets you explore
the cloud security graph. It enables proactive identification of network security risks
using pre-built or custom queries.

### Network-Relevant Queries

| Query Template | What It Finds |
|---|---|
| VMs with public IP and high-severity vulnerabilities | Internet-exposed attack surface |
| VMs with open management ports (3389, 22) | RDP/SSH exposure |
| Subnets without NSGs | Unprotected network segments |
| Storage accounts with public network access | Data exfiltration risk |
| VMs connected to VNets without DDoS protection | Missing L3/L4 protection |
| Resources with internet exposure and sensitive data | Highest-risk combinations |

### Building a Query

Queries in Cloud Security Explorer use a **graph-based** syntax:

```
[Resource Type] → [Relationship] → [Resource Type] → [Condition]

Example:
Virtual Machine
  ├── has public IP address
  ├── is connected to subnet
  │     └── without associated NSG
  └── has high-severity vulnerability
```

### Query Components

| Component | Description |
|---|---|
| **Entity** | Azure resource type (VM, VNet, subnet, storage account) |
| **Edge** | Relationship between entities (connected to, contains, uses, exposes) |
| **Condition** | Filter (has public IP, severity = high, port = 3389) |
| **Insights** | Enrichments like vulnerability data, exposure level |

> **Exam tip**: Cloud Security Explorer works against the **cloud security graph** — it
> is NOT the same as Azure Resource Graph. Cloud Security Explorer includes **security
> context** (vulnerabilities, attack paths, permissions) while Resource Graph is
> infrastructure-only.

---

## Cloud Security Graph

The cloud security graph is the **foundation** for both Attack Path Analysis and
Cloud Security Explorer. It collects and correlates:

| Data Category | Examples |
|---|---|
| **Assets** | VMs, VNets, subnets, NSGs, public IPs, storage accounts |
| **Network connections** | VNet peering, subnet associations, routing tables |
| **Permissions** | RBAC assignments, managed identities, service principals |
| **Vulnerabilities** | CVEs from Qualys/MDVM scans, misconfigurations |
| **Configurations** | NSG rules, firewall rules, service endpoints, private endpoints |
| **Internet exposure** | Public IPs, public-facing load balancers, open ports |

> The security graph is **multicloud** — it covers Azure, AWS, and GCP when connectors
> are configured.

---

## Prerequisites and Licensing

| Feature | Required Plan | Additional Requirements |
|---|---|---|
| Secure Score (basic) | Free (Foundational CSPM) | — |
| Network-specific recommendations | Free | — |
| Risk-based Secure Score | **Defender CSPM** | Microsoft Defender portal |
| Attack Path Analysis | **Defender CSPM** | Agentless scanning enabled |
| Cloud Security Explorer | **Defender CSPM** | Agentless scanning enabled |
| Adaptive Network Hardening | **Defender for Servers** (Plan 1 or 2) | Log Analytics agent or AMA |
| JIT VM Access | **Defender for Servers** (Plan 1 or 2) | NSG on the VM's subnet/NIC |

### Required Roles

| Role | Capabilities |
|---|---|
| Security Reader | View Secure Score, recommendations, attack paths (read-only) |
| Security Admin | View + dismiss recommendations, manage security policies |
| Contributor | Apply recommendations (remediate) |
| Owner | Full access including policy assignment |

---

## Adaptive Network Hardening

Adaptive Network Hardening uses **machine learning** to analyze actual traffic patterns
and recommend tighter NSG rules.

### How It Works

1. Defender for Servers monitors traffic to your VMs (14–30 days baseline)
2. ML model identifies which ports, protocols, and source IPs are actually used
3. Recommendations generated to **restrict** NSG rules to observed patterns
4. You can **apply** recommendations directly (creates/modifies NSG rules)

### Example

```
Current NSG rule:    Allow TCP 0.0.0.0/0 → Port 443
                     Allow TCP 0.0.0.0/0 → Port 22

Recommendation:      Allow TCP 10.0.0.0/8 → Port 443    (actual sources)
                     Allow TCP 203.0.113.5/32 → Port 22  (admin IP only)
                     Deny all other inbound              (new deny rule)
```

> **Key point for AZ-700**: Adaptive Network Hardening is a **Defender for Servers**
> feature, not a core networking feature. But it directly modifies NSGs, so it appears
> in the networking exam domain.

---

## Just-In-Time (JIT) VM Access

JIT reduces the attack surface by **closing management ports by default** and opening
them only on request for a limited time.

### How It Works

1. Defender for Servers adds a **deny** NSG rule on management ports (RDP 3389, SSH 22, etc.)
2. When an admin requests access, Defender creates a temporary **allow** rule
3. The allow rule is scoped to the requester's source IP and expires after a configured time
4. After expiration, the deny rule takes effect again

### Configuration

| Setting | Options |
|---|---|
| **Ports** | Any port (default: 3389, 22, 5985, 5986) |
| **Source IPs** | My IP, IP range, or Any |
| **Time window** | 1 hour to 24 hours |
| **Protocol** | TCP, UDP, or Any |

> **Exam scenario**: "A VM needs SSH access from a specific admin IP for 2 hours" →
> Configure JIT VM access with port 22, source IP of the admin, 2-hour time window.

---

## Exam Gotchas

### 1. Defender CSPM vs Foundational CSPM
- **Foundational CSPM** (free): Secure Score + basic recommendations — included for all
  Azure subscriptions.
- **Defender CSPM** (paid): Adds Attack Path Analysis, Cloud Security Explorer,
  agentless scanning, governance rules. Required for advanced network analysis.

### 2. Attack Path Analysis Requires Agentless Scanning
You must enable **agentless scanning** in the Defender CSPM plan. Without it, attack
paths based on OS-level vulnerabilities won't be detected.

### 3. Cloud Security Explorer ≠ Azure Resource Graph
Cloud Security Explorer queries the **security graph** (includes vulnerabilities,
attack context, permissions). Azure Resource Graph queries **resource properties only**.
The exam may test this distinction.

### 4. Adaptive Network Hardening = Defender for Servers
It's a Defender for **Servers** feature (not Defender CSPM). It needs an agent (Log
Analytics agent or Azure Monitor Agent) to collect traffic data.

### 5. JIT Modifies NSGs
JIT VM access creates and deletes **NSG rules** programmatically. The VM's subnet or
NIC must have an NSG for JIT to work. If there's no NSG, JIT cannot be enabled.

### 6. Secure Score Doesn't Mean Compliance
A high Secure Score doesn't guarantee regulatory compliance. Secure Score measures
**security posture** against Microsoft recommendations, not against specific regulations
(PCI-DSS, HIPAA, etc.). Regulatory compliance is a separate Defender for Cloud feature.

### 7. Recommendations Don't Auto-Remediate (by Default)
Defender for Cloud provides **recommendations** but does not automatically fix them
unless you explicitly configure **auto-remediation** (governance rules or Azure Policy
deployIfNotExists). The exam may present "automatic vs manual" remediation scenarios.

### 8. Network-Related Secure Score Controls
The "Restrict access to management ports" and "Secure transfer to storage accounts"
controls have the highest impact on network security posture. Exam questions about
maximizing Secure Score improvements should target these controls first.

---

## References

- [Secure Score overview](https://learn.microsoft.com/en-us/azure/defender-for-cloud/secure-score-security-controls)
- [Attack Path Analysis](https://learn.microsoft.com/en-us/azure/defender-for-cloud/concept-attack-path)
- [Cloud Security Explorer](https://learn.microsoft.com/en-us/azure/defender-for-cloud/concept-cloud-security-explorer)
- [Cloud Security Graph](https://learn.microsoft.com/en-us/azure/defender-for-cloud/concept-attack-path#what-is-cloud-security-graph)
- [Adaptive Network Hardening](https://learn.microsoft.com/en-us/azure/defender-for-cloud/adaptive-network-hardening)
- [JIT VM Access](https://learn.microsoft.com/en-us/azure/defender-for-cloud/just-in-time-access-usage)
- [Microsoft Cloud Security Benchmark](https://learn.microsoft.com/en-us/security/benchmark/azure/overview)
