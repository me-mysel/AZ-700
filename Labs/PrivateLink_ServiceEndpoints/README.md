# Lab: Private Link, Private Endpoints & Service Endpoints

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fme-mysel%2FAZ-700%2Fmain%2FLabs%2FPrivateLink_ServiceEndpoints%2Fmain.json)

## Lab Overview

This hands-on lab demonstrates the differences between Service Endpoints, Private Endpoints, and Private Link Service in Azure. You'll deploy infrastructure using Bicep and test connectivity scenarios.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────────────┐
│                              Lab Architecture                                        │
├─────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │  VNet-Hub (10.0.0.0/16)                                                      │   │
│   │                                                                              │   │
│   │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │   │
│   │  │ Subnet-VM        │  │ Subnet-PE        │  │ Subnet-PLS       │          │   │
│   │  │ 10.0.1.0/24      │  │ 10.0.2.0/24      │  │ 10.0.3.0/24      │          │   │
│   │  │                  │  │                  │  │                  │          │   │
│   │  │ ┌──────────────┐ │  │ ┌──────────────┐ │  │ ┌──────────────┐ │          │   │
│   │  │ │  VM-Test     │ │  │ │ Private      │ │  │ │ Private Link │ │          │   │
│   │  │ │  (Linux)     │ │  │ │ Endpoint     │ │  │ │ Service      │ │          │   │
│   │  │ └──────────────┘ │  │ │ (Storage)    │ │  │ │ + Int LB     │ │          │   │
│   │  │                  │  │ └──────────────┘ │  │ └──────────────┘ │          │   │
│   │  │ Service Endpoint │  │                  │  │                  │          │   │
│   │  │ (Microsoft.      │  │ Private DNS Zone │  │ NAT Subnet       │          │   │
│   │  │  Storage) ✓      │  │ Link ✓           │  │ 10.0.4.0/24      │          │   │
│   │  └──────────────────┘  └──────────────────┘  └──────────────────┘          │   │
│   │                                                                              │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │  VNet-Consumer (10.1.0.0/16) - Simulates external customer                   │   │
│   │                                                                              │   │
│   │  ┌──────────────────┐  ┌──────────────────┐                                 │   │
│   │  │ Subnet-Consumer  │  │ Subnet-PE        │                                 │   │
│   │  │ 10.1.1.0/24      │  │ 10.1.2.0/24      │                                 │   │
│   │  │                  │  │                  │                                 │   │
│   │  │ ┌──────────────┐ │  │ ┌──────────────┐ │                                 │   │
│   │  │ │  VM-Consumer │ │  │ │ Private      │ │                                 │   │
│   │  │ │  (Linux)     │ │  │ │ Endpoint     │ │                                 │   │
│   │  │ └──────────────┘ │  │ │ (to PLS)     │ │                                 │   │
│   │  │                  │  │ └──────────────┘ │                                 │   │
│   │  └──────────────────┘  └──────────────────┘                                 │   │
│   │                                                                              │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
│   ┌─────────────────────────────────────────────────────────────────────────────┐   │
│   │  Azure PaaS Services                                                         │   │
│   │                                                                              │   │
│   │  ┌──────────────────┐  ┌──────────────────┐                                 │   │
│   │  │ Storage Account  │  │ Storage Account  │                                 │   │
│   │  │ (with PE)        │  │ (with SE only)   │                                 │   │
│   │  │ + Public disabled│  │ + VNet allowed   │                                 │   │
│   │  └──────────────────┘  └──────────────────┘                                 │   │
│   │                                                                              │   │
│   └─────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                      │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- Azure Subscription with Owner/Contributor access
- PowerShell 7+ with Az module installed (`Install-Module Az`)
- Bicep CLI installed (`winget install Microsoft.Bicep`)
- PowerShell terminal

## Lab Exercises

### Exercise 1: Deploy the Infrastructure
### Exercise 2: Test Service Endpoint Connectivity
### Exercise 3: Test Private Endpoint Connectivity
### Exercise 4: Compare DNS Resolution
### Exercise 5: Test Private Link Service
### Exercise 6: Clean Up

