---
tags:
  - AZ-700
  - azure/networking
  - domain/core-networking
  - network-watcher
  - diagnostics
  - flow-logs
  - packet-capture
  - connection-monitor
  - ip-flow-verify
  - monitoring
aliases:
  - Network Watcher
  - Azure Network Watcher
created: 2025-01-01
updated: 2026-02-07
---

# Azure Network Watcher

> [!info] Related Notes
> - [[NSG_ASG_Firewall]] — NSG flow logs collected by Network Watcher
> - [[VNet_Peering_Routing]] — Next hop diagnostic for routing issues
> - [[VPN_Gateway]] — Connection troubleshoot for VPN tunnels
> - [[Microsoft_Defender_for_Cloud_Networking]] — Secure Score uses Network Watcher data
> - [[DDoS_Protection]] — DDoS alerts and monitoring integration

## AZ-700 Exam Domain: Design and Implement Core Networking Infrastructure (25-30%)

---

## 1. Key Concepts & Definitions

### What is Azure Network Watcher?

**Azure Network Watcher** is a comprehensive suite of network diagnostic and monitoring tools designed to help you understand, diagnose, and gain insights into your Azure network infrastructure. It provides capabilities to monitor, diagnose, and view metrics for network resources at a regional level.

### Why Network Watcher Matters for AZ-700

Network Watcher is essential for:
- **Troubleshooting connectivity issues** — Determine why traffic isn't reaching its destination
- **Monitoring network health** — Track packet loss, latency, and connection status
- **Capturing traffic** — Analyze packets for security or performance issues
- **Visualizing topology** — Understand network architecture automatically
- **Compliance** — Log and audit network flows for security requirements
- **Proactive alerting** — Get notified before issues impact users

### Core Tools Overview

| Tool | Category | Purpose |
|------|----------|---------|
| **IP Flow Verify** | Diagnose | Check if packet is allowed/denied between source and destination |
| **NSG Diagnostics** | Diagnose | Detailed NSG rule evaluation for traffic |
| **Next Hop** | Diagnose | Determine where traffic will be routed |
| **Connection Troubleshoot** | Diagnose | End-to-end connectivity testing |
| **Packet Capture** | Capture | Record network traffic on VMs |
| **Connection Monitor** | Monitor | Continuous connectivity and latency monitoring |
| **Flow Logs** | Log | NSG/VNet flow logging for analysis |
| **Traffic Analytics** | Analyze | AI-powered traffic insights |
| **Topology** | Visualize | Auto-generated network diagram |

### Network Watcher Specifications

| Specification | Value |
|---------------|-------|
| **Scope** | Per region (auto-enabled) |
| **VM Agent Required** | Yes (for packet capture, connection troubleshoot) |
| **Supported Resources** | VMs, VNets, NSGs, Load Balancers, VPN/ER Gateways |
| **Log Retention** | Configurable (Storage Account or Log Analytics) |
| **Pricing** | Per tool usage (some free, some paid) |

---

## 2. Architecture Overview

