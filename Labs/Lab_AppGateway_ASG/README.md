# AZ-700 Lab: Application Gateway with Application Security Groups

## 🎯 Lab Objectives

By completing this lab, you will learn to:

1. **Deploy and configure Azure Application Gateway v2** with backend pools
2. **Create and use Application Security Groups (ASGs)** for logical VM grouping
3. **Configure NSG rules using ASGs** instead of IP addresses
4. **Understand Application Gateway health probes** and backend health
5. **Test load balancing** across multiple backend VMs
6. **Troubleshoot common Application Gateway issues**

---

## 📋 Prerequisites

- Azure subscription with Contributor access
- Azure PowerShell module installed (`Install-Module Az`)
- Basic understanding of Azure networking concepts
- Logged in to Azure (`Connect-AzAccount`)

---

## 🏗️ Architecture Overview

```
                         Internet
                             │
                             ▼
                    ┌─────────────────┐
                    │  Public IP      │
                    │  (pip-appgw)    │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │     Application Gateway     │
              │        (appgw-lab)          │
              │   ┌───────────────────┐     │
              │   │ HTTP Listener:80  │     │
              │   │ Backend Pool      │     │
              │   │ Health Probes     │     │
              │   └───────────────────┘     │
              └──────────────┬──────────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│ AppGatewaySubnet│ │   WebSubnet     │ │   AppSubnet     │
│  10.10.0.0/24   │ │  10.10.1.0/24   │ │  10.10.2.0/24   │
│                 │ │ ┌─────────────┐ │ │ ┌─────────────┐ │
│  (App Gateway)  │ │ │ vm-web-01   │ │ │ │ vm-app-01   │ │
│                 │ │ │ ASG: web    │ │ │ │ ASG: app    │ │
│                 │ │ ├─────────────┤ │ │ └─────────────┘ │
│                 │ │ │ vm-web-02   │ │ │                 │
│                 │ │ │ ASG: web    │ │ │                 │
│                 │ │ └─────────────┘ │ │                 │
│                 │ │  NSG: nsg-web   │ │  NSG: nsg-app   │
└─────────────────┘ └─────────────────┘ └─────────────────┘

VNet: vnet-lab-appgw (10.10.0.0/16)
```

### Security Design with ASGs

```
┌──────────────────────────────────────────────────────────────────┐
│                     NSG Rules Overview                           │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  nsg-web-tier:                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Priority 100: Allow HTTP (80) from AppGatewaySubnet      │   │
│  │               → TO: asg-webservers                       │   │
│  │                                                          │   │
│  │ Priority 110: Allow HTTPS (443) from AppGatewaySubnet    │   │
│  │               → TO: asg-webservers                       │   │
│  │                                                          │   │
│  │ Priority 120: Allow AppGW Health Probes (65200-65535)    │   │
│  │               FROM: GatewayManager service tag           │   │
│  │                                                          │   │
│  │ Priority 4096: Deny All Other Inbound                    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  nsg-app-tier:                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Priority 100: Allow TCP 8080                             │   │
│  │               FROM: asg-webservers → TO: asg-appservers  │   │
│  │                                                          │   │
│  │ Priority 4096: Deny All Other Inbound                    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## 🚀 Deployment Instructions

### Step 1: Deploy the Lab Environment

**From GitHub (any machine):**
```bash
git clone https://github.com/me-mysel/AZ-700.git
cd AZ-700/Labs/Lab_AppGateway_ASG
```

**Deploy with PowerShell:**
```powershell
$password = Read-Host -AsSecureString -Prompt "Enter admin password for VMs"
.\deploy.ps1 -AdminPassword $password
```

**Or deploy with Azure CLI:**
```bash
az group create -n rg-az700-appgw-asg-lab -l uksouth
az deployment group create -g rg-az700-appgw-asg-lab -f main.bicep \
  --parameters adminPassword='<YourPassword123!>'
