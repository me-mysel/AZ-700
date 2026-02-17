---
tags:
  - AZ-700
  - azure/networking
  - domain/private-access
  - private-endpoint
  - private-link
  - private-dns-zone
  - privatelink
  - network-interface
  - paas-security
aliases:
  - Private Endpoint
  - Azure Private Endpoint
created: 2025-01-01
updated: 2026-02-07
---

# Azure Private Endpoints

> [!info] Related Notes
> - [[Private_Link_Service]] — Exposing your own service via Private Link
> - [[Service_Endpoints]] — Alternative (service endpoints vs private endpoints)
> - [[Azure_DNS]] — Private DNS zones for privatelink FQDN resolution
> - [[VNet_Subnets_IP_Addressing]] — Subnet placement for private endpoints
> - [[NSG_ASG_Firewall]] — NSG support on private endpoints
> - [[Azure_Firewall_and_Firewall_Manager]] — Filtering traffic to private endpoints
> - [[ExpressRoute]] — On-premises access to private endpoints

## Overview

Azure Private Endpoint is a network interface that connects you privately and securely to a service powered by Azure Private Link. Private Endpoint uses a private IP address from your VNet, effectively bringing the Azure service into your VNet.

### Key Concepts

| Concept | Description |
|---------|-------------|
| **Private Endpoint** | NIC with private IP in your VNet |
| **Private Link Resource** | The Azure service being accessed privately |
| **Target Sub-resource** | Specific resource type (blob, queue, sqlServer) |
| **Network Interface** | The actual NIC created in subnet |
| **Private DNS Zone** | Resolves service FQDN to private IP |
| **Approval Workflow** | Auto-approve or manual approval |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      Private Endpoint Architecture                               │
│                                                                                  │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                         YOUR VIRTUAL NETWORK                                 ││
│  │                                                                              ││
│  │   ┌──────────────────────────────────────────────────────────────────────┐  ││
│  │   │                      SUBNET: snet-workloads                          │  ││
│  │   │                                                                       │  ││
│  │   │  ┌─────────────────┐          ┌─────────────────┐                    │  ││
│  │   │  │      VM         │          │      VM         │                    │  ││
│  │   │  │   10.0.1.4      │          │   10.0.1.5      │                    │  ││
│  │   │  │                 │          │                 │                    │  ││
│  │   │  │ nslookup:       │          │ Connect to:     │                    │  ││
│  │   │  │ stgacct.blob... │          │ 10.0.2.4:443    │                    │  ││
│  │   │  │ → 10.0.2.4      │          │ (private!)      │                    │  ││
│  │   │  └─────────────────┘          └─────────────────┘                    │  ││
│  │   └──────────────────────────────────────────────────────────────────────┘  ││
│  │                                      │                                       ││
│  │   ┌──────────────────────────────────▼───────────────────────────────────┐  ││
│  │   │                      SUBNET: snet-privateendpoints                   │  ││
│  │   │                                                                       │  ││
│  │   │   ┌─────────────────────────────────────────────────────────────┐    │  ││
│  │   │   │              PRIVATE ENDPOINT: pe-storage                    │    │  ││
│  │   │   │                                                              │    │  ││
│  │   │   │   NIC IP: 10.0.2.4                                          │    │  ││
│  │   │   │   Target: stgaccount.blob.core.windows.net                  │    │  ││
│  │   │   │   Sub-resource: blob                                         │    │  ││
│  │   │   └─────────────────────────────────────────────────────────────┘    │  ││
│  │   │                                                                       │  ││
│  │   │   ┌─────────────────────────────────────────────────────────────┐    │  ││
│  │   │   │              PRIVATE ENDPOINT: pe-sql                        │    │  ││
│  │   │   │                                                              │    │  ││
│  │   │   │   NIC IP: 10.0.2.5                                          │    │  ││
│  │   │   │   Target: sqlserver.database.windows.net                    │    │  ││
│  │   │   │   Sub-resource: sqlServer                                    │    │  ││
│  │   │   └─────────────────────────────────────────────────────────────┘    │  ││
│  │   └──────────────────────────────────────────────────────────────────────┘  ││
│  │                                                                              ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                      │                                           │
│                                      │  Private Link Connection                  │
│                                      │  (Microsoft Backbone - no internet)       │
│                                      ▼                                           │
│  ┌─────────────────────────────────────────────────────────────────────────────┐│
│  │                         AZURE PAAS SERVICES                                  ││
│  │                                                                              ││
│  │   ┌─────────────────────────┐    ┌─────────────────────────┐               ││
│  │   │    STORAGE ACCOUNT      │    │     SQL DATABASE        │               ││
│  │   │                         │    │                         │               ││
│  │   │ Public endpoint: ❌     │    │ Public endpoint: ❌     │               ││
│  │   │ (disabled/denied)       │    │ (disabled/denied)       │               ││
│  │   │                         │    │                         │               ││
│  │   │ Private endpoint: ✅    │    │ Private endpoint: ✅    │               ││
│  │   │ (10.0.2.4)              │    │ (10.0.2.5)              │               ││
│  │   └─────────────────────────┘    └─────────────────────────┘               ││
│  └─────────────────────────────────────────────────────────────────────────────┘│
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Supported Services

