# AZ-700 Lab 2: Cleanup Script
# ============================
# Run this when you're done with the lab to avoid charges!

$resourceGroupName = "rg-az700-lab02"

Write-Host "`n⚠️  WARNING: This will delete ALL resources in '$resourceGroupName'" -ForegroundColor Yellow
$confirm = Read-Host "Type 'yes' to confirm deletion"

if ($confirm -eq 'yes') {
    Write-Host "`n🗑️  Deleting Resource Group..." -ForegroundColor Cyan
    Remove-AzResourceGroup -Name $resourceGroupName -Force -AsJob
    
    Write-Host "`n✅ Deletion initiated!" -ForegroundColor Green
    Write-Host "   The resource group is being deleted in the background."
    Write-Host "   This may take 2-5 minutes to complete."
    Write-Host "`n   To check status: Get-AzResourceGroup -Name '$resourceGroupName'"
} else {
    Write-Host "`n❌ Deletion cancelled." -ForegroundColor Red
}