### Network Watcher Tool Categories

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                       AZURE NETWORK WATCHER CAPABILITIES                             │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                         DIAGNOSTIC TOOLS                                     │  │
│   │                   (Troubleshoot specific issues)                            │  │
│   │                                                                              │  │
│   │  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐       │  │
│   │  │   IP FLOW VERIFY  │  │    NEXT HOP       │  │  NSG DIAGNOSTICS  │       │  │
│   │  │                   │  │                   │  │                   │       │  │
│   │  │ Q: Will this      │  │ Q: Where will     │  │ Q: Which NSG      │       │  │
│   │  │    packet be      │  │    this packet    │  │    rule allows/   │       │  │
│   │  │    allowed?       │  │    go next?       │  │    denies this?   │       │  │
│   │  │                   │  │                   │  │                   │       │  │
│   │  │ A: Allow/Deny     │  │ A: Next hop type  │  │ A: Rule name,     │       │  │
│   │  │    + Rule name    │  │    + IP address   │  │    priority, etc. │       │  │
│   │  └───────────────────┘  └───────────────────┘  └───────────────────┘       │  │
│   │                                                                              │  │
│   │  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐       │  │
│   │  │   CONNECTION      │  │  EFFECTIVE        │  │    VPN            │       │  │
│   │  │   TROUBLESHOOT    │  │  SECURITY RULES   │  │  TROUBLESHOOT     │       │  │
│   │  │                   │  │                   │  │                   │       │  │
│   │  │ End-to-end test   │  │ All NSG rules     │  │ VPN Gateway       │       │  │
│   │  │ from VM to any    │  │ affecting a NIC   │  │ connection        │       │  │
│   │  │ destination       │  │ (aggregated view) │  │ diagnostics       │       │  │
│   │  └───────────────────┘  └───────────────────┘  └───────────────────┘       │  │
│   │                                                                              │  │
│   └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                         MONITORING TOOLS                                     │  │
│   │               (Continuous monitoring and alerting)                          │  │
│   │                                                                              │  │
│   │  ┌───────────────────────────────────────────────────────────────────────┐  │  │
│   │  │                    CONNECTION MONITOR                                  │  │  │
│   │  │                                                                        │  │  │
│   │  │  Monitor connectivity between:                                         │  │  │
│   │  │  • Azure VM ───────► Azure VM                                         │  │  │
│   │  │  • Azure VM ───────► On-premises server                               │  │  │
│   │  │  • Azure VM ───────► External endpoint (URL/IP)                       │  │  │
│   │  │  • Azure VM ───────► Azure PaaS service                               │  │  │
│   │  │                                                                        │  │  │
│   │  │  Metrics: Latency, % failed probes, round-trip time                   │  │  │
│   │  │  Alerts: Configure threshold-based alerts                             │  │  │
│   │  └───────────────────────────────────────────────────────────────────────┘  │  │
│   │                                                                              │  │
│   └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                      CAPTURE & LOGGING TOOLS                                 │  │
│   │             (Record traffic for analysis and compliance)                    │  │
│   │                                                                              │  │
│   │  ┌───────────────────────────────┐  ┌─────────────────────────────────────┐ │  │
│   │  │       PACKET CAPTURE          │  │         FLOW LOGS                   │ │  │
│   │  │                               │  │                                     │ │  │
│   │  │  • Capture packets on VM NIC  │  │  NSG Flow Logs:                     │ │  │
│   │  │  • Filter by protocol, port   │  │  • Log allowed/denied flows         │ │  │
│   │  │  • Save to Storage/local file │  │  • Per-NSG configuration            │ │  │
│   │  │  • Time/size limits           │  │  • Version 1 or 2 format            │ │  │
│   │  │  • Requires VM agent          │  │                                     │ │  │
│   │  │                               │  │  VNet Flow Logs (Preview):          │ │  │
│   │  │  Use cases:                   │  │  • Log at VNet/subnet level         │ │  │
│   │  │  • Security investigation     │  │  • Simplified management            │ │  │
│   │  │  • Performance analysis       │  │  • All traffic in one place         │ │  │
│   │  │  • Protocol debugging         │  │                                     │ │  │
│   │  └───────────────────────────────┘  └─────────────────────────────────────┘ │  │
│   │                                                                              │  │
│   │  ┌─────────────────────────────────────────────────────────────────────────┐│  │
│   │  │                      TRAFFIC ANALYTICS                                   ││  │
│   │  │                                                                          ││  │
│   │  │  AI-powered analysis of flow logs:                                      ││  │
│   │  │  • Visualize traffic patterns                                           ││  │
│   │  │  • Identify top talkers                                                 ││  │
│   │  │  • Detect anomalies                                                     ││  │
│   │  │  • Security insights (malicious IPs)                                    ││  │
│   │  │  • Requires Log Analytics workspace                                     ││  │
│   │  └─────────────────────────────────────────────────────────────────────────┘│  │
│   │                                                                              │  │
│   └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                       VISUALIZATION TOOL                                     │  │
│   │                                                                              │  │
│   │  ┌─────────────────────────────────────────────────────────────────────────┐│  │
│   │  │                         TOPOLOGY                                         ││  │
│   │  │                                                                          ││  │
│   │  │  Auto-generated visual map showing:                                     ││  │
│   │  │  • VNets and subnets                                                    ││  │
│   │  │  • VMs and NICs                                                         ││  │
│   │  │  • NSGs and their associations                                          ││  │
│   │  │  • Load Balancers                                                       ││  │
│   │  │  • Application Gateways                                                 ││  │
│   │  │  • VNet peerings                                                        ││  │
│   │  │  • VPN/ExpressRoute Gateways                                            ││  │
│   │  │                                                                          ││  │
│   │  │  Export as: SVG, JSON                                                   ││  │
│   │  └─────────────────────────────────────────────────────────────────────────┘│  │
│   │                                                                              │  │
│   └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### IP Flow Verify Decision Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         IP FLOW VERIFY DECISION FLOW                                 │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   INPUT PARAMETERS:                                                                 │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │  • VM (source)                                                               │  │
│   │  • Direction: Inbound or Outbound                                           │  │
│   │  • Protocol: TCP, UDP, or ICMP                                              │  │
│   │  • Local IP (VM's IP)                                                       │  │
│   │  • Local Port                                                               │  │
│   │  • Remote IP                                                                │  │
│   │  • Remote Port                                                              │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                        │                                            │
│                                        ▼                                            │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                     NSG RULE EVALUATION                                      │  │
│   │                                                                              │  │
│   │   For OUTBOUND traffic:                                                     │  │
│   │   1. Subnet NSG outbound rules (if any)                                     │  │
│   │   2. NIC NSG outbound rules (if any)                                        │  │
│   │                                                                              │  │
│   │   For INBOUND traffic:                                                      │  │
│   │   1. NIC NSG inbound rules (if any)                                         │  │
│   │   2. Subnet NSG inbound rules (if any)                                      │  │
│   │                                                                              │  │
│   │   First matching rule wins (by priority)                                    │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                        │                                            │
│                                        ▼                                            │
│   OUTPUT:                                                                           │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │  Result: ALLOW or DENY                                                       │  │
│   │  Rule Name: e.g., "AllowInternetOutBound" or "DenyAllInBound"               │  │
│   │  NSG: Which NSG contains the matching rule                                  │  │
│   │                                                                              │  │
│   │  Example Output:                                                            │  │
│   │  ┌───────────────────────────────────────────────────────────────────────┐ │  │
│   │  │ Access        : Deny                                                   │ │  │
│   │  │ RuleName      : DefaultRule_DenyAllInBound                            │ │  │
│   │  │ NSG           : nsg-frontend                                          │ │  │
│   │  └───────────────────────────────────────────────────────────────────────┘ │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Next Hop Types

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              NEXT HOP TYPES                                          │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   When you query "Next Hop" for a destination IP, you'll get one of these:          │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │  Next Hop Type          │ Meaning                                           │  │
│   │  ───────────────────────┼─────────────────────────────────────────────────  │  │
│   │  Internet               │ Traffic goes to Azure's internet gateway         │  │
│   │  VirtualNetwork         │ Traffic stays within VNet (or peered VNet)       │  │
│   │  VirtualNetworkGateway  │ Traffic goes to VPN/ExpressRoute gateway         │  │
│   │  VnetLocal              │ Traffic is within the same subnet                 │  │
│   │  VirtualAppliance       │ Traffic goes to an NVA (via UDR)                 │  │
│   │  None                   │ Traffic is dropped (no route exists)             │  │
│   │  HyperNetGateway        │ Traffic goes to Virtual WAN                      │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   Example Query:                                                                    │
│   VM: vm-web-001, Destination: 10.1.2.4                                            │
│                                                                                      │
│   Example Output:                                                                   │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │ NextHopType    : VirtualAppliance                                           │  │
│   │ NextHopAddress : 10.0.0.4                                                   │  │
│   │ RouteTable     : rt-spoke-to-hub                                            │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   ⚠️ This tells you: Traffic to 10.1.2.4 will be sent to the firewall at 10.0.0.4 │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Configuration Best Practices

### Enable NSG Flow Logs

```powershell
# Variables
$rgName = "rg-networking-prod"
$location = "eastus"
$nsgName = "nsg-frontend"
$storageAccountName = "stflowlogs001"
$workspaceName = "law-networking"
$nwName = "NetworkWatcher_eastus"

# Get Network Watcher (auto-created per region)
$nw = Get-AzNetworkWatcher -Name $nwName -ResourceGroupName "NetworkWatcherRG"

# Get NSG
$nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $rgName

# Get/Create Storage Account for flow logs
$storageAccount = Get-AzStorageAccount -Name $storageAccountName -ResourceGroupName $rgName

# Get Log Analytics Workspace (for Traffic Analytics)
$workspace = Get-AzOperationalInsightsWorkspace -Name $workspaceName -ResourceGroupName $rgName

# Enable NSG Flow Logs (Version 2 with Traffic Analytics)
Set-AzNetworkWatcherFlowLog `
    -NetworkWatcher $nw `
    -TargetResourceId $nsg.Id `
    -StorageId $storageAccount.Id `
    -EnableFlowLog $true `
    -FormatType "Json" `
    -FormatVersion 2 `
    -EnableTrafficAnalytics $true `
    -TrafficAnalyticsWorkspaceId $workspace.ResourceId `
    -TrafficAnalyticsInterval 10  # Minutes (10 or 60)

Write-Host "NSG Flow Logs enabled for: $nsgName"
Write-Host "Storage Account: $storageAccountName"
Write-Host "Traffic Analytics enabled with 10-minute interval"
```

### Use IP Flow Verify

```powershell
# Test if SSH traffic from internet to VM is allowed
$result = Test-AzNetworkWatcherIPFlow `
    -NetworkWatcher $nw `
    -TargetVirtualMachineId "/subscriptions/xxx/resourceGroups/rg-prod/providers/Microsoft.Compute/virtualMachines/vm-web-001" `
    -Direction "Inbound" `
    -Protocol "TCP" `
    -LocalIPAddress "10.0.1.4" `
    -LocalPort "22" `
    -RemoteIPAddress "203.0.113.50" `
    -RemotePort "55000"

Write-Host "Access: $($result.Access)"
Write-Host "Rule: $($result.RuleName)"

# Expected output if SSH is blocked:
# Access: Deny
# Rule: DefaultRule_DenyAllInBound
```

### Use Next Hop

```powershell
# Determine next hop for traffic from VM to destination
$nextHop = Get-AzNetworkWatcherNextHop `
    -NetworkWatcher $nw `
    -TargetVirtualMachineId "/subscriptions/xxx/resourceGroups/rg-prod/providers/Microsoft.Compute/virtualMachines/vm-web-001" `
    -SourceIPAddress "10.0.1.4" `
    -DestinationIPAddress "10.1.2.4"

Write-Host "Next Hop Type: $($nextHop.NextHopType)"
Write-Host "Next Hop IP: $($nextHop.NextHopIpAddress)"
Write-Host "Route Table: $($nextHop.RouteTableId)"

# If traffic should go through firewall, expect:
# NextHopType: VirtualAppliance
# NextHopIpAddress: 10.0.0.4 (firewall IP)
```

### Use Connection Troubleshoot

```powershell
# Test end-to-end connectivity from VM to destination
$connectionTest = Test-AzNetworkWatcherConnectivity `
    -NetworkWatcher $nw `
    -SourceId "/subscriptions/xxx/resourceGroups/rg-prod/providers/Microsoft.Compute/virtualMachines/vm-web-001" `
    -DestinationAddress "www.microsoft.com" `
    -DestinationPort 443 `
    -Protocol "Tcp"

Write-Host "Connection Status: $($connectionTest.ConnectionStatus)"
Write-Host "Average Latency: $($connectionTest.AvgLatencyInMs) ms"
Write-Host "Min Latency: $($connectionTest.MinLatencyInMs) ms"
Write-Host "Max Latency: $($connectionTest.MaxLatencyInMs) ms"
Write-Host "Probes Sent: $($connectionTest.ProbesSent)"
Write-Host "Probes Failed: $($connectionTest.ProbesFailed)"

# View hops
Write-Host "`nHops:"
$connectionTest.Hops | ForEach-Object {
    Write-Host "  $($_.Type): $($_.Address) - $($_.Issues)"
}
```

### Create Packet Capture

```powershell
# Create packet capture on VM
$packetCapture = New-AzNetworkWatcherPacketCapture `
    -NetworkWatcher $nw `
    -TargetVirtualMachineId "/subscriptions/xxx/resourceGroups/rg-prod/providers/Microsoft.Compute/virtualMachines/vm-web-001" `
    -PacketCaptureName "capture-debug-001" `
    -StorageAccountId $storageAccount.Id `
    -StoragePath "https://$storageAccountName.blob.core.windows.net/packetcapture" `
    -TimeLimitInSeconds 300 `
    -BytesToCapturePerPacket 0 `
    -TotalBytesPerSession 104857600 `
    -Filter @(
        @{
            Protocol = "TCP"
            LocalPort = "443"
        }
    )

Write-Host "Packet capture started: $($packetCapture.Name)"
Write-Host "Duration: 5 minutes"
Write-Host "Filter: TCP port 443"

# Check capture status
Get-AzNetworkWatcherPacketCapture `
    -NetworkWatcher $nw `
    -PacketCaptureName "capture-debug-001"

# Stop capture manually if needed
Stop-AzNetworkWatcherPacketCapture `
    -NetworkWatcher $nw `
    -PacketCaptureName "capture-debug-001"
```

### Create Connection Monitor

```powershell
# Create test group for Connection Monitor
$testGroup = New-AzNetworkWatcherConnectionMonitorTestGroupObject `
    -Name "tg-web-to-api" `
    -TestConfigurationName "tc-http-443" `
    -SourceEndpoint "ep-vm-web" `
    -DestinationEndpoint "ep-api-server"

# Create source endpoint (Azure VM)
$sourceEndpoint = New-AzNetworkWatcherConnectionMonitorEndpointObject `
    -Name "ep-vm-web" `
    -ResourceId "/subscriptions/xxx/resourceGroups/rg-prod/providers/Microsoft.Compute/virtualMachines/vm-web-001"

# Create destination endpoint (external URL)
$destEndpoint = New-AzNetworkWatcherConnectionMonitorEndpointObject `
    -Name "ep-api-server" `
    -Address "api.contoso.com"

# Create test configuration
$testConfig = New-AzNetworkWatcherConnectionMonitorTestConfigurationObject `
    -Name "tc-http-443" `
    -Protocol "Tcp" `
    -TcpPortNumber 443 `
    -TestFrequencySec 30 `
    -SuccessThresholdChecksFailedPercent 10 `
    -SuccessThresholdRoundTripTimeMs 100

# Create Connection Monitor
New-AzNetworkWatcherConnectionMonitor `
    -NetworkWatcherName $nwName `
    -ResourceGroupName "NetworkWatcherRG" `
    -Name "cm-web-to-api" `
    -TestGroup $testGroup `
    -Endpoint $sourceEndpoint, $destEndpoint `
    -TestConfiguration $testConfig `
    -Location $location

Write-Host "Connection Monitor created: cm-web-to-api"
Write-Host "Test frequency: every 30 seconds"
Write-Host "Alert threshold: >10% failed probes or >100ms latency"
```

### View Topology

```powershell
# Get topology for a resource group
$topology = Get-AzNetworkWatcherTopology `
    -NetworkWatcher $nw `
    -TargetResourceGroupName $rgName

Write-Host "Topology Resources:"
$topology.Resources | ForEach-Object {
    Write-Host "  $($_.Name) ($($_.Id))"
    $_.Associations | ForEach-Object {
        Write-Host "    -> $($_.Name) ($($_.AssociationType))"
    }
}

# Export topology to JSON
$topology | ConvertTo-Json -Depth 10 | Out-File "topology-export.json"
```

---

## 4. Comparison Tables

### Diagnostic Tools Comparison

| Tool | Use Case | Input | Output |
|------|----------|-------|--------|
| **IP Flow Verify** | "Is this traffic allowed by NSG?" | VM, direction, protocol, ports, IPs | Allow/Deny + rule name |
| **Next Hop** | "Where will this traffic go?" | VM, source IP, destination IP | Next hop type + IP |
| **NSG Diagnostics** | "Which rules affect this traffic?" | NIC, direction, protocol, ports, IPs | Detailed rule evaluation |
| **Connection Troubleshoot** | "Can VM reach destination?" | VM, destination (IP/URL), port | Connectivity status + hops |
| **Effective Security Rules** | "What are all rules on this NIC?" | NIC | Aggregated NSG rules list |

### Flow Logs: NSG vs VNet

| Feature | NSG Flow Logs | VNet Flow Logs |
|---------|--------------|----------------|
| **Scope** | Per NSG | Per VNet or Subnet |
| **Configuration** | Enable on each NSG | Enable once for VNet |
| **Traffic Captured** | Only traffic through NSG | All VNet traffic |
| **Management** | Many NSGs = many configs | Simplified |
| **GA Status** | GA | Preview |
| **Best For** | Granular control | Simplicity |

### Connection Monitor vs Azure Monitor

| Aspect | Connection Monitor | Azure Monitor (Metrics) |
|--------|-------------------|------------------------|
| **Purpose** | Active probing (synthetic tests) | Passive monitoring (real traffic) |
| **What it measures** | Can I reach destination? | What traffic is flowing? |
| **Latency** | Probe round-trip time | Actual traffic latency |
| **Sources** | Azure VMs, on-prem (with agent) | Azure resources |
| **Destinations** | Any IP, URL, or Azure resource | N/A |
| **Cost** | Per test per month | Included with resource |

---

## 5. Exam Tips & Gotchas

### Critical Points to Memorize

1. **Network Watcher is regional** — Auto-enabled per region, works only in that region

2. **VM agent required for some tools** — Packet Capture and Connection Troubleshoot need the Network Watcher Agent extension

3. **IP Flow Verify checks NSGs only** — Doesn't check firewalls, UDRs, or route tables

4. **Next Hop shows routing** — Tells you the route, NOT if traffic is allowed by NSG

5. **Flow Logs need Storage Account** — In the same region as the NSG/VNet

6. **Traffic Analytics needs Log Analytics** — Requires workspace for AI-powered analysis

7. **Connection Monitor replaces Network Performance Monitor** — NPM is deprecated

8. **Packet Capture has limits** — Time limit, byte limits; stored in Storage Account

9. **NSG Diagnostics vs IP Flow Verify** — Diagnostics gives more detail about rule evaluation

10. **Topology is auto-generated** — No configuration needed, real-time view

### Common Exam Scenarios

| Scenario | Tool to Use |
|----------|-------------|
| "VM can't reach the internet" | IP Flow Verify (outbound) + Next Hop |
| "Traffic is denied but I don't know which rule" | IP Flow Verify or NSG Diagnostics |
| "Need to capture packets for security analysis" | Packet Capture |
| "Monitor latency between VM and API endpoint" | Connection Monitor |
| "Analyze traffic patterns and top talkers" | Flow Logs + Traffic Analytics |
| "Visualize network architecture" | Topology |
| "Determine next hop for packet" | Next Hop |
| "Check if routing is correct" | Next Hop |
| "Continuous connectivity monitoring" | Connection Monitor |
| "One-time connectivity test" | Connection Troubleshoot |

### Common Mistakes to Avoid

1. **Confusing IP Flow Verify with Next Hop** — IP Flow = NSG rules, Next Hop = routing
2. **Forgetting VM agent for packet capture** — Will fail without Network Watcher extension
3. **Using wrong region's Network Watcher** — Must match the resource's region
4. **Not enabling Traffic Analytics** — Flow logs without analytics = manual analysis
5. **Packet capture without filters** — Can capture massive amounts of data
6. **Expecting real-time flow logs** — There's a delay in processing

### Key Limits to Remember

| Resource | Limit |
|----------|-------|
| Packet capture duration | 5 hours max |
| Packet capture size | 1 GB max |
| Concurrent packet captures | 10 per region |
| Connection Monitor test groups | 20 per monitor |
| Connection Monitor endpoints | 25 per test group |
| Flow log retention | Configurable (Storage Account) |

---

## 6. Hands-On Lab Suggestions

### Lab 1: Troubleshoot Connectivity Issues

```powershell
# Scenario: VM cannot reach an external API

# Step 1: Use IP Flow Verify to check if outbound traffic is allowed
Test-AzNetworkWatcherIPFlow -NetworkWatcher $nw `
    -TargetVirtualMachineId $vmId `
    -Direction "Outbound" `
    -Protocol "TCP" `
    -LocalIPAddress "10.0.1.4" -LocalPort "50000" `
    -RemoteIPAddress "52.1.2.3" -RemotePort "443"

# Step 2: If allowed, check Next Hop to verify routing
Get-AzNetworkWatcherNextHop -NetworkWatcher $nw `
    -TargetVirtualMachineId $vmId `
    -SourceIPAddress "10.0.1.4" `
    -DestinationIPAddress "52.1.2.3"

# Step 3: If routing looks correct, use Connection Troubleshoot
Test-AzNetworkWatcherConnectivity -NetworkWatcher $nw `
    -SourceId $vmId `
    -DestinationAddress "52.1.2.3" `
    -DestinationPort 443 -Protocol "Tcp"

# Step 4: Analyze results to identify the issue
```

### Lab 2: Enable Flow Logs with Traffic Analytics

```powershell
# Step 1: Create Storage Account for flow logs
# Step 2: Create Log Analytics Workspace
# Step 3: Enable NSG Flow Logs with Traffic Analytics
# Step 4: Wait 10-30 minutes for data to appear
# Step 5: Query Traffic Analytics in Azure Portal:
#   - Top talkers
#   - Blocked traffic
#   - Traffic by port
```

### Lab 3: Create Connection Monitor for SLA Monitoring

```powershell
# Monitor connectivity from multiple VMs to critical endpoints
# Set up alerts for:
#   - Latency > 100ms
#   - Failed probes > 10%
# Review metrics in Azure Monitor
```

---

## 7. Cross-Service Relationships

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         NETWORK WATCHER INTEGRATION MAP                              │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    DATA STORAGE INTEGRATION                                 │   │
│   │                                                                             │   │
│   │  Storage Account     → Flow logs, packet captures                          │   │
│   │  Log Analytics       → Traffic Analytics, Connection Monitor metrics       │   │
│   │  Azure Monitor       → Alerts, dashboards, metrics                         │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    RESOURCES MONITORED                                      │   │
│   │                                                                             │   │
│   │  Virtual Machines    → Packet capture, Connection Troubleshoot            │   │
│   │  NSGs                → Flow logs, IP Flow Verify                          │   │
│   │  VNets               → VNet Flow Logs, Topology                           │   │
│   │  VPN Gateways        → VPN Troubleshoot                                   │   │
│   │  Load Balancers      → Topology visualization                             │   │
│   │  Application Gateway → Topology visualization                             │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    TROUBLESHOOTING WORKFLOW                                 │   │
│   │                                                                             │   │
│   │   1. Topology        → Understand network architecture                     │   │
│   │   2. IP Flow Verify  → Check if NSG allows traffic                        │   │
│   │   3. Next Hop        → Verify routing is correct                          │   │
│   │   4. Connection Test → End-to-end connectivity                            │   │
│   │   5. Packet Capture  → Deep dive into specific traffic                    │   │
│   │   6. Flow Logs       → Historical traffic analysis                        │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Quick Reference Card

| Tool | Purpose | Key Metric |
|------|---------|------------|
| **IP Flow Verify** | NSG rule check | Allow/Deny |
| **Next Hop** | Routing path | Next hop type + IP |
| **Connection Troubleshoot** | End-to-end test | Reachable/Unreachable |
| **Connection Monitor** | Continuous monitoring | Latency, % failed |
| **Packet Capture** | Traffic recording | PCAP file |
| **Flow Logs** | Traffic logging | JSON logs |
| **Traffic Analytics** | AI insights | Dashboards |
| **Topology** | Visualization | Network diagram |

---

## Architecture Diagram File

📂 Open [Network_Watcher_Architecture.drawio](Network_Watcher_Architecture.drawio) in VS Code with the Draw.io Integration extension.

---

## Additional Resources

- [Network Watcher Documentation](https://learn.microsoft.com/en-us/azure/network-watcher/)
- [Troubleshoot Connections with Network Watcher](https://learn.microsoft.com/en-us/azure/network-watcher/network-watcher-connectivity-overview)
- [NSG Flow Logs](https://learn.microsoft.com/en-us/azure/network-watcher/network-watcher-nsg-flow-logging-overview)
- [Traffic Analytics](https://learn.microsoft.com/en-us/azure/network-watcher/traffic-analytics)