### Common Private Endpoint Sub-resources

| Service | Sub-resource | Private DNS Zone |
|---------|--------------|------------------|
| **Storage - Blob** | blob | privatelink.blob.core.windows.net |
| **Storage - File** | file | privatelink.file.core.windows.net |
| **Storage - Queue** | queue | privatelink.queue.core.windows.net |
| **Storage - Table** | table | privatelink.table.core.windows.net |
| **Storage - Web** | web | privatelink.web.core.windows.net |
| **Storage - DFS** | dfs | privatelink.dfs.core.windows.net |
| **SQL Database** | sqlServer | privatelink.database.windows.net |
| **Cosmos DB** | sql, mongodb, cassandra | privatelink.documents.azure.com |
| **Key Vault** | vault | privatelink.vaultcore.azure.net |
| **App Service** | sites | privatelink.azurewebsites.net |
| **Azure Monitor** | azuremonitor | privatelink.monitor.azure.com |
| **Event Hub** | namespace | privatelink.servicebus.windows.net |
| **Service Bus** | namespace | privatelink.servicebus.windows.net |

---

## Private DNS Integration

### DNS Resolution Flow

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    Private Endpoint DNS Resolution                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│   WITHOUT Private DNS Zone (Broken!)                                            │
│   ┌──────────────────────────────────────────────────────────────────────────┐  │
│   │                                                                           │  │
│   │  VM: nslookup stgaccount.blob.core.windows.net                           │  │
│   │         │                                                                 │  │
│   │         ▼                                                                 │  │
│   │  Azure DNS → Returns PUBLIC IP (52.x.x.x)                                │  │
│   │         │                                                                 │  │
│   │         ▼                                                                 │  │
│   │  VM tries to connect to PUBLIC IP → ❌ BLOCKED (if public access off)   │  │
│   │                                                                           │  │
│   └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
│   WITH Private DNS Zone (Correct!)                                              │
│   ┌──────────────────────────────────────────────────────────────────────────┐  │
│   │                                                                           │  │
│   │  VM: nslookup stgaccount.blob.core.windows.net                           │  │
│   │         │                                                                 │  │
│   │         ▼                                                                 │  │
│   │  Azure DNS → Checks linked Private DNS Zone first                        │  │
│   │         │                                                                 │  │
│   │         ▼                                                                 │  │
│   │  privatelink.blob.core.windows.net zone                                  │  │
│   │         │                                                                 │  │
│   │         ▼                                                                 │  │
│   │  A Record: stgaccount → 10.0.2.4 (Private IP!)                          │  │
│   │         │                                                                 │  │
│   │         ▼                                                                 │  │
│   │  VM connects to 10.0.2.4 → ✅ SUCCESS                                    │  │
│   │                                                                           │  │
│   └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                  │
│   DNS Zone Linking Requirements:                                                │
│   • Private DNS Zone must be linked to VNet                                     │
│   • VNet must use Azure DNS (168.63.129.16)                                     │
│   • For custom DNS: configure conditional forwarder                            │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### DNS Configuration Options

