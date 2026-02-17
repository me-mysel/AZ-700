---
tags:
  - AZ-700
  - azure/networking
  - azure/monitoring
  - domain/core-networking
  - network-insights
  - azure-monitor
  - topology
  - connection-monitor
  - traffic-analytics
  - diagnostics
aliases:
  - Azure Monitor Network Insights
  - Network Insights
  - Azure Monitor for Networks
created: 2025-01-01
updated: 2026-02-07
---

# Azure Monitor Network Insights

> [!info] Related Notes
> - [[Network_Watcher]] — Diagnostic tools (IP flow verify, next hop, packet capture)
> - [[DDoS_Protection]] — DDoS monitoring and alerts
> - [[Azure_Firewall_and_Firewall_Manager]] — Firewall metrics and logs
> - [[Azure_Load_Balancer]] — Load Balancer insights and health probes
> - [[Application_Gateway]] — AppGW resource view and backend health
> - [[ExpressRoute]] — ExpressRoute circuit insights and topology
> - [[Virtual_WAN]] — Virtual WAN hub monitoring
> - [[VNet_Peering_Routing]] — VNet topology visualization
> - [[Microsoft_Defender_for_Cloud_Networking]] — Security monitoring vs operational monitoring

---

## 1. Key Concepts & Definitions

### What is Azure Monitor Network Insights?

Azure Monitor Network Insights is a **comprehensive, no-configuration-required monitoring solution** that provides a unified view of **health, metrics, topology, and connectivity** for all deployed Azure networking resources. It is part of the **Azure Monitor Insights** family (alongside VM insights, Container insights, etc.) and is accessed through the Azure Monitor blade or Network Watcher.

**Key Characteristics:**
- **Zero configuration** — No agents or setup required; auto-discovers all network resources
- **Cross-subscription visibility** — View resources across multiple subscriptions and resource groups
- **Five pillars of monitoring** — Topology, Network Health & Metrics, Connectivity, Traffic, Diagnostic Toolkit
- **Interactive drill-down** — From global overview → resource type → individual resource → metrics/diagnostics
- **Workbook-based** — Built on Azure Monitor Workbooks; fully customizable

> **⚠️ Exam Point**: Network Insights is part of **Azure Monitor** (not Network Watcher), but it integrates deeply with Network Watcher diagnostic tools, Connection Monitor, NSG flow logs, and Traffic Analytics.

### Core Terminology

| Term | Definition |
|------|-----------|
| **Topology** | Visual map of Azure VNets, subnets, connected resources, and their relationships |
| **Network Health** | Resource health status across all networking resources in selected subscriptions |
| **Metrics Grid** | Pre-configured dashboards showing key performance metrics per resource type |
| **Resource View** | Detailed visualization of individual resource configuration (e.g., AppGW backend pools, LB rules) |
| **Connection Monitor** | Active connectivity probing between Azure/on-prem endpoints (reachability, latency, packet loss) |
| **Traffic Analytics** | NSG flow log analysis providing traffic patterns, bandwidth utilization, and threat intelligence |
| **Diagnostic Toolkit** | Direct access to Network Watcher tools (IP flow verify, next hop, NSG diagnostics, etc.) |

### How It Works

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Azure Monitor Network Insights                           │
│                                                                              │
│   Azure Monitor                                                              │
│       │                                                                      │
│       ├── Networks (Network Insights Landing Page)                           │
│       │       │                                                              │
│       │       ├── TOPOLOGY ──────► Visual map of VNets & resources           │
│       │       │                    Interactive drill-down                     │
│       │       │                    Cross-subscription view                    │
│       │       │                                                              │
│       │       ├── NETWORK HEALTH ► Resource health + metrics grid            │
│       │       │                    Resource type tiles (VNets, LBs, etc.)    │
│       │       │                    Health status + alerts                     │
│       │       │                                                              │
│       │       ├── CONNECTIVITY ──► Connection Monitor results                │
│       │       │                    Reachability, RTT, packet loss             │
│       │       │                    Sources & Destinations view               │
│       │       │                                                              │
│       │       ├── TRAFFIC ───────► Traffic Analytics                         │
│       │       │                    NSG/VNet flow logs analysis               │
│       │       │                    Geo-map of traffic flows                   │
│       │       │                                                              │
│       │       └── DIAGNOSTICS ──► Network Watcher tools                     │
│       │                           IP flow verify, next hop, etc.             │
│       │                                                                      │
│       └── Insights (Other insights: VM, Container, Storage, etc.)           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. The Five Pillars

