---
tags:
  - AZ-700
  - azure/networking
  - domain/core-networking
  - avnm
  - network-groups
  - connectivity-config
  - security-admin-rules
  - mesh-topology
  - hub-spoke
  - governance
aliases:
  - AVNM
  - Azure Virtual Network Manager
created: 2025-01-01
updated: 2026-02-07
---

# Azure Virtual Network Manager (AVNM)

> [!info] Related Notes
> - [[VNet_Peering_Routing]] — Traditional peering (AVNM automates this)
> - [[VNet_Subnets_IP_Addressing]] — VNet structure managed by AVNM
> - [[NSG_ASG_Firewall]] — Security admin rules vs NSGs
> - [[Azure_Firewall_and_Firewall_Manager]] — Complementary centralized security

## AZ-700 Exam Domain: Design and Implement Core Networking Infrastructure (25-30%)

---

## 1. Key Concepts & Definitions

### What is Azure Virtual Network Manager?

**Azure Virtual Network Manager (AVNM)** is a centralized network management service that enables you to group, configure, deploy, and manage virtual networks at scale across subscriptions, regions, and even Azure AD tenants. It provides a single pane of glass for managing complex network topologies and enforcing security policies across your entire Azure network infrastructure.

### Why AVNM Matters

In large enterprise environments, managing hundreds or thousands of VNets manually becomes unsustainable:
- **Manual peering** — Each VNet-to-VNet connection requires separate configuration
- **Security consistency** — NSGs must be configured individually on each subnet
- **Cross-subscription complexity** — Managing VNets across subscriptions is error-prone
- **Scale limitations** — Traditional hub-spoke requires manual setup for each spoke

**AVNM solves these challenges** by providing:
- Automated topology management (hub-spoke, mesh)
- Dynamic network group membership based on tags/conditions
- Security Admin rules that override NSGs for centralized policy enforcement
- Cross-subscription and cross-region management from a single location

### Core Terminology

| Term | Definition |
|------|------------|
| **Network Manager** | Top-level Azure resource that defines the scope and access for network management |
| **Scope** | The management groups, subscriptions, or VNets that the Network Manager can manage |
| **Scope Access** | Permissions granted: Connectivity, SecurityAdmin, or both |
| **Network Group** | A logical collection of VNets for applying configurations |
| **Static Membership** | Manually adding VNets to a network group |
| **Dynamic Membership** | Auto-adding VNets based on Azure Policy conditions (tags, names, etc.) |
| **Connectivity Configuration** | Defines network topology (Hub-Spoke, Mesh) |
| **Security Admin Configuration** | Defines security rules that can override NSGs |
| **Deployment** | The action of applying configurations to target regions |
| **Commit** | Finalizing and deploying a configuration |

### AVNM Specifications

| Specification | Value |
|---------------|-------|
| **Max Network Managers per subscription** | 100 |
| **Max Network Groups per Network Manager** | 100 |
| **Max VNets per Network Group** | 1,000 |
| **Max Security Admin Rules per configuration** | 100 |
| **Supported Regions** | Most Azure regions |
| **Cross-region** | Yes (Global Mesh) |
| **Cross-subscription** | Yes |
| **Cross-tenant** | Yes (with proper permissions) |

---

## 2. Architecture Overview