| Scenario | Configuration |
|----------|---------------|
| **Azure DNS (Default)** | Create Private DNS Zone, link to VNet, auto-register PE |
| **Custom DNS Server** | Conditional forwarder to Azure DNS (168.63.129.16) |
| **On-premises DNS** | Forwarder to Azure DNS resolver or private DNS zone |
| **Hosts File** | Manual entry (not recommended for production) |

---

## Configuration Best Practices

### Create Private Endpoint for Storage

```powershell
# Variables
$resourceGroup = "rg-privatelink-lab"
$location = "uksouth"
$vnetName = "vnet-workloads"
$subnetName = "snet-privateendpoints"
$storageName = "stgprivatelink$(Get-Random -Maximum 9999)"

# Create storage account
$storage = New-AzStorageAccount `
    -ResourceGroupName $resourceGroup `
    -Name $storageName `
    -Location $location `
    -SkuName "Standard_LRS" `
    -Kind "StorageV2" `
    -AllowBlobPublicAccess $false

# Get subnet for private endpoint
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroup
$subnet = Get-AzVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet

# Create private endpoint connection
$privateEndpointConnection = New-AzPrivateLinkServiceConnection `
    -Name "pls-storage" `
    -PrivateLinkServiceId $storage.Id `
    -GroupId "blob"  # Sub-resource type

# Create private endpoint
$privateEndpoint = New-AzPrivateEndpoint `
    -Name "pe-storage-blob" `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -Subnet $subnet `
    -PrivateLinkServiceConnection $privateEndpointConnection

# Get private endpoint IP
$nicId = $privateEndpoint.NetworkInterfaces[0].Id
$nic = Get-AzNetworkInterface -ResourceId $nicId
$privateIp = $nic.IpConfigurations[0].PrivateIpAddress
Write-Host "Private Endpoint IP: $privateIp"
```

### Create and Configure Private DNS Zone

```powershell
# Create Private DNS Zone for blob storage
$dnsZone = New-AzPrivateDnsZone `
    -ResourceGroupName $resourceGroup `
    -Name "privatelink.blob.core.windows.net"

# Link DNS Zone to VNet
New-AzPrivateDnsVirtualNetworkLink `
    -ResourceGroupName $resourceGroup `
    -ZoneName "privatelink.blob.core.windows.net" `
    -Name "link-vnet-workloads" `
    -VirtualNetworkId $vnet.Id `
    -EnableRegistration $false  # Auto-registration not needed for PE

# Create DNS record for private endpoint
$config = New-AzPrivateDnsZoneConfig `
    -Name "privatelink.blob.core.windows.net" `
    -PrivateDnsZoneId $dnsZone.ResourceId

# Create DNS Zone Group (auto-creates A record)
New-AzPrivateDnsZoneGroup `
    -ResourceGroupName $resourceGroup `
    -PrivateEndpointName "pe-storage-blob" `
    -Name "dns-zone-group" `
    -PrivateDnsZoneConfig $config
```

### Create Private Endpoint for SQL Database

```powershell
# Create SQL Server
$sqlServer = New-AzSqlServer `
    -ResourceGroupName $resourceGroup `
    -ServerName "sql-privatelink-$(Get-Random -Maximum 9999)" `
    -Location $location `
    -SqlAdministratorCredentials (Get-Credential)

# Create private endpoint for SQL
$sqlConnection = New-AzPrivateLinkServiceConnection `
    -Name "pls-sql" `
    -PrivateLinkServiceId $sqlServer.ResourceId `
    -GroupId "sqlServer"

$peSql = New-AzPrivateEndpoint `
    -Name "pe-sql" `
    -ResourceGroupName $resourceGroup `
    -Location $location `
    -Subnet $subnet `
    -PrivateLinkServiceConnection $sqlConnection

# Create Private DNS Zone for SQL
$sqlDnsZone = New-AzPrivateDnsZone `
    -ResourceGroupName $resourceGroup `
    -Name "privatelink.database.windows.net"

New-AzPrivateDnsVirtualNetworkLink `
    -ResourceGroupName $resourceGroup `
    -ZoneName "privatelink.database.windows.net" `
    -Name "link-vnet-sql" `
    -VirtualNetworkId $vnet.Id

