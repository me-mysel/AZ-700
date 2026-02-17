# ============================================================================
# Setup Azure Automation to Stop VMs Daily at 19:00 (Recommended)
# ============================================================================
# This script creates an Azure Automation Account with a Runbook that 
# automatically stops VMs at a scheduled time.
#
# Benefits over Windows Task Scheduler:
# - Works even if your PC is off
# - No need to store credentials locally
# - Uses Managed Identity (secure)
# - Visible in Azure Portal
# - Can be monitored and alerted
# ============================================================================

#Requires -Modules Az.Accounts, Az.Automation, Az.Resources

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-privatelink-lab",
    
    [Parameter(Mandatory = $false)]
    [string]$AutomationAccountName = "aa-lab-automation",
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "uksouth",
    
    [Parameter(Mandatory = $false)]
    [string]$RunbookName = "Stop-LabVMs",
    
    [Parameter(Mandatory = $false)]
    [string]$ScheduleName = "DailyShutdown-1900",
    
    [Parameter(Mandatory = $false)]
    [string]$ScheduleTime = "19:00",
    
    [Parameter(Mandatory = $false)]
    [switch]$Remove
)

# ============================================================================
# Runbook Script Content
# ============================================================================

$runbookContent = @'
<#
.SYNOPSIS
    Stops all VMs in the specified resource group
.DESCRIPTION
    This runbook is designed to run in Azure Automation with a System Managed Identity.
    It stops (deallocates) all VMs in the target resource group to save costs.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ResourceGroupName = "rg-privatelink-lab",
    
    [Parameter(Mandatory = $false)]
    [string[]]$VMNames = @("vm-test", "vm-consumer", "vm-backend")
)

Write-Output "========================================"
Write-Output "Azure Automation - Stop Lab VMs"
Write-Output "========================================"
Write-Output "Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Output "Resource Group: $ResourceGroupName"
Write-Output ""

try {
    # Connect using Managed Identity
    Write-Output "Connecting to Azure using Managed Identity..."
    
    Connect-AzAccount -Identity -ErrorAction Stop
    
    Write-Output "Connected successfully!"
    Write-Output ""
    
    # Process each VM
    $stoppedCount = 0
    $skippedCount = 0
    $errorCount = 0
    
    foreach ($vmName in $VMNames) {
        Write-Output "Processing VM: $vmName"
        
        try {
            # Get VM with status
            $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -Status -ErrorAction Stop
            
            $powerState = ($vm.Statuses | Where-Object { $_.Code -like "PowerState/*" }).DisplayStatus
            Write-Output "  Current state: $powerState"
            
            if ($powerState -eq "VM deallocated") {
                Write-Output "  Already deallocated - skipping"
                $skippedCount++
                continue
            }
            
            # Stop the VM
            Write-Output "  Stopping VM..."
            Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -Force -NoWait
            
            Write-Output "  Stop command issued successfully"
            $stoppedCount++
        }
        catch {
            Write-Output "  ERROR: $($_.Exception.Message)"
            $errorCount++
        }
        
        Write-Output ""
    }
    
    # Summary
    Write-Output "========================================"
    Write-Output "Summary:"
    Write-Output "  VMs stopped:    $stoppedCount"
    Write-Output "  Already off:    $skippedCount"
    Write-Output "  Errors:         $errorCount"
    Write-Output "========================================"
    
    if ($errorCount -gt 0) {
        throw "Completed with $errorCount error(s)"
    }
}
catch {
    Write-Error "Runbook failed: $($_.Exception.Message)"
    throw
}
'@

# ============================================================================
# Main Script
# ============================================================================

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Setup Azure Automation for VM Shutdown" -ForegroundColor Cyan
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

