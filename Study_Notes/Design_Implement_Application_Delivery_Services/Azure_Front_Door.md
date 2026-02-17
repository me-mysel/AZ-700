---
tags:
  - AZ-700
  - azure/networking
  - domain/app-delivery
  - front-door
  - global-load-balancing
  - cdn
  - waf
  - ssl-offload
  - rules-engine
  - caching
  - private-link-origin
  - anycast
aliases:
  - Azure Front Door
  - AFD
  - Front Door
created: 2025-01-01
updated: 2026-02-07
---

# Azure Front Door

> [!info] Related Notes
> - [[WAF]] — WAF on Front Door (DRS 2.1, Premium tier required)
> - [[Application_Gateway]] — Regional L7 alternative or backend to Front Door
> - [[Traffic_Manager]] — DNS-only global routing alternative
> - [[Private_Link_Service]] — Private Link origins for Front Door Premium
> - [[DDoS_Protection]] — Built-in DDoS at the edge
> - [[Azure_DNS]] — Custom domain and CNAME configuration

## Overview

Azure Front Door is a global, scalable entry point for web applications. It provides Layer 7 load balancing, SSL offloading, caching (CDN), and WAF capabilities at the edge, delivering content from the closest Point of Presence (POP) to users.

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Front Door Profile** | Container for Front Door configuration |
| **Endpoint** | Public hostname (e.g., contoso.azurefd.net) |
| **Origin Group** | Collection of backends (origins) |
| **Origin** | Backend server (App Service, VM, Storage, etc.) |
| **Route** | Maps requests to origin groups |
| **Rule Set** | Custom rules for routing, rewrites, headers |
| **WAF Policy** | Web Application Firewall rules |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      Azure Front Door Architecture                               │
│                                                                                  │
│    USERS WORLDWIDE                                                              │
│    ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐                                │
│    │ US  │  │ EU  │  │ Asia│  │ SAm │  │ Aus │                                │
│    └──┬──┘  └──┬──┘  └──┬──┘  └──┬──┘  └──┬──┘                                │
│       │        │        │        │        │                                     │
│       └────────┴────────┴────────┴────────┘                                     │
│                         │                                                        │
│    ┌────────────────────▼────────────────────┐                                  │
│    │           AZURE FRONT DOOR               │                                  │
│    │        (Global Edge Network)             │                                  │
│    │                                          │                                  │
│    │   ┌────────────────────────────────────┐│                                  │
│    │   │      EDGE POPs (180+ locations)    ││                                  │
│    │   │                                    ││                                  │
│    │   │  • SSL Termination (edge)          ││                                  │
│    │   │  • WAF Inspection                  ││                                  │
│    │   │  • Caching (CDN)                   ││                                  │
│    │   │  • Compression                     ││                                  │
│    │   │  • Routing Decisions               ││                                  │
│    │   └────────────────────────────────────┘│                                  │
│    │                                          │                                  │
│    │   Endpoint: app.azurefd.net              │                                  │
│    │   Custom Domain: www.contoso.com         │                                  │
│    └────────────────────┬─────────────────────┘                                  │
│                         │                                                        │
│           ┌─────────────┴─────────────┐                                         │
│           │     Microsoft Backbone     │                                         │
│           │   (Private, Fast Network)  │                                         │
│           └─────────────┬─────────────┘                                         │
│                         │                                                        │
│    ┌────────────────────┼────────────────────┐                                  │
│    │                    │                    │                                  │
│    ▼                    ▼                    ▼                                  │
│ ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                           │
│ │ ORIGIN GROUP │  │ ORIGIN GROUP │  │ ORIGIN GROUP │                           │
│ │   "Primary"  │  │  "Static"    │  │    "API"     │                           │
│ │              │  │              │  │              │                           │
│ │ West Europe: │  │ Storage:     │  │ East US:     │                           │
│ │ - App Svc 1  │  │ - Blob (CDN) │  │ - API Mgmt   │                           │
│ │ - App Svc 2  │  │              │  │              │                           │
│ │              │  │              │  │              │                           │
│ │ East US:     │  │              │  │ West EU:     │                           │
│ │ - App Svc 3  │  │              │  │ - API Mgmt   │                           │
│ │ (failover)   │  │              │  │ (failover)   │                           │
│ └──────────────┘  └──────────────┘  └──────────────┘                           │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Front Door Tiers

