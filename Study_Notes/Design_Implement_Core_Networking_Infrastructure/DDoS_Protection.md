---
tags:
  - AZ-700
  - azure/networking
  - domain/core-networking
  - ddos
  - ddos-protection
  - layer3-layer4
  - adaptive-tuning
  - public-ip
aliases:
  - DDoS Protection
  - Azure DDoS Protection
created: 2025-01-01
updated: 2026-02-07
---

# Azure DDoS Protection

> [!info] Related Notes
> - [[WAF]] — Layer 7 DDoS protection (complementary to L3/L4 DDoS)
> - [[Application_Gateway]] — Application Gateway + DDoS + WAF for defense in depth
> - [[Azure_Front_Door]] — Built-in DDoS at the edge
> - [[Network_Watcher]] — DDoS diagnostic logs and monitoring
> - [[NAT_Gateway]] — DDoS protection on NAT Gateway public IPs

## AZ-700 Exam Domain: Design and Implement Core Networking Infrastructure (25-30%)

---

## 1. Key Concepts & Definitions

### What is Azure DDoS Protection?

**Azure DDoS (Distributed Denial of Service) Protection** is a service that defends your Azure applications against volumetric, protocol, and application-layer DDoS attacks. It automatically detects and mitigates malicious traffic while allowing legitimate traffic to reach your application without impacting availability.

### Why DDoS Protection Matters for AZ-700

DDoS attacks are a critical threat to cloud applications:
- **Availability** — Attacks can overwhelm resources and cause outages
- **Cost** — Attacks can trigger massive auto-scale costs
- **Reputation** — Downtime damages customer trust
- **Compliance** — Many regulations require DDoS protection

### DDoS Attack Types

| Attack Type | OSI Layer | Description | Example |
|-------------|-----------|-------------|---------|
| **Volumetric** | L3/L4 | Flood network bandwidth | UDP floods, ICMP floods |
| **Protocol** | L3/L4 | Exhaust server resources | SYN floods, Smurf attacks |
| **Application** | L7 | Target application weaknesses | HTTP GET/POST floods, Slowloris |

### Azure DDoS Protection Tiers

| Feature | DDoS Network Protection | DDoS IP Protection |
|---------|------------------------|-------------------|
| **Scope** | All resources in VNet | Single Public IP |
| **Pricing** | Monthly + overage | Per protected IP |
| **Protected Resources** | VNet, Public IPs, LB, App GW, etc. | Individual Public IP |
| **Cost Protection** | Yes | Yes |
| **Rapid Response** | Yes (optional add-on) | No |
| **Firewall Manager** | Yes | No |
| **WAF Integration** | Yes | Yes |
| **Best For** | Multiple resources, enterprise | Single resource protection |

> **Note:** DDoS Infrastructure Protection (Basic) is automatically enabled for all Azure resources at no additional cost, providing baseline protection.

### Key Specifications

| Specification | DDoS Network Protection | DDoS IP Protection |
|---------------|------------------------|-------------------|
| **Max protected public IPs** | 200 per plan (can increase) | Per IP |
| **Mitigation capacity** | Azure's full scale | Azure's full scale |
| **Attack telemetry** | Near real-time | Near real-time |
| **Attack alerts** | Yes | Yes |
| **SLA** | 99.99% | 99.99% |
| **Cost guarantee** | Yes (documented attack) | Yes |

---

## 2. Architecture Overview