# DNS Zone Group for SQL
$sqlDnsConfig = New-AzPrivateDnsZoneConfig `
    -Name "privatelink.database.windows.net" `
    -PrivateDnsZoneId $sqlDnsZone.ResourceId

New-AzPrivateDnsZoneGroup `
    -ResourceGroupName $resourceGroup `
    -PrivateEndpointName "pe-sql" `
    -Name "dns-zone-group" `
    -PrivateDnsZoneConfig $sqlDnsConfig
```

### Disable Public Access on Storage

```powershell
# Disable public blob access
Set-AzStorageAccount `
    -ResourceGroupName $resourceGroup `
    -Name $storageName `
    -AllowBlobPublicAccess $false `
    -PublicNetworkAccess "Disabled"

# Or configure firewall to deny all
Update-AzStorageAccountNetworkRuleSet `
    -ResourceGroupName $resourceGroup `
    -Name $storageName `
    -DefaultAction "Deny"
```

---

## Exam Tips & Gotchas

### Critical Points (Commonly Tested)

- **Private Endpoint = NIC in your VNet** — gets private IP from subnet
- **DNS is critical** — without proper DNS, name resolves to public IP
- **Private DNS Zone must be linked** — to each VNet needing access
- **Sub-resource specific** — different endpoints for blob, file, queue, etc.
- **NSG doesn't apply to PE traffic** — PE bypasses NSG by default
- **Network policies disabled by default** — enable for NSG/UDR on PE subnet
- **Cross-region supported** — PE and service can be in different regions

### Exam Scenarios

| Scenario | Solution |
|----------|----------|
| VMs can't connect after creating PE | DNS not configured - create Private DNS Zone |
| On-premises can't resolve PE FQDN | Configure conditional forwarder to Azure DNS |
| Need NSG on PE subnet | Enable private endpoint network policies |
| Multiple VNets need PE access | Link Private DNS Zone to all VNets |
| Service needs to remain public for some | Create PE + keep public access for specific IPs |
| Cross-subscription PE | Manual approval required on target service |

### Common Gotchas

1. **Private DNS Zone name must be exact** — e.g., `privatelink.blob.core.windows.net`
2. **VNet DNS must be Azure DNS** — or conditional forwarder configured
3. **One PE per sub-resource** — need separate PE for blob, file, queue
4. **Hub-spoke: link DNS to all VNets** — or use DNS resolver in hub
5. **Approval needed for cross-tenant** — auto-approve only works same tenant

---

## Network Policies on Private Endpoints

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Private Endpoint Network Policies                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   DEFAULT BEHAVIOR (Network Policies DISABLED):                         │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                                                                   │  │
│   │  • NSG rules do NOT apply to PE traffic                          │  │
│   │  • UDR (Route Tables) do NOT apply to PE traffic                 │  │
│   │  • Traffic flows directly to PE, bypassing security              │  │
│   │                                                                   │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│   ENABLE NETWORK POLICIES:                                              │
│   ┌──────────────────────────────────────────────────────────────────┐  │
│   │                                                                   │  │
│   │  Set-AzVirtualNetworkSubnetConfig `                              │  │
│   │      -Name "snet-pe" `                                           │  │
│   │      -VirtualNetwork $vnet `                                     │  │
│   │      -AddressPrefix "10.0.2.0/24" `                              │  │
│   │      -PrivateEndpointNetworkPoliciesFlag "Enabled"               │  │
│   │                                                                   │  │
│   │  After enabling:                                                 │  │
│   │  • NSG rules APPLY to PE traffic                                 │  │
│   │  • UDR routes APPLY to PE traffic                                │  │
│   │  • Can force PE traffic through NVA                              │  │
│   │                                                                   │  │
│   └──────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│   Use Cases for Enabling:                                               │
│   • Route PE traffic through Azure Firewall/NVA                        │
│   • Apply NSG to restrict which VMs can access PE                      │
│   • Logging/inspection requirements                                     │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Comparison Tables

### Private Endpoint vs Service Endpoint

