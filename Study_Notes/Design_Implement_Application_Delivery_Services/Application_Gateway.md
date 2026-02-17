---
tags:
  - AZ-700
  - azure/networking
  - domain/app-delivery
  - application-gateway
  - layer7
  - waf
  - ssl-termination
  - path-based-routing
  - multi-site
  - url-rewrite
  - autoscaling
  - health-probe
aliases:
  - Application Gateway
  - AppGW
  - Azure Application Gateway
created: 2025-01-01
updated: 2026-02-07
---

# Azure Application Gateway

> [!info] Related Notes
> - [[WAF]] — Dedicated WAF deep-dive (CRS/DRS rule sets, policies, exclusions)
> - [[Azure_Front_Door]] — Global L7 alternative with edge WAF
> - [[Azure_Load_Balancer]] — L4 load balancing (backend to AppGW)
> - [[Traffic_Manager]] — DNS-based routing in front of AppGW
> - [[NSG_ASG_Firewall]] — NSG rules on AppGW subnet (GatewayManager ports)
> - [[DDoS_Protection]] — Defense in depth with AppGW WAF
> - [[Private_Endpoints]] — Private frontend for internal applications

## Overview

Azure Application Gateway is a Layer 7 (HTTP/HTTPS) load balancer that provides application-level routing, SSL termination, and Web Application Firewall (WAF) capabilities. It's designed specifically for web application traffic.

### Key Concepts

| Concept | Description |
| --- | --- |
| **Frontend IP** | Public and/or private IP receiving traffic |
| **Listener** | Receives incoming requests (port, protocol, host) |
| **Backend Pool** | VMs, VMSS, App Services, or IP addresses |
| **HTTP Settings** | Backend connection config (port, protocol, affinity) |
| **Routing Rule** | Connects listener to backend pool + HTTP settings |
| **Health Probe** | Checks backend health (HTTP/HTTPS) |
| **WAF** | Web Application Firewall (optional) |

---

## Request Lifecycle (How Traffic Flows)

1. **DNS resolves** to the public/private frontend IP.
2. **Listener match** occurs based on protocol, port, and (optionally) host header/SNI.
3. **Rule evaluation** selects either a basic rule or a path-based rule.
4. **Rewrite/redirect** rules run (if configured).
5. **Backend selection** occurs from the target pool (healthy instances only).
6. **HTTP settings** determine port, protocol, cookie affinity, and timeout for the backend.
7. **Health probes** continuously evaluate backend health; unhealthy instances are removed.

Why it matters: most troubleshooting is about **listener match**, **health probe config**, or **host header** mismatches.

---

## TLS Termination Models (SSL Strategy)

| Model | Client → AppGW | AppGW → Backend | When to Use | Considerations |
| --- | --- | --- | --- | --- |
| **SSL Offload** | HTTPS | HTTP | Reduce backend CPU, simplify certs | Traffic is unencrypted inside VNet |
| **End-to-End SSL** | HTTPS | HTTPS | Compliance, zero-trust, sensitive data | Requires backend certs + trusted root on AppGW |
| **TLS Bridging** | HTTPS | HTTPS | Common variant of end-to-end | Allows inspection/re-encrypt with separate certs |

Notes:

- Use **SNI** for multi-site HTTPS listeners.
- Store certificates in **Key Vault** for managed lifecycle where possible.

---

## Backend Settings & Health Probes (Deep Dive)

### Backend HTTP Settings

- **Host header**: Use “Pick hostname from backend target” for App Service or FQDN backends.
- **Cookie-based affinity**: Enables session stickiness (ARRAffinity cookie).
- **Connection draining**: Graceful shutdown for instances during scale-in or maintenance.
- **Custom trusted root**: Required for HTTPS backends with private CA certificates.

### Health Probes

- Prefer **custom probes** for non-root endpoints (e.g., `/health`), especially for App Service.
- Ensure **probe host** matches backend expectation (Host header problems are common).
- Tune **interval/timeout** to avoid false negatives under load.

---

## WAF (Web Application Firewall) – Practical Analysis

### Operating Modes

- **Detection**: Logs threats, does not block (good for baseline tuning).
- **Prevention**: Blocks matching requests (production once tuned).

### Key WAF Tuning Actions

- Use **exclusions** for known-safe parameters to reduce false positives.
- Create **custom rules** for IP allow/deny lists and rate limiting.
- Monitor **WAF logs** to identify noisy rules and refine policies.

