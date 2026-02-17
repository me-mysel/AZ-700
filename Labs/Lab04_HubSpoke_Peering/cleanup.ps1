# AZ-700 Lab 4: Cleanup Script

$resourceGroupName = "rg-az700-lab04"

Write-Host "`n⚠️  WARNING: This will delete ALL resources in '$resourceGroupName'" -ForegroundColor Yellow
$confirm = Read-Host "Type 'yes' to confirm deletion"

if ($confirm -eq 'yes') {
    Write-Host "`n🗑️  Deleting Resource Group..." -ForegroundColor Cyan
    Remove-AzResourceGroup -Name $resourceGroupName -Force -AsJob
    Write-Host "✅ Deletion initiated (2-5 minutes in background)" -ForegroundColor Green
} else {
    Write-Host "❌ Deletion cancelled." -ForegroundColor Red
}
