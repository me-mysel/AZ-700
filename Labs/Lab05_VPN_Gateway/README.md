# AZ-700 Lab 5: VPN Gateway Fundamentals

## 🎯 Learning Objectives

1. Understand **VPN Gateway** deployment and configuration
2. Configure **Site-to-Site (S2S)** VPN connection (simulated with VNet-to-VNet)
3. Enable and verify **BGP** for dynamic route learning
4. Understand **GatewaySubnet** requirements
5. Examine VPN connection status and troubleshooting
6. Compare **Route-based vs Policy-based** VPN types

---

## 📐 Lab Architecture

This lab simulates a Site-to-Site VPN connection using two VNets in Azure. One VNet represents your "on-premises" datacenter, and the other represents your Azure hub network.

```
    "ON-PREMISES"                              AZURE
   (Simulated DC)                            (Hub VNet)
┌─────────────────────────────┐       ┌─────────────────────────────┐
│  vnet-onprem-simulated      │       │  vnet-azure-hub             │
│  192.168.0.0/16             │       │  10.0.0.0/16                │
│                             │       │                             │
│  ┌───────────────────────┐  │       │  ┌───────────────────────┐  │
│  │ GatewaySubnet         │  │       │  │ GatewaySubnet         │  │
│  │ 192.168.255.0/27      │  │       │  │ 10.0.255.0/27         │  │
│  │                       │  │       │  │                       │  │
│  │  ┌─────────────────┐  │  │IPsec/ │  │  ┌─────────────────┐  │  │
│  │  │  vpngw-onprem   │◄─┼──┼─IKEv2─┼──┼─►│  vpngw-azure    │  │  │
│  │  │  ASN: 65001     │  │  │ BGP   │  │  │  ASN: 65515     │  │  │
│  │  └─────────────────┘  │  │       │  │  └─────────────────┘  │  │
│  └───────────────────────┘  │       │  └───────────────────────┘  │
│                             │       │                             │
│  ┌───────────────────────┐  │       │  ┌───────────────────────┐  │
│  │ snet-onprem-workload  │  │       │  │ snet-azure-workload   │  │
│  │ 192.168.1.0/24        │  │       │  │ 10.0.1.0/24           │  │
│  │                       │  │       │  │                       │  │
│  │  ┌─────────────────┐  │  │       │  │  ┌─────────────────┐  │  │
│  │  │   vm-onprem     │  │  │       │  │  │   vm-azure      │  │  │
│  │  │   192.168.1.4   │  │  │       │  │  │   10.0.1.4      │  │  │
│  │  └─────────────────┘  │  │       │  │  └─────────────────┘  │  │
│  └───────────────────────┘  │       │  └───────────────────────┘  │
└─────────────────────────────┘       └─────────────────────────────┘
```

### Why Simulate S2S with VNet-to-VNet?

- Real S2S VPN requires physical on-premises hardware
- VNet-to-VNet uses the same IPsec/IKE protocols as S2S
- Demonstrates identical concepts: tunnels, BGP, shared keys
- Perfect for learning without physical infrastructure

---

## 🚀 Deployment

### Prerequisites

- Azure subscription with Contributor access
- PowerShell with Az module installed
- ~£5-10 budget (VPN Gateways are not free!)

### Deploy the Lab

**From GitHub (any machine):**
```bash
git clone https://github.com/me-mysel/AZ-700.git
cd AZ-700/Labs/Lab05_VPN_Gateway
```

**Deploy with PowerShell:**
```powershell
.\deploy.ps1
```

**Or deploy with Azure CLI:**
```bash
az group create -n rg-az700-lab05-vpn -l uksouth
az deployment group create -g rg-az700-lab05-vpn -f main.bicep \
  --parameters adminPassword='<YourPassword123!>' vpnSharedKey='<YourSharedKey!>' location=uksouth
```

⚠️ **IMPORTANT**: VPN Gateway deployment takes **30-45 minutes**! The gateways are the slowest resources to provision in Azure.