### DDoS Protection Tier Comparison

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                      AZURE DDoS PROTECTION TIERS                                     │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                 TIER 1: INFRASTRUCTURE PROTECTION (BASIC)                    │   │
│  │                         (Free - Automatic for all Azure)                    │   │
│  │                                                                              │   │
│  │   ┌─────────────────────────────────────────────────────────────────────┐  │   │
│  │   │                                                                      │  │   │
│  │   │  ✓ Always-on traffic monitoring                                     │  │   │
│  │   │  ✓ Automatic attack mitigation                                      │  │   │
│  │   │  ✓ Same protection as Microsoft's own services                      │  │   │
│  │   │  ✗ No telemetry or alerting                                         │  │   │
│  │   │  ✗ No cost protection guarantee                                     │  │   │
│  │   │  ✗ No rapid response support                                        │  │   │
│  │   │                                                                      │  │   │
│  │   │  Best for: Non-critical workloads, dev/test                         │  │   │
│  │   │                                                                      │  │   │
│  │   └─────────────────────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                 TIER 2: DDoS IP PROTECTION (Standard)                        │   │
│  │                      (Per Public IP pricing)                                │   │
│  │                                                                              │   │
│  │   ┌─────────────────────────────────────────────────────────────────────┐  │   │
│  │   │                                                                      │  │   │
│  │   │  ✓ All Basic features PLUS:                                         │  │   │
│  │   │  ✓ Enhanced mitigation for specific public IP                       │  │   │
│  │   │  ✓ Attack telemetry and analytics                                   │  │   │
│  │   │  ✓ Attack alerting                                                  │  │   │
│  │   │  ✓ Cost protection guarantee                                        │  │   │
│  │   │  ✗ No rapid response support                                        │  │   │
│  │   │                                                                      │  │   │
│  │   │  Best for: Protecting 1-2 critical public IPs                       │  │   │
│  │   │                                                                      │  │   │
│  │   └─────────────────────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────┐   │
│  │                 TIER 3: DDoS NETWORK PROTECTION (Standard)                   │   │
│  │                     (Monthly fee + per protected IP)                        │   │
│  │                                                                              │   │
│  │   ┌─────────────────────────────────────────────────────────────────────┐  │   │
│  │   │                                                                      │  │   │
│  │   │  ✓ All IP Protection features PLUS:                                 │  │   │
│  │   │  ✓ Protects ALL public IPs in linked VNets                          │  │   │
│  │   │  ✓ DDoS Rapid Response team support (optional add-on)               │  │   │
│  │   │  ✓ Azure Firewall Manager integration                               │  │   │
│  │   │  ✓ Protection policies and custom tuning                            │  │   │
│  │   │  ✓ Multi-VNet protection with one plan                              │  │   │
│  │   │                                                                      │  │   │
│  │   │  Best for: Enterprise with multiple VNets and public IPs            │  │   │
│  │   │                                                                      │  │   │
│  │   └─────────────────────────────────────────────────────────────────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### DDoS Protection Network Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    DDoS PROTECTION TRAFFIC FLOW                                      │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   NORMAL TRAFFIC FLOW:                                                              │
│   ════════════════════                                                              │
│                                                                                      │
│   Internet Users                                                                    │
│        │                                                                            │
│        ▼                                                                            │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                     AZURE GLOBAL NETWORK EDGE                                │  │
│   │                                                                              │  │
│   │   ┌───────────────────────────────────────────────────────────────────────┐│  │
│   │   │         ALWAYS-ON DDoS TRAFFIC MONITORING                             ││  │
│   │   │                                                                        ││  │
│   │   │  • Analyzing traffic patterns                                         ││  │
│   │   │  • Machine learning models                                            ││  │
│   │   │  • Baseline traffic profiling                                         ││  │
│   │   │  • Status: Monitoring (no attack detected)                            ││  │
│   │   └───────────────────────────────────────────────────────────────────────┘│  │
│   │                                                                              │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│        │                                                                            │
│        ▼                                                                            │
│   ┌──────────────────┐                                                             │
│   │ Your Azure VNet  │ ─────► Application receives traffic normally               │
│   │  (Public IP)     │                                                             │
│   └──────────────────┘                                                             │
│                                                                                      │
│   ────────────────────────────────────────────────────────────────────────────────  │
│                                                                                      │
│   ATTACK TRAFFIC FLOW:                                                              │
│   ════════════════════                                                              │
│                                                                                      │
│   ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐           │
│   │   Botnet A      │      │   Botnet B      │      │   Botnet C      │           │
│   │   (Asia)        │      │   (Europe)      │      │   (Americas)    │           │
│   └────────┬────────┘      └────────┬────────┘      └────────┬────────┘           │
│            │                        │                        │                      │
│            └────────────────────────┼────────────────────────┘                      │
│                                     │                                               │
│                          ┌──────────▼──────────┐                                   │
│                          │   50 Gbps ATTACK    │                                   │
│                          └──────────┬──────────┘                                   │
│                                     │                                               │
│                                     ▼                                               │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                     AZURE GLOBAL NETWORK EDGE                                │  │
│   │                                                                              │  │
│   │   ┌───────────────────────────────────────────────────────────────────────┐│  │
│   │   │         DDoS ATTACK DETECTED - MITIGATION ACTIVE                      ││  │
│   │   │                                                                        ││  │
│   │   │  • Anomaly detected: Traffic 500% above baseline                      ││  │
│   │   │  • Attack type: Volumetric (UDP flood)                                ││  │
│   │   │  • Mitigation: Scrubbing malicious traffic at edge                    ││  │
│   │   │  • Status: Under attack, mitigating                                   ││  │
│   │   │                                                                        ││  │
│   │   │  ┌────────────────────────────────────────────────────────────────┐  ││  │
│   │   │  │               TRAFFIC SCRUBBING                                │  ││  │
│   │   │  │                                                                 │  ││  │
│   │   │  │  50 Gbps attack traffic ──┐                                   │  ││  │
│   │   │  │                           │                                    │  ││  │
│   │   │  │           ┌───────────────▼───────────────┐                   │  ││  │
│   │   │  │           │    DROP: 49.5 Gbps            │                   │  ││  │
│   │   │  │           │    (Malicious traffic)        │                   │  ││  │
│   │   │  │           └───────────────┬───────────────┘                   │  ││  │
│   │   │  │                           │                                    │  ││  │
│   │   │  │           ┌───────────────▼───────────────┐                   │  ││  │
│   │   │  │           │    PASS: 0.5 Gbps             │                   │  ││  │
│   │   │  │           │    (Legitimate traffic)       │                   │  ││  │
│   │   │  │           └───────────────┬───────────────┘                   │  ││  │
│   │   │  │                           │                                    │  ││  │
│   │   │  └───────────────────────────┼────────────────────────────────────┘  ││  │
│   │   └───────────────────────────────┼───────────────────────────────────────┘│  │
│   │                                   │                                         │  │
│   └───────────────────────────────────┼─────────────────────────────────────────┘  │
│                                       │                                            │
│                                       ▼                                            │
│                          ┌──────────────────────┐                                  │
│                          │   Your Azure VNet    │                                  │
│                          │   (Protected)        │                                  │
│                          │                      │                                  │
│                          │   App receives only  │                                  │
│                          │   legitimate traffic │                                  │
│                          └──────────────────────┘                                  │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Protected Resources Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    DDoS NETWORK PROTECTION ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                    DDoS PROTECTION PLAN                                      │  │
│   │                    (One plan can protect multiple VNets)                    │  │
│   │                                                                              │  │
│   │   Plan Name: ddos-plan-prod                                                 │  │
│   │   Resource Group: rg-security                                               │  │
│   │   Linked VNets: 3                                                           │  │
│   │   Protected Public IPs: 15                                                  │  │
│   │                                                                              │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│         │                            │                            │                 │
│         ▼                            ▼                            ▼                 │
│   ┌─────────────┐            ┌─────────────┐            ┌─────────────┐            │
│   │   VNet-Hub  │            │  VNet-Spoke1│            │ VNet-Spoke2 │            │
│   │             │            │             │            │             │            │
│   └──────┬──────┘            └──────┬──────┘            └──────┬──────┘            │
│          │                          │                          │                    │
│   Protected Resources:       Protected Resources:       Protected Resources:        │
│          │                          │                          │                    │
│          ▼                          ▼                          ▼                    │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                                                                              │  │
│   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │  │
│   │  │ Azure        │  │ Application  │  │ VPN Gateway  │  │ Azure        │    │  │
│   │  │ Firewall     │  │ Gateway      │  │              │  │ Bastion      │    │  │
│   │  │ (Public IP)  │  │ (Public IP)  │  │ (Public IP)  │  │ (Public IP)  │    │  │
│   │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │  │
│   │       ✓                  ✓                 ✓                 ✓              │  │
│   │                                                                              │  │
│   │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │  │
│   │  │ Standard     │  │ Virtual      │  │ ExpressRoute │  │ API          │    │  │
│   │  │ Load         │  │ Machine      │  │ Gateway      │  │ Management   │    │  │
│   │  │ Balancer     │  │ (Public IP)  │  │ (Public IP)  │  │ (Public IP)  │    │  │
│   │  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │  │
│   │       ✓                  ✓                 ✓                 ✓              │  │
│   │                                                                              │  │
│   │   ✓ = Protected by DDoS Network Protection                                  │  │
│   │                                                                              │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   NOT PROTECTED (No Public IP):                                                     │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │  • VMs with only private IPs (internal traffic)                             │  │
│   │  • Private Endpoints                                                        │  │
│   │  • Internal Load Balancers                                                  │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Configuration Best Practices

