---
tags:
  - AZ-700
  - azure/networking
  - domain/private-access
  - service-endpoint
  - service-endpoint-policy
  - paas-security
  - optimal-routing
  - azure-backbone
aliases:
  - Service Endpoint
  - VNet Service Endpoint
created: 2025-01-01
updated: 2026-02-07
---

# Azure Service Endpoints

> [!info] Related Notes
> - [[Private_Endpoints]] — Private endpoints vs service endpoints comparison
> - [[VNet_Subnets_IP_Addressing]] — Service endpoints enabled per subnet
> - [[NSG_ASG_Firewall]] — Service tags in NSG rules
> - [[Azure_Firewall_and_Firewall_Manager]] — Firewall rules with service tags

## Overview

Azure Virtual Network Service Endpoints extend your VNet's private address space and identity to Azure services over a direct connection. Traffic to Azure services remains on the Microsoft Azure backbone network, but the service still uses its public IP address.

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Service Endpoint** | Extends VNet identity to Azure service |
| **Optimal Routing** | Direct path to service on Azure backbone |
| **Service Firewall** | Allow traffic from specific VNets |
| **Regional** | Same region as VNet (mostly) |
| **Free** | No additional cost |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      Service Endpoint Architecture                               │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                         YOUR VIRTUAL NETWORK                                 ││
│  │                                                                              ││
│  │   ┌──────────────────────────────────────────────────────────────────────┐  ││
│  │   │              SUBNET with Service Endpoint Enabled                    │  ││
│  │   │                                                                       │  ││
│  │   │  Service Endpoints:                                                  │  ││
│  │   │  ✓ Microsoft.Storage                                                 │  ││
│  │   │  ✓ Microsoft.Sql                                                     │  ││
│  │   │  ✓ Microsoft.KeyVault                                                │  ││
│  │   │                                                                       │  ││
│  │   │  ┌─────────────────┐          ┌─────────────────┐                    │  ││
│  │   │  │      VM         │          │      VM         │                    │  ││
│  │   │  │   10.0.1.4      │          │   10.0.1.5      │                    │  ││
│  │   │  │                 │          │                 │                    │  ││
│  │   │  │ Connect to:     │          │ DNS returns:    │                    │  ││
│  │   │  │ stg.blob...     │          │ PUBLIC IP       │                    │  ││
│  │   │  │ (public FQDN)   │          │ (52.x.x.x)      │                    │  ││
│  │   │  └─────────────────┘          └─────────────────┘                    │  ││
│  │   │           │                            │                              │  ││
│  │   │           └────────────┬───────────────┘                              │  ││
│  │   │                        │                                              │  ││
│  │   └────────────────────────┼──────────────────────────────────────────────┘  ││
│  │                            │                                                  ││
│  │                            ▼                                                  ││
│  │              ┌─────────────────────────────┐                                  ││
│  │              │   SERVICE ENDPOINT ROUTE    │                                  ││
│  │              │                             │                                  ││
│  │              │   Traffic identified with   │                                  ││
│  │              │   VNet/Subnet source        │                                  ││
│  │              │                             │                                  ││
│  │              │   Routed via Azure Backbone │                                  ││
│  │              │   (NOT via Internet)        │                                  ││
│  │              └─────────────┬───────────────┘                                  ││
│  │                            │                                                  ││
│  └────────────────────────────┼──────────────────────────────────────────────────┘│
│                               │                                                   │
│                               ▼                                                   │
│  ┌─────────────────────────────────────────────────────────────────────────────┐ │
│  │                         AZURE PAAS SERVICES                                  │ │
│  │                                                                              │ │
│  │   ┌─────────────────────────────────────────────────────────────────────┐   │ │
│  │   │                      STORAGE ACCOUNT                                 │   │ │
│  │   │                                                                      │   │ │
│  │   │   Public IP: 52.239.x.x (still used!)                               │   │ │
│  │   │                                                                      │   │ │
│  │   │   Firewall Rules:                                                   │   │ │
│  │   │   ┌─────────────────────────────────────────────────────────────┐   │   │ │
│  │   │   │  ✓ Allow: VNet "vnet-workloads" / Subnet "snet-app"         │   │   │ │
│  │   │   │  ✓ Allow: VNet "vnet-workloads" / Subnet "snet-web"         │   │   │ │
│  │   │   │  ✗ Deny:  All other traffic (default)                       │   │   │ │
│  │   │   └─────────────────────────────────────────────────────────────┘   │   │ │
│  │   │                                                                      │   │ │
│  │   │   Traffic from allowed subnet → ✅ Accepted                         │   │ │
│  │   │   Traffic from internet/other → ❌ Denied                           │   │ │
│  │   │                                                                      │   │ │
│  │   └─────────────────────────────────────────────────────────────────────┘   │ │
│  │                                                                              │ │
│  └─────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────┘
```

---

## Supported Services

| Service | Endpoint Name | Regional Scope |
|---------|---------------|----------------|
| **Azure Storage** | Microsoft.Storage | Same region + paired |
| **Azure SQL Database** | Microsoft.Sql | All regions |
| **Azure Synapse** | Microsoft.Sql | All regions |
| **Azure Cosmos DB** | Microsoft.AzureCosmosDB | All regions |
| **Azure Key Vault** | Microsoft.KeyVault | All regions |
| **Azure Service Bus** | Microsoft.ServiceBus | All regions |
| **Azure Event Hubs** | Microsoft.EventHub | All regions |
| **Azure App Service** | Microsoft.Web | Same region |
| **Azure Container Registry** | Microsoft.ContainerRegistry | All regions |
| **Azure Cognitive Services** | Microsoft.CognitiveServices | All regions |

---

## Service Endpoint vs Private Endpoint

```
┌─────────────────────────────────────────────────────────────────────────┐
│                Service Endpoint vs Private Endpoint                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   SERVICE ENDPOINT                                                       │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                                                                   │  │
│   │   VM (10.0.1.4)                                                  │  │
│   │       │                                                          │  │
│   │       │ nslookup stgacct.blob.core.windows.net                  │  │
│   │       │ → 52.239.x.x (PUBLIC IP)                                │  │
│   │       │                                                          │  │
│   │       ▼                                                          │  │
│   │   [Service Endpoint Route]                                       │  │
│   │       │                                                          │  │
│   │       │ Traffic tagged with VNet/Subnet identity                │  │
│   │       │ Routed via Azure backbone (not internet)                │  │
│   │       │                                                          │  │
│   │       ▼                                                          │  │
│   │   Storage (52.239.x.x) - Firewall allows VNet                   │  │
│   │                                                                   │  │
│   │   ✓ Fast, direct connection                                      │  │
│   │   ✓ Free                                                         │  │
│   │   ✗ Still uses public IP (DNS unchanged)                        │  │
│   │   ✗ On-premises cannot use                                       │  │
│   │   ✗ Mostly same-region only                                      │  │
│   │                                                                   │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│   PRIVATE ENDPOINT                                                       │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                                                                   │  │
│   │   VM (10.0.1.4)                                                  │  │
│   │       │                                                          │  │
│   │       │ nslookup stgacct.blob.core.windows.net                  │  │
│   │       │ → 10.0.2.4 (PRIVATE IP via Private DNS)                 │  │
│   │       │                                                          │  │
│   │       ▼                                                          │  │
│   │   Private Endpoint NIC (10.0.2.4)                               │  │
│   │       │                                                          │  │
│   │       │ Private Link connection                                 │  │
│   │       │                                                          │  │
│   │       ▼                                                          │  │
│   │   Storage - accessed via PRIVATE IP                             │  │
│   │                                                                   │  │
│   │   ✓ True private IP                                              │  │
│   │   ✓ On-premises can use (via VPN/ER)                            │  │
│   │   ✓ Cross-region supported                                       │  │
│   │   ✗ Requires Private DNS Zone                                    │  │
│   │   ✗ Costs per hour + data                                       │  │
│   │                                                                   │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Configuration Best Practices