---

## Exercise 1: Deploy the Infrastructure

### Step 1.1: Login to Azure

```powershell
# Login to Azure
Connect-AzAccount

# Set your subscription (if you have multiple)
Set-AzContext -SubscriptionId "<your-subscription-id>"

# Verify
Get-AzContext
```

### Step 1.2: Create Resource Group

```powershell
# Variables
$resourceGroup = "rg-privatelink-lab"
$location = "uksouth"

# Create Resource Group
New-AzResourceGroup -Name $resourceGroup -Location $location -Force
```

### Step 1.3: Deploy Bicep Template

```powershell
# Navigate to lab folder (after cloning: git clone https://github.com/me-mysel/AZ-700.git)
cd AZ-700/Labs/PrivateLink_ServiceEndpoints

# Deploy main template
$password = Read-Host -Prompt "Enter admin password" -AsSecureString

New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroup `
    -TemplateFile ".\main.bicep" `
    -adminPassword $password `
    -Verbose

# This will take approximately 10-15 minutes
```

### Step 1.4: Verify Deployment

```powershell
# List all resources
Get-AzResource -ResourceGroupName $resourceGroup | Format-Table Name, ResourceType, Location
```

---

## Exercise 2: Test Service Endpoint Connectivity

In this exercise, you'll test how Service Endpoints work.

### Step 2.1: Connect to VM-Test

```powershell
# Get VM public IP
$vmIp = (Get-AzPublicIpAddress -ResourceGroupName $resourceGroup -Name "vm-test-pip").IpAddress

Write-Host "VM IP: $vmIp"

# SSH to VM (use the password you set during deployment)
ssh azureuser@$vmIp
```

### Step 2.2: Test Storage Access via Service Endpoint

```bash
# On the VM, get the storage account name (with Service Endpoint)
# The name will be like: stselab<random>

# Test connectivity to storage with Service Endpoint
# Replace <storage-name> with actual name
curl -I https://<storage-name-se>.blob.core.windows.net/

# Check the route to storage (should show Azure backbone)
traceroute <storage-name-se>.blob.core.windows.net

# Try to resolve DNS - notice it returns PUBLIC IP
nslookup <storage-name-se>.blob.core.windows.net
```

### Step 2.3: Observations

**What you should see:**
- DNS resolves to a **public IP** (Service Endpoints don't change DNS)
- Traffic still flows to Azure (via backbone, not internet)
- Storage firewall allows access from VNet

**Key Learning:** Service Endpoints keep the public endpoint but route traffic optimally through Azure backbone.

---

## Exercise 3: Test Private Endpoint Connectivity

### Step 3.1: Test Storage Access via Private Endpoint

```bash
# Still on VM-Test

# Test connectivity to storage with Private Endpoint
# Replace <storage-name> with actual name (stpelab<random>)
curl -I https://<storage-name-pe>.blob.core.windows.net/

# Check DNS resolution - should return PRIVATE IP!
nslookup <storage-name-pe>.blob.core.windows.net

# You should see:
# - CNAME to privatelink.blob.core.windows.net
# - A record pointing to 10.0.2.x (private IP)
```

### Step 3.2: Compare DNS Resolution

```bash
# Service Endpoint storage - PUBLIC IP
nslookup <storage-name-se>.blob.core.windows.net
# Returns: 52.x.x.x (public)

# Private Endpoint storage - PRIVATE IP  
nslookup <storage-name-pe>.blob.core.windows.net
# Returns: 10.0.2.x (private)
```

### Step 3.3: Test from Outside (Optional)

```powershell
# From your local machine (outside Azure)
nslookup <storage-name-pe>.blob.core.windows.net

