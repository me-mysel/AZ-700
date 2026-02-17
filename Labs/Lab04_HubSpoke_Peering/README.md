# AZ-700 Lab 4: Hub-Spoke Architecture with VNet Peering

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fme-mysel%2FAZ-700%2Fmain%2FLabs%2FLab04_HubSpoke_Peering%2Fmain.json)

## 🎯 Learning Objectives
1. Understand **Hub-Spoke** topology (most common Azure pattern)
2. Configure **VNet Peering** and understand its properties
3. Prove **VNet Peering is NOT transitive** (critical exam concept!)
4. Use **Route Tables (UDR)** to enable spoke-to-spoke via hub NVA
5. Understand **IP Forwarding** requirements for NVAs

---

## 📐 Lab Architecture

```
                    ┌─────────────────────┐
                    │    vnet-hub         │
                    │    10.0.0.0/16      │
                    │  ┌───────────────┐  │
                    │  │ vm-hub-nva    │  │
                    │  │ 10.0.2.4      │  │
                    │  │ (IP Forward)  │  │
                    │  └───────────────┘  │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              │ Peering        │        Peering │
              ▼                                 ▼
┌─────────────────────┐             ┌─────────────────────┐
│   vnet-spoke1       │             │   vnet-spoke2       │
│   10.1.0.0/16       │   NO DIRECT │   10.2.0.0/16       │
│ ┌─────────────────┐ │◄───────────►│ ┌─────────────────┐ │
│ │ vm-spoke1       │ │   PEERING!  │ │ vm-spoke2       │ │
│ └─────────────────┘ │             │ └─────────────────┘ │
└─────────────────────┘             └─────────────────────┘
```

---

## 🚀 Deployment

**From GitHub (any machine):**
```bash
git clone https://github.com/me-mysel/AZ-700.git
cd AZ-700/Labs/Lab04_HubSpoke_Peering
```

**Deploy with PowerShell:**
```powershell
.\deploy.ps1
```

**Or deploy with Azure CLI:**
```bash
az group create -n rg-az700-lab04 -l uksouth
az deployment group create -g rg-az700-lab04 -f main.bicep \
  --parameters adminPassword='<YourPassword123!>' location=uksouth
```

---

## 🔬 Lab Exercises

### Exercise 1: Verify Hub-Spoke Peering Works

1. RDP to **vm-spoke1**
2. Ping the Hub NVA:
   ```cmd
   ping 10.0.2.4
   ```
   ✅ **Expected:** Success - direct peering exists

---

### Exercise 2: Test Spoke-to-Spoke (WITH Route Tables)

1. From **vm-spoke1**, ping **vm-spoke2**:
   ```cmd
   ping 10.2.1.4
   ```
   ✅ **Expected:** Success - traffic routes via Hub NVA

2. Trace the route:
   ```cmd
   tracert 10.2.1.4
   ```
   **Expected output:**
   ```
   1    <1 ms    10.0.2.4      <- Hub NVA
   2    <1 ms    10.2.1.4      <- Spoke2 VM
   ```

---

### Exercise 3: Prove Transitivity Problem (Remove Route Tables)

1. In Azure Portal, go to **vnet-spoke1** → **Subnets**
2. Click **snet-spoke1-workload**
3. Under **Route table**, select **None** and **Save**
4. Repeat for **vnet-spoke2** → **snet-spoke2-workload**

5. From **vm-spoke1**, try to ping **vm-spoke2**:
   ```cmd
   ping 10.2.1.4
   ```
   ❌ **Expected:** FAIL - "Request timed out"

**Why?** VNet peering is NOT transitive. Even though:
- Spoke1 ↔ Hub (peered)
- Spoke2 ↔ Hub (peered)

Traffic from Spoke1 to Spoke2 doesn't automatically flow through Hub!

---

### Exercise 4: Re-enable Route Tables

1. In Portal, go to **vnet-spoke1** → **Subnets** → **snet-spoke1-workload**
2. Associate **rt-spoke1**
3. Repeat for Spoke2 with **rt-spoke2**
4. Test ping again - should work now!

---

### Exercise 5: Check Effective Routes

1. Go to **vm-spoke1** NIC in Portal
2. Click **Effective routes**
3. Find the route for **10.2.0.0/16**:
   - Next Hop Type: **VirtualAppliance**
   - Next Hop IP: **10.0.2.4** (Hub NVA)

---

### Exercise 6: Verify NVA Configuration

1. RDP to **vm-hub-nva**
2. Check IP forwarding in registry:
   ```powershell
   Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name IpEnableRouter
   ```
   Should show `IpEnableRouter : 1`

3. In Portal, check NIC settings:
   - **nic-vm-hub-nva** → **IP configurations** → **Enable IP forwarding: Yes**

---

## 🧠 AZ-700 Exam Questions

### Q1: Transitivity
> "You have VNet-A peered with VNet-B, and VNet-B peered with VNet-C. Can VNet-A communicate with VNet-C?"

**Answer:** No, VNet peering is NOT transitive. You need either:
- Direct peering between VNet-A and VNet-C, OR
- UDRs routing traffic through a hub NVA in VNet-B

---

### Q2: Peering Properties
> "What must be configured on BOTH sides of a peering for forwarded traffic to work?"

**Answer:** `allowForwardedTraffic: true` must be set on both peering connections.

---

### Q3: NVA Requirements
> "You configured UDRs but spoke-to-spoke traffic still fails. The hub VM can ping both spokes. What's missing?"

**Answer:** Check:
1. **NIC-level IP forwarding** enabled in Azure
2. **OS-level IP routing** enabled (IpEnableRouter = 1)
3. **NSG rules** allow the traffic
4. **allowForwardedTraffic** = true on all peerings

---

### Q4: Gateway Transit
> "Spoke VNets need to use the VPN Gateway in the Hub. What settings are needed?"

**Answer:**
- Hub peering: `allowGatewayTransit: true`
- Spoke peering: `useRemoteGateways: true`

---

## 📚 Documentation

- [VNet Peering Overview](https://learn.microsoft.com/azure/virtual-network/virtual-network-peering-overview)
- [Hub-Spoke Topology](https://learn.microsoft.com/azure/architecture/reference-architectures/hybrid-networking/hub-spoke)
- [Configure VNet Peering](https://learn.microsoft.com/azure/virtual-network/virtual-network-manage-peering)
- [UDR Overview](https://learn.microsoft.com/azure/virtual-network/virtual-networks-udr-overview)

---

## 💰 Cost Estimate

| Resource | Cost |
|----------|------|
| 3x Standard_B2s VMs | ~£0.12/hour |
| 3x Standard Public IPs | ~£0.012/hour |
| **Total running** | **~£3-4/day** |

---

## 🧹 Cleanup

```powershell
.\cleanup.ps1
```