### AVNM Hierarchical Structure

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                    AZURE VIRTUAL NETWORK MANAGER ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                           MANAGEMENT HIERARCHY                               │  │
│   │                                                                              │  │
│   │   ┌─────────────────────────────────────────────────────────────────────┐   │  │
│   │   │                    NETWORK MANAGER SCOPE                             │   │  │
│   │   │                                                                      │   │  │
│   │   │   Can be scoped to:                                                  │   │  │
│   │   │   • Management Group (manage all child subscriptions)               │   │  │
│   │   │   • Subscription(s) (one or more)                                   │   │  │
│   │   │   • VNets (specific VNets only)                                     │   │  │
│   │   │                                                                      │   │  │
│   │   │   Scope Access Options:                                              │   │  │
│   │   │   • Connectivity — Create topology configurations                   │   │  │
│   │   │   • SecurityAdmin — Create security rules that override NSGs        │   │  │
│   │   │   • Both — Full management capabilities                             │   │  │
│   │   └─────────────────────────────────────────────────────────────────────┘   │  │
│   │                                    │                                         │  │
│   │                                    ▼                                         │  │
│   │   ┌─────────────────────────────────────────────────────────────────────┐   │  │
│   │   │                      NETWORK MANAGER                                 │   │  │
│   │   │                    nm-enterprise-001                                │   │  │
│   │   │                                                                      │   │  │
│   │   │   Location: East US (metadata only, manages all regions)            │   │  │
│   │   │   Scope: /providers/Microsoft.Management/managementGroups/corp      │   │  │
│   │   │   Access: Connectivity, SecurityAdmin                               │   │  │
│   │   └─────────────────────────────────────────────────────────────────────┘   │  │
│   │                                    │                                         │  │
│   │              ┌─────────────────────┼─────────────────────┐                  │  │
│   │              ▼                     ▼                     ▼                  │  │
│   │   ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐         │  │
│   │   │  Network Group   │  │  Network Group   │  │  Network Group   │         │  │
│   │   │  "ng-production" │  │  "ng-development"│  │  "ng-hub-vnets"  │         │  │
│   │   │                  │  │                  │  │                  │         │  │
│   │   │  Membership:     │  │  Membership:     │  │  Membership:     │         │  │
│   │   │  DYNAMIC         │  │  DYNAMIC         │  │  STATIC          │         │  │
│   │   │  tag: Env=Prod   │  │  tag: Env=Dev    │  │  (manual VNets)  │         │  │
│   │   │                  │  │                  │  │                  │         │  │
│   │   │  VNets: 45       │  │  VNets: 12       │  │  VNets: 3        │         │  │
│   │   └──────────────────┘  └──────────────────┘  └──────────────────┘         │  │
│   │                                                                              │  │
│   └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                           CONFIGURATIONS                                     │  │
│   │                                                                              │  │
│   │   ┌────────────────────────────────┐  ┌─────────────────────────────────┐  │  │
│   │   │   CONNECTIVITY CONFIGURATION   │  │  SECURITY ADMIN CONFIGURATION    │  │  │
│   │   │   config-hubspoke-prod         │  │  config-security-baseline        │  │  │
│   │   │                                │  │                                  │  │  │
│   │   │   Topology: Hub-and-Spoke      │  │  Rule Collections:               │  │  │
│   │   │   Hub: vnet-hub-eus            │  │  ├─ rc-deny-rules                │  │  │
│   │   │   Spokes: ng-production        │  │  │   • deny-ssh-from-internet   │  │  │
│   │   │                                │  │  │   • deny-rdp-from-internet   │  │  │
│   │   │   Options:                     │  │  │                               │  │  │
│   │   │   • UseHubGateway: true        │  │  ├─ rc-always-allow             │  │  │
│   │   │   • DirectlyConnected: false   │  │  │   • allow-azure-bastion      │  │  │
│   │   │                                │  │  │   • allow-lb-health-probe    │  │  │
│   │   └────────────────────────────────┘  └─────────────────────────────────┘  │  │
│   │                                                                              │  │
│   └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                           DEPLOYMENTS                                        │  │
│   │                                                                              │  │
│   │   Configurations must be DEPLOYED to take effect (per region):              │  │
│   │                                                                              │  │
│   │   Region: East US          Region: West Europe      Region: UK South        │  │
│   │   ┌─────────────────┐     ┌─────────────────┐      ┌─────────────────┐     │  │
│   │   │ ✓ Connectivity  │     │ ✓ Connectivity  │      │ ✓ Connectivity  │     │  │
│   │   │ ✓ SecurityAdmin │     │ ✓ SecurityAdmin │      │ ○ Pending...    │     │  │
│   │   └─────────────────┘     └─────────────────┘      └─────────────────┘     │  │
│   │                                                                              │  │
│   └──────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Connectivity Topologies

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         AVNM CONNECTIVITY TOPOLOGIES                                 │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   TOPOLOGY 1: HUB-AND-SPOKE                                                         │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                                                                              │  │
│   │                        ┌───────────────┐                                    │  │
│   │                        │   HUB VNET    │                                    │  │
│   │                        │  10.0.0.0/16  │                                    │  │
│   │                        │               │                                    │  │
│   │                        │  • Firewall   │                                    │  │
│   │                        │  • VPN GW     │                                    │  │
│   │                        │  • Bastion    │                                    │  │
│   │                        └───────┬───────┘                                    │  │
│   │                                │                                            │  │
│   │          ┌─────────────────────┼─────────────────────┐                     │  │
│   │          │                     │                     │                     │  │
│   │          ▼                     ▼                     ▼                     │  │
│   │   ┌───────────┐         ┌───────────┐         ┌───────────┐               │  │
│   │   │  SPOKE 1  │         │  SPOKE 2  │         │  SPOKE 3  │               │  │
│   │   │10.1.0.0/16│         │10.2.0.0/16│         │10.3.0.0/16│               │  │
│   │   └───────────┘         └───────────┘         └───────────┘               │  │
│   │                                                                              │  │
│   │   Options:                                                                  │  │
│   │   • UseHubGateway: true/false — Spoke uses hub's VPN/ER gateway            │  │
│   │   • DirectlyConnected: true/false — Spokes can reach each other directly   │  │
│   │                                                                              │  │
│   │   Traffic Flow (DirectlyConnected: false):                                  │  │
│   │   Spoke1 ──► Hub ──► Spoke2 (all traffic through hub)                       │  │
│   │                                                                              │  │
│   │   Traffic Flow (DirectlyConnected: true):                                   │  │
│   │   Spoke1 ──────────► Spoke2 (direct peering auto-created)                   │  │
│   │                                                                              │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   TOPOLOGY 2: MESH (Single Region)                                                  │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                                                                              │  │
│   │        ┌───────────┐                   ┌───────────┐                        │  │
│   │        │  VNET 1   │◄─────────────────►│  VNET 2   │                        │  │
│   │        │10.1.0.0/16│                   │10.2.0.0/16│                        │  │
│   │        └─────┬─────┘                   └─────┬─────┘                        │  │
│   │              │                               │                              │  │
│   │              │         Full Mesh             │                              │  │
│   │              │    (all-to-all peering)       │                              │  │
│   │              │                               │                              │  │
│   │              ▼                               ▼                              │  │
│   │        ┌───────────┐                   ┌───────────┐                        │  │
│   │        │  VNET 3   │◄─────────────────►│  VNET 4   │                        │  │
│   │        │10.3.0.0/16│                   │10.4.0.0/16│                        │  │
│   │        └───────────┘                   └───────────┘                        │  │
│   │                                                                              │  │
│   │   Use Case: Low-latency spoke-to-spoke communication without hub transit    │  │
│   │                                                                              │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   TOPOLOGY 3: GLOBAL MESH (Cross-Region)                                            │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                                                                              │  │
│   │     EAST US                                      WEST EUROPE                 │  │
│   │   ┌───────────┐                               ┌───────────┐                 │  │
│   │   │  VNET 1   │◄═════════════════════════════►│  VNET 3   │                 │  │
│   │   │10.1.0.0/16│         Global Peering        │10.3.0.0/16│                 │  │
│   │   └─────┬─────┘                               └─────┬─────┘                 │  │
│   │         │                                           │                       │  │
│   │         ▼                                           ▼                       │  │
│   │   ┌───────────┐                               ┌───────────┐                 │  │
│   │   │  VNET 2   │◄═════════════════════════════►│  VNET 4   │                 │  │
│   │   │10.2.0.0/16│                               │10.4.0.0/16│                 │  │
│   │   └───────────┘                               └───────────┘                 │  │
│   │                                                                              │  │
│   │   Use Case: Multi-region applications requiring direct cross-region access  │  │
│   │   Note: Global peering incurs cross-region data transfer charges            │  │
│   │                                                                              │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