```

**Deployment Time:** ~10-15 minutes

The deployment creates:
- 1 VNet with 3 subnets
- 1 Application Gateway (Standard_v2)
- 2 Application Security Groups
- 2 Network Security Groups with ASG-based rules
- 3 Virtual Machines (2 web + 1 app)
- IIS installed on web VMs with custom homepage

---

## 📝 Hands-On Exercises

### Exercise 1: Verify Application Gateway and Load Balancing

**Objective:** Understand how Application Gateway distributes traffic to backend VMs.

1. **Get the Application Gateway public IP/FQDN:**
   ```powershell
   $appGw = Get-AzApplicationGateway -ResourceGroupName "rg-az700-appgw-asg-lab" -Name "appgw-lab"
   $pip = Get-AzPublicIpAddress -ResourceGroupName "rg-az700-appgw-asg-lab" -Name "pip-appgw"
   Write-Host "URL: http://$($pip.DnsSettings.Fqdn)"
   ```

2. **Test load balancing by refreshing the page multiple times:**
   ```powershell
   # Run this multiple times - observe the server name changing
   Invoke-WebRequest -Uri "http://$($pip.IpAddress)" -UseBasicParsing | Select-Object -ExpandProperty Content
   ```

3. **Observe which server responds** - you should see responses alternating between `vm-web-01` and `vm-web-02`.

**📌 Exam Insight:** Application Gateway uses round-robin by default. For session persistence, configure cookie-based affinity.

---

### Exercise 2: Explore Application Gateway Backend Health

**Objective:** Understand how health probes work and troubleshoot unhealthy backends.

1. **Check backend health via PowerShell:**
   ```powershell
   $appGw = Get-AzApplicationGateway -ResourceGroupName "rg-az700-appgw-asg-lab" -Name "appgw-lab"
   Get-AzApplicationGatewayBackendHealth -ResourceGroupName "rg-az700-appgw-asg-lab" -Name "appgw-lab" | 
       Select-Object -ExpandProperty BackendAddressPools | 
       Select-Object -ExpandProperty BackendHttpSettingsCollection |
       Select-Object -ExpandProperty Servers
   ```

2. **In Azure Portal:**
   - Navigate to Application Gateway → Backend health
   - Observe the health status of each backend VM
   - Note the probe interval, timeout, and unhealthy threshold

**📌 Exam Insight:** If backend shows "Unhealthy":
- Check if NSG allows traffic from AppGateway subnet (not Internet!)
- Verify health probe port matches application port
- Ensure health probe path returns 200-399 status code

---

### Exercise 3: Examine Application Security Groups

**Objective:** Understand how ASGs simplify security rule management.

1. **List all ASGs in the resource group:**
   ```powershell
   Get-AzApplicationSecurityGroup -ResourceGroupName "rg-az700-appgw-asg-lab" | 
       Select-Object Name, Location, ResourceGroupName
   ```

2. **Check which NICs are associated with each ASG:**
   ```powershell
   # Get all NICs and their ASG associations
   Get-AzNetworkInterface -ResourceGroupName "rg-az700-appgw-asg-lab" | ForEach-Object {
       $nic = $_
       $asgNames = $nic.IpConfigurations[0].ApplicationSecurityGroups | ForEach-Object { 
           ($_.Id -split '/')[-1] 
       }
       [PSCustomObject]@{
           NIC = $nic.Name
           VM = ($nic.VirtualMachine.Id -split '/')[-1]
           ASGs = $asgNames -join ', '
           PrivateIP = $nic.IpConfigurations[0].PrivateIpAddress
       }
   } | Format-Table -AutoSize
   ```

**Expected Output:**
```
NIC           VM          ASGs            PrivateIP
---           --          ----            ---------
nic-vm-web-01 vm-web-01   asg-webservers  10.10.1.x
nic-vm-web-02 vm-web-02   asg-webservers  10.10.1.x
nic-vm-app-01 vm-app-01   asg-appservers  10.10.2.x
```

**📌 Exam Insight:** ASGs allow you to:
- Group VMs logically regardless of IP address
- Create rules that automatically apply when VMs join/leave groups
- Simplify rule management (no need to update rules when IPs change)

---

### Exercise 4: Analyze NSG Rules with ASG References

**Objective:** Understand how NSG rules use ASGs instead of IP addresses.

1. **View NSG rules for the web tier:**
   ```powershell
   $nsgWeb = Get-AzNetworkSecurityGroup -ResourceGroupName "rg-az700-appgw-asg-lab" -Name "nsg-web-tier"
   $nsgWeb.SecurityRules | Select-Object Name, Priority, Direction, Access, Protocol, 
       @{N='SourceASG';E={($_.SourceApplicationSecurityGroups.Id -split '/')[-1]}},
       @{N='DestASG';E={($_.DestinationApplicationSecurityGroups.Id -split '/')[-1]}},
       DestinationPortRange | Format-Table -AutoSize
   ```

2. **View NSG rules for the app tier:**
   ```powershell
   $nsgApp = Get-AzNetworkSecurityGroup -ResourceGroupName "rg-az700-appgw-asg-lab" -Name "nsg-app-tier"
   $nsgApp.SecurityRules | Select-Object Name, Priority, Direction, Access, Protocol,
       @{N='SourceASG';E={($_.SourceApplicationSecurityGroups.Id -split '/')[-1]}},
       @{N='DestASG';E={($_.DestinationApplicationSecurityGroups.Id -split '/')[-1]}},
       DestinationPortRange | Format-Table -AutoSize
   ```

**Key Observation:** The app tier rule `Allow-From-WebServers-ASG` references ASGs in both source AND destination - this creates a precise rule that only allows traffic from web servers to app servers.

---

### Exercise 5: Test ASG-Based Connectivity

**Objective:** Verify that ASG rules control traffic flow correctly.

1. **RDP to vm-web-01** (you'll need to add a public IP or use Bastion for this exercise)

2. **From vm-web-01, test connectivity to vm-app-01 on port 8080:**
   ```powershell
   # This should work (web → app on 8080 is allowed)
   Test-NetConnection -ComputerName 10.10.2.4 -Port 8080
   ```

3. **From vm-web-01, test connectivity to vm-app-01 on port 443:**
   ```powershell
   # This should FAIL (only port 8080 is allowed)
   Test-NetConnection -ComputerName 10.10.2.4 -Port 443
   ```

**📌 Exam Insight:** ASG rules are evaluated based on the NIC's ASG membership at the time of packet evaluation, not the IP address.

---

### Exercise 6: Add a New Web Server to the ASG

**Objective:** Experience how ASGs automatically apply security rules to new members.

1. **Create a new NIC associated with the web ASG:**
   ```powershell
   $vnet = Get-AzVirtualNetwork -ResourceGroupName "rg-az700-appgw-asg-lab" -Name "vnet-lab-appgw"
   $webSubnet = $vnet.Subnets | Where-Object { $_.Name -eq "WebSubnet" }
   $asgWeb = Get-AzApplicationSecurityGroup -ResourceGroupName "rg-az700-appgw-asg-lab" -Name "asg-webservers"
   
   $nicConfig = New-AzNetworkInterfaceIpConfig `
       -Name "ipconfig1" `
       -SubnetId $webSubnet.Id `
       -ApplicationSecurityGroupId $asgWeb.Id
   
   $newNic = New-AzNetworkInterface `
       -Name "nic-vm-web-03" `
       -ResourceGroupName "rg-az700-appgw-asg-lab" `
       -Location "uksouth" `
       -IpConfiguration $nicConfig
   
   Write-Host "New NIC created with ASG association: $($newNic.Name)"
   ```