### Pillar 1: Topology

**Purpose**: Visual representation of Azure virtual networks and connected resources.

**Capabilities:**
- **Multi-subscription, multi-region** view of all VNets
- **Interactive drill-down** from VNet → Subnet → VM → NIC → traffic/connectivity
- **Resource relationships** — Shows VNet peering, VPN connections, ExpressRoute circuits
- **Traffic insights** per resource — Click a VM to see its inbound/outbound flows
- **Search** — Find resources by name (e.g., search for a public IP to find the associated Application Gateway)

**Key Exam Point**: Topology auto-discovers resources via **Azure Resource Graph** — configuration changes may take **up to 30 hours** to reflect in topology.

```
┌─────────────────────────────────────────────────────────────────────────┐
│   TOPOLOGY VIEW (Example)                                                │
│                                                                          │
│   ┌────────────────────┐       Peering       ┌────────────────────┐    │
│   │   Hub VNet         │◄──────────────────►│   Spoke VNet 1     │     │
│   │   10.0.0.0/16      │                     │   10.1.0.0/16      │     │
│   │                    │                     │                    │     │
│   │  ┌──────────────┐ │                     │  ┌──────────────┐ │     │
│   │  │ GatewaySubnet│ │                     │  │ Web Subnet   │ │     │
│   │  │ VPN Gateway  │ │                     │  │  VM1  VM2    │ │     │
│   │  └──────────────┘ │                     │  └──────────────┘ │     │
│   │  ┌──────────────┐ │                     │  ┌──────────────┐ │     │
│   │  │ FW Subnet    │ │                     │  │ App Subnet   │ │     │
│   │  │ Azure FW     │ │                     │  │  VM3  VM4    │ │     │
│   │  └──────────────┘ │                     │  └──────────────┘ │     │
│   └────────────────────┘                     └────────────────────┘     │
│          │                                                               │
│          │ S2S VPN                                                       │
│          ▼                                                               │
│   ┌──────────────┐         Click VM1 for:                                │
│   │ On-premises  │         • Traffic insights                            │
│   │ Network      │         • Connectivity status                         │
│   └──────────────┘         • Network Watcher diagnostics                 │
└─────────────────────────────────────────────────────────────────────────┘
```

### Pillar 2: Network Health & Metrics

**Purpose**: Unified dashboard showing health status and key metrics for ALL network resources.

**Features:**
- **Resource type tiles** — Each networking resource type shows count + health status
- **Color-coded health** — Green (healthy), Red (unavailable), Yellow (degraded)
- **Metrics grid** — Pre-configured metric charts per resource type
- **Resource view** — Detailed config visualization (e.g., Application Gateway showing frontend → listeners → rules → backend pool health)

**Onboarded Resources** (with topology and built-in metrics workbook):

| Resource Type | Key Metrics Available |
|---------------|----------------------|
| Application Gateway | Backend health, throughput, request count, response status |
| Azure Bastion | Session count, memory/CPU |
| Azure Firewall | Rules hit count, data processed, SNAT port utilization |
| Azure Front Door | Request count, latency, WAF block rate |
| ExpressRoute | Bits in/out, BGP availability, ARP availability |
| Load Balancer | Data path availability, health probe status, SNAT connections |
| NAT Gateway | Packets, bytes, SNAT connections, dropped packets |
| Network Interface | Bytes/packets in/out |
| NSG | Rule hit counts (via flow logs) |
| Private Link | Bytes in/out |
| Public IP | Bytes in/out, DDoS trigger events |
| Route Table / UDR | Applied routes count |
| Traffic Manager | Endpoint status, queries returned |
| Virtual Network | Peering status |
| Virtual WAN | Hub status, tunnel health |
| VPN Gateway | Tunnel bandwidth, BGP peer status |

### Pillar 3: Connectivity

**Purpose**: Visualize results from **Connection Monitor** tests.