# This will return the PUBLIC IP because you're not using the Private DNS Zone
# This demonstrates why DNS configuration is critical!
```

### Step 3.4: Observations

**Key Learning:**
- Private Endpoint changes DNS resolution to return private IP
- Private DNS Zone is linked to VNet, so VMs resolve correctly
- External clients still resolve to public IP (unless you configure on-prem DNS)

---

## Exercise 4: Compare DNS Resolution Deep Dive

### Step 4.1: Examine Private DNS Zone

```powershell
# List Private DNS Zones
Get-AzPrivateDnsZone -ResourceGroupName $resourceGroup | Format-Table Name, NumberOfRecordSets

# Show records in the zone
Get-AzPrivateDnsRecordSet -ResourceGroupName $resourceGroup `
    -ZoneName "privatelink.blob.core.windows.net" | Format-Table Name, RecordType, Ttl

# Show the A record (Private Endpoint IP)
Get-AzPrivateDnsRecordSet -ResourceGroupName $resourceGroup `
    -ZoneName "privatelink.blob.core.windows.net" `
    -Name "<storage-name-pe>" `
    -RecordType A
```

### Step 4.2: Examine VNet Link

```powershell
# Show VNet links to Private DNS Zone
Get-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $resourceGroup `
    -ZoneName "privatelink.blob.core.windows.net" | Format-Table Name, VirtualNetworkId, RegistrationEnabled
```

---

## Exercise 5: Test Private Link Service

This exercise demonstrates exposing your own service to consumers.

### Step 5.1: Verify Private Link Service

```powershell
# Get Private Link Service details
Get-AzPrivateLinkService -ResourceGroupName $resourceGroup -Name "pls-web-service"

# Get the alias - this is what consumers use to connect
(Get-AzPrivateLinkService -ResourceGroupName $resourceGroup -Name "pls-web-service").Alias
```

### Step 5.2: Connect to Consumer VM

```powershell
# Get Consumer VM public IP
$consumerVmIp = (Get-AzPublicIpAddress -ResourceGroupName $resourceGroup -Name "vm-consumer-pip").IpAddress

Write-Host "Consumer VM IP: $consumerVmIp"

# SSH to Consumer VM
ssh azureuser@$consumerVmIp
```

### Step 5.3: Test Connectivity to Private Link Service

```bash
# On Consumer VM

# Get the Private Endpoint IP (should be in 10.1.2.x range)
ip addr show

# Test connectivity to the web service via Private Endpoint
# The Private Endpoint connects to the Internal Load Balancer via Private Link Service
curl http://10.1.2.4  # Replace with actual PE IP

# You should see response from the backend web server!
```

### Step 5.4: Observations

**Key Learning:**
- Consumer VNet has NO visibility into Provider VNet
- Consumer only sees their own Private Endpoint IP
- Private Link Service performs NAT
- Provider can approve/reject connection requests

---

## Exercise 6: Additional Tests

### Test 6.1: Try to Access PE Storage Without DNS

```bash
# On VM-Test, try to access storage using its public IP directly
# This should FAIL if public access is disabled

# Get the public IP of PE storage
publicIp=$(dig +short <storage-name-pe>.blob.core.windows.net @8.8.8.8)
echo "Public IP: $publicIp"

# Try to connect via public IP - should fail
curl -I https://$publicIp/ --resolve <storage-name-pe>.blob.core.windows.net:443:$publicIp
```

### Test 6.2: Verify Service Endpoint Routing

```powershell
# On your machine, check effective routes for the VM NIC
# You should see Microsoft.Storage service endpoint route

$nic = Get-AzNetworkInterface -ResourceGroupName $resourceGroup -Name "vm-test-nic"
Get-AzEffectiveRouteTable -NetworkInterfaceName $nic.Name -ResourceGroupName $resourceGroup | Format-Table
```

### Test 6.3: Test NSG with Private Endpoint

```powershell
# Private Endpoints have limited NSG support by default
# Check if network policies are enabled

$subnet = Get-AzVirtualNetworkSubnetConfig -Name "subnet-pe" `
    -VirtualNetwork (Get-AzVirtualNetwork -ResourceGroupName $resourceGroup -Name "vnet-hub")

$subnet.PrivateEndpointNetworkPolicies
```

---

## Exercise 7: Clean Up

```powershell
# Delete all resources (runs in background)
Remove-AzResourceGroup -Name $resourceGroup -Force -AsJob