2. **Verify the new NIC has ASG association:**
   ```powershell
   Get-AzNetworkInterface -Name "nic-vm-web-03" -ResourceGroupName "rg-az700-appgw-asg-lab" | 
       Select-Object -ExpandProperty IpConfigurations | 
       Select-Object -ExpandProperty ApplicationSecurityGroups
   ```

**📌 Exam Insight:** When you associate a NIC with an ASG, all NSG rules referencing that ASG automatically apply - no rule changes needed!

---

### Exercise 7: Application Gateway URL Path-Based Routing (Bonus)

**Objective:** Configure path-based routing to direct traffic to different backends.

1. **In Azure Portal, navigate to Application Gateway → Rules**

2. **Create a new path-based rule:**
   - Add a path: `/api/*` → Create a new backend pool (you could point this to the app tier)
   - Default path → webBackendPool

3. **Understand the use case:**
   - `/` and `/images/*` → Web servers
   - `/api/*` → API servers
   - This is L7 routing based on URL content

**📌 Exam Insight:** Path-based routing is a key differentiator between Application Gateway (L7) and Azure Load Balancer (L4).

---

### Exercise 8: Application Gateway Rewrite Rules (Exam Focus!)

**Objective:** Configure HTTP header and URL rewrites - a common AZ-700 exam topic.

