# ============================================================================
# Cleanup Script for Private Link / Service Endpoints Lab
# ============================================================================

#Requires -Modules Az.Accounts, Az.Resources

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-privatelink-lab",
    
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Cleanup: Private Link Lab" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check Azure connection
$context = Get-AzContext
if (-not $context) {
    Write-Host "Connecting to Azure..." -ForegroundColor Yellow
    Connect-AzAccount
}

# Check if resource group exists
$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "Resource group '$ResourceGroupName' does not exist. Nothing to clean up." -ForegroundColor Yellow
    exit 0
}

# List resources
Write-Host "Resources in $ResourceGroupName`:" -ForegroundColor Yellow
Get-AzResource -ResourceGroupName $ResourceGroupName | Format-Table Name, ResourceType, Location
Write-Host ""

if (-not $Force) {
    $confirmation = Read-Host "Are you sure you want to delete all resources in '$ResourceGroupName'? (yes/no)"
    if ($confirmation -ne "yes") {
        Write-Host "Cleanup cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Deleting resource group '$ResourceGroupName'..." -ForegroundColor Yellow
Write-Host "This may take several minutes..." -ForegroundColor Yellow

Remove-AzResourceGroup -Name $ResourceGroupName -Force -AsJob | Out-Null

Write-Host ""
Write-Host "Resource group deletion initiated." -ForegroundColor Green
Write-Host "The deletion is running in the background." -ForegroundColor Green
Write-Host ""
Write-Host "To check status, run:" -ForegroundColor Cyan
Write-Host "Get-AzResourceGroup -Name '$ResourceGroupName'" -ForegroundColor Yellow
Write-Host ""
