---
tags:
  - AZ-700
  - azure/networking
  - domain/app-delivery
  - traffic-manager
  - dns-routing
  - global-load-balancing
  - routing-methods
  - priority-routing
  - weighted-routing
  - geographic-routing
  - performance-routing
  - endpoint-monitoring
aliases:
  - Traffic Manager
  - Azure Traffic Manager
  - TM
created: 2025-01-01
updated: 2026-02-07
---

# Azure Traffic Manager

> [!info] Related Notes
> - [[Azure_Front_Door]] — Global L7 alternative (data-path vs DNS-only)
> - [[Azure_Load_Balancer]] — Regional L4 load balancing
> - [[Application_Gateway]] — Regional L7 load balancing
> - [[Azure_DNS]] — DNS resolution and CNAME to Traffic Manager

## Overview

Azure Traffic Manager is a **DNS-based global traffic load balancer** that distributes traffic across Azure regions or external endpoints. Unlike Application Gateway or Azure Load Balancer which operate in the data path, Traffic Manager operates exclusively at the DNS layer—it never sees your actual application traffic. When a client queries the Traffic Manager DNS name, it returns the IP address of the most appropriate endpoint based on the configured routing method and current endpoint health. The client then connects **directly** to that endpoint.

### Understanding the DNS-Only Nature (Critical Exam Concept)

This is the single most important concept to understand about Traffic Manager:

```
Traditional Load Balancer (Layer 4/7):
Client ──► Load Balancer ──► Backend Server
          (Traffic flows through)

Traffic Manager (DNS only):
Step 1: Client ──► DNS Query ──► Traffic Manager ──► Returns: "Use IP 1.2.3.4"
Step 2: Client ──► Direct connection ──► Backend Server (1.2.3.4)
        (Traffic Manager is NOT involved)
```

**Implications of DNS-only operation:**

| What Traffic Manager CAN Do | What Traffic Manager CANNOT Do |
|----------------------------|--------------------------------|
| Return different IPs based on routing logic | Inspect or modify HTTP headers |
| Detect unhealthy endpoints via health probes | Terminate SSL/TLS connections |
| Route based on geographic location | Cache content |
| Provide failover between regions | Apply WAF rules |
| Support any TCP/UDP protocol (DNS returns IP) | Provide session affinity (cookies) |
| Work with non-Azure endpoints | Rewrite URLs |

### Why DNS TTL Matters for Failover

When Traffic Manager returns a DNS response, it includes a **Time-To-Live (TTL)** value. Clients and recursive DNS resolvers cache this response for the TTL duration. This creates a critical trade-off:

| TTL Setting | Failover Speed | DNS Query Volume | Cost Impact |
|-------------|----------------|------------------|-------------|
| **30 seconds** | Fast (~30-60s) | High | Higher (more queries) |
| **300 seconds (5 min)** | Slow (~5-10 min) | Lower | Lower |

**Exam Scenario:** "Users experience 5 minutes of downtime during regional failover despite Traffic Manager health probes detecting the failure in 30 seconds."

**Root Cause:** TTL is set too high (300 seconds). Clients continue using the cached IP until TTL expires.

**Solution:** Reduce TTL to 30-60 seconds for faster failover. Accept the increased DNS query volume.

**Deep Dive - The Failover Timeline:**

```
Time 0:00 - Primary endpoint fails
Time 0:30 - Health probe detects failure (3 failed checks × 10-second interval)
Time 0:30 - Traffic Manager updates DNS to return secondary IP
Time 0:30 to TTL - Clients with cached DNS still connect to failed primary
Time TTL   - Cached DNS expires, new queries get secondary IP
```

### Key Concepts Reference

| Concept | Description | Exam Relevance |
|---------|-------------|----------------|
| **Profile** | Container for Traffic Manager configuration | One profile = one DNS name |
| **Endpoint** | Destination target (Azure, External, or Nested) | Can mix types in one profile |
| **Routing Method** | Algorithm determining endpoint selection | 6 methods—know when to use each |
| **DNS TTL** | Cache duration for DNS responses | Directly affects failover speed |
| **Health Probe** | Monitors endpoint availability | Customizable path, protocol, interval |
| **Nested Profile** | Another TM profile used as an endpoint | Enables complex routing scenarios |

