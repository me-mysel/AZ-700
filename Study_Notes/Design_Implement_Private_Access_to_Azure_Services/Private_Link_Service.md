---
tags:
  - AZ-700
  - azure/networking
  - domain/private-access
  - private-link-service
  - private-link
  - nat-ip
  - standard-load-balancer
  - approval-workflow
  - consumer-provider
aliases:
  - Private Link Service
  - Azure Private Link Service
created: 2025-01-01
updated: 2026-02-07
---

# Azure Private Link Service

> [!info] Related Notes
> - [[Private_Endpoints]] — Consumer connects via Private Endpoint
> - [[Azure_Load_Balancer]] — Standard LB required as frontend
> - [[Azure_Front_Door]] — Private Link origin for Front Door Premium
> - [[VNet_Subnets_IP_Addressing]] — NAT subnet for Private Link Service

## Overview

Azure Private Link Service enables you to expose your own service privately to consumers in other VNets or subscriptions. Consumers connect via Private Endpoint, and traffic flows entirely over the Microsoft backbone without internet exposure.

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Private Link Service** | Your service exposed via Private Link |
| **Provider** | You - the service owner |
| **Consumer** | Other VNets/subscriptions connecting to your service |
| **Standard Load Balancer** | Required frontend for the service |
| **NAT IP** | IP used to NAT consumer traffic |
| **Alias** | Unique identifier for service discovery |
| **Visibility** | Controls who can create PEs to your service |
| **Auto-approval** | Subscriptions that don't need manual approval |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      Private Link Service Architecture                           │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                    CONSUMER SUBSCRIPTION / VNET                              ││
│  │                                                                              ││
│  │   ┌──────────────────────────────────────────────────────────────────────┐  ││
│  │   │                      CONSUMER VNET                                    │  ││
│  │   │                                                                       │  ││
│  │   │  ┌─────────────────┐                                                 │  ││
│  │   │  │   Consumer VM   │                                                 │  ││
│  │   │  │   10.1.0.4      │                                                 │  ││
│  │   │  │                 │                                                 │  ││
│  │   │  │ Connects to:    │                                                 │  ││
│  │   │  │ 10.1.1.4        │◄── Private Endpoint IP                         │  ││
│  │   │  └────────┬────────┘                                                 │  ││
│  │   │           │                                                          │  ││
│  │   │           ▼                                                          │  ││
│  │   │  ┌─────────────────────────────────────────────────────────────┐    │  ││
│  │   │  │              PRIVATE ENDPOINT                                │    │  ││
│  │   │  │                                                              │    │  ││
│  │   │  │   IP: 10.1.1.4                                              │    │  ││
│  │   │  │   Target: Private Link Service Alias                        │    │  ││
│  │   │  │   Status: Approved                                          │    │  ││
│  │   │  └─────────────────────────────────────────────────────────────┘    │  ││
│  │   └──────────────────────────────────────────────────────────────────────┘  ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                      │                                           │
│                                      │ Private Link Connection                   │
│                                      │ (Microsoft Backbone)                      │
│                                      │                                           │
│  ┌───────────────────────────────────▼─────────────────────────────────────────┐│
│  │                    PROVIDER SUBSCRIPTION / VNET                              ││
│  │                                                                              ││
│  │   ┌──────────────────────────────────────────────────────────────────────┐  ││
│  │   │                      PROVIDER VNET                                    │  ││
│  │   │                                                                       │  ││
│  │   │  ┌─────────────────────────────────────────────────────────────┐     │  ││
│  │   │  │              PRIVATE LINK SERVICE                            │     │  ││
│  │   │  │                                                              │     │  ││
│  │   │  │   Alias: myservice.{guid}.uksouth.azure.privatelinkservice  │     │  ││
│  │   │  │   NAT IPs: 10.0.2.4, 10.0.2.5 (for SNAT)                   │     │  ││
│  │   │  │   Visibility: Subscription-based                            │     │  ││
│  │   │  │   Auto-approve: Selected subscriptions                      │     │  ││
│  │   │  └─────────────────────────────────────────────────────────────┘     │  ││
│  │   │                              │                                        │  ││
│  │   │                              ▼                                        │  ││
│  │   │  ┌─────────────────────────────────────────────────────────────┐     │  ││
│  │   │  │         STANDARD LOAD BALANCER (Internal)                    │     │  ││
│  │   │  │                                                              │     │  ││
│  │   │  │   Frontend IP: 10.0.1.100                                   │     │  ││
│  │   │  │   Backend Pool: Service VMs                                  │     │  ││
│  │   │  └─────────────────────────────────────────────────────────────┘     │  ││
│  │   │                              │                                        │  ││
│  │   │           ┌──────────────────┼──────────────────┐                    │  ││
│  │   │           ▼                  ▼                  ▼                    │  ││
│  │   │     ┌──────────┐       ┌──────────┐       ┌──────────┐              │  ││
│  │   │     │ Service  │       │ Service  │       │ Service  │              │  ││
│  │   │     │  VM 1    │       │  VM 2    │       │  VM 3    │              │  ││
│  │   │     │10.0.3.4  │       │10.0.3.5  │       │10.0.3.6  │              │  ││
│  │   │     └──────────┘       └──────────┘       └──────────┘              │  ││
│  │   │                                                                       │  ││
│  │   └──────────────────────────────────────────────────────────────────────┘  ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## Traffic Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Private Link Service Traffic Flow                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   STEP 1: Consumer VM sends request                                     │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │  Source: 10.1.0.4 (Consumer VM)                                  │  │
│   │  Destination: 10.1.1.4 (Private Endpoint)                        │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                         │                                                │
│                         ▼                                                │
│   STEP 2: Private Link routes to Provider                               │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │  Traffic traverses Microsoft backbone                            │  │
│   │  Arrives at Private Link Service                                 │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                         │                                                │
│                         ▼                                                │
│   STEP 3: NAT applied by Private Link Service                           │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │  Original Source: 10.1.0.4                                       │  │
│   │                    ↓                                              │  │
│   │  NAT'd Source: 10.0.2.4 (NAT IP from PLS)                       │  │
│   │                                                                   │  │
│   │  Backend VMs see traffic from NAT IP, NOT consumer IP            │  │
│   │  (Unless proxy protocol enabled)                                 │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                         │                                                │
│                         ▼                                                │
│   STEP 4: Load Balancer distributes to backend                          │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │  Source: 10.0.2.4 (NAT IP)                                       │  │
│   │  Destination: 10.0.3.4 (Backend VM via LB)                       │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│   Important: Consumer's original IP is hidden by default!               │
│   Use Proxy Protocol v2 if backend needs real client IP                │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Configuration Best Practices