### Tier Comparison

| Feature | Standard | Premium |
|---------|----------|---------|
| **Custom Domains** | ✅ | ✅ |
| **SSL Termination** | ✅ | ✅ |
| **Caching** | ✅ | ✅ |
| **Compression** | ✅ | ✅ |
| **URL Rewrite/Redirect** | ✅ | ✅ |
| **Rules Engine** | Basic | Advanced |
| **WAF** | ✅ | ✅ (Advanced) |
| **Bot Protection** | ❌ | ✅ |
| **Private Link Origin** | ❌ | ✅ |
| **Enhanced Analytics** | Basic | Advanced |
| **DDoS Protection** | ✅ | ✅ (Enhanced) |

---

## Routing and Origins

### Routing Methods

| Method | Description |
|--------|-------------|
| **Latency** | Route to lowest latency origin |
| **Priority** | Primary/secondary failover |
| **Weighted** | Distribute by percentage |
| **Session Affinity** | Stick to same origin |

### Origin Configuration

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Origin Group Configuration                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ORIGIN GROUP: "webapp-origins"                                        │
│   Load Balancing: Latency-based                                         │
│   Health Probe: /health, HTTPS, 30s interval                           │
│                                                                          │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │  ORIGIN 1                    ORIGIN 2                           │   │
│   │                                                                  │   │
│   │  Name: west-europe           Name: east-us                      │   │
│   │  Host: app-we.azurewebsites  Host: app-eus.azurewebsites       │   │
│   │  Priority: 1                 Priority: 1                        │   │
│   │  Weight: 50                  Weight: 50                         │   │
│   │  Enabled: Yes                Enabled: Yes                       │   │
│   │                                                                  │   │
│   │  ORIGIN 3 (DR)                                                  │   │
│   │                                                                  │   │
│   │  Name: southeast-asia                                           │   │
│   │  Host: app-sea.azurewebsites                                   │   │
│   │  Priority: 2  ← Only used if Priority 1 origins fail           │   │
│   │  Weight: 100                                                    │   │
│   │  Enabled: Yes                                                   │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│   Health Probe Settings:                                                │
│   • Path: /health                                                       │
│   • Protocol: HTTPS                                                     │
│   • Interval: 30 seconds                                               │
│   • Sample Size: 4                                                      │
│   • Successful Samples: 3                                              │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Key Features