---

## 🔬 Lab Exercises

### Exercise 1: Verify VPN Connection Status

1. Navigate to **Azure Portal** → **Virtual network gateways** → **vpngw-azure**
2. Click **Connections** in the left menu
3. Verify the connection status shows **Connected**

**PowerShell Method:**
```powershell
Get-AzVirtualNetworkGatewayConnection -ResourceGroupName rg-az700-lab05-vpn |
    Select-Object Name, ConnectionStatus, EgressBytesTransferred, IngressBytesTransferred
```

✅ **Expected**: `ConnectionStatus: Connected`

---

### Exercise 2: Test Connectivity Through VPN Tunnel

1. RDP to **vm-onprem** (the "on-premises" simulated VM)
2. Open Command Prompt and ping the Azure VM:

```cmd
ping 10.0.1.4
```

✅ **Expected**: `Reply from 10.0.1.4: bytes=32 time=Xms TTL=128`

3. Trace the route:

```cmd
tracert 10.0.1.4
```

✅ **Expected**: Single hop through encrypted tunnel (no intermediate hops visible)

---

### Exercise 3: Examine BGP Configuration

BGP enables automatic route learning between sites.

1. **View BGP Settings:**
   - Portal → **vpngw-azure** → **Configuration**
   - Note: BGP ASN = **65515** (Azure default)
   - Note: BGP peer IP address

2. **View BGP Peer Status:**

```powershell
Get-AzVirtualNetworkGatewayBGPPeerStatus `
    -VirtualNetworkGatewayName vpngw-azure `
    -ResourceGroupName rg-az700-lab05-vpn
```

3. **View Learned Routes:**

```powershell
Get-AzVirtualNetworkGatewayLearnedRoute `
    -VirtualNetworkGatewayName vpngw-azure `
    -ResourceGroupName rg-az700-lab05-vpn | Format-Table
```

✅ **Expected**: You should see `192.168.0.0/16` learned from the "on-prem" gateway

---

### Exercise 4: Examine Effective Routes on VM

See how routes are propagated to VMs automatically.

1. Portal → **vm-azure** → **Network settings** → **nic-vm-azure**
2. Click **Effective routes**
3. Look for:
   - `192.168.0.0/16` → **VirtualNetworkGateway** (learned via BGP!)
   - `10.0.0.0/16` → **VirtualNetwork** (local VNet)

🔑 **Key Insight**: Without BGP, you'd need to manually specify `192.168.0.0/16` in the Local Network Gateway. With BGP, routes are learned automatically!

---

### Exercise 5: Understand Gateway Subnet Requirements

Critical AZ-700 exam knowledge!

1. Portal → **vnet-azure-hub** → **Subnets**
2. Examine the **GatewaySubnet**:

| Requirement | Value in Lab | AZ-700 Exam Note |
|-------------|--------------|------------------|
| **Name** | `GatewaySubnet` | MUST be exactly this name (case-sensitive!) |
| **Size** | `/27` (32 IPs) | Minimum recommended; `/26` for ExpressRoute coexistence |
| **NSG** | None | NSGs are NOT supported on GatewaySubnet |
| **UDR** | None | Avoid UDRs unless absolutely necessary |

3. **Test the Name Requirement (Optional):**
   - Try creating a subnet called "VPNSubnet"
   - Attempt to deploy a VPN Gateway to it
   - ❌ It will **FAIL** - the name MUST be "GatewaySubnet"

---

### Exercise 6: View VPN Connection Properties

1. Portal → **Connections** → **conn-azure-to-onprem**
2. Review the configuration:

| Property | Value | Description |
|----------|-------|-------------|
| Connection type | IPsec | Standard VPN protocol |
| Connection protocol | IKEv2 | Newer, more secure than IKEv1 |
| Enable BGP | True | Dynamic routing enabled |
| Shared key | (hidden) | Pre-shared key for authentication |