### Security Admin Rules Flow

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                       SECURITY ADMIN RULES EVALUATION                                │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   Traffic arrives at a VM's NIC. How are rules evaluated?                           │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐  │
│   │                                                                              │  │
│   │   STEP 1: SECURITY ADMIN RULES (Evaluated FIRST - from AVNM)               │  │
│   │   ┌──────────────────────────────────────────────────────────────────────┐ │  │
│   │   │                                                                       │ │  │
│   │   │  Rule Action      │ Behavior                                         │ │  │
│   │   │  ─────────────────┼────────────────────────────────────────────────  │ │  │
│   │   │  DENY             │ Block traffic. NSG rules NOT evaluated.          │ │  │
│   │   │                   │ Cannot be overridden by local admins.            │ │  │
│   │   │  ─────────────────┼────────────────────────────────────────────────  │ │  │
│   │   │  ALLOW            │ Permit this rule, but NSG still evaluated.       │ │  │
│   │   │                   │ NSG can still deny the traffic.                  │ │  │
│   │   │  ─────────────────┼────────────────────────────────────────────────  │ │  │
│   │   │  ALWAYS ALLOW     │ Permit traffic. NSG rules SKIPPED entirely.      │ │  │
│   │   │                   │ Use for critical services (Bastion, LB probes).  │ │  │
│   │   │                                                                       │ │  │
│   │   └──────────────────────────────────────────────────────────────────────┘ │  │
│   │                              │                                              │  │
│   │                              ▼                                              │  │
│   │                                                                              │  │
│   │   STEP 2: NETWORK SECURITY GROUP (Evaluated SECOND)                        │  │
│   │   ┌──────────────────────────────────────────────────────────────────────┐ │  │
│   │   │                                                                       │ │  │
│   │   │  NSG rules evaluated only if:                                        │ │  │
│   │   │  • No Security Admin DENY matched                                    │ │  │
│   │   │  • Security Admin ALLOW matched (not Always Allow)                   │ │  │
│   │   │  • No Security Admin rule matched at all                             │ │  │
│   │   │                                                                       │ │  │
│   │   │  NSG rules SKIPPED if:                                               │ │  │
│   │   │  • Security Admin DENY matched                                       │ │  │
│   │   │  • Security Admin ALWAYS ALLOW matched                               │ │  │
│   │   │                                                                       │ │  │
│   │   └──────────────────────────────────────────────────────────────────────┘ │  │
│   │                              │                                              │  │
│   │                              ▼                                              │  │
│   │                                                                              │  │
│   │   STEP 3: TRAFFIC DELIVERED (or dropped)                                   │  │
│   │                                                                              │  │
│   └─────────────────────────────────────────────────────────────────────────────┘  │
│                                                                                      │
│   ⚠️  EXAM KEY: Security Admin rules provide CENTRALIZED OVERRIDE of NSGs          │
│       • Central security team can enforce policies that local admins cannot bypass  │
│       • DENY rules guarantee traffic is blocked regardless of NSG configuration     │
│       • ALWAYS ALLOW ensures critical traffic flows even with restrictive NSGs      │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Configuration Best Practices