### Common WAF Pitfalls

- Blocking legitimate API requests due to JSON payloads or encoded data.
- Forgetting to enable WAF policy association at the listener/rule level.

---

## Observability & Troubleshooting

Enable **Diagnostics** and send to Log Analytics:

- **Access logs** (request/response details)
- **Performance logs** (latency, throughput, failed requests)
- **WAF logs** (rule matches and actions)

Quick triage checklist:

1. Is the **listener** matched (port/host)?
2. Are **backend health probes** succeeding?
3. Are **NSG/UDR** rules blocking backend connectivity?
4. Are **rewrite/redirect** rules affecting routing?

---

## Design Considerations (Exam-Relevant)

### Networking

- **Dedicated subnet only** for App Gateway.
- **Standard Public IP** required for v2.
- For **internal-only apps**, use a private frontend IP.

### Scalability & Resilience

- **Autoscale** adjusts instance count based on load.
- **Zone redundancy** improves availability (requires multiple instances).

### Security

- Use **end-to-end TLS** for sensitive workloads.
- Combine **WAF** with **custom rules** to tailor protection.

---

## AZ-700 Decision Guide (When to Use Application Gateway)

Application Gateway is the **regional** choice when the requirement is **HTTP(S) L7 routing inside/into a VNet**.

Use **Application Gateway** when you need:

- **Private frontend IP** (internal-only entry point)
- **Path-based routing** (e.g., `/api/*` to one pool)
- **Multi-site hosting** with host headers / SNI
- **Regional WAF** in front of web apps/APIs
- Tight **VNet integration** for private backends

Prefer other services when requirements differ:

| Requirement | Better Fit | Why |
| --- | --- | --- |
| Global anycast entry, edge acceleration, instant global failover | **Azure Front Door** | Global layer with WAF/CDN features; AppGW is regional |
| Non-HTTP traffic (TCP/UDP), pure L4 balancing | **Azure Load Balancer** | AppGW is HTTP(S)-only |
| DNS-based failover / geo routing without proxying traffic | **Traffic Manager** | DNS answers change; clients connect directly to endpoints |
| Deep packet inspection / third-party firewalling | **NVA** | AppGW WAF is HTTP-focused (OWASP) |

Exam framing: AppGW often appears as the **regional ingress** component, paired with **Front Door or Traffic Manager** for multi-region designs.

---

## Common Reference Architectures (Exam Patterns)

### Global-to-Regional Pattern (Front Door → AppGW)

```text
Client
  |
  v
Azure Front Door (global WAF/routing)
  |
  v
Application Gateway (per region, VNet ingress)
  |
  v
Private backends (VMSS / AKS / App Service via private endpoints)
```

Typical reasons the exam chooses this:

- **Global entry** with geo-routing plus **regional private backends**
- Centralized WAF at edge plus **regional WAF** for defense-in-depth

### Multi-Region Active/Active (Traffic Manager → AppGW)

```text
Client DNS query
  |
  v
Traffic Manager (DNS-based geo/perf/priority)
  |
  +--> Region A: AppGW → Backends
  |
  +--> Region B: AppGW → Backends
```

Typical reasons:

- DNS-level failover and region choice, with **identical ingress stacks per region**

### Hub-and-Spoke Ingress (Enterprise VNet)

- Place AppGW in a **hub VNet** and route to spoke backends over **VNet peering**.
- Validate **UDR/NSG** doesn’t block health probes and backend traffic.
- Ensure name resolution works for FQDN backends (DNS is a common hidden dependency).

---

## Troubleshooting Playbook (AZ-700 Style)

In exam questions, the fastest way to the correct answer is mapping **symptom → component → likely root cause**.

| Symptom | Likely Root Cause | What to Check | Typical Fix |
| --- | --- | --- | --- |
| **502 Bad Gateway** | Backend marked unhealthy | Backend health/probes, NSG/UDR, backend TLS trust | Fix probe path/host, allow traffic, add trusted root, correct backend settings |
| Backend shows **Unhealthy** | Probe endpoint/host mismatch | Probe host header, path, protocol | Configure custom probe (`/health`) and correct host header |
| **403** with WAF enabled | WAF rule matched | WAF logs, rule ID/message | Start in Detection, add exclusions, then switch to Prevention |
| Works by IP, fails by hostname | Listener/rule mismatch on host header | Listener host name, multi-site config, SNI/cert | Configure multi-site listener + correct cert, validate DNS |
| Intermittent errors during scale-in | Connections dropped | Connection draining, backend timeouts | Enable draining, tune timeouts, validate app readiness |
| Redirect loop (HTTP↔HTTPS) | Conflicting rewrite/redirect rules | Redirect config + app redirects | Implement single source of truth (gateway or app) |

