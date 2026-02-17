# ============================================================================
# Deploy Script for Private Link / Service Endpoints Lab
# ============================================================================
# This script uses native PowerShell Az module cmdlets (not Azure CLI)
# Prerequisites: Install-Module -Name Az -Scope CurrentUser -Force
# ============================================================================

#Requires -Modules Az.Accounts, Az.Resources

param(
    [Parameter(Mandatory = $false, HelpMessage = "Name of the resource group to create")]
    [ValidateNotNullOrEmpty()]
    [string]$ResourceGroupName = "rg-privatelink-lab",
    
    [Parameter(Mandatory = $false, HelpMessage = "Azure region for deployment")]
    [ValidateSet("eastus", "westus", "westeurope", "northeurope", "uksouth", "ukwest")]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory = $true, HelpMessage = "Admin password for VMs")]
    [ValidateNotNullOrEmpty()]
    [securestring]$AdminPassword,
    
    [Parameter(Mandatory = $false, HelpMessage = "Preview changes without deploying")]
    [switch]$WhatIf
)

# ============================================================================
# Script Configuration
# ============================================================================

# Set strict error handling - script stops on any error
$ErrorActionPreference = "Stop"

# Enable verbose output if -Verbose switch is used
$VerbosePreference = if ($PSBoundParameters['Verbose']) { "Continue" } else { "SilentlyContinue" }

# ============================================================================
# Helper Functions
# ============================================================================

function Write-Banner {
    <#
    .SYNOPSIS
        Displays a formatted banner message
    .PARAMETER Message
        The message to display in the banner
    .PARAMETER Color
        The foreground color for the banner
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$Color = [ConsoleColor]::Cyan
    )
    
    $border = "=" * 60
    Write-Host $border -ForegroundColor $Color
    Write-Host "  $Message" -ForegroundColor $Color
    Write-Host $border -ForegroundColor $Color
    Write-Host ""
}

function Write-Step {
    <#
    .SYNOPSIS
        Displays a step message with consistent formatting
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )
    
    $colorMap = @{
        "Info"    = [ConsoleColor]::Yellow
        "Success" = [ConsoleColor]::Green
        "Warning" = [ConsoleColor]::DarkYellow
        "Error"   = [ConsoleColor]::Red
    }
    
    $prefixMap = @{
        "Info"    = "[*]"
        "Success" = "[✓]"
        "Warning" = "[!]"
        "Error"   = "[✗]"
    }
    
    Write-Host "$($prefixMap[$Type]) $Message" -ForegroundColor $colorMap[$Type]
}

function Test-AzureConnection {
    <#
    .SYNOPSIS
        Checks if user is connected to Azure and prompts for login if not
    .OUTPUTS
        Returns the current Azure context
    #>
    
    Write-Step "Checking Azure connection status..."
    
    try {
        # Get-AzContext returns $null if not connected
        $context = Get-AzContext
        
        if (-not $context) {
            throw "Not connected to Azure"
        }
        
        # Verify the context is valid by making a simple API call
        $null = Get-AzSubscription -SubscriptionId $context.Subscription.Id -ErrorAction Stop
        
        return $context
    }
    catch {
        Write-Step "Not logged in. Opening Azure login..." -Type Warning
        
        # Connect-AzAccount opens interactive login
        $context = Connect-AzAccount
        
        if (-not $context) {
            throw "Failed to connect to Azure. Please try again."
        }
        
        return $context.Context
    }
}

function New-ResourceGroupIfNotExists {
    <#
    .SYNOPSIS
        Creates a resource group if it doesn't already exist
    .PARAMETER Name
        Name of the resource group
    .PARAMETER Location
        Azure region for the resource group
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [string]$Location
    )
    
    Write-Step "Checking if resource group '$Name' exists..."
    
    # Get-AzResourceGroup returns $null if not found (with -ErrorAction SilentlyContinue)
    $existingRg = Get-AzResourceGroup -Name $Name -ErrorAction SilentlyContinue
    
    if ($existingRg) {
        Write-Step "Resource group '$Name' already exists" -Type Warning
        return $existingRg
    }
    
    Write-Step "Creating resource group '$Name' in '$Location'..."
    
    # Splatting: cleaner way to pass parameters using hashtable
    $rgParams = @{
        Name     = $Name
        Location = $Location
        Tag      = @{
            Environment = "Lab"
            Purpose     = "PrivateLink-ServiceEndpoints-Learning"
            CreatedBy   = $env:USERNAME
            CreatedOn   = (Get-Date -Format "yyyy-MM-dd")
        }
    }
    
    $resourceGroup = New-AzResourceGroup @rgParams
    Write-Step "Resource group created successfully!" -Type Success
    
    return $resourceGroup
}

# ============================================================================
# Main Script Execution
# ============================================================================

# Display banner
Write-Banner -Message "Private Link / Service Endpoints Lab"

# Track execution time using Stopwatch
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

