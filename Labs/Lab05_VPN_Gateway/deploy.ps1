# AZ-700 Lab 5: Deploy Script

$resourceGroupName = "rg-az700-lab05-vpn"
$location = "uksouth"

# Prompt for passwords
$adminPassword = Read-Host -Prompt "Enter VM admin password" -AsSecureString
$vpnSharedKey = Read-Host -Prompt "Enter VPN shared key (PSK)" -AsSecureString

Write-Host "`n📦 Creating Resource Group..." -ForegroundColor Cyan
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

Write-Host @"

================================================================================
⚠️  IMPORTANT: VPN Gateway Deployment Takes 30-45 MINUTES!
================================================================================
The VPN Gateways are the most time-consuming resources to deploy.
Go grab a coffee ☕ and come back later!

Resources being deployed:
  • 2 VNets (simulated on-prem + Azure hub)
  • 2 VPN Gateways (this takes the longest!)
  • 2 Local Network Gateways
  • 2 VPN Connections (with BGP enabled)
  • 2 Test VMs (one in each VNet)
================================================================================

"@ -ForegroundColor Yellow

Write-Host "🚀 Starting deployment..." -ForegroundColor Cyan
$startTime = Get-Date

$deployment = New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile ".\main.bicep" `
    -adminPassword $adminPassword `
    -vpnSharedKey $vpnSharedKey `
    -location $location `
    -Verbose

$endTime = Get-Date
$duration = $endTime - $startTime

Write-Host "`n✅ Deployment Complete!" -ForegroundColor Green
Write-Host "⏱️  Duration: $($duration.TotalMinutes.ToString('0.0')) minutes" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Yellow

Write-Host "`n🖥️  VM ACCESS:" -ForegroundColor Cyan
Write-Host "   'On-Prem' VM:  mstsc /v:$($deployment.Outputs.onPremVmPublicIp.Value)    (192.168.1.4)"
Write-Host "   Azure VM:      mstsc /v:$($deployment.Outputs.azureVmPublicIp.Value)    (10.0.1.4)"
Write-Host "   Username:      azureadmin"

Write-Host "`n🔐 VPN GATEWAY INFO:" -ForegroundColor Cyan
Write-Host "   On-Prem GW IP:     $($deployment.Outputs.onPremVpnGwPublicIp.Value)"
Write-Host "   Azure GW IP:       $($deployment.Outputs.azureVpnGwPublicIp.Value)"
Write-Host "   On-Prem BGP ASN:   $($deployment.Outputs.onPremBgpAsn.Value)"
Write-Host "   Azure BGP ASN:     $($deployment.Outputs.azureBgpAsn.Value)"

Write-Host @"

================================================================================
LAB 5: VPN GATEWAY FUNDAMENTALS - EXERCISES
================================================================================

TOPOLOGY (Simulates Site-to-Site VPN):

    "ON-PREMISES"                              AZURE
   (Simulated DC)                            (Hub VNet)
┌─────────────────────┐       IPsec/IKE      ┌─────────────────────┐
│  vnet-onprem        │       Tunnel         │  vnet-azure-hub     │
│  192.168.0.0/16     │◄════════════════════►│  10.0.0.0/16        │
│                     │       (BGP)          │                     │
│  ┌───────────────┐  │                      │  ┌───────────────┐  │
│  │ GatewaySubnet │  │                      │  │ GatewaySubnet │  │
│  │ vpngw-onprem  │  │                      │  │ vpngw-azure   │  │
│  │ ASN: 65001    │  │                      │  │ ASN: 65515    │  │
│  └───────────────┘  │                      │  └───────────────┘  │
│                     │                      │                     │
│  ┌───────────────┐  │                      │  ┌───────────────┐  │
│  │ vm-onprem     │  │                      │  │ vm-azure      │  │
│  │ 192.168.1.4   │  │                      │  │ 10.0.1.4      │  │
│  └───────────────┘  │                      │  └───────────────┘  │
└─────────────────────┘                      └─────────────────────┘

────────────────────────────────────────────────────────────────────────────────
EXERCISE 1: Verify VPN Connection Status
────────────────────────────────────────────────────────────────────────────────
1. Azure Portal → Virtual network gateways → vpngw-azure
2. Click "Connections" in left menu
3. Verify status shows "Connected" (may take 2-3 min after deployment)

   PowerShell alternative:
   Get-AzVirtualNetworkGatewayConnection -ResourceGroupName rg-az700-lab05-vpn |
       Select-Object Name, ConnectionStatus