### Create Network Manager

```powershell
# Variables
$rgName = "rg-network-management"
$location = "eastus"
$nmName = "nm-enterprise-001"

# Create resource group
New-AzResourceGroup -Name $rgName -Location $location

# Define scope (management group or subscriptions)
$scope = @{
    ManagementGroup = @("/providers/Microsoft.Management/managementGroups/corp-mg")
}
# Or for subscription scope:
# $scope = @{
#     Subscription = @("/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx")
# }

# Create Network Manager with both Connectivity and SecurityAdmin access
$networkManager = New-AzNetworkManager `
    -Name $nmName `
    -ResourceGroupName $rgName `
    -Location $location `
    -Scope $scope `
    -ScopeAccess @("Connectivity", "SecurityAdmin")

Write-Host "Network Manager created: $($networkManager.Name)"
Write-Host "Scope: $($networkManager.Scope)"
Write-Host "Scope Access: $($networkManager.ScopeAccesses)"
```

### Create Network Group with Static Membership

```powershell
# Create network group
$networkGroup = New-AzNetworkManagerGroup `
    -Name "ng-hub-vnets" `
    -NetworkManagerName $nmName `
    -ResourceGroupName $rgName `
    -Description "Hub VNets for connectivity"

Write-Host "Network Group created: $($networkGroup.Name)"

# Add VNets as static members
$hubVnet = Get-AzVirtualNetwork -Name "vnet-hub-eus" -ResourceGroupName "rg-hub"