Log signal mapping (what the exam expects you to use):

- **Access logs**: did the request reach the gateway and which rule fired?
- **Performance logs**: where is latency building (frontend vs backend)?
- **WAF logs**: which rule blocked/flagged the request?

---

## AZ-700 Gotchas (Frequently Tested)

- **Multi-site HTTPS needs SNI + correct certificate**; wrong host/cert often looks like “site not found”.
- **App Service backends** commonly need correct host header behavior (“pick hostname from backend”).
- **Health probes** are not “set and forget”; wrong host/path is the #1 cause of 502s.
- **WAF tuning**: Detection → tune exclusions → Prevention is the safe path.

---

## Architecture Diagram

```text
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      Application Gateway Architecture                            │
│                                                                                  │
│                              INTERNET                                            │
│                                  │                                               │
│                                  ▼                                               │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                        APPLICATION GATEWAY                                 │  │
│  │                       (Dedicated Subnet)                                   │  │
│  │                                                                            │  │
│  │   ┌─────────────────────────────────────────────────────────────────────┐ │  │
│  │   │                      FRONTEND                                        │ │  │
│  │   │   Public IP: 52.x.x.x    Private IP: 10.0.0.100                     │ │  │
│  │   └─────────────────────────────────────────────────────────────────────┘ │  │
│  │                              │                                             │  │
│  │   ┌─────────────────────────────────────────────────────────────────────┐ │  │
│  │   │                      LISTENERS                                       │ │  │
│  │   │                                                                      │ │  │
│  │   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────────┐  │ │  │
│  │   │  │ HTTP (80)   │  │ HTTPS (443) │  │ Multi-site: api.contoso.com │  │ │  │
│  │   │  │ Basic       │  │ + SSL Cert  │  │ www.contoso.com             │  │ │  │
│  │   │  └─────────────┘  └─────────────┘  └─────────────────────────────┘  │ │  │
│  │   └─────────────────────────────────────────────────────────────────────┘ │  │
│  │                              │                                             │  │
│  │   ┌─────────────────────────────────────────────────────────────────────┐ │  │
│  │   │                    ROUTING RULES                                     │ │  │
│  │   │                                                                      │ │  │
│  │   │   /api/*    → API Backend Pool                                      │ │  │
│  │   │   /images/* → Static Backend Pool                                   │ │  │
│  │   │   /*        → Web Backend Pool (default)                            │ │  │
│  │   └─────────────────────────────────────────────────────────────────────┘ │  │
│  │                              │                                             │  │
│  │   ┌─────────────────────────────────────────────────────────────────────┐ │  │
│  │   │                    WAF (Optional)                                    │ │  │
│  │   │   Mode: Prevention    Rules: OWASP 3.2                              │ │  │
│  │   │   Custom Rules: Block specific IPs, rate limiting                   │ │  │
│  │   └─────────────────────────────────────────────────────────────────────┘ │  │
│  └───────────────────────────────────────────────────────────────────────────┘  │
│                              │                                                   │
│           ┌──────────────────┼──────────────────┐                               │
│           ▼                  ▼                  ▼                               │
│    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                       │
│    │ WEB POOL    │    │ API POOL    │    │STATIC POOL  │                       │
│    │             │    │             │    │             │                       │
│    │ VM1  VM2   │    │ App Service │    │ Storage     │                       │
│    │             │    │             │    │ Account     │                       │
│    └─────────────┘    └─────────────┘    └─────────────┘                       │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Application Gateway SKUs

### SKU Comparison

| Feature | Standard v2 | WAF v2 |
| --- | --- | --- |
| **Layer 7 Load Balancing** | ✅ | ✅ |
| **SSL Termination** | ✅ | ✅ |
| **URL-based Routing** | ✅ | ✅ |
| **Multi-site Hosting** | ✅ | ✅ |
| **Autoscaling** | ✅ | ✅ |
| **Zone Redundancy** | ✅ | ✅ |
| **WAF** | ❌ | ✅ |
| **Bot Protection** | ❌ | ✅ |
| **Cost** | Lower | Higher |

**Note**: v1 SKUs (Standard, WAF) are deprecated - use v2 only

### Autoscaling vs Manual

| Mode | When to Use |
| --- | --- |
| **Autoscale** | Variable traffic, pay for what you use |
| **Manual** | Predictable traffic, fixed capacity |

---

## Key Features

### URL Path-Based Routing

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                    URL Path-Based Routing                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   Incoming Request                                                       │
│        │                                                                 │
│        ▼                                                                 │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                     PATH MAP                                     │   │
│   │                                                                  │   │
│   │   /api/*        ──────────►  API Backend Pool                   │   │
│   │   /api/v2/*     ──────────►  API v2 Backend Pool                │   │
│   │   /images/*     ──────────►  Storage Backend Pool               │   │
│   │   /video/*      ──────────►  Media Backend Pool                 │   │
│   │   /*            ──────────►  Default Web Pool                   │   │
│   │   (default)                                                      │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│   Example:                                                              │
│   https://app.contoso.com/api/users → API Backend Pool                 │
│   https://app.contoso.com/images/logo.png → Storage Backend Pool       │
│   https://app.contoso.com/about → Default Web Pool                     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Multi-Site Hosting

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                    Multi-Site Hosting                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   Single Application Gateway, Multiple Sites                            │
│                                                                          │
│   ┌────────────────────────────────────────────────────────────────┐    │
│   │                    LISTENERS                                    │    │
│   │                                                                 │    │
│   │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐│    │
│   │  │ www.contoso.com │  │ api.contoso.com │  │ admin.contoso   ││    │
│   │  │ (Host Header)   │  │ (Host Header)   │  │ .com            ││    │
│   │  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘│    │
│   │           │                    │                    │         │    │
│   └───────────┼────────────────────┼────────────────────┼─────────┘    │
│               │                    │                    │              │
│               ▼                    ▼                    ▼              │
│        ┌─────────────┐      ┌─────────────┐      ┌─────────────┐      │
│        │  Web Pool   │      │  API Pool   │      │ Admin Pool  │      │
│        └─────────────┘      └─────────────┘      └─────────────┘      │
│                                                                          │
│   Benefits:                                                             │
│   • Single public IP for multiple sites                                │
│   • Separate SSL certificates per site                                 │
│   • Independent backend pools                                          │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Rewrite Rules

| Rewrite Type | Use Case |
| --- | --- |
| **Request Header** | Add/modify headers to backend |
| **Response Header** | Remove server info, add security headers |
| **URL Rewrite** | Change URL path before routing |
| **URL Redirect** | HTTP to HTTPS, old URLs to new |

---

## Configuration Best Practices

### Create Application Gateway

```powershell
# Create dedicated subnet (minimum /26, recommended /24)
$vnet = Get-AzVirtualNetwork -Name "vnet-prod" -ResourceGroupName "rg-networking"
Add-AzVirtualNetworkSubnetConfig `
    -Name "snet-appgw" `
    -VirtualNetwork $vnet `
    -AddressPrefix "10.0.10.0/24"
$vnet | Set-AzVirtualNetwork

# Create public IP
$pip = New-AzPublicIpAddress `
    -Name "pip-appgw" `
    -ResourceGroupName "rg-appgw" `
    -Location "uksouth" `
    -Sku "Standard" `
    -AllocationMethod "Static"