### Create DDoS Protection Plan

```powershell
# Variables
$rgName = "rg-security"
$location = "eastus"
$ddosPlanName = "ddos-plan-prod"

# Create Resource Group
New-AzResourceGroup -Name $rgName -Location $location

# Create DDoS Protection Plan
$ddosPlan = New-AzDdosProtectionPlan `
    -ResourceGroupName $rgName `
    -Name $ddosPlanName `
    -Location $location

Write-Host "DDoS Protection Plan created: $($ddosPlan.Name)"
Write-Host "Resource ID: $($ddosPlan.Id)"
```

### Associate DDoS Plan with VNet

```powershell
# Get existing VNet
$vnet = Get-AzVirtualNetwork -Name "vnet-hub" -ResourceGroupName "rg-networking"

# Get DDoS Protection Plan
$ddosPlan = Get-AzDdosProtectionPlan `
    -ResourceGroupName "rg-security" `
    -Name "ddos-plan-prod"

# Enable DDoS Protection on VNet
$vnet.DdosProtectionPlan = New-Object Microsoft.Azure.Commands.Network.Models.PSResourceId
$vnet.DdosProtectionPlan.Id = $ddosPlan.Id
$vnet.EnableDdosProtection = $true

# Update VNet
Set-AzVirtualNetwork -VirtualNetwork $vnet