### Provider: Create Private Link Service

```powershell
# Variables
$resourceGroup = "rg-provider"
$location = "uksouth"
$vnetName = "vnet-provider"

# 1. Create VNet with subnets
$subnetLB = New-AzVirtualNetworkSubnetConfig -Name "snet-lb" -AddressPrefix "10.0.1.0/24"
$subnetPLS = New-AzVirtualNetworkSubnetConfig -Name "snet-pls" -AddressPrefix "10.0.2.0/24" `
    -PrivateLinkServiceNetworkPoliciesFlag "Disabled"  # Required for PLS
$subnetBackend = New-AzVirtualNetworkSubnetConfig -Name "snet-backend" -AddressPrefix "10.0.3.0/24"

$vnet = New-AzVirtualNetwork `
    -Name $vnetName `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -AddressPrefix "10.0.0.0/16" `
    -Subnet $subnetLB, $subnetPLS, $subnetBackend

# 2. Create Internal Standard Load Balancer
$feConfig = New-AzLoadBalancerFrontendIpConfig `
    -Name "fe-internal" `
    -PrivateIpAddress "10.0.1.100" `
    -SubnetId $vnet.Subnets[0].Id

$bePool = New-AzLoadBalancerBackendAddressPoolConfig -Name "be-pool"

$probe = New-AzLoadBalancerProbeConfig `
    -Name "probe-http" `
    -Protocol "Tcp" `
    -Port 80 `
    -IntervalInSeconds 5 `
    -ProbeCount 2

$lbRule = New-AzLoadBalancerRuleConfig `
    -Name "rule-http" `
    -FrontendIpConfiguration $feConfig `
    -BackendAddressPool $bePool `
    -Probe $probe `
    -Protocol "Tcp" `
    -FrontendPort 80 `
    -BackendPort 80