### Enable Service Endpoint on Subnet

```powershell
# Get VNet
$vnet = Get-AzVirtualNetwork -Name "vnet-workloads" -ResourceGroupName "rg-networking"

# Enable service endpoints on subnet
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "snet-app" -VirtualNetwork $vnet

Set-AzVirtualNetworkSubnetConfig `
    -VirtualNetwork $vnet `
    -Name "snet-app" `
    -AddressPrefix $subnet.AddressPrefix `
    -ServiceEndpoint "Microsoft.Storage", "Microsoft.Sql", "Microsoft.KeyVault"

# Apply changes
$vnet | Set-AzVirtualNetwork
```

### Configure Storage Account Firewall

```powershell
# Get storage account
$storage = Get-AzStorageAccount -ResourceGroupName "rg-storage" -Name "stgworkloads"

# Get subnet with service endpoint
$vnet = Get-AzVirtualNetwork -Name "vnet-workloads" -ResourceGroupName "rg-networking"
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "snet-app" -VirtualNetwork $vnet

# Add network rule to allow subnet
Add-AzStorageAccountNetworkRule `
    -ResourceGroupName "rg-storage" `
    -Name "stgworkloads" `
    -VirtualNetworkResourceId $subnet.Id

# Set default action to Deny
Update-AzStorageAccountNetworkRuleSet `
    -ResourceGroupName "rg-storage" `
    -Name "stgworkloads" `
    -DefaultAction "Deny"

# Optionally allow specific IP (for admin access)
Add-AzStorageAccountNetworkRule `
    -ResourceGroupName "rg-storage" `
    -Name "stgworkloads" `
    -IPAddressOrRange "203.0.113.0/24"