New-AzNetworkManagerStaticMember `
    -Name "member-hub-eus" `
    -NetworkGroupName "ng-hub-vnets" `
    -NetworkManagerName $nmName `
    -ResourceGroupName $rgName `
    -ResourceId $hubVnet.Id

Write-Host "Static member added: $($hubVnet.Name)"
```

### Create Network Group with Dynamic Membership

```powershell
# Create network group for production VNets
$prodGroup = New-AzNetworkManagerGroup `
    -Name "ng-production-spokes" `
    -NetworkManagerName $nmName `
    -ResourceGroupName $rgName `
    -Description "All production spoke VNets (auto-populated by tag)"

# Create Azure Policy definition for dynamic membership
# VNets with tag Environment=Production will automatically join

$policyDefinition = @"
{
    "if": {
        "allOf": [
            {
                "field": "type",
                "equals": "Microsoft.Network/virtualNetworks"
            },
            {
                "field": "tags['Environment']",
                "equals": "Production"
            }
        ]
    },
    "then": {
        "effect": "addToNetworkGroup",
        "details": {
            "networkGroupId": "$($prodGroup.Id)"
        }
    }
}
"@

# Note: Dynamic membership requires Azure Policy assignment
# The above is a conceptual example - actual implementation uses 
# conditional statements in the network group configuration

Write-Host "Network Group for dynamic membership created: $($prodGroup.Name)"
Write-Host "VNets tagged with Environment=Production will auto-join"
```

### Create Hub-Spoke Connectivity Configuration

```powershell
# Get hub VNet and spoke network group
$hubVnet = Get-AzVirtualNetwork -Name "vnet-hub-eus" -ResourceGroupName "rg-hub"
$spokeGroup = Get-AzNetworkManagerGroup -Name "ng-production-spokes" `
    -NetworkManagerName $nmName -ResourceGroupName $rgName

# Create connectivity configuration
$connectivityConfig = New-AzNetworkManagerConnectivityConfiguration `
    -Name "config-hubspoke-production" `
    -NetworkManagerName $nmName `
    -ResourceGroupName $rgName `
    -ConnectivityTopology "HubAndSpoke" `
    -Hub @{
        ResourceId = $hubVnet.Id
        ResourceType = "Microsoft.Network/virtualNetworks"
    } `
    -AppliesToGroup @{
        GroupConnectivity = "None"  # "DirectlyConnected" for spoke-to-spoke
        NetworkGroupId = $spokeGroup.Id
        UseHubGateway = "True"  # Spokes use hub's VPN/ER gateway
        IsGlobal = "False"  # Same region only
    }

Write-Host "Connectivity Configuration created: $($connectivityConfig.Name)"
Write-Host "Topology: Hub-and-Spoke"
Write-Host "Hub: $($hubVnet.Name)"
Write-Host "UseHubGateway: True"
```

### Create Mesh Connectivity Configuration

```powershell
# Create mesh configuration for dev/test VNets
$devGroup = Get-AzNetworkManagerGroup -Name "ng-development" `
    -NetworkManagerName $nmName -ResourceGroupName $rgName

$meshConfig = New-AzNetworkManagerConnectivityConfiguration `
    -Name "config-mesh-development" `
    -NetworkManagerName $nmName `
    -ResourceGroupName $rgName `
    -ConnectivityTopology "Mesh" `
    -AppliesToGroup @{
        NetworkGroupId = $devGroup.Id
        IsGlobal = "False"  # Set to "True" for Global Mesh (cross-region)
    }

Write-Host "Mesh Configuration created: $($meshConfig.Name)"
```

### Create Security Admin Configuration

```powershell
# Create security admin configuration
$securityConfig = New-AzNetworkManagerSecurityAdminConfiguration `
    -Name "config-security-baseline" `
    -NetworkManagerName $nmName `
    -ResourceGroupName $rgName `
    -Description "Enterprise security baseline rules"

Write-Host "Security Admin Configuration created: $($securityConfig.Name)"