**Features:**
- **Sources and Destinations** tiles showing reachability status
- **Checks Failed %** and **Round-Trip Time (ms)** graphs
- **Alert integration** — Navigate directly to fired alerts
- **Hop-by-hop topology** — View the network path for each test

**Connection Monitor Setup** (links to Network Watcher Connection Monitor):
- Azure VM → Azure VM (cross-VNet, cross-region)
- Azure VM → On-premises endpoint
- Azure VM → External URL (internet endpoint)

### Pillar 4: Traffic

**Purpose**: Analyze traffic patterns using **Traffic Analytics** (built on NSG flow logs / VNet flow logs).

**Capabilities:**
- **Geo-map** of traffic flows (source/destination countries)
- **Top talkers** (VMs with most traffic)
- **Allowed vs blocked flows** by NSG rules
- **Malicious traffic detection** using threat intelligence
- **Bandwidth utilization** per VNet, subnet, NIC

> **Prerequisite**: Requires **NSG flow logs** or **VNet flow logs** to be enabled and **Traffic Analytics** processing configured with a Log Analytics workspace.

### Pillar 5: Diagnostic Toolkit

**Purpose**: Quick access to Network Watcher diagnostic tools.

**Available Tools:**
- **IP Flow Verify** — Test if traffic is allowed/denied by NSG rules
- **Next Hop** — Determine the next hop for a given IP
- **NSG Diagnostics** — Effective rules analysis
- **Connection Troubleshoot** — Test connectivity between two endpoints
- **Packet Capture** — Capture packets on a VM NIC
- **VPN Troubleshoot** — Diagnose VPN gateway issues

---

## 3. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│               Azure Monitor Network Insights Data Flow                       │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐  │
│   │                     Azure Networking Resources                        │  │
│   │                                                                       │  │
│   │   VNets  Load Balancers  App Gateways  Firewalls  VPN GWs  ER       │  │
│   │   NSGs   NAT Gateways   Front Door    Bastion    PIPs    VWANs     │  │
│   └───────┬──────────┬──────────┬──────────┬──────────┬──────────────┘  │
│           │          │          │          │          │                    │
│           ▼          ▼          ▼          ▼          ▼                    │
│   ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐     │
│   │ Platform │ │ Resource │ │  NSG /   │ │Connection│ │ Resource │      │
│   │ Metrics  │ │  Health  │ │VNet Flow │ │ Monitor  │ │  Graph   │      │
│   │          │ │          │ │  Logs    │ │          │ │(topology)│      │
│   └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘     │
│        │            │            │            │            │              │
│        └─────────┐  │  ┌─────────┘  ┌─────────┘  ┌────────┘              │
│                  ▼  ▼  ▼            ▼            ▼                        │
│         ┌────────────────────────────────────────────────────┐            │
│         │          Azure Monitor Network Insights             │            │
│         │                                                      │            │
│         │   ┌──────────┬──────────┬──────────┬──────────┐    │            │
│         │   │Topology  │ Health   │Connectiv │ Traffic  │    │            │
│         │   │          │& Metrics │ity       │Analytics │    │            │
│         │   └──────────┴──────────┴──────────┴──────────┘    │            │
│         │                                                      │            │
│         │           ┌──────────────────┐                      │            │
│         │           │ Diagnostic       │                      │            │
│         │           │ Toolkit          │                      │            │
│         │           └──────────────────┘                      │            │
│         └────────────────────────────────────────────────────┘            │
│                                                                              │
│   Outputs:                                                                  │
│   • Azure Portal dashboards (Azure Monitor → Networks)                     │
│   • Alerts (metric alerts, log alerts)                                      │
│   • Azure Monitor Workbooks (customizable)                                  │
│   • Log Analytics queries (KQL)                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Configuration Best Practices

### Access Network Insights

```
Azure Portal → Azure Monitor → Networks (under Insights section)
```

Or:

```
Azure Portal → Network Watcher → Network Insights
```

### Enable NSG Flow Logs for Traffic Analytics