# Verify deletion (will show error when deleted)
Get-AzResourceGroup -Name $resourceGroup
```

---

## Key Takeaways

### Service Endpoints
| Aspect | Observation |
|--------|-------------|
| DNS | Returns **public IP** |
| Traffic | Goes through Azure backbone (not internet) |
| PaaS endpoint | Still public, requires firewall rules |
| Cost | **Free** |
| On-premises | Does NOT work |

### Private Endpoints
| Aspect | Observation |
|--------|-------------|
| DNS | Returns **private IP** (via Private DNS Zone) |
| Traffic | Stays entirely within VNet |
| PaaS endpoint | Can disable public access |
| Cost | Per hour + data |
| On-premises | Works via VPN/ExpressRoute |

### Private Link Service
| Aspect | Observation |
|--------|-------------|
| Purpose | Expose YOUR service to others |
| Consumer view | Only sees Private Endpoint IP |
| Provider view | Sees NAT IP, not consumer's real IP |
| Use case | SaaS, multi-tenant services |

---

## Troubleshooting

### DNS Not Resolving to Private IP

```powershell
# Check if Private DNS Zone is linked to VNet
Get-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $resourceGroup `
    -ZoneName "privatelink.blob.core.windows.net"

# Check if A record exists
Get-AzPrivateDnsRecordSet -ResourceGroupName $resourceGroup `
    -ZoneName "privatelink.blob.core.windows.net" `
    -RecordType A
```

### Cannot Connect to Storage

```powershell
# Check storage firewall settings
$storage = Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name "<storage-name>"
$storage.NetworkRuleSet | Format-List

# Check if VNet is allowed (for Service Endpoint)
$storage.NetworkRuleSet.VirtualNetworkRules | Format-Table
```

### Private Link Service Connection Pending

```powershell
# Check connection status
$pls = Get-AzPrivateLinkService -ResourceGroupName $resourceGroup -Name "pls-web-service"
$pls.PrivateEndpointConnections | Format-Table Name, PrivateLinkServiceConnectionState

# Approve if pending
Approve-AzPrivateEndpointConnection -ResourceGroupName $resourceGroup `
    -ServiceName "pls-web-service" `
    -Name "<connection-name>" `
    -Description "Approved"
```

---

## Next Steps

1. Try adding a second storage account and creating a Service Endpoint Policy
2. Configure on-premises DNS forwarding for Private Endpoints
3. Test cross-region Private Endpoints
4. Implement Azure Private Resolver for hybrid DNS

---

---

## Addendum: Bicep Deployment Troubleshooting Guide

This section documents real deployment issues encountered during lab creation and how they were resolved. Use this as a learning resource for troubleshooting Bicep/ARM deployments.

---

### Issue 1: Password Complexity Requirements

**Error Message:**
```
The supplied password must be between 6-72 characters long and must satisfy at least 3 of password complexity requirements
```

**Cause:**
Azure VMs require passwords that meet complexity requirements:
- Minimum 12 characters (recommended)
- At least 3 of: uppercase, lowercase, number, special character

**Fix:**
Use a compliant password like `P@ssw0rd2026!`

```powershell
# Bad - too simple
$password = ConvertTo-SecureString "password123" -AsPlainText -Force