### Caching (CDN)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Front Door Caching                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   User Request                                                          │
│        │                                                                 │
│        ▼                                                                 │
│   ┌─────────────────────────────────────────────────────────────────┐   │
│   │                    FRONT DOOR EDGE POP                           │   │
│   │                                                                  │   │
│   │   1. Check Cache                                                 │   │
│   │      │                                                           │   │
│   │      ├── HIT  → Return cached content (fast!)                   │   │
│   │      │                                                           │   │
│   │      └── MISS → Fetch from origin, cache response               │   │
│   │                                                                  │   │
│   └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│   Cache Settings:                                                       │
│   • Query String Caching: Ignore, Include All, Include Specific        │
│   • Compression: Enabled (gzip, brotli)                                │
│   • Cache Duration: Honor origin, override with rules                  │
│                                                                          │
│   Purge Cache:                                                          │
│   • Purge all content                                                  │
│   • Purge by URL pattern (/images/*)                                   │
│   • Purge single URL                                                   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Private Link to Origins (Premium)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Private Link Origin (Premium Tier)                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│                         INTERNET                                         │
│                            │                                             │
│                            ▼                                             │
│                    ┌───────────────┐                                    │
│                    │  FRONT DOOR   │                                    │
│                    │   Premium     │                                    │
│                    └───────┬───────┘                                    │
│                            │                                             │
│                    ┌───────▼───────┐                                    │
│                    │ Private Link  │◄── Traffic stays on Microsoft     │
│                    │  Connection   │    backbone (no public internet)   │
│                    └───────┬───────┘                                    │
│                            │                                             │
│   ┌────────────────────────▼────────────────────────────────────────┐   │
│   │                    CUSTOMER VNET                                 │   │
│   │                                                                  │   │
│   │   ┌──────────────────┐  ┌──────────────────────────────────┐   │   │
│   │   │ Private Endpoint │  │  Internal Load Balancer           │   │   │
│   │   │ (for App Svc)    │  │  (for VMs)                        │   │   │
│   │   │                  │  │                                    │   │   │
│   │   │  No public IP    │  │  No public exposure               │   │   │
│   │   │  needed          │  │  needed                           │   │   │
│   │   └──────────────────┘  └──────────────────────────────────┘   │   │
│   │                                                                  │   │
│   │   Origin remains private - only Front Door can access           │   │
│   └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
│   Supported Origins for Private Link:                                   │
│   • App Service / Web Apps                                              │
│   • Azure Storage (Blob)                                                │
│   • Internal Load Balancer (Standard)                                   │
│   • API Management (internal VNet mode)                                 │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Configuration Best Practices

### Create Front Door Profile

```powershell
# Create Front Door Profile (Standard tier)
$fdProfile = New-AzFrontDoorCdnProfile `
    -Name "fd-global-app" `
    -ResourceGroupName "rg-frontdoor" `
    -Location "Global" `
    -SkuName "Standard_AzureFrontDoor"

# Create endpoint
$endpoint = New-AzFrontDoorCdnEndpoint `
    -EndpointName "contoso-app" `
    -ProfileName "fd-global-app" `
    -ResourceGroupName "rg-frontdoor" `
    -Location "Global"
```

### Configure Origin Group and Origins

```powershell
# Create origin group
$originGroup = New-AzFrontDoorCdnOriginGroup `
    -OriginGroupName "webapp-origins" `
    -ProfileName "fd-global-app" `
    -ResourceGroupName "rg-frontdoor" `
    -LoadBalancingSettingSampleSize 4 `
    -LoadBalancingSettingSuccessfulSamplesRequired 3 `
    -HealthProbeSettingProbeIntervalInSecond 30 `
    -HealthProbeSettingProbePath "/health" `
    -HealthProbeSettingProbeProtocol "Https" `
    -HealthProbeSettingProbeRequestType "GET"

# Add origin (West Europe App Service)
New-AzFrontDoorCdnOrigin `
    -OriginName "webapp-westeu" `
    -OriginGroupName "webapp-origins" `
    -ProfileName "fd-global-app" `
    -ResourceGroupName "rg-frontdoor" `
    -HostName "app-westeu.azurewebsites.net" `
    -HttpPort 80 `
    -HttpsPort 443 `
    -Priority 1 `
    -Weight 50 `
    -OriginHostHeader "app-westeu.azurewebsites.net"

# Add origin (East US App Service)
New-AzFrontDoorCdnOrigin `
    -OriginName "webapp-eastus" `
    -OriginGroupName "webapp-origins" `
    -ProfileName "fd-global-app" `
    -ResourceGroupName "rg-frontdoor" `
    -HostName "app-eastus.azurewebsites.net" `
    -HttpPort 80 `
    -HttpsPort 443 `
    -Priority 1 `
    -Weight 50 `
    -OriginHostHeader "app-eastus.azurewebsites.net"
```

### Create Route

```powershell
# Create route to connect endpoint to origin group
New-AzFrontDoorCdnRoute `
    -RouteName "default-route" `
    -EndpointName "contoso-app" `
    -ProfileName "fd-global-app" `
    -ResourceGroupName "rg-frontdoor" `
    -OriginGroupId $originGroup.Id `
    -SupportedProtocol "Https", "Http" `
    -PatternsToMatch "/*" `
    -ForwardingProtocol "HttpsOnly" `
    -HttpsRedirect "Enabled" `
    -LinkToDefaultDomain "Enabled" `
    -CacheConfigurationQueryStringCachingBehavior "IgnoreQueryString"
```

### Configure Custom Domain

```powershell
# Add custom domain
$customDomain = New-AzFrontDoorCdnCustomDomain `
    -CustomDomainName "www-contoso" `
    -ProfileName "fd-global-app" `
    -ResourceGroupName "rg-frontdoor" `
    -HostName "www.contoso.com" `
    -TlsSettingCertificateType "ManagedCertificate" `
    -TlsSettingMinimumTlsVersion "TLS12"

# Associate with route
# Update route to include custom domain
```

### Configure WAF Policy

```powershell
# Create WAF policy
$wafPolicy = New-AzFrontDoorWafPolicy `
    -Name "waf-fd-policy" `
    -ResourceGroupName "rg-frontdoor" `
    -Sku "Standard_AzureFrontDoor" `
    -EnabledState "Enabled" `
    -Mode "Prevention"

# Add managed rule set (OWASP)
$managedRule = New-AzFrontDoorWafManagedRuleObject `
    -Type "DefaultRuleSet" `
    -Version "1.0"

$wafPolicy | Set-AzFrontDoorWafPolicy -ManagedRule $managedRule

# Associate WAF with Front Door
New-AzFrontDoorCdnSecurityPolicy `
    -SecurityPolicyName "waf-security" `
    -ProfileName "fd-global-app" `
    -ResourceGroupName "rg-frontdoor" `
    -WafPolicyId $wafPolicy.Id `
    -DomainId $endpoint.Id
```

---

## Exam Tips & Gotchas

### Critical Points (Commonly Tested)

- **Global service at edge** — Front Door runs at 180+ POPs worldwide
- **Premium required for Private Link** — Standard cannot use private origins
- **WAF at edge** — attacks blocked before reaching origin
- **Caching reduces origin load** — configure cache rules appropriately
- **Session affinity uses cookie** — ARRAffinity for sticky sessions
- **Origin host header important** — must match for App Service backends
- **HTTP to HTTPS redirect** — built-in redirect option

### Exam Scenarios

| Scenario | Solution |
|----------|----------|
| Global web app with low latency | Front Door with latency-based routing |
| Protect web app from DDoS/attacks | Front Door with WAF policy |
| Cache static content globally | Enable caching, configure rules |
| Keep origins private (no public IP) | Premium tier + Private Link |
| Blue/green deployment | Weighted routing between origin groups |
| Failover between regions | Priority routing with health probes |
| A/B testing new version | Weighted routing (90/10 split) |

### Common Gotchas

1. **Origin host header must match** — App Services require correct host header
2. **Health probe path must return 200** — ensure /health endpoint exists
3. **Private Link requires approval** — origin owner must approve connection
4. **Purge cache takes time** — not instant, may take minutes
5. **Custom domain needs DNS validation** — CNAME or TXT record required

---

## Comparison Tables

### Front Door vs Other Services

| Feature | Front Door | Application Gateway | Traffic Manager | CDN |
|---------|------------|-------------------|-----------------|-----|
| **Scope** | Global | Regional | Global (DNS) | Global |
| **Layer** | 7 (HTTP/S) | 7 (HTTP/S) | DNS | 7 (HTTP/S) |
| **Proxy** | ✅ | ✅ | ❌ | ✅ |
| **WAF** | ✅ | ✅ | ❌ | ❌ |
| **Caching** | ✅ | ❌ | ❌ | ✅ |
| **SSL Offload** | ✅ | ✅ | ❌ | ✅ |
| **Private Backend** | Premium only | ✅ | N/A | ❌ |
| **Non-HTTP** | ❌ | ❌ | ✅ | ❌ |

---

## Hands-On Lab Suggestions

### Lab: Deploy Front Door with Multi-Region Origins

```powershell
# 1. Create resource group
New-AzResourceGroup -Name "rg-fd-lab" -Location "uksouth"

# 2. Create two App Services in different regions
# (West Europe and East US)

# 3. Create Front Door profile
$fdProfile = New-AzFrontDoorCdnProfile `
    -Name "fd-lab" `
    -ResourceGroupName "rg-fd-lab" `
    -Location "Global" `
    -SkuName "Standard_AzureFrontDoor"

# 4. Create endpoint
$endpoint = New-AzFrontDoorCdnEndpoint `
    -EndpointName "fd-lab-$(Get-Random)" `
    -ProfileName "fd-lab" `
    -ResourceGroupName "rg-fd-lab" `
    -Location "Global"

# 5. Create origin group with both App Services
# 6. Create route
# 7. Test from different locations (use VPN or online tools)

# 8. Test failover by stopping one App Service
Stop-AzWebApp -Name "app-westeu" -ResourceGroupName "rg-fd-lab"
# Traffic should automatically route to remaining healthy origin

# 9. View metrics in Azure Portal
# - Requests, latency, cache hit ratio
```

---

## Cross-Service Relationships

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Front Door Integration                                    │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        Azure Front Door                                 │ │
│  │                                                                         │ │
│  │   Origins ─────────► App Services                                      │ │
│  │           ─────────► Azure Storage (Blob)                              │ │
│  │           ─────────► API Management                                    │ │
│  │           ─────────► Application Gateway                               │ │
│  │           ─────────► Load Balancer (via Private Link - Premium)        │ │
│  │           ─────────► Any public FQDN/IP                                │ │
│  │                                                                         │ │
│  │   Security ────────► WAF Policy                                        │ │
│  │           ────────► DDoS Protection (built-in)                         │ │
│  │           ────────► Managed Certificates                               │ │
│  │                                                                         │ │
│  │   Monitoring ──────► Azure Monitor                                     │ │
│  │             ──────► Log Analytics                                      │ │
│  │             ──────► Diagnostic Logs                                    │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  Common Architecture:                                                       │
│  Internet → Front Door (global, WAF, cache) → App Gateway (regional, WAF)  │
│           → VMs/App Services                                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Draw.io Diagram

```xml
<mxfile host="app.diagrams.net">
  <diagram name="Azure Front Door" id="fd-arch">
    <mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1169" pageHeight="827" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <mxCell id="users" value="Global Users" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;verticalAlign=top" vertex="1" parent="1">
          <mxGeometry x="40" y="40" width="840" height="60" as="geometry" />
        </mxCell>
        <mxCell id="fd" value="Azure Front Door&#xa;(Global Edge Network)&#xa;&#xa;• 180+ POPs&#xa;• WAF&#xa;• Caching&#xa;• SSL Termination" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
          <mxGeometry x="320" y="160" width="280" height="120" as="geometry" />
        </mxCell>
        <mxCell id="og1" value="Origin Group 1&#xa;(Web App)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="120" y="360" width="160" height="80" as="geometry" />
        </mxCell>
        <mxCell id="og2" value="Origin Group 2&#xa;(API)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="380" y="360" width="160" height="80" as="geometry" />
        </mxCell>
        <mxCell id="og3" value="Origin Group 3&#xa;(Static/CDN)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="640" y="360" width="160" height="80" as="geometry" />
        </mxCell>
        <mxCell id="waf" value="WAF Policy" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;" vertex="1" parent="1">
          <mxGeometry x="680" y="180" width="100" height="40" as="geometry" />
        </mxCell>
        <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="users" target="fd">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e2" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="fd" target="og1">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e3" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="fd" target="og2">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e4" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="fd" target="og3">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```
