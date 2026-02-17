# AZ-700 Lab 5: Cleanup Script

$resourceGroupName = "rg-az700-lab05-vpn"

Write-Host "`n⚠️  WARNING: This will delete ALL resources in '$resourceGroupName'" -ForegroundColor Yellow
Write-Host "   Including VPN Gateways (which took 30+ minutes to create!)" -ForegroundColor Yellow
$confirm = Read-Host "`nType 'yes' to confirm deletion"

if ($confirm -eq 'yes') {
    Write-Host "`n🗑️  Deleting Resource Group..." -ForegroundColor Cyan
    Write-Host "   This may take 10-15 minutes (VPN Gateways take time to delete)" -ForegroundColor Yellow
    Remove-AzResourceGroup -Name $resourceGroupName -Force -AsJob
    Write-Host "`n✅ Deletion initiated (running in background)" -ForegroundColor Green
    Write-Host "   Check status with: Get-Job | Where-Object {`$_.State -eq 'Running'}" -ForegroundColor Cyan
} else {
    Write-Host "❌ Deletion cancelled." -ForegroundColor Red
}
