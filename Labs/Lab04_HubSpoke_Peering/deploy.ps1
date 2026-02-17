# AZ-700 Lab 4: Hub-Spoke with VNet Peering - Deployment Script

$resourceGroupName = "rg-az700-lab04"
$location = "uksouth"
$adminPassword = Read-Host -Prompt "Enter VM admin password" -AsSecureString

Write-Host "`n📦 Creating Resource Group..." -ForegroundColor Cyan
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

Write-Host "`n🚀 Deploying Hub-Spoke Infrastructure (~5 min)..." -ForegroundColor Cyan
$deployment = New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile ".\main.bicep" `
    -adminPassword $adminPassword `
    -location $location `
    -Verbose

Write-Host "`n✅ Deployment Complete!" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Yellow

Write-Host "`n🖥️  VM ACCESS:" -ForegroundColor Cyan
Write-Host "   Hub NVA:    mstsc /v:$($deployment.Outputs.hubVmPublicIp.Value)    (10.0.2.4)"
Write-Host "   Spoke 1:    mstsc /v:$($deployment.Outputs.spoke1VmPublicIp.Value)"
Write-Host "   Spoke 2:    mstsc /v:$($deployment.Outputs.spoke2VmPublicIp.Value)"
Write-Host "   Username:   azureadmin"

Write-Host @"

================================================================================
LAB 4: HUB-SPOKE ARCHITECTURE - EXERCISES
================================================================================

TOPOLOGY:
                    ┌─────────────────────┐
                    │    vnet-hub         │
                    │    10.0.0.0/16      │
                    │  ┌───────────────┐  │
                    │  │ vm-hub-nva    │  │
                    │  │ 10.0.2.4      │  │
                    │  │ (IP Forward)  │  │
                    │  └───────────────┘  │
                    └──────────┬──────────┘
              ┌────────────────┼────────────────┐
              │ Peering        │        Peering │
              ▼                                 ▼
┌─────────────────────┐             ┌─────────────────────┐
│   vnet-spoke1       │             │   vnet-spoke2       │
│   10.1.0.0/16       │◄─ NO DIRECT─►│   10.2.0.0/16       │
│   vm-spoke1         │   PEERING!  │   vm-spoke2         │
└─────────────────────┘             └─────────────────────┘

EXERCISE 1: Test Hub-Spoke Connectivity
  From vm-spoke1: ping 10.0.2.4  ✅ Should WORK

EXERCISE 2: Test Spoke-to-Spoke WITH Route Tables
  From vm-spoke1: ping 10.2.1.4  ✅ Should WORK (via Hub NVA)
  From vm-spoke1: tracert 10.2.1.4  (see traffic go through 10.0.2.4)

EXERCISE 3: Remove Route Tables to See Transitivity Problem
  - Portal: vnet-spoke1 > Subnets > Dissociate route table
  - From vm-spoke1: ping 10.2.1.4  ❌ Will FAIL!
  
EXERCISE 4: Check Effective Routes
  - Portal: vm-spoke1 NIC > Effective routes
  - Look for 10.2.0.0/16 -> VirtualAppliance -> 10.0.2.4

KEY AZ-700 CONCEPTS:
  ✅ VNet Peering is NOT transitive
  ✅ NVA needs IP Forwarding on NIC + OS level
  ✅ UDR (Route Tables) enable spoke-to-spoke via hub
  ✅ allowForwardedTraffic must be TRUE on peerings

================================================================================
"@ -ForegroundColor White

Write-Host "`n⚠️  COST: ~£3-5/day. Run .\cleanup.ps1 when done!" -ForegroundColor Yellow