# Good - meets complexity
$password = ConvertTo-SecureString "P@ssw0rd2026!" -AsPlainText -Force
```

**Lesson:** Always validate password requirements before deployment. Consider using `@secure()` parameter decorators in Bicep.

---

### Issue 2: VM Extension Package Installation Failures (Ubuntu)

**Error Message:**
```
E: Package 'traceroute' has no installation candidate
E: Unable to locate package net-tools
Unable to connect to azure.archive.ubuntu.com:http
```

**Cause:**
1. Package names changed in Ubuntu 22.04 (`traceroute` → `inetutils-traceroute`)
2. VMs couldn't reach Ubuntu package repositories due to network timeouts
3. IPv6 connectivity issues in Azure causing apt-get failures

**Original Bicep (problematic):**
```bicep
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  properties: {
    commandToExecute: 'apt-get update && apt-get install -y dnsutils curl traceroute net-tools'
  }
}
```

**Fixed Bicep:**
```bicep
resource vmExtension 'Microsoft.Compute/virtualMachines/extensions@2023-07-01' = {
  properties: {
    // Use correct package names and add || true to continue on failure
    commandToExecute: 'apt-get update && apt-get install -y dnsutils curl iputils-ping || true'
  }
}
```

**Key Fixes:**
1. **Use correct package names** - Research which packages exist in your target OS version
2. **Add `|| true`** - Makes the extension succeed even if some packages fail
3. **Avoid unnecessary packages** - Only install what's truly needed

**Alternative: Use Python HTTP Server Instead of nginx:**
```bicep
// Instead of installing nginx (requires network access to repos)
commandToExecute: 'mkdir -p /var/www/html && echo "Hello!" > /var/www/html/index.html && cd /var/www/html && nohup python3 -m http.server 80 &'
```

**Lesson:** VM extensions that require package downloads are fragile. Consider:
- Using pre-built images with tools installed
- Using cloud-init instead of CustomScript extension
- Making scripts resilient with `|| true` or proper error handling

---

### Issue 3: Storage Account Not Found During Deployment

**Error Message:**
```
The Resource 'Microsoft.Storage/storageAccounts/stpelaby7aw2phzczdw6' under resource group 'rg-privatelink-lab' was not found
```

**Cause:**
The deployment was rerun after a partial cleanup, and the `uniqueSuffix` parameter generated a reference to a storage account that existed in a previous deployment but was deleted.

**Fix:**
When redeploying after cleanup, ensure the resource group is completely deleted first:

```powershell
# Wait for complete deletion before redeploying
Remove-AzResourceGroup -Name "rg-privatelink-lab" -Force

# Verify it's gone
do {
    Start-Sleep -Seconds 10
    $rg = Get-AzResourceGroup -Name "rg-privatelink-lab" -ErrorAction SilentlyContinue
} while ($rg)

# Now safe to recreate
New-AzResourceGroup -Name "rg-privatelink-lab" -Location "uksouth"
```

**Lesson:** ARM deployments use incremental mode by default. If resources were partially created/deleted, you may get orphaned references. Always ensure clean state before redeployment.

---

### Issue 4: Deployment Not Found (404)

**Error Message:**
```
Deployment '93517977-5aa2-4ea5-aa07-66883feda07e' could not be found.
StatusCode: 404
```

**Cause:**
The deployment tracking record was lost or timed out while Azure was still provisioning resources.

**Fix:**
Check if resources were actually created despite the error:

```powershell
# Check what actually got deployed
Get-AzResource -ResourceGroupName "rg-privatelink-lab" | Select-Object Name, ResourceType

# Check VM status specifically
Get-AzVM -ResourceGroupName "rg-privatelink-lab" -Status
```

If partial deployment occurred, rerun the deployment - Bicep/ARM is idempotent:

```powershell
# Safe to rerun - will create missing resources and skip existing ones
New-AzResourceGroupDeployment `
    -ResourceGroupName "rg-privatelink-lab" `
    -TemplateFile ".\main.bicep" `
    -adminPassword $securePassword
```

**Lesson:** ARM deployments are idempotent. If something goes wrong, you can usually just rerun the deployment.

---

### Issue 5: Wrong Working Directory

**Error Message:**
```
Cannot find path 'C:\Users\...\Labs\main.bicep' because it does not exist.
```

**Cause:**
Terminal was in `Labs\` directory instead of `Labs\PrivateLink_ServiceEndpoints\`

**Fix:**
Always use full paths or ensure correct working directory:

```powershell
# Option 1: Change to correct directory first
cd Labs/PrivateLink_ServiceEndpoints
New-AzResourceGroupDeployment -TemplateFile ".\main.bicep"