# Create gateway IP configuration
$vnet = Get-AzVirtualNetwork -Name "vnet-prod" -ResourceGroupName "rg-networking"
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "snet-appgw" -VirtualNetwork $vnet
$gwIpConfig = New-AzApplicationGatewayIPConfiguration `
    -Name "appgw-ipconfig" `
    -Subnet $subnet

# Create frontend IP configuration
$fipConfig = New-AzApplicationGatewayFrontendIPConfig `
    -Name "appgw-frontend" `
    -PublicIPAddress $pip

# Create frontend port
$frontendPort = New-AzApplicationGatewayFrontendPort `
    -Name "port-443" `
    -Port 443

# Create backend pool
$backendPool = New-AzApplicationGatewayBackendAddressPool `
    -Name "pool-web" `
    -BackendIPAddresses "10.0.1.4", "10.0.1.5"

# Create backend HTTP settings
$backendSettings = New-AzApplicationGatewayBackendHttpSetting `
    -Name "http-settings" `
    -Port 80 `
    -Protocol "Http" `
    -CookieBasedAffinity "Enabled" `
    -RequestTimeout 30

# Create health probe
$probe = New-AzApplicationGatewayProbeConfig `
    -Name "probe-http" `
    -Protocol "Http" `
    -HostName "localhost" `
    -Path "/health" `
    -Interval 30 `
    -Timeout 30 `
    -UnhealthyThreshold 3