| Feature | Private Endpoint | Service Endpoint |
|---------|------------------|------------------|
| **IP Address** | Private IP in VNet | Service uses public IP |
| **Traffic Path** | Microsoft backbone | Microsoft backbone |
| **DNS** | Requires Private DNS | No DNS change |
| **On-premises Access** | ✅ Via ExpressRoute/VPN | ❌ VNet only |
| **Cross-region** | ✅ Supported | ❌ Same region only |
| **Cost** | Per hour + data | Free |
| **Service Firewall** | Full isolation possible | Allow VNet rules |
| **NSG Support** | Requires enabling | N/A |

### When to Use What

| Requirement | Use |
|-------------|-----|
| Full isolation from internet | Private Endpoint |
| On-premises needs access | Private Endpoint |
| Cross-region access | Private Endpoint |
| Cost-sensitive, VNet-only | Service Endpoint |
| Quick setup, no DNS changes | Service Endpoint |
| Compliance requires private IP | Private Endpoint |

---

## Hands-On Lab Suggestions

### Lab: Private Endpoint with DNS Resolution

```powershell
# 1. Create resource group and VNet
$rg = "rg-pe-lab"
$location = "uksouth"

New-AzResourceGroup -Name $rg -Location $location

$subnet1 = New-AzVirtualNetworkSubnetConfig -Name "snet-vms" -AddressPrefix "10.0.1.0/24"
$subnet2 = New-AzVirtualNetworkSubnetConfig -Name "snet-pe" -AddressPrefix "10.0.2.0/24"

$vnet = New-AzVirtualNetwork `
    -Name "vnet-lab" `
    -ResourceGroupName $rg `
    -Location $location `
    -AddressPrefix "10.0.0.0/16" `
    -Subnet $subnet1, $subnet2

# 2. Create storage account
$storageName = "stgpelab$(Get-Random -Maximum 9999)"
$storage = New-AzStorageAccount -ResourceGroupName $rg -Name $storageName `
    -Location $location -SkuName "Standard_LRS" -Kind "StorageV2"

# 3. Create VM to test from
# (Create simple Windows/Linux VM in snet-vms)

# 4. Test DNS resolution BEFORE private endpoint
# From VM: nslookup $storageName.blob.core.windows.net
# Result: Returns PUBLIC IP

# 5. Create Private Endpoint
$subnet = Get-AzVirtualNetworkSubnetConfig -Name "snet-pe" -VirtualNetwork $vnet
$conn = New-AzPrivateLinkServiceConnection -Name "pls-storage" `
    -PrivateLinkServiceId $storage.Id -GroupId "blob"

$pe = New-AzPrivateEndpoint -Name "pe-storage" -ResourceGroupName $rg `
    -Location $location -Subnet $subnet -PrivateLinkServiceConnection $conn

# 6. Test DNS BEFORE Private DNS Zone
# From VM: nslookup $storageName.blob.core.windows.net
# Result: Still returns PUBLIC IP (broken!)

# 7. Create Private DNS Zone and link
$dnsZone = New-AzPrivateDnsZone -ResourceGroupName $rg `
    -Name "privatelink.blob.core.windows.net"

New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $rg `
    -ZoneName "privatelink.blob.core.windows.net" `
    -Name "link-vnet" -VirtualNetworkId $vnet.Id

# 8. Create DNS Zone Group (auto-registers A record)
$dnsConfig = New-AzPrivateDnsZoneConfig -Name "privatelink.blob.core.windows.net" `
    -PrivateDnsZoneId $dnsZone.ResourceId

New-AzPrivateDnsZoneGroup -ResourceGroupName $rg -PrivateEndpointName "pe-storage" `
    -Name "dns-group" -PrivateDnsZoneConfig $dnsConfig

# 9. Test DNS AFTER Private DNS Zone
# From VM: nslookup $storageName.blob.core.windows.net
# Result: Returns PRIVATE IP (10.0.2.x) ✅

# 10. Disable public access
Set-AzStorageAccount -ResourceGroupName $rg -Name $storageName `
    -PublicNetworkAccess "Disabled"

# 11. Test blob access from VM (should work via PE)
# Test from internet (should fail)
```

---

## AZ-700 Exam Tips & Gotchas

### Private Endpoint vs Service Endpoint (Critical Comparison)