# Option 2: Use the deploy script
.\deploy.ps1 -AdminPassword (Read-Host -AsSecureString -Prompt "Password")
```

**Lesson:** Always verify your working directory before running deployment commands.

---

### Debugging Techniques Summary

#### 1. View Deployment Errors

```powershell
# Get latest deployment
$deployment = Get-AzResourceGroupDeployment -ResourceGroupName "rg-privatelink-lab" | 
    Sort-Object Timestamp -Descending | 
    Select-Object -First 1

# View failed operations
Get-AzResourceGroupDeploymentOperation -ResourceGroupName "rg-privatelink-lab" -DeploymentName $deployment.DeploymentName | 
    Where-Object { $_.Properties.ProvisioningState -eq "Failed" } |
    Select-Object @{N='Resource';E={$_.Properties.TargetResource.ResourceType}}, 
                  @{N='Error';E={$_.Properties.StatusMessage}}
```

#### 2. Validate Before Deploying

```powershell
# Test deployment without actually deploying
Test-AzResourceGroupDeployment `
    -ResourceGroupName "rg-privatelink-lab" `
    -TemplateFile ".\main.bicep" `
    -adminPassword $securePassword
```

#### 3. Use What-If for Safe Preview

```powershell
# Preview what changes would be made
New-AzResourceGroupDeployment `
    -ResourceGroupName "rg-privatelink-lab" `
    -TemplateFile ".\main.bicep" `
    -WhatIf
```

#### 4. Check Bicep Linter Warnings

Bicep provides helpful warnings during compilation:

```
Warning no-hardcoded-env-urls: Environment URLs should not be hardcoded.
Warning no-unnecessary-dependson: Remove unnecessary dependsOn entry.
```

Fix hardcoded URLs:
```bicep
// Bad
var storageEndpoint = 'core.windows.net'

// Good - use environment function
var storageEndpoint = environment().suffixes.storage
```

#### 5. View VM Extension Logs (After Deployment)

```bash
# SSH to VM and check extension logs
sudo cat /var/log/azure/custom-script/handler.log
sudo cat /var/lib/waagent/custom-script/download/0/stdout
sudo cat /var/lib/waagent/custom-script/download/0/stderr
```

---

### Cost Optimisation: Auto-Shutdown Setup

To save costs when not using the lab, we configured Azure Automation to deallocate VMs daily at 19:00.

**Setup Script:** `setup-azure-automation.ps1`

**What It Creates:**
1. **Automation Account** - `aa-lab-automation` with System Managed Identity
2. **Role Assignment** - VM Contributor on the resource group
3. **Runbook** - PowerShell script to stop VMs
4. **Schedule** - Daily at 19:00 GMT

**Cost Savings:**
| State | Cost/Day (approx) |
|-------|------------------|
| Running 24/7 | £3.50 - £4.00 |
| Deallocated at 19:00 | £1.20 - £1.60 |
| **Savings** | **~60%** |

**Manual Commands:**
```powershell
# Stop VMs immediately
Start-AzAutomationRunbook -ResourceGroupName 'rg-privatelink-lab' `
    -AutomationAccountName 'aa-lab-automation' -Name 'Stop-LabVMs'

# Start VMs when needed
Get-AzVM -ResourceGroupName 'rg-privatelink-lab' | Start-AzVM

# Check automation schedule
Get-AzAutomationSchedule -ResourceGroupName 'rg-privatelink-lab' `
    -AutomationAccountName 'aa-lab-automation'
```

---

### Files in This Lab

| File | Purpose |
|------|---------|
| `main.bicep` | Main infrastructure template |
| `deploy.ps1` | Deployment script with error handling |
| `cleanup.ps1` | Resource cleanup script |
| `stop-vms.ps1` | Manual VM stop script |
| `setup-azure-automation.ps1` | Configure scheduled VM shutdown |
| `setup-scheduled-task.ps1` | Windows Task Scheduler alternative |
| `enable-autoshutdown.ps1` | Azure built-in auto-shutdown (simplest) |

---

*Addendum Added: January 2026*
*Documenting real troubleshooting scenarios for learning purposes*