Write-Host "DDoS Protection enabled on VNet: $($vnet.Name)"
```

### Configure DDoS IP Protection (Per IP)

```powershell
# Get Public IP to protect
$publicIp = Get-AzPublicIpAddress `
    -Name "pip-appgw-prod" `
    -ResourceGroupName "rg-networking"

# Enable DDoS IP Protection
$publicIp.DdosSettings = New-Object Microsoft.Azure.Commands.Network.Models.PSDdosSettings
$publicIp.DdosSettings.ProtectionMode = "Enabled"

# Update Public IP
Set-AzPublicIpAddress -PublicIpAddress $publicIp

Write-Host "DDoS IP Protection enabled on: $($publicIp.Name)"
```

### Configure Alerts for DDoS Attacks

```powershell
# Variables
$rgName = "rg-security"
$publicIpId = "/subscriptions/xxx/resourceGroups/rg-networking/providers/Microsoft.Network/publicIPAddresses/pip-appgw-prod"
$actionGroupId = "/subscriptions/xxx/resourceGroups/rg-monitoring/providers/Microsoft.Insights/actionGroups/ag-security-team"

# Create alert for "Under DDoS Attack"
$condition = New-AzMetricAlertRuleV2Criteria `
    -MetricName "IfUnderDdosAttack" `
    -MetricNamespace "Microsoft.Network/publicIPAddresses" `
    -Operator GreaterThanOrEqual `
    -Threshold 1 `
    -TimeAggregation Maximum

$actionGroup = New-AzMetricAlertRuleV2ActionGroup `
    -ActionGroupId $actionGroupId