```

### Configure SQL Server Firewall

```powershell
# Create VNet rule for SQL Server
$vnet = Get-AzVirtualNetwork -Name "vnet-workloads" -ResourceGroupName "rg-networking"
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "snet-app" -VirtualNetwork $vnet

New-AzSqlServerVirtualNetworkRule `
    -ResourceGroupName "rg-sql" `
    -ServerName "sql-workloads" `
    -VirtualNetworkRuleName "allow-snet-app" `
    -VirtualNetworkSubnetId $subnet.Id

# Disable public network access (optional - only VNet access)
Set-AzSqlServer `
    -ResourceGroupName "rg-sql" `
    -ServerName "sql-workloads" `
    -PublicNetworkAccess "Disabled"
```

### Configure Key Vault Firewall

```powershell
# Add VNet rule to Key Vault
$vnet = Get-AzVirtualNetwork -Name "vnet-workloads" -ResourceGroupName "rg-networking"
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "snet-app" -VirtualNetwork $vnet

Add-AzKeyVaultNetworkRule `
    -VaultName "kv-workloads" `
    -VirtualNetworkResourceId $subnet.Id

# Set default action to Deny
Update-AzKeyVaultNetworkRuleSet `
    -VaultName "kv-workloads" `
    -DefaultAction "Deny"
```

---

## Service Endpoint Policies

### Overview

Service Endpoint Policies allow you to filter traffic to specific Azure resources, not just service types.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Service Endpoint Policies                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   WITHOUT Policy (Default):                                             │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                                                                   │  │
│   │   Service Endpoint: Microsoft.Storage enabled                    │  │
│   │                                                                   │  │
│   │   VM can access ALL storage accounts in the region               │  │
│   │   (if storage account allows VNet)                               │  │
│   │                                                                   │  │
│   │   VM → Storage Account A ✓                                       │  │
│   │   VM → Storage Account B ✓                                       │  │
│   │   VM → Storage Account C ✓  (even if unintended!)               │  │
│   │                                                                   │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│   WITH Service Endpoint Policy:                                         │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                                                                   │  │
│   │   Policy allows only: /subscriptions/.../stgworkloads            │  │
│   │                                                                   │  │
│   │   VM → Storage Account A (stgworkloads) ✓                       │  │
│   │   VM → Storage Account B ❌ Blocked by policy                   │  │
│   │   VM → Storage Account C ❌ Blocked by policy                   │  │
│   │                                                                   │  │
│   │   Use case: Prevent data exfiltration to rogue storage accounts │  │
│   │                                                                   │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│   Currently Supported: Azure Storage only                               │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Create Service Endpoint Policy