$lb = New-AzLoadBalancer `
    -Name "lb-service" `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -Sku "Standard" `
    -FrontendIpConfiguration $feConfig `
    -BackendAddressPool $bePool `
    -Probe $probe `
    -LoadBalancingRule $lbRule

# 3. Create NAT IP configuration for Private Link Service
$plsSubnet = Get-AzVirtualNetworkSubnetConfig -Name "snet-pls" -VirtualNetwork $vnet

$natIpConfig = New-AzPrivateLinkServiceIpConfig `
    -Name "nat-ip-1" `
    -PrivateIpAddress "10.0.2.4" `
    -Subnet $plsSubnet `
    -Primary

$natIpConfig2 = New-AzPrivateLinkServiceIpConfig `
    -Name "nat-ip-2" `
    -PrivateIpAddress "10.0.2.5" `
    -Subnet $plsSubnet

# 4. Create Private Link Service
$pls = New-AzPrivateLinkService `
    -Name "pls-myservice" `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -LoadBalancerFrontendIpConfiguration $lb.FrontendIpConfigurations[0] `
    -IpConfiguration $natIpConfig, $natIpConfig2 `
    -Visibility "Subscription" `
    -AutoApproval @()  # Empty = manual approval required

# Get the alias for consumers
Write-Host "Private Link Service Alias: $($pls.Alias)"
```

### Consumer: Create Private Endpoint to Service

```powershell
# Consumer creates PE using the alias
$resourceGroup = "rg-consumer"
$location = "uksouth"

# Consumer VNet
$subnet = New-AzVirtualNetworkSubnetConfig -Name "snet-pe" -AddressPrefix "10.1.1.0/24"
$vnet = New-AzVirtualNetwork -Name "vnet-consumer" -ResourceGroupName $resourceGroup `
    -Location $location -AddressPrefix "10.1.0.0/16" -Subnet $subnet

# Create Private Endpoint using alias
$plsConnection = New-AzPrivateLinkServiceConnection `
    -Name "pls-connection" `
    -PrivateLinkServiceId "myservice.{guid}.uksouth.azure.privatelinkservice"  # Use alias

$pe = New-AzPrivateEndpoint `
    -Name "pe-to-provider-service" `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -Subnet $vnet.Subnets[0] `
    -PrivateLinkServiceConnection $plsConnection

# Check connection status
$pe.PrivateLinkServiceConnections[0].PrivateLinkServiceConnectionState
# Status will be "Pending" until provider approves
```

### Provider: Approve Connection

```powershell
# Provider approves the connection request
$pls = Get-AzPrivateLinkService -Name "pls-myservice" -ResourceGroupName "rg-provider"

# List pending connections
$pls.PrivateEndpointConnections | Where-Object { $_.PrivateLinkServiceConnectionState.Status -eq "Pending" }

# Approve connection
Approve-AzPrivateEndpointConnection `
    -Name $pls.PrivateEndpointConnections[0].Name `
    -ResourceGroupName "rg-provider" `
    -ServiceName "pls-myservice"

# Or reject
# Deny-AzPrivateEndpointConnection ...
```

### Configure Auto-Approval

```powershell
# Update PLS with auto-approval subscriptions
$consumerSubId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

Set-AzPrivateLinkService `
    -Name "pls-myservice" `
    -ResourceGroupName "rg-provider" `
    -AutoApproval @($consumerSubId)

# Also set visibility to allow the subscription
Set-AzPrivateLinkService `
    -Name "pls-myservice" `
    -ResourceGroupName "rg-provider" `
    -Visibility @($consumerSubId)
```

---

