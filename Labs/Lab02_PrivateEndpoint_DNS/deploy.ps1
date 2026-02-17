# AZ-700 Lab 2: Private Endpoint + DNS Resolution
# ================================================
# Deployment script for Lab 2
#
# Estimated Cost: ~$5/day (VM + Storage + Private Endpoint)
# Clean up when done to avoid charges!

# Variables
$resourceGroupName = "rg-az700-lab02"
$location = "uksouth"  # UK South for lower latency from UK
$adminPassword = Read-Host -Prompt "Enter VM admin password" -AsSecureString

# Create Resource Group
Write-Host "`n📦 Creating Resource Group..." -ForegroundColor Cyan
New-AzResourceGroup -Name $resourceGroupName -Location $location -Force

# Deploy Bicep Template
Write-Host "`n🚀 Deploying Lab Infrastructure..." -ForegroundColor Cyan
$deployment = New-AzResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile ".\main.bicep" `
    -adminPassword $adminPassword `
    -location $location `
    -Verbose

# Display Outputs
Write-Host "`n✅ Deployment Complete!" -ForegroundColor Green
Write-Host "=" * 70 -ForegroundColor Yellow

Write-Host "`n📋 LAB RESOURCES:" -ForegroundColor Cyan
Write-Host "   Resource Group:    $($deployment.Outputs.resourceGroupName.Value)"
Write-Host "   VNet:              $($deployment.Outputs.vnetName.Value)"
Write-Host "   Storage Account:   $($deployment.Outputs.storageAccountName.Value)"
Write-Host "   Storage FQDN:      $($deployment.Outputs.storageBlobFqdn.Value)"
Write-Host "   Private Endpoint IP: $($deployment.Outputs.privateEndpointIp.Value)"
Write-Host "   Private DNS Zone:  $($deployment.Outputs.privateDnsZoneName.Value)"

Write-Host "`n🖥️  VM ACCESS:" -ForegroundColor Cyan
Write-Host "   VM Name:           $($deployment.Outputs.vmName.Value)"
Write-Host "   VM Public IP:      $($deployment.Outputs.vmPublicIp.Value)"
Write-Host "   RDP Command:       mstsc /v:$($deployment.Outputs.vmPublicIp.Value)"

Write-Host "`n" + $deployment.Outputs.labInstructions.Value -ForegroundColor White

Write-Host "`n⚠️  COST WARNING:" -ForegroundColor Yellow
Write-Host "   This lab costs approximately £4-5/day."
Write-Host "   Run .\cleanup.ps1 when finished to delete all resources!"
Write-Host "=" * 70 -ForegroundColor Yellow
