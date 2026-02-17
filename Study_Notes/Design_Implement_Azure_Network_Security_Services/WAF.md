---
tags:
  - AZ-700
  - azure/networking
  - azure/security
  - domain/network-security
  - waf
  - web-application-firewall
  - owasp
  - crs
  - drs
  - managed-rules
  - custom-rules
  - exclusions
  - bot-protection
  - rate-limiting
  - anomaly-scoring
  - waf-policy
aliases:
  - WAF
  - Web Application Firewall
  - Azure WAF
created: 2026-02-07
updated: 2026-02-07
---

# Web Application Firewall (WAF)

> **AZ-700 Exam Domain 5.3** — Design and implement a Web Application Firewall (WAF) deployment

> [!info] Related Notes
> - [[Application_Gateway]] — WAF on Application Gateway (CRS 3.2 / DRS 2.1)
> - [[Azure_Front_Door]] — WAF on Front Door (DRS 2.1, Premium tier)
> - [[Azure_Firewall_and_Firewall_Manager]] — L3-L7 firewall (complementary to WAF)
> - [[NSG_ASG_Firewall]] — L3/L4 security (complementary to WAF L7)
> - [[DDoS_Protection]] — L3/L4 DDoS + WAF L7 = defense in depth

---

## Table of Contents

1. [Overview](#overview)
2. [Map WAF Requirements to Features](#map-waf-requirements-to-features)
3. [Design a WAF Deployment](#design-a-waf-deployment)
4. [Detection vs Prevention Mode](#detection-vs-prevention-mode)
5. [Rule Sets — Front Door (DRS)](#rule-sets--front-door-drs)
6. [Rule Sets — Application Gateway (CRS)](#rule-sets--application-gateway-crs)
7. [Comparison: Front Door WAF vs Application Gateway WAF](#comparison-front-door-waf-vs-application-gateway-waf)
8. [Implement a WAF Policy](#implement-a-waf-policy)
9. [Associate a WAF Policy](#associate-a-waf-policy)
10. [Custom Rules](#custom-rules)
11. [Exclusions](#exclusions)
12. [Bot Protection](#bot-protection)
13. [Rate Limiting](#rate-limiting)
14. [Tuning Workflow](#tuning-workflow)
15. [Exam Gotchas](#exam-gotchas)

---

## Overview

Azure WAF is a cloud-native web application firewall that protects web applications
from common exploits and vulnerabilities (OWASP Top 10). It can be deployed on:

| Platform | SKU Requirement | Rule-Set Family |
|---|---|---|
| **Azure Application Gateway** | WAF_v2 | OWASP CRS (3.1, 3.2) or DRS 2.1 |
| **Azure Front Door** | Premium (or Classic) tier | Microsoft Default Rule Set (DRS 2.1) |
| **Azure CDN** (from Microsoft) | Standard Microsoft | Limited WAF support |

> **Key fact**: Managed rule sets on Front Door are **only available in the Premium tier**
> (and legacy Classic tier). Front Door Standard does NOT support managed rules.

---

## Map WAF Requirements to Features

| Requirement | WAF Feature / Capability |
|---|---|
| Protect against OWASP Top 10 | Managed rule sets (DRS/CRS) |
| Block specific IPs or geo-regions | Custom rules (IP match, geo-match) |
| Throttle excessive requests | Rate-limiting custom rules |
| Prevent bot abuse | Bot Manager rule set |
| Override false positives | Exclusions (global or per-rule) |
| Separate policies per app | Per-site / per-listener / per-URI WAF policies |
| Monitor without blocking | Detection mode |
| Protect API payloads | JSON/XML body inspection |

---

## Design a WAF Deployment

### Decision Matrix

```
Internet → (Global L7?)
  ├── YES → Azure Front Door Premium + WAF
  │         ✔ Global anycast, caching, Private Link origins  
  │         ✔ DRS 2.1 managed rules, bot protection
  │
  └── NO → Regional L7?
        ├── YES → Application Gateway WAF_v2 + WAF policy
        │         ✔ Path-based routing, SSL offload
        │         ✔ CRS 3.2 / DRS 2.1, per-URI policies
        │
        └── CDN-only → Azure CDN (Microsoft) with basic WAF
```

### Architecture Considerations

- **Front Door + Application Gateway**: Can be combined. Front Door handles global
  load balancing and WAF at the edge; Application Gateway provides regional routing.
  In this scenario you typically enable WAF on **Front Door only** (or both, with
  tuned rule sets) to avoid double inspection overhead.
- **Application Gateway alone**: Single-region workloads with path-based routing needs.
- **Dedicated subnet**: Application Gateway requires its own subnet; WAF policy is
  a separate Azure resource from the gateway itself.

---

## Detection vs Prevention Mode

| Mode | Behavior | Use Case |
|---|---|---|
| **Detection** | Logs matched rules but does **not block** traffic | Initial deployment — observe traffic patterns, tune rules |
| **Prevention** | **Blocks** matched requests and logs them | Production protection after tuning |

> **Best practice**: Always start in **Detection mode** to analyze logs and identify
> false positives. Switch to **Prevention mode** only after tuning exclusions and
> disabling irrelevant rules.

**Logging difference (AppGW WAF engine)**:
- Previous engine: Detection mode logs action as "Detected"; Prevention mode logs
  custom-rule LOG actions as "Blocked" (misleading).
- New WAF engine (CRS 3.2+): Logs action as "Log" regardless of mode.

---

## Rule Sets — Front Door (DRS)

### Microsoft Default Rule Set (DRS 2.1)

- **Rule ID format**: `949xxx` (e.g., `949110`)
- **Scoring**: Anomaly scoring (DRS 2.0+)
- **Body inspection limit**: First **128 KB** of request body
- **Availability**: **Premium tier only** (and Classic tier)
- **Rule groups**: SQL injection, XSS, LFI, RFI, PHP attacks, Java attacks,
  session fixation, protocol enforcement, protocol anomalies

### Anomaly Scoring (DRS 2.0+)

| Rule Severity | Score Contribution |
|---|---|
| Critical | 5 |
| Error | 4 |
| Warning | 3 |
| Notice | 2 |

- **Threshold**: Score ≥ 5 triggers action (block in Prevention, log in Detection).
- Earlier DRS versions (1.x) block immediately per rule — no anomaly scoring.

### Front Door Custom Rules

- Processed **before** managed rules
- Lower priority number = higher priority (evaluated first)
- Actions: `Allow`, `Block`, `Log`, `Redirect`
- Match variables: RemoteAddr, RequestMethod, QueryString, PostArgs, RequestUri,
  RequestHeader, RequestBody, Cookies, SocketAddr

---

## Rule Sets — Application Gateway (CRS)

### Available Rule Sets

| Rule Set | Status | Key Features |
|---|---|---|
| **DRS 2.1** | Current default | Same as Front Door DRS, anomaly scoring |
| **CRS 3.2** | Supported | Per-rule exclusions, rate limiting, 2 MB body inspection |
| **CRS 3.1** | Supported (legacy) | Still usable, no per-rule exclusions |
| **CRS 3.0** | Deprecated | Cannot create new policies |
| **CRS 2.2.9** | Deprecated | Cannot be used with CRS 3.2/DRS 2.1 |

> **Exam tip**: CRS 2.2.9 and CRS 3.0 are **no longer supported for new WAF policies**.
> Microsoft recommends upgrading to DRS 2.1 or CRS 3.2.

### AppGW CRS Specifics

- **Rule ID format**: Standard OWASP IDs (e.g., `942270`)
- **Body inspection limit**: Up to **2 MB** (CRS 3.2+ on new WAF engine)
- **File upload limit**: Up to **4 GB** (CRS 3.2+ on new WAF engine)
- **Per-rule exclusions**: Available with CRS 3.2+ and Bot Manager 1.0+
- **Rate-limit custom rules**: Requires CRS 3.2 (new WAF engine)
- **Supported content types**: `application/json`, `application/xml`,
  `application/x-www-form-urlencoded`, `multipart/form-data`

---

## Comparison: Front Door WAF vs Application Gateway WAF

| Feature | Front Door WAF | Application Gateway WAF |
|---|---|---|
| **Scope** | Global (anycast edge) | Regional (single VNet) |
| **SKU required** | Premium (managed rules) | WAF_v2 |
| **Default rule set** | DRS 2.1 | DRS 2.1 or CRS 3.2 |
| **Rule ID format** | `949xxx` | OWASP `9xxxxx` (e.g., `942270`) |
| **Body inspection** | 128 KB | 2 MB (CRS 3.2+) |
| **File upload limit** | — | 4 GB (CRS 3.2+) |
| **Anomaly scoring** | DRS 2.0+ | CRS 3.x / DRS 2.1 |
| **Per-rule exclusions** | Yes | Yes (CRS 3.2+) |
| **Rate limiting** | Yes (custom rules) | Yes (custom rules, CRS 3.2+) |
| **Bot protection** | Yes (Bot Manager rule set) | Yes (Bot Manager rule set) |
| **Policy scope** | Per Front Door profile or per domain | Global, per-site, per-listener, **per-URI** |
| **Geo-filtering** | Custom rules (geo-match) | Custom rules (geo-match) |
| **Private Link origins** | Yes | N/A (takes VNet backends) |

---

## Implement a WAF Policy

A WAF policy is a **standalone Azure resource** (`Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies` or `Microsoft.Network/FrontDoorWebApplicationFirewallPolicies`).

### WAF Policy Components

```
WAF Policy
├── Managed Rules
│   ├── Rule set selection (DRS 2.1 / CRS 3.2)
│   ├── Rule overrides (disable/enable individual rules)
│   └── Per-rule exclusions
├── Custom Rules
│   ├── Match conditions (IP, geo, header, body, etc.)
│   ├── Priority (lower number = higher priority)
│   └── Action (Allow / Block / Log / Redirect / Rate-limit)
├── Exclusions (global)
│   └── Match variable, operator, selector
├── Policy Settings
│   ├── Mode (Detection / Prevention)
│   ├── Request body inspection (on/off)
│   ├── Max request body size
│   └── File upload limit
└── Bot Manager Rule Set (optional)
```

### Bicep Example (Application Gateway WAF Policy)

```bicep
resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2024-01-01' = {
  name: 'waf-policy-01'
  location: resourceGroup().location
  properties: {
    policySettings: {
      mode: 'Prevention'
      state: 'Enabled'
      requestBodyCheck: true
      maxRequestBodySizeInKb: 128
      fileUploadLimitInMb: 100
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
        }
      ]
    }
    customRules: [
      {
        name: 'BlockBadIPs'
        priority: 1
        ruleType: 'MatchRule'
        action: 'Block'
        matchConditions: [
          {
            matchVariables: [
              { variableName: 'RemoteAddr' }
            ]
            operator: 'IPMatch'
            matchValues: [ '203.0.113.0/24' ]
          }
        ]
      }
    ]
  }
}
```

---

## Associate a WAF Policy

### Application Gateway Association Levels

| Scope | Applies To | Inheritance |
|---|---|---|
| **Global** | Entire Application Gateway | All listeners and path rules inherit |
| **Per-site (per-listener)** | Specific HTTP listener | Overrides global for that listener |
| **Per-URI (path-based rule)** | Specific path in URL path map | Overrides listener and global for that path |

> **Priority**: Per-URI policy > Per-listener policy > Global policy

```bicep
// Associate at the Application Gateway level
resource appGw 'Microsoft.Network/applicationGateways@2024-01-01' = {
  // ...
  properties: {
    firewallPolicy: {
      id: wafPolicy.id   // Global association
    }
    httpListeners: [
      {
        properties: {
          firewallPolicy: {
            id: listenerWafPolicy.id  // Per-listener override
          }
        }
      }
    ]
  }
}
```

### Front Door Association

WAF policies are associated **per Front Door profile** or **per custom domain** (endpoint).

```bicep
resource fdSecurityPolicy 'Microsoft.Cdn/profiles/securityPolicies@2024-02-01' = {
  parent: frontDoorProfile
  name: 'waf-security-policy'
  properties: {
    parameters: {
      type: 'WebApplicationFirewall'
      wafPolicy: {
        id: fdWafPolicy.id
      }
      associations: [
        {
          domains: [
            { id: customDomain.id }
          ]
          patternsToMatch: [ '/*' ]
        }
      ]
    }
  }
}
```

---

## Custom Rules

Custom rules are evaluated **before** managed rule sets.

### Rule Processing Order

```
Request arrives
  → Custom rules (priority order, lowest number first)
      → If match: Apply action (Allow/Block/Log/Redirect)
      → Stop processing other custom rules
  → Managed rules (if no custom rule matched with terminal action)
      → Anomaly scoring accumulates
      → If score ≥ 5: Block (Prevention) or Log (Detection)
```

### Common Custom Rule Scenarios

| Scenario | Match Variable | Operator |
|---|---|---|
| Block IP range | `RemoteAddr` | `IPMatch` |
| Geo-block countries | `RemoteAddr` | `GeoMatch` |
| Block User-Agent | `RequestHeaders['User-Agent']` | `Contains` |
| Allow specific path | `RequestUri` | `BeginsWith` |
| Rate limit login page | `RequestUri` + Rate setting | `BeginsWith` |

---

## Exclusions

Use exclusions to prevent false positives without disabling entire rules.

### Scope Levels

| Scope | Description |
|---|---|
| **Global** | Applies across all managed rules |
| **Per-rule set** | Applies to a specific rule set (e.g., OWASP 3.2) |
| **Per-rule group** | Applies to a rule group (e.g., `REQUEST-942-APPLICATION-ATTACK-SQLI`) |
| **Per-rule** | Applies to a single rule (e.g., rule `942270`). Requires CRS 3.2+ |

### Match Variables for Exclusions

- `RequestHeaderNames` / `RequestHeaderValues`
- `RequestCookieNames` / `RequestCookieValues`
- `RequestArgNames` / `RequestArgValues` (query string)
- `RequestBodyPostArgNames` / `RequestBodyPostArgValues`
- `RequestBodyJsonArgNames` / `RequestBodyJsonArgValues`

### Operators

`Equals`, `StartsWith`, `EndsWith`, `Contains`, `EqualsAny`

> **Best practice**: Make exclusions as narrow as possible — prefer **per-rule** exclusions
> over global exclusions.

---

## Bot Protection

The **Bot Manager rule set** classifies bots into categories:

| Category | Examples | Default Action |
|---|---|---|
| Good bots | Googlebot, Bingbot, monitoring tools | Allow |
| Bad bots | Scrapers, vulnerability scanners, spam bots | Block |
| Unknown bots | Unclassified automated agents | Log |

- Available on both Application Gateway WAF and Front Door WAF
- Requires CRS 3.2+ or DRS 2.0+ (new WAF engine) on Application Gateway
- Actions per bot rule: `Allow`, `Block`, `Log`

---

## Rate Limiting

Rate limiting is implemented via **custom rules** with `RateLimitRule` type.

### AppGW Rate Limiting

| Setting | Description |
|---|---|
| **Threshold** | Max requests allowed per time window |
| **Time window** | 1 minute or 5 minutes |
| **GroupByUserSession** | How requests are grouped for counting |
| **Match condition** | When to activate the rate limit |

### GroupByVariables

| Variable | Behavior |
|---|---|
| `ClientAddr` | Per source IP (default) |
| `GeoLocation` | Per geographic region |
| `None` | All traffic counted together |
| `ClientAddrXFFHeader` | Per IP from X-Forwarded-For header |
| `GeoLocationXFFHeader` | Per geo from X-Forwarded-For header |

> **Requirement**: Rate limit rules require **CRS 3.2** (new WAF engine). Not supported
> in air-gapped clouds.

### Rate Limiting Algorithm

- Uses **sliding window** algorithm
- First window breach: All additional matching traffic dropped
- Subsequent windows: Up to threshold allowed (throttling effect)

---

## Tuning Workflow

```
1. Deploy WAF in DETECTION mode
   │
2. Review diagnostic logs (WAF logs / Access logs)
   │ Identify false positives
   │
3. Create EXCLUSIONS for legitimate traffic
   │ - Per-rule exclusions (preferred, narrowest scope)
   │ - Global exclusions (broader, use sparingly)
   │
4. DISABLE individual rules that don't apply
   │ (e.g., PHP rules for a .NET application)
   │
5. Create CUSTOM RULES for application-specific protection
   │ (IP blocks, geo-filtering, rate limiting)
   │
6. Switch to PREVENTION mode
   │
7. Continuously monitor and refine
```

---

## Exam Gotchas

### 1. Front Door Standard Does NOT Support Managed Rules
Only Front Door **Premium** tier (and legacy Classic) supports managed rule sets.
Standard tier supports custom rules only.

### 2. Body Inspection Limits Differ Significantly
- Front Door: **128 KB** — requests larger than this are not inspected by managed rules
- AppGW (CRS 3.2+): **2 MB** body inspection, **4 GB** file upload

### 3. CRS vs DRS Rule ID Formats
- AppGW CRS rules use OWASP IDs: `942270`, `942100`, etc.
- Front Door DRS rules use `949xxx` format: `949110`, etc.
- Don't confuse them on the exam!

### 4. Custom Rules Execute BEFORE Managed Rules
If a custom rule matches with `Allow`, the request skips **all** managed rules.
This is a common exam scenario — an `Allow` custom rule effectively bypasses WAF.

### 5. WAF Policy Is a Separate Resource
The WAF policy is NOT part of the Application Gateway or Front Door resource.
It's a standalone resource that gets **associated** to the gateway/profile.

### 6. Per-URI Policy Overrides Per-Listener
Application Gateway supports three levels of WAF policy association:
Per-URI > Per-listener > Global (most specific wins).

### 7. Anomaly Scoring Threshold = 5
A single **Critical** rule match (score = 5) is enough to block in Prevention mode.
Two **Warning** matches (3 + 3 = 6) will also trigger a block.

### 8. Deprecated Rule Sets
CRS 2.2.9 and CRS 3.0 cannot be used for **new** WAF policies. You cannot combine
CRS 2.2.9 with CRS 3.2 or DRS 2.1 in the same policy.

### 9. Rate Limiting Requires CRS 3.2
Rate limit custom rules on Application Gateway only work with the **new WAF engine**
(CRS 3.2 selected). They do not work with CRS 3.1 or older.

### 10. WAF + DDoS Protection Are Complementary
WAF protects at Layer 7 (HTTP/HTTPS); DDoS Protection protects at Layer 3/4.
Enable **both** on the VNet and Application Gateway for defense in depth.

---

## References

- [WAF on Application Gateway overview](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/ag-overview)
- [WAF on Front Door overview](https://learn.microsoft.com/en-us/azure/web-application-firewall/afds/afds-overview)
- [DRS and CRS rule groups and rules](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/application-gateway-crs-rulegroups-rules)
- [WAF policy overview (Application Gateway)](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/policy-overview)
- [WAF exclusion lists](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/application-gateway-waf-configuration)
- [Rate limiting on Application Gateway WAF](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/rate-limiting-overview)
- [WAF engine features](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/waf-engine)
- [Bot protection (Application Gateway)](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/bot-protection)