# Create rule collection
$ruleCollection = New-AzNetworkManagerSecurityAdminRuleCollection `
    -Name "rc-deny-dangerous-ports" `
    -SecurityAdminConfigurationName $securityConfig.Name `
    -NetworkManagerName $nmName `
    -ResourceGroupName $rgName `
    -AppliesToGroup @{
        NetworkGroupId = $spokeGroup.Id
    }

Write-Host "Rule Collection created: $($ruleCollection.Name)"

# Create DENY rule for SSH from internet (cannot be overridden by NSG)
New-AzNetworkManagerSecurityAdminRule `
    -Name "deny-ssh-from-internet" `
    -RuleCollectionName $ruleCollection.Name `
    -SecurityAdminConfigurationName $securityConfig.Name `
    -NetworkManagerName $nmName `
    -ResourceGroupName $rgName `
    -Protocol "Tcp" `
    -Access "Deny" `
    -Direction "Inbound" `
    -Priority 100 `
    -SourceAddressPrefix @("Internet") `
    -DestinationAddressPrefix @("*") `
    -SourcePortRange @("*") `
    -DestinationPortRange @("22")

Write-Host "Rule created: deny-ssh-from-internet (Deny SSH from Internet)"

# Create DENY rule for RDP from internet
New-AzNetworkManagerSecurityAdminRule `
    -Name "deny-rdp-from-internet" `
    -RuleCollectionName $ruleCollection.Name `
    -SecurityAdminConfigurationName $securityConfig.Name `
    -NetworkManagerName $nmName `
    -ResourceGroupName $rgName `
    -Protocol "Tcp" `
    -Access "Deny" `
    -Direction "Inbound" `
    -Priority 110 `
    -SourceAddressPrefix @("Internet") `
    -DestinationAddressPrefix @("*") `
    -SourcePortRange @("*") `
    -DestinationPortRange @("3389")

Write-Host "Rule created: deny-rdp-from-internet (Deny RDP from Internet)"

# Create ALWAYS ALLOW rule for Azure Bastion (bypasses NSGs)
New-AzNetworkManagerSecurityAdminRule `
    -Name "always-allow-bastion" `
    -RuleCollectionName $ruleCollection.Name `
    -SecurityAdminConfigurationName $securityConfig.Name `
    -NetworkManagerName $nmName `
    -ResourceGroupName $rgName `
    -Protocol "Tcp" `
    -Access "AlwaysAllow" `
    -Direction "Inbound" `
    -Priority 50 `
    -SourceAddressPrefix @("VirtualNetwork") `
    -DestinationAddressPrefix @("*") `
    -SourcePortRange @("*") `
    -DestinationPortRange @("22", "3389")

Write-Host "Rule created: always-allow-bastion (Always Allow Bastion traffic)"
```

### Deploy Configurations

```powershell
# Deploy connectivity configuration to regions
New-AzNetworkManagerDeployment `
    -NetworkManagerName $nmName `
    -ResourceGroupName $rgName `
    -ConfigurationId @($connectivityConfig.Id) `
    -TargetLocation @("eastus", "westus2", "westeurope") `
    -CommitType "Connectivity"

Write-Host "Connectivity configuration deployed to: eastus, westus2, westeurope"

# Deploy security admin configuration to regions
New-AzNetworkManagerDeployment `
    -NetworkManagerName $nmName `
    -ResourceGroupName $rgName `
    -ConfigurationId @($securityConfig.Id) `
    -TargetLocation @("eastus", "westus2", "westeurope") `
    -CommitType "SecurityAdmin"

Write-Host "Security Admin configuration deployed to: eastus, westus2, westeurope"
```

### Verify Deployment Status

```powershell
# Check deployment status
$deployments = Get-AzNetworkManagerDeploymentStatus `
    -NetworkManagerName $nmName `
    -ResourceGroupName $rgName `
    -Region @("eastus", "westus2")

$deployments | ForEach-Object {
    Write-Host "Region: $($_.Region)"
    Write-Host "  Connectivity: $($_.ConfigurationId)"
    Write-Host "  Status: $($_.DeploymentStatus)"
    Write-Host ""
}
```

---

## 4. Comparison Tables

### AVNM vs Manual VNet Management