if ($Remove) {
    Write-Host "Removing Azure Automation resources..." -ForegroundColor Yellow
    
    # Remove schedule link
    $scheduleLink = Get-AzAutomationScheduledRunbook `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -RunbookName $RunbookName `
        -ErrorAction SilentlyContinue
    
    if ($scheduleLink) {
        Unregister-AzAutomationScheduledRunbook `
            -ResourceGroupName $ResourceGroupName `
            -AutomationAccountName $AutomationAccountName `
            -RunbookName $RunbookName `
            -ScheduleName $ScheduleName `
            -Force
        Write-Host "  Schedule link removed" -ForegroundColor Green
    }
    
    # Remove schedule
    Remove-AzAutomationSchedule `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -Name $ScheduleName `
        -Force `
        -ErrorAction SilentlyContinue
    Write-Host "  Schedule removed" -ForegroundColor Green
    
    # Remove runbook
    Remove-AzAutomationRunbook `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -Name $RunbookName `
        -Force `
        -ErrorAction SilentlyContinue
    Write-Host "  Runbook removed" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Note: Automation Account retained. Delete manually if not needed:" -ForegroundColor Yellow
    Write-Host "  Remove-AzAutomationAccount -ResourceGroupName $ResourceGroupName -Name $AutomationAccountName" -ForegroundColor Yellow
    
    exit 0
}

try {
    # ========================================================================
    # Step 1: Create Automation Account
    # ========================================================================
    
    Write-Host "Step 1: Creating Automation Account..." -ForegroundColor Cyan
    
    $automationAccount = Get-AzAutomationAccount `
        -ResourceGroupName $ResourceGroupName `
        -Name $AutomationAccountName `
        -ErrorAction SilentlyContinue
    
    if (-not $automationAccount) {
        $automationAccount = New-AzAutomationAccount `
            -ResourceGroupName $ResourceGroupName `
            -Name $AutomationAccountName `
            -Location $Location `
            -AssignSystemIdentity
        
        Write-Host "  Automation Account created: $AutomationAccountName" -ForegroundColor Green
    }
    else {
        Write-Host "  Automation Account already exists" -ForegroundColor Yellow
    }
    
    # Get Managed Identity Principal ID
    $principalId = $automationAccount.Identity.PrincipalId
    Write-Host "  Managed Identity Principal ID: $principalId" -ForegroundColor White
    Write-Host ""
    
    # ========================================================================
    # Step 2: Assign Permissions to Managed Identity
    # ========================================================================
    
    Write-Host "Step 2: Assigning permissions to Managed Identity..." -ForegroundColor Cyan
    
    # Get resource group ID
    $rg = Get-AzResourceGroup -Name $ResourceGroupName
    
    # Check if assignment already exists
    $existingAssignment = Get-AzRoleAssignment `
        -ObjectId $principalId `
        -RoleDefinitionName "Virtual Machine Contributor" `
        -Scope $rg.ResourceId `
        -ErrorAction SilentlyContinue
    
    if (-not $existingAssignment) {
        # Assign VM Contributor role to the resource group
        New-AzRoleAssignment `
            -ObjectId $principalId `
            -RoleDefinitionName "Virtual Machine Contributor" `
            -Scope $rg.ResourceId
        
        Write-Host "  Assigned 'Virtual Machine Contributor' role" -ForegroundColor Green
    }
    else {
        Write-Host "  Role assignment already exists" -ForegroundColor Yellow
    }
    Write-Host ""
    
    # ========================================================================
    # Step 3: Create Runbook
    # ========================================================================
    
    Write-Host "Step 3: Creating Runbook..." -ForegroundColor Cyan
    
    # Save runbook content to temp file
    $tempFile = Join-Path $env:TEMP "Stop-LabVMs.ps1"
    $runbookContent | Out-File -FilePath $tempFile -Encoding UTF8 -Force
    
    # Import runbook
    $runbook = Import-AzAutomationRunbook `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -Name $RunbookName `
        -Path $tempFile `
        -Type PowerShell `
        -Published `
        -Force
    
    # Clean up temp file
    Remove-Item $tempFile -Force
    
    Write-Host "  Runbook created and published: $RunbookName" -ForegroundColor Green
    Write-Host ""
    
    # ========================================================================
    # Step 4: Create Schedule
    # ========================================================================
    
    Write-Host "Step 4: Creating Schedule..." -ForegroundColor Cyan
    
    # Parse time
    $timeParts = $ScheduleTime.Split(':')
    $scheduleDateTime = (Get-Date).Date.AddHours([int]$timeParts[0]).AddMinutes([int]$timeParts[1])
    
    # If time has passed today, start tomorrow
    if ($scheduleDateTime -lt (Get-Date)) {
        $scheduleDateTime = $scheduleDateTime.AddDays(1)
    }
    
    # Remove existing schedule if exists
    Remove-AzAutomationSchedule `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -Name $ScheduleName `
        -Force `
        -ErrorAction SilentlyContinue
    
    # Create daily schedule
    $schedule = New-AzAutomationSchedule `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -Name $ScheduleName `
        -StartTime $scheduleDateTime `
        -DayInterval 1 `
        -TimeZone "GMT Standard Time" `
        -Description "Daily VM shutdown at $ScheduleTime"
    
    Write-Host "  Schedule created: $ScheduleName" -ForegroundColor Green
    Write-Host "  First run: $scheduleDateTime" -ForegroundColor White
    Write-Host ""
    
    # ========================================================================
    # Step 5: Link Schedule to Runbook
    # ========================================================================
    
    Write-Host "Step 5: Linking Schedule to Runbook..." -ForegroundColor Cyan
    
    # Define runbook parameters
    $runbookParams = @{
        ResourceGroupName = $ResourceGroupName
        VMNames           = @("vm-test", "vm-consumer", "vm-backend")
    }
    
    Register-AzAutomationScheduledRunbook `
        -ResourceGroupName $ResourceGroupName `
        -AutomationAccountName $AutomationAccountName `
        -RunbookName $RunbookName `
        -ScheduleName $ScheduleName `
        -Parameters $runbookParams
    
    Write-Host "  Schedule linked to runbook" -ForegroundColor Green
    Write-Host ""
    
    # ========================================================================
    # Success Summary
    # ========================================================================
    
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  Setup Complete!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your VMs will automatically stop at $ScheduleTime daily." -ForegroundColor White
    Write-Host ""
    Write-Host "View in Azure Portal:" -ForegroundColor Cyan
    Write-Host "  https://portal.azure.com/#@/resource/subscriptions/$($context.Subscription.Id)/resourceGroups/$ResourceGroupName/providers/Microsoft.Automation/automationAccounts/$AutomationAccountName/runbooks" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Manual Commands:" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  # Run runbook manually:" -ForegroundColor Gray
    Write-Host "  Start-AzAutomationRunbook -ResourceGroupName '$ResourceGroupName' -AutomationAccountName '$AutomationAccountName' -Name '$RunbookName'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  # View job history:" -ForegroundColor Gray
    Write-Host "  Get-AzAutomationJob -ResourceGroupName '$ResourceGroupName' -AutomationAccountName '$AutomationAccountName' -RunbookName '$RunbookName'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  # Remove automation:" -ForegroundColor Gray
    Write-Host "  .\setup-azure-automation.ps1 -Remove" -ForegroundColor Yellow
    Write-Host ""
    
    # Cost note
    Write-Host "Cost Note:" -ForegroundColor Yellow
    Write-Host "  Azure Automation: First 500 minutes/month FREE" -ForegroundColor White
    Write-Host "  This job runs ~1 minute/day = ~30 minutes/month (FREE tier)" -ForegroundColor White
    Write-Host ""
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    throw
}