#### Part A: Add Security Headers (Remove Server Information)

1. **Get the Application Gateway:**
   ```powershell
   $appGw = Get-AzApplicationGateway -ResourceGroupName "rg-az700-appgw-asg-lab" -Name "appgw-lab"
   ```

2. **Create a rewrite rule to remove the Server header (security hardening):**
   ```powershell
   # Create response header configuration - empty value removes the header
   $responseHeaderConfig = New-AzApplicationGatewayRewriteRuleHeaderConfiguration `
       -HeaderName "Server" `
       -HeaderValue ""
   
   # Create another to remove X-Powered-By
   $poweredByConfig = New-AzApplicationGatewayRewriteRuleHeaderConfiguration `
       -HeaderName "X-Powered-By" `
       -HeaderValue ""
   
   # Create the action set with both header removals
   $actionSet = New-AzApplicationGatewayRewriteRuleActionSet `
       -ResponseHeaderConfiguration $responseHeaderConfig, $poweredByConfig
   
   # Create the rewrite rule
   $rewriteRule = New-AzApplicationGatewayRewriteRule `
       -Name "RemoveServerHeaders" `
       -ActionSet $actionSet `
       -RuleSequence 100
   
   # Create the rewrite rule set
   $rewriteRuleSet = New-AzApplicationGatewayRewriteRuleSet `
       -Name "SecurityHeaders" `
       -RewriteRule $rewriteRule
   
   # Add to Application Gateway
   $appGw.RewriteRuleSets = $rewriteRuleSet
   ```

3. **Apply the changes:**
   ```powershell
   Set-AzApplicationGateway -ApplicationGateway $appGw
   ```

#### Part B: Add X-Forwarded Headers (Backend Awareness)

1. **Create rules to add forwarding headers:**
   ```powershell
   $appGw = Get-AzApplicationGateway -ResourceGroupName "rg-az700-appgw-asg-lab" -Name "appgw-lab"
   
   # Add X-Forwarded-Proto so backend knows original protocol
   $forwardedProtoConfig = New-AzApplicationGatewayRewriteRuleHeaderConfiguration `
       -HeaderName "X-Forwarded-Proto" `
       -HeaderValue "https"
   
   # Add X-Original-Host to preserve original host header
   $originalHostConfig = New-AzApplicationGatewayRewriteRuleHeaderConfiguration `
       -HeaderName "X-Original-Host" `
       -HeaderValue "{var_host}"
   
   $requestActionSet = New-AzApplicationGatewayRewriteRuleActionSet `
       -RequestHeaderConfiguration $forwardedProtoConfig, $originalHostConfig
   
   $forwardingRule = New-AzApplicationGatewayRewriteRule `
       -Name "AddForwardingHeaders" `
       -ActionSet $requestActionSet `
       -RuleSequence 200
   
   # Add to existing rule set
   $appGw.RewriteRuleSets[0].RewriteRules += $forwardingRule
   
   Set-AzApplicationGateway -ApplicationGateway $appGw
   ```

#### Part C: View Rewrite Rules Configuration (Exam Skill!)