---

## Routing Methods - Deep Technical Analysis

Traffic Manager offers six routing methods. Exam questions frequently present scenarios requiring you to identify the correct method.

### Priority Routing (Active/Passive Failover)

**How it works:** Each endpoint has a priority number (1-1000). Traffic Manager always returns the lowest-priority healthy endpoint.

**Detailed behavior:**
1. DNS query arrives
2. Traffic Manager checks health of Priority 1 endpoint
3. If healthy → return Priority 1 IP
4. If unhealthy → check Priority 2, and so on
5. If all endpoints unhealthy → return "no answer" or degraded endpoint (configurable)

**Use cases:**
- Disaster recovery with primary/secondary sites
- Blue/green deployments where blue is primary
- Maintenance scenarios (lower priority during updates)

**Exam Trap:** "Priority routing returns ALL healthy endpoints for client-side selection." 
**FALSE** - Priority returns only ONE endpoint (the highest-priority healthy one). MultiValue returns multiple.

### Weighted Routing (Percentage Distribution)

**How it works:** Each endpoint has a weight (1-1000). Traffic distribution is proportional to weights among healthy endpoints.

**Calculation example:**
```
Endpoint A: Weight 100
Endpoint B: Weight 50  
Endpoint C: Weight 50

Total weight = 200

Traffic distribution (all healthy):
- A: 100/200 = 50%
- B: 50/200 = 25%
- C: 50/200 = 25%

If Endpoint A becomes unhealthy:
Total weight = 100
- B: 50/100 = 50%
- C: 50/100 = 50%
```

**Use cases:**
- Gradual migration: Start new region at weight 10, increase over days
- A/B testing: Send 10% to experimental version
- Capacity-based distribution: Higher weight for larger deployments

**Exam Scenario:** "Migrate from on-premises (External endpoint) to Azure (Azure endpoint) with zero downtime."
**Solution:** Weighted routing. Start Azure at weight 1, on-prem at weight 99. Gradually shift.

### Performance Routing (Lowest Latency)

**How it works:** Traffic Manager uses the **Internet Latency Table** to determine which endpoint is "closest" to the user based on network latency, not geographic distance.

**Critical detail - Internet Latency Table:**
- Microsoft continuously measures latency between Azure regions and internet networks worldwide
- Updated regularly but **not real-time**
- Measures latency to the **Azure region** where the endpoint is registered, not to the endpoint itself

**Why this matters:**
```
Scenario: User in London, UK
- Endpoint A: App Service in West Europe (Netherlands) - 20ms latency
- Endpoint B: App Service in UK South (London) - 10ms latency  
- Endpoint C: VM in UK South with Public IP registered as "East US" - WRONG REGION

Result: Traffic Manager might send user to Endpoint A or B based on table, 
        but Endpoint C (despite being in UK) shows as "East US" because
        External endpoints require explicit EndpointLocation setting.
```

**Exam Trap:** "Performance routing guarantees users connect to the geographically closest endpoint."
**FALSE** - It routes based on network latency, which may differ from geographic distance due to network topology.

### Geographic Routing (Location-Based Compliance)

**How it works:** You explicitly map geographic regions (countries, continents, states) to specific endpoints. Users from mapped regions ONLY go to their assigned endpoint.

**Critical behavior:**
- **Unmapped regions receive NO answer** unless you configure a "World" fallback
- Each region can only be mapped to ONE endpoint
- Geographic hierarchy: World → Continent → Country → State (US states)

**Mapping examples:**
```powershell
# Map all of Europe to EU endpoint
-GeoMapping "GEO-EU"

# Map specific countries to UK endpoint  
-GeoMapping @("GB", "IE")  # UK and Ireland

# Map US states to specific endpoint
-GeoMapping @("US-CA", "US-NV")  # California and Nevada

# CRITICAL: Always include a World fallback
-GeoMapping "WORLD"  # Catches all unmapped regions
```

**Exam Scenario:** "German users must always connect to the Frankfurt data center for GDPR compliance, regardless of latency."
**Solution:** Geographic routing with Germany mapped to Frankfurt endpoint. (NOT Performance—that might route elsewhere.)

