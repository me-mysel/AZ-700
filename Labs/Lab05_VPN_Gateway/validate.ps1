# AZ-700 Lab 5: Validation Script
# Run this script to verify the lab deployment and VPN connection status

$resourceGroupName = "rg-az700-lab05-vpn"

Write-Host "`n" + "=" * 70 -ForegroundColor Yellow
Write-Host "AZ-700 LAB 5: VPN GATEWAY VALIDATION" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Yellow

# Check if resource group exists
$rg = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "`n❌ Resource group '$resourceGroupName' not found!" -ForegroundColor Red
    Write-Host "   Run .\deploy.ps1 first" -ForegroundColor Yellow
    exit
}

Write-Host "`n✅ Resource Group: $resourceGroupName" -ForegroundColor Green

# Check VPN Gateways
Write-Host "`n📡 VPN GATEWAYS:" -ForegroundColor Cyan
$gateways = Get-AzVirtualNetworkGateway -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue

if ($gateways) {
    foreach ($gw in $gateways) {
        $status = if ($gw.ProvisioningState -eq 'Succeeded') { "✅" } else { "⏳" }
        Write-Host "   $status $($gw.Name)"
        Write-Host "      SKU: $($gw.Sku.Name)"
        Write-Host "      Type: $($gw.VpnType)"
        Write-Host "      BGP Enabled: $($gw.EnableBgp)"
        if ($gw.EnableBgp) {
            Write-Host "      BGP ASN: $($gw.BgpSettings.Asn)"
            Write-Host "      BGP Peer IP: $($gw.BgpSettings.BgpPeeringAddress)"
        }
        Write-Host ""
    }
} else {
    Write-Host "   ⏳ VPN Gateways still deploying (this takes 30-45 minutes)" -ForegroundColor Yellow
}

# Check VPN Connections
Write-Host "🔗 VPN CONNECTIONS:" -ForegroundColor Cyan
$connections = Get-AzVirtualNetworkGatewayConnection -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue

if ($connections) {
    foreach ($conn in $connections) {
        $statusIcon = switch ($conn.ConnectionStatus) {
            'Connected' { "✅" }
            'Connecting' { "⏳" }
            'NotConnected' { "❌" }
            default { "❓" }
        }
        Write-Host "   $statusIcon $($conn.Name): $($conn.ConnectionStatus)"
        Write-Host "      Protocol: $($conn.ConnectionProtocol)"
        Write-Host "      BGP: $($conn.EnableBgp)"
        Write-Host "      Ingress: $($conn.IngressBytesTransferred) bytes"
        Write-Host "      Egress: $($conn.EgressBytesTransferred) bytes"
        Write-Host ""
    }
} else {
    Write-Host "   ⏳ Connections not yet created (waiting for gateways)" -ForegroundColor Yellow
}

# Check BGP Peer Status (if gateways exist)
if ($gateways -and $gateways.Count -gt 0) {
    Write-Host "🌐 BGP PEER STATUS:" -ForegroundColor Cyan
    foreach ($gw in $gateways) {
        Write-Host "   Gateway: $($gw.Name)"
        try {
            $bgpPeers = Get-AzVirtualNetworkGatewayBGPPeerStatus -VirtualNetworkGatewayName $gw.Name -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
            if ($bgpPeers) {
                foreach ($peer in $bgpPeers) {
                    $peerStatus = if ($peer.State -eq 'Connected') { "✅" } else { "❌" }
                    Write-Host "      $peerStatus Peer: $($peer.Neighbor) - State: $($peer.State) - ASN: $($peer.Asn)"
                }
            }
        } catch {
            Write-Host "      (BGP status not yet available)" -ForegroundColor Yellow
        }
        Write-Host ""
    }
}

# Check VMs
Write-Host "🖥️  VIRTUAL MACHINES:" -ForegroundColor Cyan
$vms = Get-AzVM -ResourceGroupName $resourceGroupName -ErrorAction SilentlyContinue
foreach ($vm in $vms) {
    $vmStatus = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vm.Name -Status
    $powerState = ($vmStatus.Statuses | Where-Object { $_.Code -like 'PowerState/*' }).DisplayStatus
    $statusIcon = if ($powerState -eq 'VM running') { "✅" } else { "⏹️" }
    
    # Get NIC to find IPs
    $nicId = $vm.NetworkProfile.NetworkInterfaces[0].Id
    $nic = Get-AzNetworkInterface -ResourceId $nicId
    $privateIp = $nic.IpConfigurations[0].PrivateIpAddress
    $pipId = $nic.IpConfigurations[0].PublicIpAddress.Id
    if ($pipId) {
        $pip = Get-AzPublicIpAddress -ResourceId $pipId -ErrorAction SilentlyContinue
        $publicIp = $pip.IpAddress
    }
    
    Write-Host "   $statusIcon $($vm.Name): $powerState"
    Write-Host "      Private IP: $privateIp"
    Write-Host "      Public IP:  $publicIp"
    Write-Host "      RDP:        mstsc /v:$publicIp"
    Write-Host ""
}

# Summary
Write-Host "=" * 70 -ForegroundColor Yellow
Write-Host "VALIDATION SUMMARY" -ForegroundColor Cyan
Write-Host "=" * 70 -ForegroundColor Yellow

$allConnected = $connections | Where-Object { $_.ConnectionStatus -eq 'Connected' }
if ($allConnected.Count -eq 2) {
    Write-Host "`n✅ LAB READY! Both VPN connections are established." -ForegroundColor Green
    Write-Host "   You can now proceed with the exercises in README.md" -ForegroundColor Cyan
} elseif ($gateways.Count -lt 2) {
    Write-Host "`n⏳ VPN Gateways still deploying..." -ForegroundColor Yellow
    Write-Host "   This takes 30-45 minutes. Please wait." -ForegroundColor Yellow
} else {
    Write-Host "`n⏳ VPN Connections establishing..." -ForegroundColor Yellow
    Write-Host "   Gateways are ready, connections should be up within 2-3 minutes." -ForegroundColor Yellow
}

Write-Host "`n💡 Run this script again to check status: .\validate.ps1" -ForegroundColor Cyan