Add-AzMetricAlertRuleV2 `
    -Name "alert-ddos-attack-detected" `
    -ResourceGroupName $rgName `
    -WindowSize 00:05:00 `
    -Frequency 00:01:00 `
    -TargetResourceId $publicIpId `
    -Condition $condition `
    -ActionGroupId $actionGroup.ActionGroupId `
    -Severity 1 `
    -Description "Alert when Public IP is under DDoS attack"

Write-Host "DDoS attack alert configured for pip-appgw-prod"

# Create alert for high packet drop rate
$dropCondition = New-AzMetricAlertRuleV2Criteria `
    -MetricName "PacketsDroppedDDoS" `
    -MetricNamespace "Microsoft.Network/publicIPAddresses" `
    -Operator GreaterThanOrEqual `
    -Threshold 10000 `
    -TimeAggregation Total

Add-AzMetricAlertRuleV2 `
    -Name "alert-ddos-packets-dropped" `
    -ResourceGroupName $rgName `
    -WindowSize 00:05:00 `
    -Frequency 00:01:00 `
    -TargetResourceId $publicIpId `
    -Condition $dropCondition `
    -ActionGroupId $actionGroup.ActionGroupId `
    -Severity 2 `
    -Description "Alert when packets dropped due to DDoS exceeds threshold"

Write-Host "DDoS packet drop alert configured"
```

### View DDoS Metrics

```powershell
# Get DDoS metrics for a Public IP
$publicIpId = "/subscriptions/xxx/resourceGroups/rg-networking/providers/Microsoft.Network/publicIPAddresses/pip-appgw-prod"

# Check if under attack
$attackMetric = Get-AzMetric `
    -ResourceId $publicIpId `
    -MetricName "IfUnderDdosAttack" `
    -StartTime (Get-Date).AddHours(-1) `
    -EndTime (Get-Date) `
    -AggregationType Maximum

if ($attackMetric.Data.Maximum -eq 1) {
    Write-Host "WARNING: Currently under DDoS attack!" -ForegroundColor Red
} else {
    Write-Host "Status: No active DDoS attack" -ForegroundColor Green
}

# Get traffic metrics during potential attack
$inboundMetric = Get-AzMetric `
    -ResourceId $publicIpId `
    -MetricName "BytesInDDoS" `
    -StartTime (Get-Date).AddHours(-1) `
    -EndTime (Get-Date) `
    -AggregationType Total

$droppedMetric = Get-AzMetric `
    -ResourceId $publicIpId `
    -MetricName "BytesDroppedDDoS" `
    -StartTime (Get-Date).AddHours(-1) `
    -EndTime (Get-Date) `
    -AggregationType Total

Write-Host "Last hour statistics:"
Write-Host "  Total inbound bytes: $($inboundMetric.Data.Total)"
Write-Host "  Bytes dropped by DDoS: $($droppedMetric.Data.Total)"
```

### Configure Diagnostic Logs

```powershell
# Variables
$publicIpId = "/subscriptions/xxx/resourceGroups/rg-networking/providers/Microsoft.Network/publicIPAddresses/pip-appgw-prod"
$workspaceId = "/subscriptions/xxx/resourceGroups/rg-monitoring/providers/Microsoft.OperationalInsights/workspaces/law-security"

# Enable diagnostic settings for DDoS
$logCategories = @(
    (New-AzDiagnosticSettingLogSettingsObject -Category "DDoSProtectionNotifications" -Enabled $true),
    (New-AzDiagnosticSettingLogSettingsObject -Category "DDoSMitigationFlowLogs" -Enabled $true),
    (New-AzDiagnosticSettingLogSettingsObject -Category "DDoSMitigationReports" -Enabled $true)
)

$metricCategories = @(
    (New-AzDiagnosticSettingMetricSettingsObject -Category "AllMetrics" -Enabled $true)
)