### MultiValue Routing (Multiple IPs Returned)

**How it works:** Returns IP addresses of ALL healthy endpoints (up to a configurable maximum) in the DNS response. Client chooses which to use.

**When to use:**
- Client applications that can handle multiple IPs and retry on failure
- Scenarios where you want client-side load balancing
- Services that benefit from client IP caching with fallbacks

**Configuration:**
```powershell
New-AzTrafficManagerProfile `
    -TrafficRoutingMethod "MultiValue" `
    -MaxReturn 3  # Return up to 3 healthy endpoint IPs
```

**Exam Trap:** MultiValue only works with **External endpoints** that have IPv4 addresses explicitly configured. Azure endpoints and nested profiles are NOT supported.

### Subnet Routing (Client IP-Based)

**How it works:** You map specific client IP subnets to specific endpoints. Useful for enterprise scenarios where you know client IP ranges.

**Use cases:**
- Corporate VPN users → Internal endpoint
- Partner network → Dedicated partner endpoint
- Testing subnet → Beta version endpoint

**Configuration:**
```powershell
New-AzTrafficManagerEndpoint `
    -Name "internal-endpoint" `
    -Type "ExternalEndpoints" `
    -Target "internal.contoso.com" `
    -SubnetMapping @(
        @{First="10.0.0.0"; Last="10.0.255.255"; Scope=16},  # 10.0.0.0/16
        @{First="192.168.1.0"; Last="192.168.1.255"; Scope=24}  # 192.168.1.0/24
    )
```

---

## Health Probes - Deep Dive

Traffic Manager health probes are fundamental to all routing methods. Understanding their behavior is critical for troubleshooting.

### Probe Configuration Parameters

| Parameter | Default | Range | Impact |
|-----------|---------|-------|--------|
| **Protocol** | HTTP | HTTP, HTTPS, TCP | HTTPS validates certificate |
| **Port** | 80/443 | 1-65535 | Must match your app |
| **Path** | / | Any path | Should return 200-399 quickly |
| **Interval** | 30s | 10-30s (Standard) | How often probes are sent |
| **Tolerated Failures** | 3 | 0-9 | Failures before marking unhealthy |
| **Timeout** | 10s | 5-10s | Time to wait for response |

### Probe Behavior Nuances

**Where probes originate:**
- Probes come from **multiple Azure locations worldwide**
- Your endpoint must be accessible from the internet (or Azure network)
- You cannot whitelist specific IPs (they change); use service tags if possible

**What constitutes a "healthy" response:**
- HTTP/HTTPS: Status code 200-399
- TCP: Successful TCP connection establishment
- Response time within timeout
- HTTPS: Valid SSL certificate (expired/self-signed = unhealthy)

**Exam Scenario:** "Traffic Manager shows endpoint as 'Degraded' but the application works fine when accessed directly."

**Troubleshooting checklist:**
1. Is health probe path correct? (`/health` vs `/` vs `/api/health`)
2. Does health path require authentication? (Must return 200 without auth)
3. Is there a firewall blocking Azure probe IPs?
4. For HTTPS, is the SSL certificate valid and trusted?
5. Is the response time within timeout?

### Endpoint Status States

| Status | Meaning | Traffic Routed? |
|--------|---------|-----------------|
| **Online** | Healthy, passing probes | ✅ Yes |
| **Degraded** | Failing health probes | ❌ No (usually) |
| **Disabled** | Manually disabled | ❌ No |
| **Inactive** | Profile disabled | ❌ No |
| **Stopped** | Endpoint resource stopped | ❌ No |

**Special case - All endpoints degraded:**
When ALL endpoints are unhealthy, Traffic Manager returns ALL endpoints in DNS (degraded endpoints included) rather than returning nothing. This is a "best effort" behavior to maintain some level of availability.

---

## Nested Profiles - Advanced Scenarios

Nested profiles allow combining multiple routing methods in a hierarchy. The parent profile treats child profiles as endpoints.

### Common Pattern: Performance + Priority

**Scenario:** Route users to nearest region (Performance), but within each region have primary/secondary failover (Priority).