```powershell
# Enable NSG flow logs with Traffic Analytics
$nsg = Get-AzNetworkSecurityGroup -Name "nsg-web" -ResourceGroupName "rg-prod"
$workspace = Get-AzOperationalInsightsWorkspace -Name "law-networking" -ResourceGroupName "rg-monitoring"
$storageAccount = Get-AzStorageAccount -Name "stflowlogs" -ResourceGroupName "rg-monitoring"

# Enable NSG flow logs v2 with Traffic Analytics
Set-AzNetworkWatcherConfigFlowLog `
    -NetworkWatcher (Get-AzNetworkWatcher -Name "NetworkWatcher_uksouth" -ResourceGroupName "NetworkWatcherRG") `
    -TargetResourceId $nsg.Id `
    -StorageAccountId $storageAccount.Id `
    -EnableFlowLog $true `
    -FormatType Json `
    -FormatVersion 2 `
    -EnableTrafficAnalytics `
    -TrafficAnalyticsWorkspaceId $workspace.ResourceId `
    -TrafficAnalyticsInterval 10  # Processing interval: 10 or 60 minutes
```

### Enable VNet Flow Logs (Preview)

```powershell
# VNet flow logs provide per-VNet flow collection (vs per-NSG)
# Captures flows even for traffic not hitting an NSG
$vnet = Get-AzVirtualNetwork -Name "vnet-prod" -ResourceGroupName "rg-prod"

New-AzNetworkWatcherFlowLog `
    -NetworkWatcher (Get-AzNetworkWatcher -Name "NetworkWatcher_uksouth" -ResourceGroupName "NetworkWatcherRG") `
    -Name "flowlog-vnet-prod" `
    -TargetResourceId $vnet.Id `
    -StorageAccountId $storageAccount.Id `
    -Enabled $true `
    -EnableTrafficAnalytics `
    -TrafficAnalyticsWorkspaceId $workspace.ResourceId
```

### Create Connection Monitor Test

```powershell
# Create a Connection Monitor test group
$sourceEndpoint = New-AzNetworkWatcherConnectionMonitorEndpointObject `
    -Name "vm-web-01" `
    -AzureVMResourceId "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachines/vm-web-01"

$destEndpoint = New-AzNetworkWatcherConnectionMonitorEndpointObject `
    -Name "vm-db-01" `
    -AzureVMResourceId "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Compute/virtualMachines/vm-db-01"

$testConfig = New-AzNetworkWatcherConnectionMonitorTestConfigurationObject `
    -Name "tcp-1433" `
    -TestFrequencySec 30 `
    -ProtocolConfiguration (New-AzNetworkWatcherConnectionMonitorProtocolConfigurationObject -TcpProtocol -Port 1433) `
    -SuccessThresholdChecksFailedPercent 10 `
    -SuccessThresholdRoundTripTimeMs 100

$testGroup = New-AzNetworkWatcherConnectionMonitorTestGroupObject `
    -Name "web-to-db" `
    -TestConfiguration $testConfig `
    -Source $sourceEndpoint `
    -Destination $destEndpoint

New-AzNetworkWatcherConnectionMonitor `
    -NetworkWatcherName "NetworkWatcher_uksouth" `
    -ResourceGroupName "NetworkWatcherRG" `
    -Name "cm-web-db" `
    -TestGroup $testGroup `
    -Location "uksouth"
```

### Key KQL Queries for Network Insights Data

```kusto
// Top blocked flows by NSG in last 24 hours
AzureNetworkAnalytics_CL
| where TimeGenerated > ago(24h)
| where FlowStatus_s == "D"  // Denied
| summarize BlockedFlows = count() by NSGRules_s, DestIP_s, DestPort_d
| order by BlockedFlows desc
| take 20

// Connection Monitor results - failed checks
NWConnectionMonitorTestResult
| where TimeGenerated > ago(1h)
| where TestResult == "Fail"
| project TimeGenerated, ConnectionMonitorName = SourceName, DestinationName, TestGroupName, ChecksFailed, RoundTripTimeMsThreshold

// ExpressRoute circuit availability
AzureMetrics
| where ResourceProvider == "MICROSOFT.NETWORK"
| where MetricName == "BgpAvailability" or MetricName == "ArpAvailability"
| summarize AvgAvailability = avg(Average) by Resource, MetricName, bin(TimeGenerated, 5m)
```

---

## 5. Comparison Tables

### Network Insights vs Network Watcher vs Defender for Cloud