New-AzDiagnosticSetting `
    -Name "diag-ddos-logs" `
    -ResourceId $publicIpId `
    -WorkspaceId $workspaceId `
    -Log $logCategories `
    -Metric $metricCategories

Write-Host "DDoS diagnostic settings configured"
Write-Host "Logs sent to Log Analytics workspace"
```

### Query DDoS Attack Logs (KQL)

```kql
// View DDoS attack notifications
AzureDiagnostics
| where Category == "DDoSProtectionNotifications"
| project TimeGenerated, Resource, Message_s, Type_s
| order by TimeGenerated desc

// View mitigation flow logs during attack
AzureDiagnostics
| where Category == "DDoSMitigationFlowLogs"
| project TimeGenerated, SourceIP_s, DestinationIP_s, SourcePort_d, 
          DestinationPort_d, Protocol_s, DropReason_s
| order by TimeGenerated desc

// Summarize attack traffic by source
AzureDiagnostics
| where Category == "DDoSMitigationFlowLogs"
| summarize AttackVolume = count() by SourceIP_s
| order by AttackVolume desc
| take 20
```

---

## 4. Comparison Tables

### DDoS Protection Tier Comparison

| Feature | Infrastructure (Basic) | IP Protection | Network Protection |
|---------|----------------------|--------------|-------------------|
| **Cost** | Free | Per Public IP | Monthly + per IP |
| **Automatic Mitigation** | ✓ | ✓ | ✓ |
| **Attack Telemetry** | ✗ | ✓ | ✓ |
| **Attack Alerts** | ✗ | ✓ | ✓ |
| **Mitigation Reports** | ✗ | ✓ | ✓ |
| **Mitigation Policies** | ✗ | ✗ | ✓ |
| **Cost Protection** | ✗ | ✓ | ✓ |
| **Rapid Response** | ✗ | ✗ | ✓ (add-on) |
| **Multi-VNet** | ✗ | ✗ | ✓ |
| **Best For** | Dev/Test | 1-2 IPs | Enterprise |

### DDoS vs WAF Protection

| Aspect | DDoS Protection | Web Application Firewall (WAF) |
|--------|----------------|-------------------------------|
| **OSI Layer** | L3/L4 (Network/Transport) | L7 (Application) |
| **Attack Types** | Volumetric, Protocol | SQL injection, XSS, etc. |
| **Protected Resources** | Any with Public IP | HTTP/HTTPS apps |
| **Deployment** | VNet-wide or per IP | App Gateway, Front Door, CDN |
| **Use Together** | Yes - complementary | Yes - complementary |

### DDoS Attack Types & Mitigation

| Attack Type | Layer | Example | Mitigation Technique |
|-------------|-------|---------|---------------------|
| **UDP Flood** | L3/L4 | Massive UDP packets | Rate limiting, filtering |
| **SYN Flood** | L4 | TCP handshake exhaustion | SYN cookies, rate limiting |
| **DNS Amplification** | L3/L4 | Amplified DNS responses | Source validation |
| **HTTP Flood** | L7 | Massive HTTP requests | WAF + rate limiting |
| **Slowloris** | L7 | Slow HTTP headers | Connection timeout |

---

## 5. Exam Tips & Gotchas

### Critical Points to Memorize

1. **DDoS Basic is always on** — Free protection for all Azure resources automatically

2. **Network Protection = VNet-level** — One plan can protect multiple VNets

3. **IP Protection = Per IP** — Pay per protected Public IP

4. **Standard protects Public IPs only** — Resources without Public IPs aren't protected

5. **Cost Protection requires documented attack** — Submit claim for scale-out costs during attack

6. **Rapid Response is optional add-on** — Only available with Network Protection

7. **DDoS + WAF = Comprehensive protection** — Use both for L3-L7 coverage

8. **Metrics show attack status** — IfUnderDdosAttack = 1 means active attack

9. **15-minute detection guarantee** — Attack detected within 15 minutes

10. **Same mitigation capacity** — All tiers use Azure's full-scale infrastructure

### Common Exam Scenarios

