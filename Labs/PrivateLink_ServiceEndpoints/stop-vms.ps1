# ============================================================================
# Stop VMs Script - Cost Optimisation for Lab Environment
# ============================================================================
# This script stops (deallocates) all VMs in the lab resource group
# Can be run manually or scheduled via Task Scheduler / Azure Automation
# ============================================================================

#Requires -Modules Az.Accounts, Az.Compute

param(
    [Parameter(Mandatory = $false, HelpMessage = "Resource group containing the VMs")]
    [string]$ResourceGroupName = "rg-privatelink-lab",
    
    [Parameter(Mandatory = $false, HelpMessage = "Specific VM names to stop (comma-separated)")]
    [string[]]$VMNames = @("vm-test", "vm-consumer", "vm-backend"),
    
    [Parameter(Mandatory = $false, HelpMessage = "Stop all VMs in resource group")]
    [switch]$All,
    
    [Parameter(Mandatory = $false, HelpMessage = "Run without confirmation prompts")]
    [switch]$Force,
    
    [Parameter(Mandatory = $false, HelpMessage = "Log output to file")]
    [switch]$LogToFile
)

# ============================================================================
# Configuration
# ============================================================================

$ErrorActionPreference = "Stop"
$scriptName = "Stop-LabVMs"
$logFile = Join-Path $PSScriptRoot "logs\vm-shutdown-$(Get-Date -Format 'yyyy-MM-dd').log"

# ============================================================================
# Logging Function
# ============================================================================

function Write-Log {
    <#
    .SYNOPSIS
        Writes timestamped messages to console and optionally to log file
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    # Console output with colours
    $colorMap = @{
        "INFO"    = "Cyan"
        "SUCCESS" = "Green"
        "WARNING" = "Yellow"
        "ERROR"   = "Red"
    }
    
    Write-Host $logMessage -ForegroundColor $colorMap[$Level]
    
    # File output if enabled
    if ($LogToFile) {
        # Ensure log directory exists
        $logDir = Split-Path $logFile -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        Add-Content -Path $logFile -Value $logMessage
    }
}

# ============================================================================
# Main Script
# ============================================================================

Write-Log "========================================"
Write-Log "$scriptName - Starting VM shutdown process"
Write-Log "========================================"
Write-Log "Resource Group: $ResourceGroupName"
Write-Log "Scheduled Time: $(Get-Date -Format 'HH:mm:ss')"

try {
    # Check Azure connection
    Write-Log "Checking Azure connection..."
    
    $context = Get-AzContext
    
    if (-not $context) {
        Write-Log "Not connected to Azure. Attempting to connect..." -Level WARNING
        
        # For scheduled tasks, use Service Principal or Managed Identity
        # Interactive login for manual runs
        Connect-AzAccount -ErrorAction Stop
        $context = Get-AzContext
    }
    
    Write-Log "Connected to subscription: $($context.Subscription.Name)" -Level SUCCESS
    
    # Get VMs to stop
    if ($All) {
        Write-Log "Getting all VMs in resource group..."
        $vmsToStop = Get-AzVM -ResourceGroupName $ResourceGroupName -Status
    }
    else {
        Write-Log "Getting specified VMs: $($VMNames -join ', ')"
        $vmsToStop = foreach ($vmName in $VMNames) {
            Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -Status -ErrorAction SilentlyContinue
        }
    }
    
    if (-not $vmsToStop -or $vmsToStop.Count -eq 0) {
        Write-Log "No VMs found to stop" -Level WARNING
        exit 0
    }
    
    Write-Log "Found $($vmsToStop.Count) VM(s)"
    
    # Process each VM
    $stoppedCount = 0
    $alreadyStoppedCount = 0
    $errorCount = 0
    
    foreach ($vm in $vmsToStop) {
        $vmName = $vm.Name
        $powerState = ($vm.Statuses | Where-Object { $_.Code -like "PowerState/*" }).DisplayStatus
        
        Write-Log "Processing VM: $vmName (Current state: $powerState)"
        
        if ($powerState -eq "VM deallocated") {
            Write-Log "  VM '$vmName' is already deallocated - skipping" -Level WARNING
            $alreadyStoppedCount++
            continue
        }
        
        if ($powerState -eq "VM stopped") {
            Write-Log "  VM '$vmName' is stopped but not deallocated - deallocating..." -Level WARNING
        }
        
        if (-not $Force) {
            $confirmation = Read-Host "  Stop VM '$vmName'? (Y/N)"
            if ($confirmation -ne 'Y') {
                Write-Log "  Skipped by user" -Level WARNING
                continue
            }
        }
        
        try {
            Write-Log "  Stopping VM '$vmName'..."
            
            # Stop-AzVM with -Force skips confirmation
            # -NoWait makes it async (faster if stopping multiple VMs)
            $job = Stop-AzVM -ResourceGroupName $ResourceGroupName `
                -Name $vmName `
                -Force `
                -NoWait
            
            Write-Log "  Stop command issued for '$vmName'" -Level SUCCESS
            $stoppedCount++
        }
        catch {
            Write-Log "  Failed to stop VM '$vmName': $($_.Exception.Message)" -Level ERROR
            $errorCount++
        }
    }
    
    # Wait for all VMs to stop (optional - for verification)
    if ($stoppedCount -gt 0) {
        Write-Log "Waiting for VMs to deallocate (this may take a few minutes)..."
        
        # Give Azure time to process
        Start-Sleep -Seconds 30
        
        # Verify final state
        foreach ($vmName in $VMNames) {
            $vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $vmName -Status -ErrorAction SilentlyContinue
            if ($vm) {
                $powerState = ($vm.Statuses | Where-Object { $_.Code -like "PowerState/*" }).DisplayStatus
                Write-Log "  $vmName : $powerState"
            }
        }
    }
    
    # Summary
    Write-Log "========================================"
    Write-Log "Summary:"
    Write-Log "  VMs stopped:          $stoppedCount"
    Write-Log "  Already deallocated:  $alreadyStoppedCount"
    Write-Log "  Errors:               $errorCount"
    Write-Log "========================================"
    
    # Calculate estimated savings
    $hourlyRate = 0.033  # £ per VM per hour (Standard_B2s)
    $hoursUntilMorning = 14  # 19:00 to 09:00 = 14 hours
    $estimatedSavings = $stoppedCount * $hourlyRate * $hoursUntilMorning
    
    Write-Log "Estimated overnight savings: £$([math]::Round($estimatedSavings, 2))" -Level SUCCESS
}
catch {
    Write-Log "Script failed: $($_.Exception.Message)" -Level ERROR
    exit 1
}
finally {
    Write-Log "$scriptName completed at $(Get-Date -Format 'HH:mm:ss')"
}