| Capability | Network Insights | Network Watcher | Defender for Cloud |
|-----------|------------------|----------------|-------------------|
| **Purpose** | Operational monitoring & visualization | Diagnostic tools & troubleshooting | Security posture & threat detection |
| **Scope** | All networking resources | VMs, VNets, NSGs | Security recommendations |
| **Configuration** | Zero config | Per-resource enable | Defender plans |
| **Topology** | ✅ Interactive multi-subscription | ✅ Per-region topology | ❌ No topology |
| **Health dashboard** | ✅ Cross-resource | ❌ Per-tool | ✅ Secure Score |
| **Flow logs** | ✅ Visualizes | ✅ Configures & stores | ❌ No |
| **Traffic Analytics** | ✅ Visualizes | ✅ Processes | ❌ No |
| **Connection Monitor** | ✅ Visualizes results | ✅ Creates & runs | ❌ No |
| **Diagnostics** | ✅ Links to tools | ✅ Runs tools | ❌ No |
| **Security posture** | ❌ No | ❌ No | ✅ Yes |
| **Attack path analysis** | ❌ No | ❌ No | ✅ Yes |

### Network Insights Data Sources

| Tab | Data Source | Prerequisite |
|-----|-----------|-------------|
| Topology | Azure Resource Graph | None (auto-discovered) |
| Network Health | Azure Resource Health + Platform Metrics | None |
| Connectivity | Connection Monitor | Must create Connection Monitor tests |
| Traffic | NSG Flow Logs + Traffic Analytics | Must enable flow logs + Log Analytics workspace |
| Diagnostics | Network Watcher | Network Watcher must be enabled in region |

---

## 6. Exam Tips & Gotchas

### Critical Points (Commonly Tested)

1. **Network Insights ≠ Network Watcher** — Insights is a visualization/monitoring layer in Azure Monitor; Watcher provides the underlying diagnostic tools
2. **Zero configuration for topology and health** — No agents or setup needed for basic monitoring
3. **Traffic Analytics REQUIRES** — NSG flow logs enabled + Log Analytics workspace + Traffic Analytics processing enabled
4. **Connection Monitor REQUIRES** — Network Watcher agent on VMs + Connection Monitor test group configuration
5. **Topology uses Azure Resource Graph** — Changes may take up to **30 hours** to appear in topology
6. **Standard Load Balancer required** for Load Balancer metrics in the metrics dashboard — Basic LB has limited metrics
7. **VNet flow logs are newer than NSG flow logs** — VNet flow logs capture all VNet traffic regardless of NSG presence
8. **Traffic Analytics processing interval** — Can be set to 10 minutes or 60 minutes; 10 minutes costs more but provides near-real-time insights

### Exam Scenarios

| Scenario | Answer |
|----------|--------|
| *"Monitor and visualize all networking resources across subscriptions"* | **Azure Monitor Network Insights** |
| *"See topology of VNets and peering relationships"* | **Network Insights → Topology tab** |
| *"Identify which NSG rule is blocking traffic"* | **Network Watcher → IP Flow Verify** (accessible from Insights → Diagnostics) |
| *"Monitor connectivity between VMs with alerting"* | **Connection Monitor** (visible in Insights → Connectivity) |
| *"Analyze traffic patterns and identify top talkers"* | **Traffic Analytics** (visible in Insights → Traffic) |
| *"View backend health of Application Gateway"* | **Network Insights → Resource View** for AppGW |
| *"Check ExpressRoute circuit BGP availability"* | **Network Insights → Network Health → ExpressRoute tile** |
| *"Troubleshoot VPN gateway connectivity"* | **Network Insights → Diagnostics → VPN Troubleshoot** |

### Common Gotchas

1. **Traffic tab shows nothing** — Flow logs and Traffic Analytics not enabled (common mistake)
2. **Connectivity tab empty** — No Connection Monitor tests configured
3. **Topology shows stale data** — Azure Resource Graph latency (up to 30 hours after changes)
4. **Can't see Basic LB metrics** — Basic SKU has limited metrics support; upgrade to Standard
5. **Connection Monitor requires agent** — Network Watcher agent (or Log Analytics agent) must be installed on VMs
6. **Flow logs have storage costs** — Log data stored in Storage Account + Log Analytics workspace

---

## 7. Hands-On Lab Suggestions