1. **Export the configuration to understand the JSON structure:**
   ```powershell
   $appGw = Get-AzApplicationGateway -ResourceGroupName "rg-az700-appgw-asg-lab" -Name "appgw-lab"
   
   # View rewrite rule sets
   $appGw.RewriteRuleSets | ConvertTo-Json -Depth 10
   ```

2. **Examine the JSON output - understand each field:**
   ```powershell
   # List all rewrite rules with their sequences
   $appGw.RewriteRuleSets | ForEach-Object {
       Write-Host "Rule Set: $($_.Name)" -ForegroundColor Cyan
       $_.RewriteRules | ForEach-Object {
           Write-Host "  Rule: $($_.Name) (Sequence: $($_.RuleSequence))" -ForegroundColor Yellow
           Write-Host "    Request Headers:" -ForegroundColor Gray
           $_.ActionSet.RequestHeaderConfigurations | ForEach-Object {
               $action = if ($_.HeaderValue -eq "") { "REMOVE" } else { "SET" }
               Write-Host "      $action $($_.HeaderName) = '$($_.HeaderValue)'"
           }
           Write-Host "    Response Headers:" -ForegroundColor Gray
           $_.ActionSet.ResponseHeaderConfigurations | ForEach-Object {
               $action = if ($_.HeaderValue -eq "") { "REMOVE" } else { "SET" }
               Write-Host "      $action $($_.HeaderName) = '$($_.HeaderValue)'"
           }
       }
   }
   ```

#### Part D: Associate Rewrite Rule Set with Routing Rule

1. **Link the rewrite rules to the routing rule:**
   ```powershell
   $appGw = Get-AzApplicationGateway -ResourceGroupName "rg-az700-appgw-asg-lab" -Name "appgw-lab"
   
   # Get the rewrite rule set ID
   $rewriteRuleSetId = $appGw.RewriteRuleSets[0].Id
   
   # Update the routing rule to use the rewrite set
   $appGw.RequestRoutingRules[0].RewriteRuleSet = New-Object Microsoft.Azure.Commands.Network.Models.PSApplicationGatewayRewriteRuleSet
   $appGw.RequestRoutingRules[0].RewriteRuleSet.Id = $rewriteRuleSetId
   
   Set-AzApplicationGateway -ApplicationGateway $appGw
   ```

2. **Verify the rewrite is working:**
   ```powershell
   $pip = Get-AzPublicIpAddress -ResourceGroupName "rg-az700-appgw-asg-lab" -Name "pip-appgw"
   
   # Check response headers - Server should be absent
   $response = Invoke-WebRequest -Uri "http://$($pip.IpAddress)" -UseBasicParsing
   $response.Headers
   
   # The "Server" header should no longer appear!
   ```

**📌 Exam Insight - Rewrite Rules JSON Fields:**

| Field | Purpose | Exam Trap |
|-------|---------|-----------|
| `ruleSequence` | Execution order | **Lower numbers run first** |
| `headerValue: ""` | Empty string | **Removes** the header |
| `{var_host}` | Server variable | Captures original host |
| `http_req_*` | Request header variable | Use underscores, not hyphens |
| `http_resp_*` | Response header variable | Can't use in request configs |

**Common Exam Scenarios:**

| Requirement | Solution |
|-------------|----------|
| Hide server technology | Remove `Server` and `X-Powered-By` response headers |
| Backend needs original protocol | Add `X-Forwarded-Proto` request header |
| Backend needs client IP | Add `X-Forwarded-For` with `{var_add_x_forwarded_for_proxy}` |
| Add CORS headers | Add `Access-Control-Allow-Origin` response header |
| URL path rewrite | Use `urlConfiguration.modifiedPath` |

---

## 🔍 Troubleshooting Scenarios

### Scenario A: Backend Health Shows "Unhealthy"

**Symptoms:** Application Gateway shows backend as unhealthy, but VM is running.