# Create SSL certificate
$cert = New-AzApplicationGatewaySslCertificate `
    -Name "ssl-cert" `
    -CertificateFile "C:\certs\appgw.pfx" `
    -Password (ConvertTo-SecureString "CertPassword123!" -AsPlainText -Force)

# Create HTTPS listener
$listener = New-AzApplicationGatewayHttpListener `
    -Name "listener-https" `
    -FrontendIPConfiguration $fipConfig `
    -FrontendPort $frontendPort `
    -Protocol "Https" `
    -SslCertificate $cert

# Create routing rule
$rule = New-AzApplicationGatewayRequestRoutingRule `
    -Name "rule-web" `
    -RuleType "Basic" `
    -Priority 100 `
    -HttpListener $listener `
    -BackendAddressPool $backendPool `
    -BackendHttpSettings $backendSettings

# Create Application Gateway
$sku = New-AzApplicationGatewaySku -Name "Standard_v2" -Tier "Standard_v2"
$autoscale = New-AzApplicationGatewayAutoscaleConfiguration -MinCapacity 2 -MaxCapacity 10

New-AzApplicationGateway `
    -Name "appgw-prod" `
    -ResourceGroupName "rg-appgw" `
    -Location "uksouth" `
    -Sku $sku `
    -AutoscaleConfiguration $autoscale `
    -GatewayIPConfigurations $gwIpConfig `
    -FrontendIPConfigurations $fipConfig `
    -FrontendPorts $frontendPort `
    -BackendAddressPools $backendPool `
    -BackendHttpSettingsCollection $backendSettings `
    -HttpListeners $listener `
    -RequestRoutingRules $rule `
    -Probes $probe `
    -SslCertificates $cert
```

### Configure URL Path-Based Routing

```powershell
# Create path rule for API
$apiPathRule = New-AzApplicationGatewayPathRuleConfig `
    -Name "api-rule" `
    -Paths "/api/*" `
    -BackendAddressPool $apiPool `
    -BackendHttpSettings $apiSettings

# Create path rule for images
$imagesPathRule = New-AzApplicationGatewayPathRuleConfig `
    -Name "images-rule" `
    -Paths "/images/*" `
    -BackendAddressPool $storagePool `
    -BackendHttpSettings $storageSettings

# Create URL path map
$urlPathMap = New-AzApplicationGatewayUrlPathMapConfig `
    -Name "url-path-map" `
    -PathRules $apiPathRule, $imagesPathRule `
    -DefaultBackendAddressPool $webPool `
    -DefaultBackendHttpSettings $webSettings

# Create path-based routing rule
$pathRule = New-AzApplicationGatewayRequestRoutingRule `
    -Name "rule-path-based" `
    -RuleType "PathBasedRouting" `
    -Priority 100 `
    -HttpListener $listener `
    -UrlPathMap $urlPathMap
```

### Configure HTTP to HTTPS Redirect

```powershell
# Create redirect configuration
$redirectConfig = New-AzApplicationGatewayRedirectConfiguration `
    -Name "http-to-https" `
    -RedirectType "Permanent" `
    -TargetListener $httpsListener `
    -IncludePath $true `
    -IncludeQueryString $true

# Create routing rule for redirect
$redirectRule = New-AzApplicationGatewayRequestRoutingRule `
    -Name "rule-redirect" `
    -RuleType "Basic" `
    -Priority 200 `
    -HttpListener $httpListener `
    -RedirectConfiguration $redirectConfig
```

---

## Exam Tips & Gotchas

### Critical Points (Commonly Tested)

- **Dedicated subnet required** — minimum /26 for v2, /28 for v1
- **No NSG on AppGw subnet** — or allow AppGW management ports (65200-65535)
- **v2 supports autoscaling** — v1 does not
- **SSL termination at gateway** — backend can use HTTP
- **End-to-end SSL** — reencrypt traffic to backend
- **Cookie-based affinity** — ARRAffinity cookie for session persistence
- **WAF_v2 for security** — OWASP rules, bot protection

### Exam Scenarios