| Feature | Private Endpoint | Service Endpoint |
| --- | --- | --- |
| **IP Address** | Private IP in your VNet | Still uses PUBLIC IP |
| **DNS Resolution** | Resolves to private IP | Resolves to public IP |
| **On-Premises Access** | ✅ Via VPN/ExpressRoute | ❌ No (Azure only) |
| **Cross-Region** | ✅ Yes | ❌ Mostly same-region |
| **Cost** | Per hour + data transfer | Free |
| **NSG/UDR Support** | ✅ With network policies | ✅ Yes |
| **Setup Complexity** | Higher (DNS required) | Lower |
| **Routing** | Through VNet | Azure backbone (optimal) |

### Exam Decision Tree

```text
┌─────────────────────────────────────────────────────────────────────────┐
│            PRIVATE ENDPOINT vs SERVICE ENDPOINT DECISION                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   Need on-premises access to Azure PaaS?                                │
│                    │                                                     │
│         ┌─────────┴─────────┐                                           │
│        YES                 NO                                            │
│         │                   │                                            │
│         ▼                   ▼                                            │
│   PRIVATE ENDPOINT      Need cross-region access?                       │
│   (only option)              │                                          │
│                     ┌────────┴────────┐                                 │
│                    YES               NO                                  │
│                     │                 │                                  │
│                     ▼                 ▼                                  │
│               PRIVATE              Cost-sensitive?                      │
│               ENDPOINT                  │                               │
│                              ┌──────────┴──────────┐                    │
│                             YES                   NO                    │
│                              │                     │                    │
│                              ▼                     ▼                    │
│                         SERVICE              PRIVATE                    │
│                         ENDPOINT             ENDPOINT                   │
│                         (free)               (more features)            │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### Gotchas That Appear on Exams

1. **DNS is REQUIRED for Private Endpoints** - Without Private DNS Zone, FQDN still resolves to public IP
2. **Service Endpoints don't change DNS** - Traffic uses public IP but via Azure backbone
3. **Private Endpoint subnet cannot be too small** - Each PE needs one IP
4. **Network policies disabled by default** - Must enable for NSG/UDR on PE subnet
5. **Approval can be required** - Some services require manual approval for PE connections
6. **Hub-spoke DNS** - Private DNS zone must be linked to ALL VNets that need resolution
7. **On-prem DNS forwarding** - Need conditional forwarder to Azure DNS (168.63.129.16)

### Common Exam Scenarios

| Scenario | Answer |
| --- | --- |
| *"On-prem server needs to access Azure SQL privately"* | **Private Endpoint** (SE can't work from on-prem) |
| *"Minimize cost, Azure VMs only, same region"* | **Service Endpoint** (free) |
| *"DNS still returns public IP after creating PE"* | **Missing Private DNS Zone** or zone not linked to VNet |
| *"Storage accessible from internet despite PE"* | **Disable public access** on storage firewall |
| *"Need to apply NSG to PE subnet"* | **Enable network policies** on the subnet |
| *"Hub-spoke, spokes can't resolve PE"* | **Link Private DNS Zone to spoke VNets** |
| *"Multiple services, minimize DNS zones"* | **One zone per service type** (e.g., one for blob, one for SQL) |

### Private DNS Zone Names (Must Know!)

| Service | Private DNS Zone |
| --- | --- |
| Storage Blob | `privatelink.blob.core.windows.net` |
| Storage File | `privatelink.file.core.windows.net` |
| Azure SQL | `privatelink.database.windows.net` |
| Cosmos DB (SQL) | `privatelink.documents.azure.com` |
| Key Vault | `privatelink.vaultcore.azure.net` |
| App Service | `privatelink.azurewebsites.net` |

### Troubleshooting Checklist

| Symptom | Check | Fix |
| --- | --- | --- |
| DNS returns public IP | Private DNS Zone linked? | Create zone and link to VNet |
| PE unreachable from on-prem | DNS forwarding configured? | Set up conditional forwarder to 168.63.129.16 |
| NSG not filtering PE traffic | Network policies enabled? | Enable on subnet: `PrivateEndpointNetworkPolicies` |
| Service still accessible publicly | Public access disabled? | Configure service firewall to deny public access |
| Cross-VNet PE access fails | DNS zone linked to all VNets? | Link zone to requesting VNet |

---

## Cross-Service Relationships

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Private Endpoint Integration                              │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        Private Endpoint                                 │ │
│  │                                                                         │ │
│  │   Connects to ─────► Storage (blob, file, queue, table, web, dfs)     │ │
│  │              ─────► SQL Database / Managed Instance                    │ │
│  │              ─────► Cosmos DB                                          │ │
│  │              ─────► Key Vault                                          │ │
│  │              ─────► App Service / Functions                            │ │
│  │              ─────► Azure Monitor                                      │ │
│  │              ─────► Event Hub / Service Bus                            │ │
│  │              ─────► Azure Container Registry                           │ │
│  │              ─────► Many more...                                       │ │
│  │                                                                         │ │
│  │   Requires ────────► Private DNS Zone (linked to VNet)                │ │
│  │                                                                         │ │
│  │   Optional ────────► NSG (with network policies enabled)              │ │
│  │           ────────► UDR (with network policies enabled)               │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  Hub-Spoke with Private Endpoint:                                           │
│  • Create PE in hub VNet                                                    │
│  • Link Private DNS Zone to ALL VNets (hub + spokes)                       │
│  • Or use Azure DNS Private Resolver in hub                                │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Draw.io Diagram

```xml
<mxfile host="app.diagrams.net">
  <diagram name="Private Endpoint" id="pe-arch">
    <mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1169" pageHeight="827" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <mxCell id="vnet" value="Virtual Network: 10.0.0.0/16" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;verticalAlign=top;fontSize=14" vertex="1" parent="1">
          <mxGeometry x="80" y="40" width="440" height="320" as="geometry" />
        </mxCell>
        <mxCell id="subnet1" value="snet-workloads&#xa;10.0.1.0/24" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;verticalAlign=top" vertex="1" parent="1">
          <mxGeometry x="100" y="80" width="180" height="120" as="geometry" />
        </mxCell>
        <mxCell id="vm" value="VM&#xa;10.0.1.4" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="1">
          <mxGeometry x="140" y="120" width="80" height="60" as="geometry" />
        </mxCell>
        <mxCell id="subnet2" value="snet-pe&#xa;10.0.2.0/24" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;verticalAlign=top" vertex="1" parent="1">
          <mxGeometry x="100" y="220" width="400" height="120" as="geometry" />
        </mxCell>
        <mxCell id="pe1" value="PE: Storage&#xa;10.0.2.4" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;" vertex="1" parent="1">
          <mxGeometry x="120" y="260" width="100" height="60" as="geometry" />
        </mxCell>
        <mxCell id="pe2" value="PE: SQL&#xa;10.0.2.5" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;" vertex="1" parent="1">
          <mxGeometry x="260" y="260" width="100" height="60" as="geometry" />
        </mxCell>
        <mxCell id="pe3" value="PE: KeyVault&#xa;10.0.2.6" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#f8cecc;strokeColor=#b85450;" vertex="1" parent="1">
          <mxGeometry x="380" y="260" width="100" height="60" as="geometry" />
        </mxCell>
        <mxCell id="dns" value="Private DNS Zone&#xa;privatelink.blob...&#xa;Linked to VNet" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="1">
          <mxGeometry x="320" y="100" width="180" height="80" as="geometry" />
        </mxCell>
        <mxCell id="storage" value="Storage Account&#xa;(Public access disabled)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="600" y="160" width="140" height="60" as="geometry" />
        </mxCell>
        <mxCell id="sql" value="SQL Database" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="600" y="240" width="140" height="60" as="geometry" />
        </mxCell>
        <mxCell id="kv" value="Key Vault" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="600" y="320" width="140" height="60" as="geometry" />
        </mxCell>
        <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;dashed=1;" edge="1" parent="1" source="pe1" target="storage">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e2" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;dashed=1;" edge="1" parent="1" source="pe2" target="sql">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e3" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;dashed=1;" edge="1" parent="1" source="pe3" target="kv">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="label" value="Private Link&#xa;(Microsoft Backbone)" style="text;html=1;strokeColor=none;fillColor=none;align=center;" vertex="1" parent="1">
          <mxGeometry x="540" y="130" width="120" height="30" as="geometry" />
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```