**Troubleshooting Steps:**
```powershell
# 1. Check if IIS is running on the VM
Invoke-Command -VMName "vm-web-01" -Credential $cred -ScriptBlock {
    Get-Service W3SVC | Select-Object Name, Status
}

# 2. Check NSG effective rules
Get-AzEffectiveNetworkSecurityGroup -NetworkInterfaceName "nic-vm-web-01" -ResourceGroupName "rg-az700-appgw-asg-lab"

# 3. Verify health probe settings
$appGw = Get-AzApplicationGateway -ResourceGroupName "rg-az700-appgw-asg-lab" -Name "appgw-lab"
$appGw.Probes | Select-Object Name, Protocol, Path, Interval, Timeout, UnhealthyThreshold
```

**Common Causes:**
1. NSG blocking traffic from Application Gateway subnet
2. Health probe path not returning 200-399
3. Probe port doesn't match application port
4. Windows Firewall on the VM blocking traffic

---

### Scenario B: ASG Rule Not Working

**Symptoms:** Traffic between VMs is blocked despite ASG rule allowing it.

**Troubleshooting Steps:**
```powershell
# 1. Verify NIC is associated with correct ASG
Get-AzNetworkInterface -Name "nic-vm-web-01" -ResourceGroupName "rg-az700-appgw-asg-lab" | 
    Select-Object -ExpandProperty IpConfigurations | 
    Select-Object -ExpandProperty ApplicationSecurityGroups

# 2. Check effective security rules
Get-AzEffectiveNetworkSecurityGroup -NetworkInterfaceName "nic-vm-web-01" -ResourceGroupName "rg-az700-appgw-asg-lab" |
    Select-Object -ExpandProperty EffectiveSecurityRules | Format-Table

# 3. Ensure both source and destination NICs have ASG association
```

**Common Causes:**
1. ASG not associated with NIC (most common!)
2. Higher priority deny rule blocking traffic
3. ASGs in different regions (not supported)
4. Traffic from peered VNet (ASGs don't work across peered VNets)

---

## 📚 Key AZ-700 Exam Concepts Covered

| Concept | What to Remember |
|---------|------------------|
| **Application Gateway v2** | Requires dedicated subnet, Standard SKU public IP, supports autoscaling |
| **AppGateway Health Probes** | Source is AppGW subnet IP, not Internet. NSG must allow from subnet range |
| **AppGateway Ports** | Needs 65200-65535 open for v2 health probes from GatewayManager |
| **ASG Scope** | Same region only, same VNet for NIC association |
| **ASG + NSG** | ASGs can be used in both source and destination fields |
| **ASG Membership** | NIC can belong to multiple ASGs (up to limits) |
| **Traffic Flow** | AppGW → Backend uses private IPs within VNet |
| **Backend Pool** | Can contain IPs, FQDNs, or VM scale sets |

---

## 🧹 Cleanup

When you're done with the lab, clean up resources to avoid charges:

```powershell
.\cleanup.ps1
```

Or with force (no confirmation):
```powershell
.\cleanup.ps1 -Force
```

---

## 📖 Additional Resources

- [Application Gateway Documentation](https://docs.microsoft.com/azure/application-gateway/overview)
- [Application Security Groups](https://docs.microsoft.com/azure/virtual-network/application-security-groups)
- [Application Gateway Health Monitoring](https://docs.microsoft.com/azure/application-gateway/application-gateway-probe-overview)
- [NSG with ASG Rules](https://docs.microsoft.com/azure/virtual-network/network-security-groups-overview#application-security-groups)

---

## ✅ Lab Completion Checklist

- [ ] Successfully deployed the lab environment
- [ ] Verified Application Gateway is distributing traffic (Exercise 1)
- [ ] Checked backend health and understand probe requirements (Exercise 2)
- [ ] Listed ASGs and understand their purpose (Exercise 3)
- [ ] Analyzed NSG rules using ASG references (Exercise 4)
- [ ] Tested connectivity governed by ASG rules (Exercise 5)
- [ ] Added a new NIC to an ASG and verified automatic rule application (Exercise 6)
- [ ] Cleaned up resources

---

*Lab Version: 1.0*  
*AZ-700: Designing and Implementing Microsoft Azure Networking Solutions*  
*Last Updated: January 2026*