| Scenario | Answer |
|----------|--------|
| "Protect all VNets with one configuration" | DDoS Network Protection Plan |
| "Protect single critical Public IP cost-effectively" | DDoS IP Protection |
| "Get notified during DDoS attack" | Configure metric alerts on IfUnderDdosAttack |
| "Protect against HTTP floods" | WAF + DDoS Protection (complementary) |
| "Cost protection during attack" | DDoS Network/IP Protection + documented claim |
| "Enterprise with Rapid Response needs" | DDoS Network Protection + Rapid Response add-on |
| "View attack telemetry" | Enable diagnostic logs to Log Analytics |
| "Basic protection for dev environment" | DDoS Infrastructure Protection (automatic, free) |

### Common Mistakes to Avoid

1. **Thinking DDoS protects against application attacks** — WAF is needed for L7

2. **Not configuring alerts** — Attacks can go unnoticed without alerting

3. **Forgetting about logging** — Enable diagnostic logs BEFORE an attack

4. **Expecting instant detection** — 15-minute SLA for detection

5. **Confusing Network vs IP Protection** — Network = VNet-wide, IP = per IP

6. **Not understanding cost protection** — Requires documented attack + claim

7. **Assuming private resources are protected** — Only Public IPs are protected

### Key Metrics to Know

| Metric Name | Description |
|-------------|-------------|
| **IfUnderDdosAttack** | 1 = under attack, 0 = normal |
| **PacketsInDDoS** | Total packets entering during attack |
| **PacketsDroppedDDoS** | Packets dropped by mitigation |
| **BytesInDDoS** | Total bytes entering during attack |
| **BytesDroppedDDoS** | Bytes dropped by mitigation |
| **TCPPacketsInDDoS** | TCP packets received |
| **TCPPacketsDroppedDDoS** | TCP packets dropped |
| **UDPPacketsInDDoS** | UDP packets received |
| **UDPPacketsDroppedDDoS** | UDP packets dropped |

---

## 6. Hands-On Lab Suggestions

### Lab 1: Enable DDoS Network Protection

```powershell
# Objective: Create DDoS Plan and protect a VNet

# Step 1: Create DDoS Protection Plan
$ddosPlan = New-AzDdosProtectionPlan `
    -Name "ddos-plan-lab" `
    -ResourceGroupName "rg-ddos-lab" `
    -Location "eastus"

# Step 2: Create or get VNet
$vnet = Get-AzVirtualNetwork -Name "vnet-lab" -ResourceGroupName "rg-ddos-lab"

# Step 3: Enable DDoS Protection on VNet
$vnet.DdosProtectionPlan = @{ Id = $ddosPlan.Id }
$vnet.EnableDdosProtection = $true
Set-AzVirtualNetwork -VirtualNetwork $vnet

# Step 4: Verify protection
$vnetUpdated = Get-AzVirtualNetwork -Name "vnet-lab" -ResourceGroupName "rg-ddos-lab"
Write-Host "DDoS Enabled: $($vnetUpdated.EnableDdosProtection)"
```

### Lab 2: Configure Monitoring and Alerting

```powershell
# Objective: Set up alerts for DDoS attacks

# Step 1: Create Action Group for notifications
# Step 2: Create alert rule for IfUnderDdosAttack metric
# Step 3: Create alert rule for high packet drops
# Step 4: Enable diagnostic logs to Log Analytics
# Step 5: Create Workbook for DDoS visibility
```

### Lab 3: Review Attack Telemetry

```powershell
# Objective: Understand DDoS metrics and logs