────────────────────────────────────────────────────────────────────────────────
EXERCISE 2: Test Connectivity Through VPN Tunnel
────────────────────────────────────────────────────────────────────────────────
1. RDP to vm-onprem (simulated on-premises)
2. Open Command Prompt and ping the Azure VM through the VPN:
   
   ping 10.0.1.4
   
   ✅ Expected: Reply from 10.0.1.4

3. Trace the route to see it goes through the VPN:
   
   tracert 10.0.1.4
   
   ✅ Expected: Direct route (1 hop) through encrypted tunnel

────────────────────────────────────────────────────────────────────────────────
EXERCISE 3: Examine BGP Configuration
────────────────────────────────────────────────────────────────────────────────
1. Portal → vpngw-azure → Configuration
   - Note: BGP ASN = 65515 (Azure's default)
   - Note: BGP peer IP address (from GatewaySubnet)

2. View BGP Peers:
   Portal → vpngw-azure → BGP peers
   
   Or PowerShell:
   Get-AzVirtualNetworkGatewayBGPPeerStatus -VirtualNetworkGatewayName vpngw-azure `
       -ResourceGroupName rg-az700-lab05-vpn

3. View Learned Routes (BGP routes from "on-prem"):
   Get-AzVirtualNetworkGatewayLearnedRoute -VirtualNetworkGatewayName vpngw-azure `
       -ResourceGroupName rg-az700-lab05-vpn | Format-Table

────────────────────────────────────────────────────────────────────────────────
EXERCISE 4: Examine Effective Routes on VM
────────────────────────────────────────────────────────────────────────────────
1. Portal → vm-azure → Network settings → nic-vm-azure
2. Click "Effective routes"
3. Look for:
   - 192.168.0.0/16 → VirtualNetworkGateway (learned via BGP!)
   - 10.0.0.0/16 → VirtualNetwork (local VNet)

KEY OBSERVATION: The 192.168.0.0/16 route was learned automatically via BGP.
Without BGP, you'd need to manually add this to the Local Network Gateway!

────────────────────────────────────────────────────────────────────────────────
EXERCISE 5: View VPN Tunnel Details
────────────────────────────────────────────────────────────────────────────────
1. Portal → conn-azure-to-onprem
2. Note the following properties:
   - Connection type: IPsec
   - Connection protocol: IKEv2
   - Enable BGP: True
   - Ingress bytes transferred
   - Egress bytes transferred

3. Check IPsec policy (should be default Azure policy):
   Portal → conn-azure-to-onprem → Configuration

────────────────────────────────────────────────────────────────────────────────
EXERCISE 6: Understand Gateway Subnet Requirements
────────────────────────────────────────────────────────────────────────────────
1. Portal → vnet-azure-hub → Subnets
2. Note the GatewaySubnet:
   - Name: MUST be exactly "GatewaySubnet" (case-sensitive!)
   - Size: /27 (32 IPs) - Microsoft recommended minimum
   - No NSG attached (not supported on GatewaySubnet)

3. Try creating a subnet named "VPNSubnet" - it will NOT work for VPN Gateway!

────────────────────────────────────────────────────────────────────────────────
BONUS EXERCISE: Reset VPN Gateway (Troubleshooting Skill)
────────────────────────────────────────────────────────────────────────────────
If connection was stuck, you'd reset the gateway:

Reset-AzVirtualNetworkGateway -VirtualNetworkGateway (Get-AzVirtualNetworkGateway `
    -Name vpngw-azure -ResourceGroupName rg-az700-lab05-vpn)

⚠️ This causes brief connectivity disruption - only do in lab/troubleshooting!

================================================================================
KEY AZ-700 CONCEPTS DEMONSTRATED:
================================================================================
  ✅ GatewaySubnet must be named EXACTLY "GatewaySubnet"
  ✅ Minimum subnet size: /27 (32 addresses recommended)
  ✅ Route-based VPN is recommended (vs Policy-based)
  ✅ BGP enables automatic route learning (no manual address prefixes needed)
  ✅ Azure default BGP ASN is 65515 (can be changed)
  ✅ VPN Gateway SKU determines throughput and features
  ✅ VpnGw1+ required for BGP support (Basic SKU doesn't support BGP)
  ✅ Standard Public IP required for zone-redundant gateways
  ✅ Local Network Gateway represents the "other side" of the connection

================================================================================
"@ -ForegroundColor White

Write-Host "`n⚠️  COST WARNING:" -ForegroundColor Red
Write-Host "   VPN Gateways cost ~£0.03/hour each (~£1.50/day for 2 gateways)" -ForegroundColor Yellow
Write-Host "   Plus data transfer and VM costs" -ForegroundColor Yellow
Write-Host "   Run .\cleanup.ps1 when done!" -ForegroundColor Yellow