3. Check **Ingress/Egress bytes** to verify traffic is flowing

---

### Exercise 7: Compare VPN Types (Conceptual)

This lab uses **Route-based** VPN. Understand the differences:

| Feature | Route-based (This Lab) | Policy-based |
|---------|------------------------|--------------|
| **VPN Type** | RouteBased | PolicyBased |
| **IKE Version** | IKEv1 and IKEv2 | IKEv1 only |
| **Max Tunnels** | Up to 30 (S2S) | 1 tunnel only |
| **BGP Support** | ✅ Yes | ❌ No |
| **P2S Support** | ✅ Yes | ❌ No |
| **Active-Active** | ✅ Yes | ❌ No |
| **SKUs** | All SKUs | Basic only |
| **Use Case** | Most scenarios | Legacy devices only |

---

## 🔧 Bonus Exercises

### Bonus 1: Reset VPN Gateway

If a VPN connection is stuck or behaving unexpectedly:

```powershell
$gw = Get-AzVirtualNetworkGateway -Name vpngw-azure -ResourceGroupName rg-az700-lab05-vpn
Reset-AzVirtualNetworkGateway -VirtualNetworkGateway $gw
```

⚠️ This causes brief connectivity disruption!

### Bonus 2: View Shared Key

```powershell
Get-AzVirtualNetworkGatewayConnectionSharedKey `
    -Name conn-azure-to-onprem `
    -ResourceGroupName rg-az700-lab05-vpn
```

### Bonus 3: Check Gateway SKU Features

```powershell
Get-AzVirtualNetworkGateway -ResourceGroupName rg-az700-lab05-vpn |
    Select-Object Name, @{N='SKU';E={$_.Sku.Name}}, @{N='BGP';E={$_.EnableBgp}}, @{N='ASN';E={$_.BgpSettings.Asn}}
```

---

## 📋 AZ-700 Exam Tips

### Key Concepts Demonstrated

| Concept | What You Learned |
|---------|------------------|
| **GatewaySubnet** | Must be named EXACTLY "GatewaySubnet" |
| **Subnet Size** | /27 minimum recommended |
| **Route-based VPN** | Default and recommended for most scenarios |
| **BGP** | Enables automatic route learning |
| **ASN 65515** | Azure's default BGP ASN |
| **VPN SKUs** | Basic doesn't support BGP; VpnGw1+ does |
| **IKEv2** | Preferred protocol (more secure than IKEv1) |
| **Local Network Gateway** | Represents the remote site |

### Exam Question Patterns

1. **"VPN Gateway deployment fails..."** → Check GatewaySubnet name
2. **"Routes not propagating automatically..."** → Enable BGP
3. **"Need P2S, Active-Active, or multiple tunnels..."** → Must use Route-based
4. **"Legacy device only supports IKEv1..."** → Can still use Route-based
5. **"On-prem using ASN 65515..."** → Invalid - that's Azure's reserved ASN

---

## 💰 Cost Management

| Resource | Approximate Cost |
|----------|------------------|
| VPN Gateway (VpnGw1) x2 | ~£0.03/hour each |
| VMs (Standard_B2s) x2 | ~£0.02/hour each |
| Public IPs x4 | ~£0.004/hour each |
| **Total** | **~£3-5/day** |

⚠️ **Run cleanup when done!**

```powershell
.\cleanup.ps1
```

---

## 🧹 Cleanup

```powershell
# From the lab folder
.\cleanup.ps1
```

Note: Deletion takes 10-15 minutes (VPN Gateways are slow to delete too!)

---

## 📚 Additional Resources

- [Microsoft Learn: VPN Gateway Documentation](https://learn.microsoft.com/azure/vpn-gateway/)
- [VPN Gateway FAQ](https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-vpn-faq)
- [BGP with VPN Gateway](https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-bgp-overview)
- [Validated VPN Devices](https://learn.microsoft.com/azure/vpn-gateway/vpn-gateway-about-vpn-devices)