| Scenario | Solution |
| --- | --- |
| Route /api/* to API servers | URL path-based routing |
| Host multiple sites on one IP | Multi-site listeners with host headers |
| Redirect HTTP to HTTPS | Redirect configuration |
| Protect against SQL injection | WAF with OWASP rules |
| Route based on client location | Use with Traffic Manager (TM → AppGW per region) |
| Internal-only web apps | Private frontend IP only |
| Add security headers | Rewrite rules on response |

### Common Gotchas

1. **Subnet can't have other resources** — only App Gateway instances
2. **NSG must allow 65200-65535 inbound** — AppGW v2 management
3. **Backend pool can include App Services** — use FQDN, enable "Pick hostname from backend"
4. **Custom health probe needed for App Services** — default probe may fail
5. **Autoscale min=2 for zone redundancy** — single instance = no HA

---

## Comparison Tables

### Application Gateway vs Front Door

| Feature | Application Gateway | Azure Front Door |
| --- | --- | --- |
| **Scope** | Regional | Global |
| **Deployment** | In VNet | Edge (POP) |
| **Private backends** | ✅ (VNet) | Via Private Link |
| **WAF** | ✅ WAF v2 | ✅ WAF |
| **Caching** | ❌ | ✅ (CDN) |
| **SSL Offload** | ✅ | ✅ |
| **URL Routing** | ✅ | ✅ |
| **Autoscaling** | ✅ | Built-in |
| **WebSocket** | ✅ | ✅ |

---

## Hands-On Lab Suggestions

### Lab: Deploy Application Gateway with WAF

```powershell
# 1. Create resource group
New-AzResourceGroup -Name "rg-appgw-lab" -Location "uksouth"

# 2. Create VNet with AppGW subnet
$appgwSubnet = New-AzVirtualNetworkSubnetConfig -Name "snet-appgw" -AddressPrefix "10.0.0.0/24"
$backendSubnet = New-AzVirtualNetworkSubnetConfig -Name "snet-backend" -AddressPrefix "10.0.1.0/24"

$vnet = New-AzVirtualNetwork `
    -Name "vnet-appgw-lab" `
    -ResourceGroupName "rg-appgw-lab" `
    -Location "uksouth" `
    -AddressPrefix "10.0.0.0/16" `
    -Subnet $appgwSubnet, $backendSubnet

# 3. Create public IP
$pip = New-AzPublicIpAddress -Name "pip-appgw" -ResourceGroupName "rg-appgw-lab" `
    -Location "uksouth" -Sku "Standard" -AllocationMethod "Static"

# 4. Create WAF policy
$wafPolicy = New-AzApplicationGatewayFirewallPolicy `
    -Name "waf-policy" `
    -ResourceGroupName "rg-appgw-lab" `
    -Location "uksouth"

# 5. Create Application Gateway with WAF_v2 SKU
# (Use detailed commands from above with WAF_v2 SKU)

# 6. Test WAF by sending attack patterns
# curl "https://<appgw-ip>/?id=1' OR 1=1--"  # Should be blocked
```

---

## Draw.io Diagram

```xml
<mxfile host="app.diagrams.net">
  <diagram name="Application Gateway" id="appgw-arch">
    <mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1169" pageHeight="827" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <mxCell id="internet" value="Internet" style="ellipse;shape=cloud;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;" vertex="1" parent="1">
          <mxGeometry x="400" y="20" width="120" height="60" as="geometry" />
        </mxCell>
        <mxCell id="appgw" value="Application Gateway v2&#xa;&#xa;• SSL Termination&#xa;• URL Routing&#xa;• WAF (Optional)&#xa;• Autoscaling" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
          <mxGeometry x="320" y="140" width="280" height="120" as="geometry" />
        </mxCell>
        <mxCell id="listener" value="Listeners&#xa;HTTPS :443&#xa;HTTP :80 (redirect)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="1">
          <mxGeometry x="600" y="160" width="120" height="60" as="geometry" />
        </mxCell>
        <mxCell id="webpool" value="Web Pool&#xa;VMs / App Service" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="200" y="340" width="120" height="60" as="geometry" />
        </mxCell>
        <mxCell id="apipool" value="API Pool&#xa;/api/*" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="400" y="340" width="120" height="60" as="geometry" />
        </mxCell>
        <mxCell id="staticpool" value="Static Pool&#xa;/images/*" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="600" y="340" width="120" height="60" as="geometry" />
        </mxCell>
        <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="internet" target="appgw">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e2" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="appgw" target="webpool">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e3" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="appgw" target="apipool">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e4" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="appgw" target="staticpool">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```
