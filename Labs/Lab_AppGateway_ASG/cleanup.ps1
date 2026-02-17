# ============================================================================
# AZ-700 Lab: Application Gateway + ASG - Cleanup Script
# ============================================================================

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-az700-appgw-asg-lab",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

$ErrorActionPreference = "Stop"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "AZ-700 Lab Cleanup" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if resource group exists
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

if (-not $rg) {
    Write-Host "Resource Group '$ResourceGroupName' does not exist. Nothing to clean up." -ForegroundColor Yellow
    exit 0
}

Write-Host "This will delete the following Resource Group and ALL resources within it:" -ForegroundColor Yellow
Write-Host "  Resource Group: $ResourceGroupName" -ForegroundColor Red
Write-Host "  Location: $($rg.Location)" -ForegroundColor White
Write-Host ""

if (-not $Force) {
    $confirmation = Read-Host "Are you sure you want to delete this resource group? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Host "Cleanup cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""
Write-Host "Deleting Resource Group..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Gray

Remove-AzResourceGroup -Name $ResourceGroupName -Force

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "Cleanup Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host "Resource Group '$ResourceGroupName' has been deleted." -ForegroundColor White