```
                    Parent Profile
                   (Performance Routing)
                          │
           ┌──────────────┼──────────────┐
           │              │              │
           ▼              ▼              ▼
    Child Profile   Child Profile   Azure Endpoint
    (US - Priority) (EU - Priority)  (Asia)
           │              │
      ┌────┴────┐    ┌────┴────┐
      ▼         ▼    ▼         ▼
   US-East   US-West EU-West  EU-North
   (Pri 1)   (Pri 2) (Pri 1)  (Pri 2)
```

### Nested Profile Health Behavior

**Critical concept:** The parent profile monitors the child profile's health using a special calculation:

**MinChildEndpoints setting:**
```powershell
# Child profile must have at least 2 healthy endpoints
# for parent to consider it healthy
New-AzTrafficManagerEndpoint `
    -Name "us-region" `
    -Type "NestedEndpoints" `
    -TargetResourceId $childProfile.Id `
    -MinChildEndpoints 2
```

If child has fewer healthy endpoints than MinChildEndpoints, parent marks it as unhealthy and fails over.

---

## Exam Scenarios - Complex Problem Solving

### Scenario 1: Multi-Region with Compliance Requirements

**Setup:** Global company with:
- Users in EU must connect to EU data center (GDPR)
- Users in US should get best performance
- All other users go to nearest region

**Solution:** Nested profiles with Geographic + Performance

```
Parent Profile (Geographic)
├── GEO-EU → EU endpoint (direct - compliance)
├── GEO-NA → Child Profile (Performance routing in North America)
│            ├── US East
│            └── US West  
└── WORLD → Child Profile (Performance routing globally)
             ├── EU West
             ├── US East
             └── East Asia
```

### Scenario 2: Blue-Green Deployment with Gradual Shift

**Setup:** Moving from blue (production) to green (new version) with risk mitigation.

**Solution:** Weighted routing with gradual weight adjustment

**Day 1:** Blue: 100, Green: 0 (Green not receiving traffic)
**Day 2:** Blue: 95, Green: 5 (5% canary)
**Day 3:** Blue: 80, Green: 20 
**Day 7:** Blue: 50, Green: 50
**Day 14:** Blue: 0, Green: 100 (complete migration)

If issues detected at any stage, immediately set Green weight to 0.

### Scenario 3: Failover Taking Too Long

**Problem:** "Health probe detects failure in 30 seconds, but users experience 5 minutes of downtime."

**Analysis:**
- Probe interval: 10 seconds
- Tolerated failures: 3
- Detection time: 30 seconds ✓
- DNS TTL: 300 seconds ← **This is the problem**

**Solution:** Reduce TTL to 30-60 seconds.

**Trade-off:** More DNS queries = slightly higher cost and latency for initial DNS resolution.

---

## Related Resources