```powershell
# Define allowed storage account
$storageAccount = Get-AzStorageAccount -ResourceGroupName "rg-storage" -Name "stgworkloads"

# Create policy definition
$policyDef = New-AzServiceEndpointPolicyDefinition `
    -Name "allow-stg-workloads" `
    -Service "Microsoft.Storage" `
    -ServiceResource $storageAccount.Id

# Create service endpoint policy
$policy = New-AzServiceEndpointPolicy `
    -Name "sep-storage-policy" `
    -ResourceGroupName "rg-networking" `
    -Location "uksouth" `
    -ServiceEndpointPolicyDefinition $policyDef

# Associate with subnet
$vnet = Get-AzVirtualNetwork -Name "vnet-workloads" -ResourceGroupName "rg-networking"

Set-AzVirtualNetworkSubnetConfig `
    -VirtualNetwork $vnet `
    -Name "snet-app" `
    -AddressPrefix "10.0.1.0/24" `
    -ServiceEndpoint "Microsoft.Storage" `
    -ServiceEndpointPolicy $policy

$vnet | Set-AzVirtualNetwork
```

---

## Exam Tips & Gotchas

### Critical Points (Commonly Tested)

- **Service endpoint uses public IP** — DNS still returns public IP
- **Traffic stays on Azure backbone** — doesn't traverse internet
- **Regional limitation** — mostly same region (Storage includes paired)
- **Free feature** — no additional cost
- **On-premises cannot use** — VNet traffic only
- **Must enable on subnet first** — then configure service firewall
- **Service endpoint policy for storage** — prevent data exfiltration

### Exam Scenarios

| Scenario | Solution |
|----------|----------|
| Secure storage from internet, allow VNet | Enable service endpoint + storage firewall |
| Prevent data exfil to rogue storage | Service endpoint policy |
| On-premises needs access to storage | Use Private Endpoint instead |
| Cross-region access to SQL | Service endpoint works (SQL is global) |
| Cross-region access to storage | Use Private Endpoint (SE is regional) |
| Quick, free VNet-to-PaaS security | Service Endpoint |

### Common Gotchas

1. **Two-step process** — enable endpoint on subnet AND configure service firewall
2. **Public IP still used** — only routing changes, not DNS
3. **Default deny needed** — set firewall default action to Deny
4. **Can combine with Private Endpoint** — not mutually exclusive
5. **Storage paired regions** — SE works to paired region storage

---

## Comparison Tables

### Full Comparison

| Feature | Service Endpoint | Private Endpoint |
|---------|------------------|------------------|
| **Traffic Path** | Azure backbone | Azure backbone |
| **IP Address** | Public IP | Private IP in VNet |
| **DNS Resolution** | Public IP | Private IP (needs DNS zone) |
| **On-premises Access** | ❌ | ✅ |
| **Cross-region** | Limited | ✅ |
| **Cost** | Free | Per hour + data |
| **Setup Complexity** | Simple | More complex (DNS) |
| **Service Isolation** | VNet firewall rules | Full private connectivity |
| **Data Exfil Prevention** | Policy (storage only) | Full isolation |

---

## Hands-On Lab Suggestions

### Lab: Service Endpoint for Storage

```powershell
# 1. Create resource group
New-AzResourceGroup -Name "rg-se-lab" -Location "uksouth"

# 2. Create VNet and subnet
$subnet = New-AzVirtualNetworkSubnetConfig -Name "snet-app" -AddressPrefix "10.0.1.0/24"
$vnet = New-AzVirtualNetwork -Name "vnet-lab" -ResourceGroupName "rg-se-lab" `
    -Location "uksouth" -AddressPrefix "10.0.0.0/16" -Subnet $subnet

# 3. Create storage account
$storageName = "stgselab$(Get-Random -Maximum 9999)"
$storage = New-AzStorageAccount -ResourceGroupName "rg-se-lab" -Name $storageName `
    -Location "uksouth" -SkuName "Standard_LRS" -Kind "StorageV2"

# 4. Create a container and upload test blob
$ctx = $storage.Context
New-AzStorageContainer -Name "test" -Context $ctx -Permission Off
Set-AzStorageBlobContent -File "C:\temp\test.txt" -Container "test" `
    -Blob "test.txt" -Context $ctx

