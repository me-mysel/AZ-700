# ============================================================================
# Enable Azure VM Auto-Shutdown (Simplest Option)
# ============================================================================
# This script enables the built-in Azure VM auto-shutdown feature.
# This is the SIMPLEST option - no Automation Account or Task Scheduler needed!
#
# Benefits:
# - Built into Azure - no extra resources
# - Works automatically
# - Can send email notifications
# - FREE!
# ============================================================================

#Requires -Modules Az.Accounts, Az.Compute

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-privatelink-lab",
    
    [Parameter(Mandatory = $false)]
    [string[]]$VMNames = @("vm-test", "vm-consumer", "vm-backend"),
    
    [Parameter(Mandatory = $false)]
    [string]$ShutdownTime = "1900",  # 24-hour format: 1900 = 7:00 PM
    
    [Parameter(Mandatory = $false)]
    [string]$TimeZone = "GMT Standard Time",
    
    [Parameter(Mandatory = $false)]
    [string]$NotificationEmail = "",
    
    [Parameter(Mandatory = $false)]
    [switch]$Disable
)

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Azure VM Auto-Shutdown Configuration" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check Azure connection
$context = Get-AzContext
if (-not $context) {
    Write-Host "Connecting to Azure..." -ForegroundColor Yellow
    Connect-AzAccount
    $context = Get-AzContext
}

Write-Host "Subscription: $($context.Subscription.Name)" -ForegroundColor Green
Write-Host ""

foreach ($vmName in $VMNames) {
    Write-Host "Processing VM: $vmName" -ForegroundColor Cyan
    
    try {
        # Get VM
        $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -ErrorAction Stop
        
        # Auto-shutdown resource name follows a specific pattern
        $shutdownResourceName = "shutdown-computevm-$vmName"
        $resourceId = "/subscriptions/$($context.Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.DevTestLab/schedules/$shutdownResourceName"
        
        if ($Disable) {
            # Remove auto-shutdown
            Write-Host "  Disabling auto-shutdown..." -ForegroundColor Yellow
            
            Remove-AzResource -ResourceId $resourceId -Force -ErrorAction SilentlyContinue
            
            Write-Host "  Auto-shutdown disabled" -ForegroundColor Green
        }
        else {
            # Configure auto-shutdown properties
            $properties = @{
                status           = "Enabled"
                taskType         = "ComputeVmShutdownTask"
                dailyRecurrence  = @{
                    time = $ShutdownTime
                }
                timeZoneId       = $TimeZone
                targetResourceId = $vm.Id
            }
            
            # Add notification if email provided
            if ($NotificationEmail) {
                $properties.notificationSettings = @{
                    status        = "Enabled"
                    timeInMinutes = 30  # Notify 30 mins before shutdown
                    emailRecipient = $NotificationEmail
                    notificationLocale = "en"
                }
                Write-Host "  Notification email: $NotificationEmail (30 mins before)" -ForegroundColor White
            }
            
            # Create/Update auto-shutdown schedule
            Write-Host "  Configuring auto-shutdown at $ShutdownTime ($TimeZone)..." -ForegroundColor Yellow
            
            New-AzResource `
                -ResourceId $resourceId `
                -Location $vm.Location `
                -Properties $properties `
                -Force | Out-Null
            
            Write-Host "  Auto-shutdown enabled!" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    }
    
    Write-Host ""
}

# Summary
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Configuration Complete!" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

if (-not $Disable) {
    # Convert time to readable format
    $hour = [int]($ShutdownTime.Substring(0, 2))
    $minute = $ShutdownTime.Substring(2, 2)
    $ampm = if ($hour -ge 12) { "PM" } else { "AM" }
    $displayHour = if ($hour -gt 12) { $hour - 12 } elseif ($hour -eq 0) { 12 } else { $hour }
    
    Write-Host "VMs will automatically shut down at ${displayHour}:${minute} ${ampm} ($TimeZone)" -ForegroundColor White
    Write-Host ""
    Write-Host "View in Azure Portal:" -ForegroundColor Cyan
    Write-Host "  VM → Operations → Auto-shutdown" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "To disable:" -ForegroundColor Cyan
    Write-Host "  .\enable-autoshutdown.ps1 -Disable" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Note: This shuts down VMs but does NOT deallocate them." -ForegroundColor Yellow
    Write-Host "      You still pay for disks and IPs." -ForegroundColor Yellow
    Write-Host "      For full deallocation, use Azure Automation instead." -ForegroundColor Yellow
}
else {
    Write-Host "Auto-shutdown has been disabled for all VMs" -ForegroundColor Yellow
}

Write-Host ""
