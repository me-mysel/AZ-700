# ============================================================================
# Setup Windows Scheduled Task to Stop VMs Daily at 19:00
# ============================================================================
# This script creates a Windows Task Scheduler job that runs the stop-vms.ps1
# script every day at 19:00 (7 PM)
# 
# Run this script AS ADMINISTRATOR
# ============================================================================

#Requires -RunAsAdministrator

param(
    [Parameter(Mandatory = $false)]
    [string]$TaskName = "StopAzureLabVMs",
    
    [Parameter(Mandatory = $false)]
    [string]$TriggerTime = "19:00",
    
    [Parameter(Mandatory = $false)]
    [switch]$Remove
)

# ============================================================================
# Remove existing task if requested
# ============================================================================

if ($Remove) {
    Write-Host "Removing scheduled task '$TaskName'..." -ForegroundColor Yellow
    
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    
    if ($existingTask) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Task '$TaskName' removed successfully!" -ForegroundColor Green
    }
    else {
        Write-Host "Task '$TaskName' not found" -ForegroundColor Yellow
    }
    
    exit 0
}

# ============================================================================
# Configuration
# ============================================================================

$scriptPath = Join-Path $PSScriptRoot "stop-vms.ps1"
$logPath = Join-Path $PSScriptRoot "logs"

# Verify script exists
if (-not (Test-Path $scriptPath)) {
    Write-Host "Error: stop-vms.ps1 not found at: $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Setup VM Auto-Shutdown Scheduled Task" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Task Name:    $TaskName" -ForegroundColor White
Write-Host "Trigger Time: $TriggerTime daily" -ForegroundColor White
Write-Host "Script:       $scriptPath" -ForegroundColor White
Write-Host ""

# ============================================================================
# Create Scheduled Task
# ============================================================================

try {
    # Check if task already exists
    $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    
    if ($existingTask) {
        Write-Host "Task '$TaskName' already exists. Updating..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
    
    # Parse trigger time
    $timeParts = $TriggerTime.Split(':')
    $hour = [int]$timeParts[0]
    $minute = [int]$timeParts[1]
    
    # Create the trigger - Daily at specified time
    $trigger = New-ScheduledTaskTrigger -Daily -At "${hour}:${minute}"
    
    # Create the action - Run PowerShell with the script
    # -ExecutionPolicy Bypass: Allows script to run regardless of policy
    # -NoProfile: Faster startup, doesn't load profile
    # -WindowStyle Hidden: No visible window
    # -File: Path to script
    $action = New-ScheduledTaskAction `
        -Execute "pwsh.exe" `
        -Argument "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$scriptPath`" -Force -LogToFile" `
        -WorkingDirectory $PSScriptRoot
    
    # Task settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable `
        -MultipleInstances IgnoreNew
    
    # Create principal (run as current user)
    # Note: For production, use a service account or Managed Identity
    $principal = New-ScheduledTaskPrincipal `
        -UserId $env:USERNAME `
        -LogonType Interactive `
        -RunLevel Highest
    
    # Register the task
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Trigger $trigger `
        -Action $action `
        -Settings $settings `
        -Principal $principal `
        -Description "Automatically stops Azure lab VMs at $TriggerTime to save costs"
    
    Write-Host ""
    Write-Host "Scheduled task created successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Display task info
    $task = Get-ScheduledTask -TaskName $TaskName
    $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
    
    Write-Host "Task Details:" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  Name:         $($task.TaskName)" -ForegroundColor White
    Write-Host "  State:        $($task.State)" -ForegroundColor White
    Write-Host "  Next Run:     $($taskInfo.NextRunTime)" -ForegroundColor White
    Write-Host "  Description:  $($task.Description)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Commands:" -ForegroundColor Cyan
    Write-Host "─────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  # View task in Task Scheduler:" -ForegroundColor Gray
    Write-Host "  taskschd.msc" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  # Run task manually:" -ForegroundColor Gray
    Write-Host "  Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  # Check task status:" -ForegroundColor Gray
    Write-Host "  Get-ScheduledTaskInfo -TaskName '$TaskName'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  # Remove task:" -ForegroundColor Gray
    Write-Host "  .\setup-scheduled-task.ps1 -Remove" -ForegroundColor Yellow
    Write-Host ""
}
catch {
    Write-Host "Error creating scheduled task: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# ============================================================================
# Important Notes
# ============================================================================

Write-Host "Important Notes:" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  1. Your computer must be ON at $TriggerTime for the task to run" -ForegroundColor White
Write-Host "  2. You must be logged in (task runs as your user)" -ForegroundColor White
Write-Host "  3. You'll need to authenticate to Azure on first run" -ForegroundColor White
Write-Host "  4. For unattended runs, see: setup-azure-automation.ps1" -ForegroundColor White
Write-Host ""