try {
    # Step 1: Verify Azure connection
    $azContext = Test-AzureConnection
    
    Write-Host ""
    Write-Host "Azure Context:" -ForegroundColor Cyan
    Write-Host "  Account:      $($azContext.Account.Id)" -ForegroundColor White
    Write-Host "  Subscription: $($azContext.Subscription.Name)" -ForegroundColor White
    Write-Host "  Tenant:       $($azContext.Tenant.Id)" -ForegroundColor White
    Write-Host ""

    # Step 2: Create Resource Group
    if ($WhatIf) {
        Write-Step "[WhatIf] Would create resource group: $ResourceGroupName" -Type Warning
    }
    else {
        $null = New-ResourceGroupIfNotExists -Name $ResourceGroupName -Location $Location
    }
    Write-Host ""

    # Step 3: Deploy Bicep Template
    Write-Step "Preparing Bicep deployment..."
    
    # Get template file path (relative to script location)
    $templateFile = Join-Path -Path $PSScriptRoot -ChildPath "main.bicep"
    
    # Verify template file exists
    if (-not (Test-Path -Path $templateFile)) {
        throw "Template file not found: $templateFile"
    }
    
    Write-Step "Template file: $templateFile"
    Write-Host ""
    
    # Deployment parameters using hashtable
    $deploymentParams = @{
        ResourceGroupName = $ResourceGroupName
        TemplateFile      = $templateFile
        adminPassword     = $AdminPassword  # SecureString - no conversion needed!
        Verbose           = $VerbosePreference -eq "Continue"
    }
    
    if ($WhatIf) {
        Write-Step "[WhatIf] Validating template (no deployment)..." -Type Warning
        
        # Test-AzResourceGroupDeployment validates without deploying
        $validation = Test-AzResourceGroupDeployment @deploymentParams
        
        if ($validation) {
            # Validation returns errors if any
            Write-Step "Validation errors found:" -Type Error
            $validation | ForEach-Object { Write-Host "  - $($_.Message)" -ForegroundColor Red }
        }
        else {
            Write-Step "Template validation passed!" -Type Success
        }
    }
    else {
        Write-Step "Deploying Bicep template..."
        Write-Step "This will take approximately 10-15 minutes..." -Type Warning
        Write-Host ""
        
        # Generate unique deployment name with timestamp
        $deploymentName = "PrivateLinkLab-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        
        # New-AzResourceGroupDeployment deploys ARM/Bicep templates
        $deployment = New-AzResourceGroupDeployment `
            -Name $deploymentName `
            @deploymentParams
        
        # Check deployment state
        if ($deployment.ProvisioningState -eq "Succeeded") {
            Write-Host ""
            Write-Banner -Message "Deployment Complete!" -Color Green
            
            # Access deployment outputs
            # Outputs are returned as a hashtable with Value and Type properties
            $outputs = $deployment.Outputs
            
            Write-Host "Resource Information:" -ForegroundColor Cyan
            Write-Host "─────────────────────────────────────────────────" -ForegroundColor DarkGray
            
            # Using format operator -f for aligned output
            $format = "  {0,-25} {1}"
            Write-Host ($format -f "VM Test Public IP:", $outputs.vmTestPublicIp.Value) -ForegroundColor White
            Write-Host ($format -f "VM Consumer Public IP:", $outputs.vmConsumerPublicIp.Value) -ForegroundColor White
            Write-Host ($format -f "Storage (PE) Name:", $outputs.storageAccountPEName.Value) -ForegroundColor White
            Write-Host ($format -f "Storage (SE) Name:", $outputs.storageAccountSEName.Value) -ForegroundColor White
            Write-Host ($format -f "Private Endpoint IP:", $outputs.privateEndpointStorageIp.Value) -ForegroundColor White
            Write-Host ""
            
            Write-Host "Quick Start Commands:" -ForegroundColor Cyan
            Write-Host "─────────────────────────────────────────────────" -ForegroundColor DarkGray
            Write-Host "  # SSH to test VM:" -ForegroundColor Gray
            Write-Host "  ssh azureuser@$($outputs.vmTestPublicIp.Value)" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  # On the VM, test DNS resolution:" -ForegroundColor Gray
            Write-Host "  nslookup $($outputs.storageAccountSEName.Value).blob.core.windows.net  # Service Endpoint" -ForegroundColor Yellow
            Write-Host "  nslookup $($outputs.storageAccountPEName.Value).blob.core.windows.net  # Private Endpoint" -ForegroundColor Yellow
            Write-Host ""
            
            # Export outputs to JSON file for later reference
            $outputFile = Join-Path -Path $PSScriptRoot -ChildPath "deployment-outputs.json"
            $outputs | ConvertTo-Json -Depth 10 | Out-File -FilePath $outputFile -Encoding UTF8
            Write-Step "Outputs saved to: $outputFile" -Type Success
        }
        else {
            throw "Deployment failed with state: $($deployment.ProvisioningState)"
        }
    }
}
catch {
    # $_ contains the current error in catch block
    # $_.Exception.Message gets just the message
    Write-Host ""
    Write-Step "Error: $($_.Exception.Message)" -Type Error
    
    # Write full error details to verbose output
    Write-Verbose "Full Error Details:"
    Write-Verbose ($_ | Format-List -Force | Out-String)
    
    # Exit with error code
    exit 1
}
finally {
    # Finally block ALWAYS runs, even if error occurs
    # Good for cleanup operations
    
    $stopwatch.Stop()
    $elapsed = $stopwatch.Elapsed
    
    Write-Host ""
    Write-Host "─────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "Execution Time: $($elapsed.ToString('mm\:ss')) (mm:ss)" -ForegroundColor DarkGray
    Write-Host ""
}

# ============================================================================
# Next Steps
# ============================================================================

Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "───────────" -ForegroundColor DarkGray
Write-Host "  1. Follow the exercises in README.md" -ForegroundColor White
Write-Host "  2. SSH to the VMs and test connectivity" -ForegroundColor White
Write-Host "  3. Compare DNS resolution between Service Endpoint and Private Endpoint" -ForegroundColor White
Write-Host ""