### Lab 1: Explore Network Insights Dashboard

```
1. Navigate to Azure Monitor → Networks
2. Explore the Topology tab — find your VNets and peering relationships
3. Go to Network Health — identify any unhealthy resources
4. Click on a resource type tile → view the metrics grid
5. Select an Application Gateway or Load Balancer → explore the Resource View
6. Search for a specific resource by name in the search bar
```

### Lab 2: Enable End-to-End Monitoring

```powershell
# 1. Enable NSG Flow Logs with Traffic Analytics
# (Use PowerShell commands from Configuration section)

# 2. Create Connection Monitor tests
# (Use PowerShell commands from Configuration section)

# 3. Wait 10-60 minutes for data to flow

# 4. Navigate to Network Insights:
#    - Traffic tab → view flow analytics
#    - Connectivity tab → view Connection Monitor results
#    - Diagnostics tab → run IP flow verify on a VM

# 5. Set up metric alert for LB health probe availability < 100%
$actionGroup = Get-AzActionGroup -Name "ag-network-ops" -ResourceGroupName "rg-monitoring"

Add-AzMetricAlertRuleV2 `
    -Name "alert-lb-health" `
    -ResourceGroupName "rg-monitoring" `
    -TargetResourceId "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.Network/loadBalancers/lb-web" `
    -Condition (New-AzMetricAlertRuleV2Criteria `
        -MetricName "HealthProbeStatus" `
        -Operator "LessThan" `
        -Threshold 100 `
        -TimeAggregation "Average") `
    -ActionGroup $actionGroup.Id `
    -WindowSize 00:05:00 `
    -Frequency 00:01:00 `
    -Severity 2
```

---

## 8. Cross-Service Relationships

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Network Insights Integration Map                          │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                    Azure Monitor Network Insights                       │ │
│  │                                                                         │ │
│  │   Data Sources ───► Azure Resource Health (topology, health)           │ │
│  │               ───► Platform Metrics (LB, AppGW, FW, ER, VPN)         │ │
│  │               ───► NSG / VNet Flow Logs (traffic analysis)            │ │
│  │               ───► Connection Monitor (connectivity probing)          │ │
│  │               ───► Azure Resource Graph (topology discovery)          │ │
│  │                                                                         │ │
│  │   Tools ──────────► Network Watcher (diagnostics, packet capture)     │ │
│  │                                                                         │ │
│  │   Outputs ────────► Azure Dashboards / Workbooks (visualization)      │ │
│  │              ────► Azure Alerts (metric + log alerts)                 │ │
│  │              ────► Log Analytics (KQL queries)                        │ │
│  │              ────► Azure Resource Graph (topology queries)            │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│   Key Monitoring Patterns:                                                  │
│   • Network Insights (what's happening) → Network Watcher (why)            │
│   • Traffic Analytics (traffic patterns) → NSG rules (enforcement)          │
│   • Connection Monitor (reachability) → VPN/ER troubleshoot (fix)          │
│   • Defender for Cloud (security posture) ↔ Network Insights (operations)  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Draw.io Diagram

```xml
<mxfile host="app.diagrams.net">
  <diagram name="Network Insights" id="net-insights">
    <mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1169" pageHeight="827">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <mxCell id="insights" value="Azure Monitor&#xa;Network Insights&#xa;&#xa;Topology | Health | Connectivity&#xa;Traffic | Diagnostics" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;fontSize=12;" vertex="1" parent="1">
          <mxGeometry x="360" y="40" width="280" height="100" as="geometry" />
        </mxCell>
        <mxCell id="nw" value="Network Watcher&#xa;(Diagnostic Tools)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
          <mxGeometry x="100" y="220" width="180" height="60" as="geometry" />
        </mxCell>
        <mxCell id="flowlogs" value="NSG / VNet&#xa;Flow Logs" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
          <mxGeometry x="320" y="220" width="140" height="60" as="geometry" />
        </mxCell>
        <mxCell id="cm" value="Connection&#xa;Monitor" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
          <mxGeometry x="500" y="220" width="140" height="60" as="geometry" />
        </mxCell>
        <mxCell id="rg" value="Azure Resource&#xa;Graph" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
          <mxGeometry x="680" y="220" width="140" height="60" as="geometry" />
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```