| Aspect | Manual Management | Azure Virtual Network Manager |
|--------|-------------------|-------------------------------|
| **Peering Setup** | Create each peering individually | Auto-created by connectivity config |
| **Scale** | 500 peerings per VNet limit | Managed, simplified |
| **Cross-subscription** | Complex IAM setup | Native with scope definition |
| **Dynamic membership** | Not available | Tag-based auto-join |
| **Security enforcement** | NSG per subnet/NIC | Security Admin rules (override NSGs) |
| **Topology changes** | Update each peering | Update config, redeploy |
| **Audit/compliance** | Manual review | Centralized view |
| **Multi-region** | Separate peerings | Global mesh option |

### Security Admin Rules vs NSGs

| Feature | Network Security Groups | Security Admin Rules |
|---------|------------------------|---------------------|
| **Scope** | Subnet or NIC | Network Group (multiple VNets) |
| **Management** | Local (per VNet/subnet) | Centralized (Network Manager) |
| **Override capability** | No | Yes (Deny overrides NSG Allow) |
| **Always Allow** | No | Yes (skips NSG evaluation) |
| **Cross-subscription** | No | Yes |
| **Use case** | Workload-specific rules | Enterprise-wide policies |
| **Who manages** | Application team | Central security team |

### Connectivity Topologies Comparison

| Topology | Hub Required | Spoke-to-Spoke | Cross-Region | Best For |
|----------|--------------|----------------|--------------|----------|
| **Hub-Spoke** | Yes | Via hub (or DirectlyConnected) | No (separate hubs) | Traditional enterprise, NVA inspection |
| **Hub-Spoke + DirectlyConnected** | Yes | Direct | No | Hub-spoke with low-latency spoke traffic |
| **Mesh** | No | Direct (all pairs) | No | Flat architecture, all VNets equal |
| **Global Mesh** | No | Direct (all pairs) | Yes | Multi-region mesh |

---

## 5. Exam Tips & Gotchas

### Critical Points to Memorize

1. **Security Admin rules are evaluated BEFORE NSGs** — Deny rules cannot be overridden
2. **Deployment is per-region** — Must deploy to each region where VNets exist
3. **Scope determines reach** — Management group scope enables cross-subscription management
4. **Dynamic membership uses conditions** — Tags, naming patterns, etc.
5. **Configurations don't auto-apply** — Must explicitly deploy to regions
6. **ALWAYS ALLOW skips NSG entirely** — Use carefully for critical services
7. **Managed peerings** — Don't manually create peerings for AVNM-managed VNets
8. **Network Manager location** — Metadata only; manages all regions within scope

### Common Exam Scenarios

| Scenario | Solution |
|----------|----------|
| "Block SSH from internet across all VNets" | Security Admin Deny rule on network group |
| "Auto-add VNets tagged 'Production'" | Dynamic membership with tag condition |
| "Spoke-to-spoke without going through hub" | Hub-Spoke with DirectlyConnected=true, or Mesh |
| "Manage VNets in 5 subscriptions" | Network Manager scoped to management group |
| "Ensure Bastion always works regardless of NSGs" | Security Admin AlwaysAllow rule |
| "Deploy hub-spoke to East US and West Europe" | Deploy connectivity config to both regions |
| "Local admin configured NSG to allow SSH but it's blocked" | Security Admin Deny rule is overriding NSG |

### Common Mistakes to Avoid

1. **Forgetting to deploy** — Creating config doesn't apply it
2. **Manual peering on AVNM VNets** — Conflicts with managed topology
3. **Expecting instant propagation** — Deployments take time
4. **Not understanding rule precedence** — Deny > Allow > NSG
5. **Missing region deployments** — Must deploy to each region with VNets
6. **Wrong scope access** — Need both Connectivity and SecurityAdmin for full management

### Key Limits to Remember

| Resource | Limit |
|----------|-------|
| Network Managers per subscription | 100 |
| Network Groups per Network Manager | 100 |
| VNets per Network Group | 1,000 |
| Static members per Network Group | 1,000 |
| Security Admin rules per config | 100 |
| Connectivity configs per Network Manager | 100 |

---

## 6. Hands-On Lab Suggestions

### Lab 1: Create Hub-Spoke with AVNM