## Visibility and Auto-Approval

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Visibility and Auto-Approval                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   VISIBILITY - Who can discover and request connection                  │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                                                                   │  │
│   │  Option 1: None (Alias only)                                     │  │
│   │  • Service not visible in portal                                 │  │
│   │  • Must share alias directly with consumers                      │  │
│   │                                                                   │  │
│   │  Option 2: Subscription List                                     │  │
│   │  • Only listed subscriptions can see/connect                     │  │
│   │  • Recommended for controlled access                             │  │
│   │                                                                   │  │
│   │  Option 3: All (*) - Not recommended                            │  │
│   │  • Anyone can request connection                                 │  │
│   │  • Still requires approval                                       │  │
│   │                                                                   │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│   AUTO-APPROVAL - Skip manual approval for trusted consumers           │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                                                                   │  │
│   │  • List specific subscription IDs                                │  │
│   │  • PE connections from these subs approved automatically         │  │
│   │  • Others require manual approval                                │  │
│   │                                                                   │  │
│   │  Best Practice: Only auto-approve known, trusted subscriptions  │  │
│   │                                                                   │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Exam Tips & Gotchas

### Critical Points (Commonly Tested)

- **Standard Load Balancer required** — internal LB for PLS
- **NAT IP hides consumer IP** — backend sees NAT IP, not original source
- **Proxy Protocol v2** — enables backend to see original client IP
- **Visibility controls discovery** — who can see/request the service
- **Auto-approval for trusted** — bypass manual approval for known subs
- **Alias is unique identifier** — share with consumers for connection
- **Disable network policies on PLS subnet** — required for PLS creation

### Exam Scenarios

| Scenario | Solution |
|----------|----------|
| Expose service to partner tenant | Create PLS, share alias, approve their PE |
| SaaS provider to multiple customers | PLS with subscription-based visibility |
| Backend needs original client IP | Enable Proxy Protocol v2 |
| Auto-approve internal team's sub | Add subscription to auto-approval list |
| Prevent unauthorized discovery | Use "None" visibility, share alias directly |

### Common Gotchas

1. **NAT IP exhaustion** — plan for enough NAT IPs based on expected connections
2. **Can't use Basic LB** — must be Standard SKU
3. **Disable network policies** — on PLS subnet before creating PLS
4. **One PLS per LB frontend** — can have multiple frontends on LB
5. **TCP only** — UDP not supported

---

## Comparison Tables

### Private Endpoint vs Private Link Service

| Aspect | Private Endpoint | Private Link Service |
|--------|------------------|---------------------|
| **You are** | Consumer | Provider |
| **Purpose** | Connect TO a service | Expose YOUR service |
| **Creates** | NIC in your VNet | NAT endpoint |
| **Target** | Azure PaaS or PLS | Your backend via LB |
| **Requires** | Target service/PLS | Standard Internal LB |

### PLS NAT Behavior

| Configuration | Backend Sees |
|---------------|--------------|
| Default (no proxy) | NAT IP as source |
| Proxy Protocol v2 | Original client IP (in header) |

---

## Hands-On Lab Suggestions

### Lab: Create Private Link Service for Custom App

```powershell
# PROVIDER SIDE

# 1. Create resource group
New-AzResourceGroup -Name "rg-pls-provider" -Location "uksouth"

# 2. Create VNet
$subnetLB = New-AzVirtualNetworkSubnetConfig -Name "snet-lb" -AddressPrefix "10.0.1.0/24"
$subnetPLS = New-AzVirtualNetworkSubnetConfig -Name "snet-pls" -AddressPrefix "10.0.2.0/24" `
    -PrivateLinkServiceNetworkPoliciesFlag "Disabled"
$subnetVM = New-AzVirtualNetworkSubnetConfig -Name "snet-vm" -AddressPrefix "10.0.3.0/24"

