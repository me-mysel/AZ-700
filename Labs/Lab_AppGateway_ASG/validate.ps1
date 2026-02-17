# ============================================================================
# Validation Script for Application Gateway + ASG Lab
# Run this after deployment to verify everything is configured correctly
# ============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-az700-appgw-asg-lab"
)

$ErrorActionPreference = "Continue"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Lab Validation: Application Gateway + ASG" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true

function Test-Condition {
    param(
        [string]$TestName,
        [bool]$Condition,
        [string]$SuccessMessage,
        [string]$FailMessage
    )
    
    if ($Condition) {
        Write-Host "✓ PASS: $TestName" -ForegroundColor Green
        Write-Host "        $SuccessMessage" -ForegroundColor Gray
    }
    else {
        Write-Host "✗ FAIL: $TestName" -ForegroundColor Red
        Write-Host "        $FailMessage" -ForegroundColor Yellow
        $script:allPassed = $false
    }
    Write-Host ""
}

# Test 1: Resource Group Exists
Write-Host "Running validation tests..." -ForegroundColor Yellow
Write-Host ""

$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
Test-Condition `
    -TestName "Resource Group Exists" `
    -Condition ($null -ne $rg) `
    -SuccessMessage "Resource group '$ResourceGroupName' found" `
    -FailMessage "Resource group '$ResourceGroupName' not found. Deploy the lab first."

if (-not $rg) {
    Write-Host "Cannot continue validation without resource group." -ForegroundColor Red
    exit 1
}

# Test 2: Application Gateway Exists and Running
$appGw = Get-AzApplicationGateway -ResourceGroupName $ResourceGroupName -Name "appgw-lab" -ErrorAction SilentlyContinue
Test-Condition `
    -TestName "Application Gateway Deployed" `
    -Condition ($null -ne $appGw -and $appGw.OperationalState -eq "Running") `
    -SuccessMessage "Application Gateway 'appgw-lab' is running" `
    -FailMessage "Application Gateway not found or not running"

# Test 3: ASGs Created
$asgWeb = Get-AzApplicationSecurityGroup -ResourceGroupName $ResourceGroupName -Name "asg-webservers" -ErrorAction SilentlyContinue
$asgApp = Get-AzApplicationSecurityGroup -ResourceGroupName $ResourceGroupName -Name "asg-appservers" -ErrorAction SilentlyContinue
Test-Condition `
    -TestName "Application Security Groups Created" `
    -Condition ($null -ne $asgWeb -and $null -ne $asgApp) `
    -SuccessMessage "Both ASGs (asg-webservers, asg-appservers) found" `
    -FailMessage "One or more ASGs missing"

# Test 4: NSGs Created with Rules
$nsgWeb = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name "nsg-web-tier" -ErrorAction SilentlyContinue
$nsgApp = Get-AzNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name "nsg-app-tier" -ErrorAction SilentlyContinue
$nsgWebRuleCount = ($nsgWeb.SecurityRules | Measure-Object).Count
$nsgAppRuleCount = ($nsgApp.SecurityRules | Measure-Object).Count
Test-Condition `
    -TestName "NSGs with Security Rules" `
    -Condition ($nsgWebRuleCount -ge 4 -and $nsgAppRuleCount -ge 2) `
    -SuccessMessage "NSGs have expected rules (Web: $nsgWebRuleCount, App: $nsgAppRuleCount)" `
    -FailMessage "NSGs missing or have fewer rules than expected"

# Test 5: Web VMs Associated with ASG
$nicWeb1 = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name "nic-vm-web-01" -ErrorAction SilentlyContinue
$nicWeb2 = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name "nic-vm-web-02" -ErrorAction SilentlyContinue
$web1HasAsg = ($nicWeb1.IpConfigurations[0].ApplicationSecurityGroups | Where-Object { $_.Id -like "*asg-webservers*" }) -ne $null
$web2HasAsg = ($nicWeb2.IpConfigurations[0].ApplicationSecurityGroups | Where-Object { $_.Id -like "*asg-webservers*" }) -ne $null
Test-Condition `
    -TestName "Web VMs Associated with ASG" `
    -Condition ($web1HasAsg -and $web2HasAsg) `
    -SuccessMessage "Both web VM NICs are associated with asg-webservers" `
    -FailMessage "Web VM NICs not properly associated with ASG"

# Test 6: App VM Associated with ASG
$nicApp = Get-AzNetworkInterface -ResourceGroupName $ResourceGroupName -Name "nic-vm-app-01" -ErrorAction SilentlyContinue
$appHasAsg = ($nicApp.IpConfigurations[0].ApplicationSecurityGroups | Where-Object { $_.Id -like "*asg-appservers*" }) -ne $null
Test-Condition `
    -TestName "App VM Associated with ASG" `
    -Condition $appHasAsg `
    -SuccessMessage "App VM NIC is associated with asg-appservers" `
    -FailMessage "App VM NIC not properly associated with ASG"

# Test 7: Application Gateway Backend Health
if ($appGw) {
    $backendHealth = Get-AzApplicationGatewayBackendHealth -ResourceGroupName $ResourceGroupName -Name "appgw-lab" -ErrorAction SilentlyContinue
    $healthyServers = $backendHealth.BackendAddressPools.BackendHttpSettingsCollection.Servers | Where-Object { $_.Health -eq "Healthy" }
    $healthyCount = ($healthyServers | Measure-Object).Count
    Test-Condition `
        -TestName "Backend Pool Health" `
        -Condition ($healthyCount -ge 2) `
        -SuccessMessage "$healthyCount backend servers are healthy" `
        -FailMessage "Backend servers unhealthy. Check NSG rules and IIS status."
}

# Test 8: Public IP Accessible
$pip = Get-AzPublicIpAddress -ResourceGroupName $ResourceGroupName -Name "pip-appgw" -ErrorAction SilentlyContinue
if ($pip -and $pip.IpAddress) {
    try {
        $response = Invoke-WebRequest -Uri "http://$($pip.IpAddress)" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        $isAccessible = $response.StatusCode -eq 200
    }
    catch {
        $isAccessible = $false
    }
    Test-Condition `
        -TestName "Application Gateway Publicly Accessible" `
        -Condition $isAccessible `
        -SuccessMessage "Application Gateway responds on http://$($pip.IpAddress)" `
        -FailMessage "Cannot reach Application Gateway. May need a few more minutes for health probes."
}

# Summary
Write-Host "============================================" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host "All Validation Tests Passed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Application Gateway URL: http://$($pip.IpAddress)" -ForegroundColor Yellow
    Write-Host "FQDN: http://$($pip.DnsSettings.Fqdn)" -ForegroundColor Yellow
}
else {
    Write-Host "Some Tests Failed" -ForegroundColor Red
    Write-Host "Review the failures above and check your deployment." -ForegroundColor Yellow
}
Write-Host "============================================" -ForegroundColor Cyan