```powershell
# 1. Create test VNets
New-AzResourceGroup -Name "rg-avnm-lab" -Location "eastus"

# Hub
New-AzVirtualNetwork -Name "vnet-hub" -ResourceGroupName "rg-avnm-lab" `
    -Location "eastus" -AddressPrefix "10.0.0.0/16" `
    -Tag @{Role="Hub"}

# Spokes with tags for dynamic membership
1..3 | ForEach-Object {
    New-AzVirtualNetwork -Name "vnet-spoke$_" -ResourceGroupName "rg-avnm-lab" `
        -Location "eastus" -AddressPrefix "10.$_.0.0/16" `
        -Tag @{Environment="Production"; Role="Spoke"}
}

# 2. Create Network Manager
# 3. Create Network Group with dynamic membership (tag: Environment=Production)
# 4. Create Hub-Spoke connectivity configuration
# 5. Deploy to eastus
# 6. Verify auto-created peerings
Get-AzVirtualNetworkPeering -VirtualNetworkName "vnet-hub" -ResourceGroupName "rg-avnm-lab"
```

### Lab 2: Implement Security Admin Rules

```powershell
# 1. Create Security Admin configuration
# 2. Create rule collection applied to production network group
# 3. Add Deny rule for SSH from internet
# 4. Add Always Allow rule for Azure Load Balancer health probes
# 5. Deploy to region
# 6. Test: Try to SSH from internet (should fail even with NSG allow)
# 7. Test: Verify LB health probes work (Always Allow bypasses NSG)
```

---

## 7. Cross-Service Relationships

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                         AVNM INTEGRATION MAP                                         │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    MANAGED BY AVNM                                          │   │
│   │                                                                             │   │
│   │  VNet Peering          → Auto-created/managed by connectivity configs      │   │
│   │  Security Rules        → Security Admin rules override NSGs                │   │
│   │  Network Groups        → Dynamic membership via tags/conditions            │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    WORKS WITH (NOT MANAGED BY AVNM)                         │   │
│   │                                                                             │   │
│   │  VPN Gateway           → UseHubGateway option propagates gateway           │   │
│   │  ExpressRoute Gateway  → UseHubGateway option propagates gateway           │   │
│   │  Azure Firewall        → Route traffic through hub NVA                     │   │
│   │  NSGs                  → Still apply (after Security Admin rules)          │   │
│   │  Route Tables (UDR)    → Still apply for custom routing                    │   │
│   │  Azure Policy          → Enables dynamic network group membership          │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌────────────────────────────────────────────────────────────────────────────┐   │
│   │                    RULE EVALUATION ORDER                                    │   │
│   │                                                                             │   │
│   │   1. Security Admin Rules (from AVNM)                                      │   │
│   │      ├─ Deny → Block (NSG not evaluated)                                   │   │
│   │      ├─ Always Allow → Permit (NSG not evaluated)                          │   │
│   │      └─ Allow → Permit, but continue to NSG                                │   │
│   │                                                                             │   │
│   │   2. Network Security Groups (if not already decided)                      │   │
│   │      └─ Standard NSG rule evaluation                                       │   │
│   │                                                                             │   │
│   └────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Quick Reference Card

| Item | Value |
|------|-------|
| **Max VNets per Network Group** | 1,000 |
| **Max Security Admin rules** | 100 per configuration |
| **Scope options** | Management group, Subscription, VNets |
| **Access options** | Connectivity, SecurityAdmin, or both |
| **Topologies** | Hub-Spoke, Mesh, Global Mesh |
| **Rule actions** | Deny, Allow, AlwaysAllow |
| **Rule evaluation** | Security Admin → then NSG |
| **Deployment scope** | Per region |

---

## Architecture Diagram File

📂 Open [Azure_Virtual_Network_Manager_Architecture.drawio](Azure_Virtual_Network_Manager_Architecture.drawio) in VS Code with the Draw.io Integration extension.

---

## Additional Resources

- [Azure Virtual Network Manager Documentation](https://learn.microsoft.com/en-us/azure/virtual-network-manager/)
- [Create a mesh topology with AVNM](https://learn.microsoft.com/en-us/azure/virtual-network-manager/how-to-create-mesh-network-topology)
- [Security Admin Rules](https://learn.microsoft.com/en-us/azure/virtual-network-manager/concept-security-admins)
- [Network Groups](https://learn.microsoft.com/en-us/azure/virtual-network-manager/concept-network-groups)