$vnet = New-AzVirtualNetwork -Name "vnet-provider" -ResourceGroupName "rg-pls-provider" `
    -Location "uksouth" -AddressPrefix "10.0.0.0/16" -Subnet $subnetLB, $subnetPLS, $subnetVM

# 3. Create backend VM running web server
# (Deploy VM in snet-vm, install IIS/nginx)

# 4. Create Internal Load Balancer
# (Standard SKU, frontend in snet-lb, backend pool with VM)

# 5. Create Private Link Service
# (Use snet-pls for NAT IPs)

# 6. Note the alias

# CONSUMER SIDE

# 7. Create consumer VNet
New-AzResourceGroup -Name "rg-pls-consumer" -Location "uksouth"
$consumerVnet = New-AzVirtualNetwork -Name "vnet-consumer" -ResourceGroupName "rg-pls-consumer" `
    -Location "uksouth" -AddressPrefix "10.1.0.0/16" `
    -Subnet (New-AzVirtualNetworkSubnetConfig -Name "snet-pe" -AddressPrefix "10.1.1.0/24")

# 8. Create Private Endpoint using alias
# (Status will be "Pending")

# BACK TO PROVIDER

# 9. Approve the connection

# TEST

# 10. From consumer VM, access the service via PE IP
# curl http://10.1.1.4  # PE IP
# Should reach provider's web server!
```

---

## Cross-Service Relationships

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Private Link Service Integration                          │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        Private Link Service                             │ │
│  │                                                                         │ │
│  │   Requires ────────► Standard Internal Load Balancer                   │ │
│  │                                                                         │ │
│  │   Backend can be ──► VMs                                               │ │
│  │                  ──► VMSS                                              │ │
│  │                  ──► Any TCP service                                   │ │
│  │                                                                         │ │
│  │   Consumers use ───► Private Endpoint (in their VNet)                 │ │
│  │                                                                         │ │
│  │   Use cases ──────► SaaS multi-tenant exposure                        │ │
│  │              ──────► Cross-tenant service sharing                     │ │
│  │              ──────► Partner integration                              │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  This is how Azure PaaS services (Storage, SQL) offer Private Endpoints:   │
│  They use Private Link Service internally!                                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Draw.io Diagram

```xml
<mxfile host="app.diagrams.net">
  <diagram name="Private Link Service" id="pls-arch">
    <mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1169" pageHeight="827" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <mxCell id="consumer" value="CONSUMER VNET" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;verticalAlign=top;fontSize=14" vertex="1" parent="1">
          <mxGeometry x="40" y="40" width="200" height="180" as="geometry" />
        </mxCell>
        <mxCell id="consumervm" value="Consumer VM" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="1">
          <mxGeometry x="60" y="80" width="80" height="40" as="geometry" />
        </mxCell>
        <mxCell id="pe" value="Private&#xa;Endpoint" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;" vertex="1" parent="1">
          <mxGeometry x="60" y="150" width="80" height="50" as="geometry" />
        </mxCell>
        <mxCell id="provider" value="PROVIDER VNET" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;verticalAlign=top;fontSize=14" vertex="1" parent="1">
          <mxGeometry x="400" y="40" width="320" height="260" as="geometry" />
        </mxCell>
        <mxCell id="pls" value="Private Link Service&#xa;NAT IPs: 10.0.2.x" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;" vertex="1" parent="1">
          <mxGeometry x="420" y="80" width="140" height="60" as="geometry" />
        </mxCell>
        <mxCell id="lb" value="Internal Load Balancer&#xa;(Standard SKU)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="1">
          <mxGeometry x="420" y="160" width="140" height="50" as="geometry" />
        </mxCell>
        <mxCell id="vm1" value="VM1" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="1">
          <mxGeometry x="420" y="240" width="60" height="40" as="geometry" />
        </mxCell>
        <mxCell id="vm2" value="VM2" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="1">
          <mxGeometry x="500" y="240" width="60" height="40" as="geometry" />
        </mxCell>
        <mxCell id="vm3" value="VM3" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="1">
          <mxGeometry x="580" y="240" width="60" height="40" as="geometry" />
        </mxCell>
        <mxCell id="backbone" value="Microsoft&#xa;Backbone" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;" vertex="1" parent="1">
          <mxGeometry x="260" y="120" width="100" height="60" as="geometry" />
        </mxCell>
        <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="pe" target="backbone">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e2" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="backbone" target="pls">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e3" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="pls" target="lb">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e4" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="lb" target="vm1">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e5" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="lb" target="vm2">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e6" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="lb" target="vm3">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```
