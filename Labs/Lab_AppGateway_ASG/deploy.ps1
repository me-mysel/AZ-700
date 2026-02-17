# ============================================================================
# AZ-700 Lab: Application Gateway with Application Security Groups
# Deployment Script
# ============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-az700-appgw-asg-lab",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "uksouth",
    
    [Parameter(Mandatory = $false)]
    [string]$AdminUsername = "azureadmin",
    
    [Parameter(Mandatory = $true)]
    [SecureString]$AdminPassword
)

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "AZ-700 Lab: Application Gateway + ASG" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if logged in to Azure
$context = Get-AzContext
if (-not $context) {
    Write-Host "Not logged in to Azure. Please login..." -ForegroundColor Yellow
    Connect-AzAccount
}

Write-Host "Current Azure Context:" -ForegroundColor Green
Write-Host "  Subscription: $($context.Subscription.Name)" -ForegroundColor White
Write-Host "  Tenant: $($context.Tenant.Id)" -ForegroundColor White
Write-Host ""

# Create Resource Group
Write-Host "Creating Resource Group: $ResourceGroupName..." -ForegroundColor Yellow
$rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Force
Write-Host "  Resource Group created in $Location" -ForegroundColor Green
Write-Host ""

# Deploy Bicep template
Write-Host "Deploying Bicep template..." -ForegroundColor Yellow
Write-Host "  This will take approximately 10-15 minutes..." -ForegroundColor Gray
Write-Host ""

$deploymentName = "appgw-asg-lab-$(Get-Date -Format 'yyyyMMddHHmmss')"

$deployment = New-AzResourceGroupDeployment `
    -Name $deploymentName `
    -ResourceGroupName $ResourceGroupName `
    -TemplateFile "$PSScriptRoot\main.bicep" `
    -adminUsername $AdminUsername `
    -adminPassword $AdminPassword `
    -Verbose

if ($deployment.ProvisioningState -eq "Succeeded") {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "Deployment Successful!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Key Resources Deployed:" -ForegroundColor Cyan
    Write-Host "  - Application Gateway: appgw-lab" -ForegroundColor White
    Write-Host "  - ASG (Web): asg-webservers" -ForegroundColor White
    Write-Host "  - ASG (App): asg-appservers" -ForegroundColor White
    Write-Host "  - Web VMs: vm-web-01, vm-web-02" -ForegroundColor White
    Write-Host "  - App VM: vm-app-01" -ForegroundColor White
    Write-Host ""
    Write-Host "Connection Information:" -ForegroundColor Cyan
    Write-Host "  Application Gateway Public IP: $($deployment.Outputs.appGatewayPublicIP.Value)" -ForegroundColor Yellow
    Write-Host "  Application Gateway FQDN: $($deployment.Outputs.appGatewayFQDN.Value)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Web VM 1 Private IP: $($deployment.Outputs.webVm1PrivateIP.Value)" -ForegroundColor White
    Write-Host "  Web VM 2 Private IP: $($deployment.Outputs.webVm2PrivateIP.Value)" -ForegroundColor White
    Write-Host "  App VM Private IP: $($deployment.Outputs.appVmPrivateIP.Value)" -ForegroundColor White
    Write-Host ""
    Write-Host "Test the Application Gateway:" -ForegroundColor Cyan
    Write-Host "  curl http://$($deployment.Outputs.appGatewayFQDN.Value)" -ForegroundColor Gray
    Write-Host "  Or open in browser: http://$($deployment.Outputs.appGatewayFQDN.Value)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Note: It may take 2-3 minutes for the backend health probes to succeed." -ForegroundColor Yellow
}
else {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "Deployment Failed!" -ForegroundColor Red
    Write-Host "============================================" -ForegroundColor Red
    Write-Host "Check the Azure Portal for deployment details." -ForegroundColor Yellow
}