- [Traffic Manager Documentation](https://docs.microsoft.com/azure/traffic-manager/traffic-manager-overview)
- [Routing Methods](https://docs.microsoft.com/azure/traffic-manager/traffic-manager-routing-methods)
- [Nested Profiles](https://docs.microsoft.com/azure/traffic-manager/traffic-manager-nested-profiles)
- [Health Probe Monitoring](https://docs.microsoft.com/azure/traffic-manager/traffic-manager-monitoring)

---

*Last Updated: January 2026*
*AZ-700: Designing and Implementing Microsoft Azure Networking Solutions*
# Add App Service endpoint
$webApp = Get-AzWebApp -Name "app-westus" -ResourceGroupName "rg-app"

New-AzTrafficManagerEndpoint `
    -Name "endpoint-westus" `
    -ProfileName "tm-global-app" `
    -ResourceGroupName "rg-traffic-manager" `
    -Type "AzureEndpoints" `
    -TargetResourceId $webApp.Id `
    -EndpointStatus "Enabled" `
    -Priority 1 `
    -Weight 100

# Add another region
$webAppEu = Get-AzWebApp -Name "app-westeu" -ResourceGroupName "rg-app-eu"

New-AzTrafficManagerEndpoint `
    -Name "endpoint-westeu" `
    -ProfileName "tm-global-app" `
    -ResourceGroupName "rg-traffic-manager" `
    -Type "AzureEndpoints" `
    -TargetResourceId $webAppEu.Id `
    -EndpointStatus "Enabled" `
    -Priority 2 `
    -Weight 100
```

### Add External Endpoint

```powershell
# Add external (non-Azure) endpoint
New-AzTrafficManagerEndpoint `
    -Name "endpoint-onprem" `
    -ProfileName "tm-global-app" `
    -ResourceGroupName "rg-traffic-manager" `
    -Type "ExternalEndpoints" `
    -Target "www.contoso-onprem.com" `
    -EndpointStatus "Enabled" `
    -Priority 3 `
    -Weight 50 `
    -EndpointLocation "UK South"  # Required for Performance routing
```

### Geographic Routing Configuration

```powershell
# Create profile with Geographic routing
$tmGeo = New-AzTrafficManagerProfile `
    -Name "tm-geo-app" `
    -ResourceGroupName "rg-traffic-manager" `
    -TrafficRoutingMethod "Geographic" `
    -RelativeDnsName "mygeoapp" `
    -Ttl 30 `
    -MonitorProtocol "HTTPS" `
    -MonitorPort 443 `
    -MonitorPath "/health"

# Add endpoint with geographic mapping
New-AzTrafficManagerEndpoint `
    -Name "endpoint-europe" `
    -ProfileName "tm-geo-app" `
    -ResourceGroupName "rg-traffic-manager" `
    -Type "AzureEndpoints" `
    -TargetResourceId $webAppEu.Id `
    -GeoMapping "GEO-EU"  # All of Europe

# Geographic codes: GEO-EU, GEO-NA, GEO-AS, GEO-AF, GEO-SA, GEO-AN, WORLD
# Country codes: US, GB, DE, FR, etc.
```

---

## Exam Tips & Gotchas

### Critical Points (Commonly Tested)

- **DNS-based only** — Traffic Manager returns IP, doesn't proxy traffic
- **Not in data path** — once resolved, client connects directly to endpoint
- **TTL affects failover speed** — lower TTL = faster failover, more DNS queries
- **Performance routing uses Internet Latency Table** — not real-time measurement
- **Geographic requires mapping ALL regions** — unmapped = no response (unless default)
- **Nested profiles enable complex routing** — combine methods hierarchically
- **Health probes from multiple locations** — endpoint must be globally accessible

### Exam Scenarios

| Scenario | Solution |
|----------|----------|
| Active/passive DR across regions | Priority routing |
| Route EU users to EU data center | Geographic routing |
| Gradual migration to new version | Weighted routing (shift weight over time) |
| Best performance for global users | Performance routing |
| Combine failover + weighted | Nested profiles |
| Return all healthy endpoints | MultiValue routing |
| Route by client IP range | Subnet routing |

### Common Gotchas

1. **DNS caching** — clients may use stale IP during failover (respect TTL)
2. **Geographic: unmapped = no answer** — always configure "World" fallback
3. **External endpoints need EndpointLocation** — required for Performance routing
4. **Nested profile health** — parent profile monitors child profile as endpoint
5. **IPv6 not supported** — Traffic Manager returns IPv4 only

---

## Comparison: Traffic Manager vs Front Door

| Feature | Traffic Manager | Front Door |
|---------|-----------------|------------|
| **Layer** | DNS (Layer 7 DNS) | HTTP/HTTPS (Layer 7) |
| **Proxy** | No (DNS only) | Yes (full proxy) |
| **SSL Offload** | ❌ | ✅ |
| **Caching** | ❌ | ✅ (CDN) |
| **WAF** | ❌ | ✅ |
| **URL Routing** | ❌ | ✅ |
| **Session Affinity** | ❌ | ✅ (cookie) |
| **Non-HTTP** | ✅ (any protocol) | ❌ (HTTP/S only) |
| **Failover Speed** | Depends on TTL | Instant (active probing) |
| **Cost** | Lower | Higher |

---

## Hands-On Lab Suggestions

### Lab: Multi-Region Failover with Traffic Manager

```powershell
# 1. Create resource group
New-AzResourceGroup -Name "rg-tm-lab" -Location "uksouth"

# 2. Create App Service Plan and App in two regions
# West Europe
$planEu = New-AzAppServicePlan -Name "asp-westeu" -ResourceGroupName "rg-tm-lab" `
    -Location "westeurope" -Tier "Standard" -NumberofWorkers 1 -WorkerSize "Small"
$appEu = New-AzWebApp -Name "app-tm-lab-westeu" -ResourceGroupName "rg-tm-lab" `
    -Location "westeurope" -AppServicePlan $planEu.Id

# UK South
$planUk = New-AzAppServicePlan -Name "asp-uksouth" -ResourceGroupName "rg-tm-lab" `
    -Location "uksouth" -Tier "Standard" -NumberofWorkers 1 -WorkerSize "Small"
$appUk = New-AzWebApp -Name "app-tm-lab-uksouth" -ResourceGroupName "rg-tm-lab" `
    -Location "uksouth" -AppServicePlan $planUk.Id

# 3. Create Traffic Manager profile with Priority routing
$tm = New-AzTrafficManagerProfile `
    -Name "tm-lab-failover" `
    -ResourceGroupName "rg-tm-lab" `
    -TrafficRoutingMethod "Priority" `
    -RelativeDnsName "tm-lab-$(Get-Random)" `
    -Ttl 30 `
    -MonitorProtocol "HTTPS" `
    -MonitorPort 443 `
    -MonitorPath "/"

# 4. Add primary endpoint (West Europe)
New-AzTrafficManagerEndpoint `
    -Name "primary-westeu" `
    -ProfileName $tm.Name `
    -ResourceGroupName "rg-tm-lab" `
    -Type "AzureEndpoints" `
    -TargetResourceId $appEu.Id `
    -Priority 1

# 5. Add secondary endpoint (UK South)
New-AzTrafficManagerEndpoint `
    -Name "secondary-uksouth" `
    -ProfileName $tm.Name `
    -ResourceGroupName "rg-tm-lab" `
    -Type "AzureEndpoints" `
    -TargetResourceId $appUk.Id `
    -Priority 2

# 6. Test DNS resolution
nslookup "$($tm.RelativeDnsName).trafficmanager.net"

# 7. Disable primary endpoint to test failover
Set-AzTrafficManagerEndpoint -Name "primary-westeu" -ProfileName $tm.Name `
    -ResourceGroupName "rg-tm-lab" -Type "AzureEndpoints" -EndpointStatus "Disabled"

# 8. Verify DNS now returns secondary
```

---

## AZ-700 Exam Tips & Gotchas

### Traffic Manager vs Other Services

| Requirement | Traffic Manager | Front Door | Load Balancer | App Gateway |
| --- | --- | --- | --- | --- |
| **Layer** | DNS (L7 name resolution) | HTTP/S (L7 proxy) | TCP/UDP (L4) | HTTP/S (L7) |
| **Global/Regional** | Global | Global | Regional* | Regional |
| **Traffic path** | DNS only (client→endpoint) | Through Azure POP | Through LB | Through AppGW |
| **Protocol** | Any (DNS returns IP) | HTTP/HTTPS | TCP/UDP | HTTP/HTTPS |
| **Session affinity** | ❌ | ✅ | ✅ | ✅ |
| **SSL termination** | ❌ | ✅ | ❌ | ✅ |
| **Caching/CDN** | ❌ | ✅ | ❌ | ❌ |
| **WAF** | ❌ | ✅ | ❌ | ✅ |

*Cross-region LB available with Global tier

### Exam Decision Guide

| Scenario | Best Choice | Why |
| --- | --- | --- |
| *"Multi-region web app with CDN and WAF"* | **Front Door** | Global L7 with edge features |
| *"DNS-based failover for any protocol"* | **Traffic Manager** | DNS works with all protocols |
| *"Multi-region app, no WAF needed, cost-sensitive"* | **Traffic Manager** | Cheaper than Front Door |
| *"Geographic routing for data residency"* | **Traffic Manager** | Geographic routing method |
| *"Gradual migration between regions"* | **Traffic Manager** | Weighted routing method |
| *"Combine multiple routing strategies"* | **Traffic Manager** | Nested profiles |

### Common Exam Scenarios

| Question Pattern | Answer |
| --- | --- |
| *"Users must connect to nearest region for lowest latency"* | **Performance** routing |
| *"Primary/secondary disaster recovery"* | **Priority** routing |
| *"A/B testing with 90/10 traffic split"* | **Weighted** routing |
| *"EU users must use EU datacenter (compliance)"* | **Geographic** routing |
| *"Return multiple IPs for client-side balancing"* | **MultiValue** routing |
| *"Route corporate subnets to internal endpoints"* | **Subnet** routing |

### Key Gotchas

1. **Traffic Manager is DNS ONLY** - It never sees actual traffic, just answers DNS queries
2. **TTL matters** - Low TTL = faster failover but more DNS queries; High TTL = slower failover
3. **Health probes from Azure** - Must allow Azure IPs in firewall (no fixed IP list, use Service Tag)
4. **Nested profiles** - Child profile must be healthy for parent to route to it
5. **Geographic routing needs default** - Always configure a "World" fallback or unmapped users fail
6. **Not a proxy** - Cannot modify headers, cache, or terminate SSL

### Troubleshooting Quick Reference

| Symptom | Check | Fix |
| --- | --- | --- |
| Endpoint shows Degraded | Health probe path/response | Fix app health endpoint, allow probe IPs |
| DNS returns wrong region | Routing method, endpoint status | Verify method, check endpoint health |
| Slow failover | TTL value | Lower TTL (30-60 seconds recommended) |
| Geographic mismatch | Geo mapping configuration | Verify regions mapped to correct endpoints |
| Nested profile not working | Child profile health | Ensure child has healthy endpoints |

---

## Cross-Service Relationships

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Traffic Manager Integration                               │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        Traffic Manager                                  │ │
│  │                                                                         │ │
│  │   Endpoints ───────► App Services (Web Apps)                           │ │
│  │             ───────► Cloud Services                                    │ │
│  │             ───────► Public IP addresses (VMs, LBs)                    │ │
│  │             ───────► External endpoints (on-prem, other clouds)        │ │
│  │             ───────► Nested Traffic Manager profiles                   │ │
│  │                                                                         │ │
│  │   Combines with ──► Azure Front Door (TM for non-HTTP, FD for HTTP)   │ │
│  │                ──► Application Gateway (TM global, AppGW regional)    │ │
│  │                ──► Load Balancer (TM → LB → VMs)                      │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  Key Point: TM is DNS only - combine with other services for full stack   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Draw.io Diagram

```xml
<mxfile host="app.diagrams.net">
  <diagram name="Traffic Manager" id="tm-arch">
    <mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1169" pageHeight="827" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <mxCell id="user" value="User" style="shape=actor;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;" vertex="1" parent="1">
          <mxGeometry x="440" y="40" width="40" height="60" as="geometry" />
        </mxCell>
        <mxCell id="tm" value="Traffic Manager&#xa;(DNS-based)&#xa;&#xa;Routing: Performance&#xa;TTL: 30s" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="1">
          <mxGeometry x="360" y="160" width="200" height="100" as="geometry" />
        </mxCell>
        <mxCell id="westus" value="West US&#xa;App Service&#xa;(Healthy)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="160" y="340" width="120" height="80" as="geometry" />
        </mxCell>
        <mxCell id="westeu" value="West Europe&#xa;App Service&#xa;(Healthy)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="400" y="340" width="120" height="80" as="geometry" />
        </mxCell>
        <mxCell id="eastasia" value="East Asia&#xa;App Service&#xa;(Unhealthy)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;" vertex="1" parent="1">
          <mxGeometry x="640" y="340" width="120" height="80" as="geometry" />
        </mxCell>
        <mxCell id="dns1" value="1. DNS Query" style="text;html=1;strokeColor=none;fillColor=none;" vertex="1" parent="1">
          <mxGeometry x="480" y="120" width="80" height="20" as="geometry" />
        </mxCell>
        <mxCell id="dns2" value="2. Return best IP" style="text;html=1;strokeColor=none;fillColor=none;" vertex="1" parent="1">
          <mxGeometry x="280" y="280" width="100" height="20" as="geometry" />
        </mxCell>
        <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="user" target="tm">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e2" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;dashed=1;" edge="1" parent="1" source="tm" target="westus">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e3" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;dashed=1;" edge="1" parent="1" source="tm" target="westeu">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e4" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;dashed=1;" edge="1" parent="1" source="tm" target="eastasia">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```