# 5. Test access from VM (before SE) - should work
# curl "https://$storageName.blob.core.windows.net/test/test.txt?SAS"

# 6. Configure storage firewall - deny all
Update-AzStorageAccountNetworkRuleSet -ResourceGroupName "rg-se-lab" `
    -Name $storageName -DefaultAction "Deny"

# 7. Test access from VM - should FAIL now

# 8. Enable service endpoint on subnet
$vnet = Get-AzVirtualNetwork -Name "vnet-lab" -ResourceGroupName "rg-se-lab"
Set-AzVirtualNetworkSubnetConfig -VirtualNetwork $vnet -Name "snet-app" `
    -AddressPrefix "10.0.1.0/24" -ServiceEndpoint "Microsoft.Storage"
$vnet | Set-AzVirtualNetwork

# 9. Add VNet rule to storage firewall
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "snet-app" -VirtualNetwork $vnet
Add-AzStorageAccountNetworkRule -ResourceGroupName "rg-se-lab" `
    -Name $storageName -VirtualNetworkResourceId $subnet.Id

# 10. Test access from VM - should work again!

# 11. Test from internet - should FAIL (expected)
```

---

## Cross-Service Relationships

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Service Endpoint Integration                              │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        Service Endpoint                                 │ │
│  │                                                                         │ │
│  │   Connects to ─────► Storage Account (Firewall VNet rules)            │ │
│  │              ─────► SQL Database (VNet rules)                         │ │
│  │              ─────► Key Vault (Network rules)                         │ │
│  │              ─────► Cosmos DB (VNet rules)                            │ │
│  │              ─────► App Service (Access restrictions)                 │ │
│  │              ─────► Service Bus / Event Hubs                          │ │
│  │                                                                         │ │
│  │   Works with ──────► NSG (SE doesn't bypass NSG)                      │ │
│  │             ──────► UDR (SE adds optimal routes)                      │ │
│  │                                                                         │ │
│  │   Combined with ───► Private Endpoint (both can coexist)             │ │
│  │                                                                         │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  Best Practice:                                                             │
│  • Use SE for simple VNet-only scenarios                                    │
│  • Use PE when on-premises or cross-region needed                          │
│  • Use SE Policy to prevent data exfiltration to rogue storage             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Draw.io Diagram

```xml
<mxfile host="app.diagrams.net">
  <diagram name="Service Endpoint" id="se-arch">
    <mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1169" pageHeight="827" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <mxCell id="vnet" value="Virtual Network" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;verticalAlign=top;fontSize=14" vertex="1" parent="1">
          <mxGeometry x="80" y="60" width="320" height="200" as="geometry" />
        </mxCell>
        <mxCell id="subnet" value="Subnet with Service Endpoints&#xa;Microsoft.Storage ✓&#xa;Microsoft.Sql ✓" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;verticalAlign=top" vertex="1" parent="1">
          <mxGeometry x="100" y="100" width="280" height="140" as="geometry" />
        </mxCell>
        <mxCell id="vm" value="VM&#xa;10.0.1.4" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="1">
          <mxGeometry x="200" y="150" width="80" height="60" as="geometry" />
        </mxCell>
        <mxCell id="storage" value="Storage Account&#xa;&#xa;Firewall: Allow VNet" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="520" y="80" width="140" height="80" as="geometry" />
        </mxCell>
        <mxCell id="sql" value="SQL Database&#xa;&#xa;VNet Rules: Allow" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="520" y="180" width="140" height="80" as="geometry" />
        </mxCell>
        <mxCell id="backbone" value="Azure Backbone&#xa;(Not Internet)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;" vertex="1" parent="1">
          <mxGeometry x="400" y="120" width="100" height="80" as="geometry" />
        </mxCell>
        <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="vm" target="backbone">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e2" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="backbone" target="storage">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e3" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="backbone" target="sql">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="note1" value="DNS still returns PUBLIC IP&#xa;but routing uses Azure backbone" style="text;html=1;strokeColor=#d79b00;fillColor=#ffe6cc;align=center;rounded=1;" vertex="1" parent="1">
          <mxGeometry x="80" y="280" width="200" height="40" as="geometry" />
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```