# Step 1: Access Azure Monitor metrics for Public IP
# Step 2: Review available DDoS metrics
# Step 3: Query Log Analytics for DDoS logs
# Step 4: Create custom dashboard showing:
#   - Attack status
#   - Traffic volume
#   - Packets dropped
#   - Top source IPs (during attack)
```

---

## 7. Cross-Service Relationships

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    DDoS PROTECTION INTEGRATION MAP                                   │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    COMPLEMENTARY SECURITY SERVICES                          │   │
│   │                                                                             │   │
│   │  Azure Firewall       → Network filtering + DDoS = defense in depth        │   │
│   │  WAF (App Gateway)    → L7 protection + DDoS L3/L4 = full coverage        │   │
│   │  Azure Front Door     → Global edge + WAF + DDoS at edge                  │   │
│   │  Azure CDN            → Cache + DDoS absorption at edge                   │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    MONITORING & MANAGEMENT                                  │   │
│   │                                                                             │   │
│   │  Azure Monitor        → Metrics, alerts, dashboards                        │   │
│   │  Log Analytics        → DDoS diagnostic logs, KQL queries                 │   │
│   │  Firewall Manager     → Centralized policy (Network Protection)           │   │
│   │  Security Center      → Security recommendations                          │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    PROTECTED RESOURCE TYPES                                 │   │
│   │                                                                             │   │
│   │  Application Gateway  → Public-facing web apps                            │   │
│   │  Load Balancer       → Public load balanced services                      │   │
│   │  Virtual Machines    → VMs with Public IPs                                │   │
│   │  VPN Gateway         → Hybrid connectivity endpoint                       │   │
│   │  Azure Bastion       → Secure management access                           │   │
│   │  Azure Firewall      → Centralized network security                       │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    RECOMMENDED ARCHITECTURE                                 │   │
│   │                                                                             │   │
│   │   Internet                                                                  │   │
│   │      │                                                                      │   │
│   │      ▼                                                                      │   │
│   │   Azure DDoS Protection ─────► Mitigate L3/L4 attacks at edge             │   │
│   │      │                                                                      │   │
│   │      ▼                                                                      │   │
│   │   Azure Front Door + WAF ───► Global load balancing + L7 protection       │   │
│   │      │                                                                      │   │
│   │      ▼                                                                      │   │
│   │   Azure Firewall ────────────► Network filtering + threat intelligence    │   │
│   │      │                                                                      │   │
│   │      ▼                                                                      │   │
│   │   Application Gateway + WAF ─► Regional L7 load balancing + protection    │   │
│   │      │                                                                      │   │
│   │      ▼                                                                      │   │
│   │   Backend VMs ────────────────► Application workloads                      │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Quick Reference Card

| Term | Definition |
|------|------------|
| **DDoS** | Distributed Denial of Service attack |
| **Volumetric Attack** | Flood network with massive traffic |
| **Protocol Attack** | Exploit protocol weaknesses (SYN flood) |
| **Application Attack** | Target L7 application layer (HTTP flood) |
| **Mitigation** | Automatic scrubbing of malicious traffic |
| **Scrubbing** | Filtering bad traffic while passing good traffic |
| **DDoS Protection Plan** | Resource that enables Network Protection |
| **Cost Protection** | Guarantee for scale-out costs during attacks |
| **Rapid Response** | 24x7 access to DDoS experts during attack |

---

## Pricing Reference

| Component | DDoS Network Protection | DDoS IP Protection |
|-----------|------------------------|-------------------|
| **Base Fee** | ~$2,944/month | $0 |
| **Per Protected IP** | ~$30/month each | ~$199/month each |
| **Overage** | Per GB over threshold | Per GB over threshold |
| **Rapid Response** | Add-on: $3,000/month | Not available |

*Prices are approximate - check Azure pricing calculator for current rates*

---

## Architecture Diagram File

📂 Open [DDoS_Protection_Architecture.drawio](DDoS_Protection_Architecture.drawio) in VS Code with the Draw.io Integration extension.

---

## Additional Resources

- [Azure DDoS Protection Overview](https://learn.microsoft.com/en-us/azure/ddos-protection/ddos-protection-overview)
- [DDoS Protection Tiers](https://learn.microsoft.com/en-us/azure/ddos-protection/ddos-protection-sku-comparison)
- [Configure DDoS Alerts](https://learn.microsoft.com/en-us/azure/ddos-protection/alerts)
- [DDoS Best Practices](https://learn.microsoft.com/en-us/azure/ddos-protection/fundamental-best-practices)
