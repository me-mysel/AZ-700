# AZ-700 Lab 2: Private Endpoint + DNS Resolution

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fme-mysel%2FAZ-700%2Fmain%2FLabs%2FLab02_PrivateEndpoint_DNS%2Fmain.json)

## Hands-On Lab Guide

### 🎯 Learning Objectives
By completing this lab, you will understand:
1. How Private Endpoints provide private connectivity to Azure PaaS services
2. How Azure Private DNS Zones enable name resolution for private endpoints
3. The "split-brain DNS" behavior between Azure VMs and on-premises clients
4. Why VNet Links are required for DNS resolution

---

## 📁 Lab Files

| File | Purpose |
|------|---------|
| `main.bicep` | Infrastructure as Code template |
| `deploy.ps1` | Deployment script |
| `cleanup.ps1` | Resource cleanup script |

---

## 🚀 Deployment Instructions

### Prerequisitesrg-az700-lab02
- Azure PowerShell module (`Az`) installed
- Active Azure subscription
- Permissions to create resources

### Step 1: Clone & Navigate
```bash
git clone https://github.com/me-mysel/AZ-700.git
cd AZ-700/Labs/Lab02_PrivateEndpoint_DNS
```

### Step 2: Login to Azure (if not already)
```powershell
Connect-AzAccount
```

### Step 3: Deploy the Lab
```powershell
.\deploy.ps1
```

**Or deploy with Azure CLI:**
```bash
az group create -n rg-az700-lab02 -l uksouth
az deployment group create -g rg-az700-lab02 -f main.bicep \
  --parameters adminPassword='<YourPassword123!>' location=uksouth
```
You'll be prompted for a VM admin password (must meet Azure complexity requirements).

---

## 🔬 Lab Exercises

### Exercise 1: Verify Private DNS Zone Configuration

1. Open Azure Portal → Resource Groups → `rg-az700-lab02`
2. Click on the Private DNS Zone (`privatelink.blob.core.windows.net`)
3. **Observe:**
   - The A record pointing to the Private Endpoint's private IP
   - The Virtual Network Link to `vnet-lab02-hub`

**❓ Exam Question:** What happens if you delete the VNet Link?
<details>
<summary>Answer</summary>
VMs in the linked VNet would no longer be able to resolve the private endpoint's FQDN to its private IP. They would fall back to public DNS resolution.
</details>

---

### Exercise 2: Test DNS Resolution from Azure VM

1. RDP to the VM using the Public IP from deployment output:
   ```powershell
   mstsc /v:<VM_PUBLIC_IP>
   ```
   Username: `azureadmin`

2. Open Command Prompt on the VM and run:
   ```cmd
   nslookup <storage_account_name>.blob.core.windows.net
   ```

3. **Expected Result:** Resolution to the Private IP (10.0.2.x)

**❓ Exam Question:** Which DNS server does the Azure VM use by default?
<details>
<summary>Answer</summary>
168.63.129.16 - Azure's virtual public IP for platform services including DNS. This IP routes DNS queries to Azure DNS, which checks Private DNS Zones first.
</details>

---

### Exercise 3: Test DNS Resolution from Local Machine

1. Open Command Prompt on your **local machine** (not the VM):
   ```cmd
   nslookup <storage_account_name>.blob.core.windows.net
   ```

2. **Expected Result:** Resolution to a PUBLIC IP address

**❓ Exam Question:** Why does the same FQDN resolve differently?
<details>
<summary>Answer</summary>
This is "split-brain DNS" behavior:
- Azure VM → Uses 168.63.129.16 → Checks Private DNS Zone → Returns Private IP
- Local machine → Uses public DNS → No access to Private DNS Zone → Returns Public IP

This is why hybrid scenarios require DNS forwarding or Azure DNS Private Resolver.
</details>

---

### Exercise 4: Test Connectivity to Storage

> **Note:** Blob Storage returns `400 Bad Request` if you hit the root URL without a container path. Use `Test-NetConnection` for connectivity validation and the Blob REST API with a container path for access tests.

1. From the **Azure VM**, verify TCP connectivity via Private Endpoint:
   ```powershell
   # Test TCP connectivity on port 443 — should succeed
   Test-NetConnection -ComputerName "<storage_account_name>.blob.core.windows.net" -Port 443
   # Expected: TcpTestSucceeded = True, RemoteAddress = 10.0.2.x (private IP)
   ```

2. From the **Azure VM**, verify DNS resolves to the private IP:
   ```powershell
   Resolve-DnsName "<storage_account_name>.blob.core.windows.net"
   # Expected: CNAME → privatelink.blob.core.windows.net → 10.0.2.x
   ```

3. From your **local machine**, try the same connectivity test:
   ```powershell
   # This should FAIL or resolve to a public IP
   Test-NetConnection -ComputerName "<storage_account_name>.blob.core.windows.net" -Port 443
   # Expected: TcpTestSucceeded = False (public access disabled) or resolves to public IP
   ```

**❓ Exam Question:** Why does the VM reach the storage account but your local machine cannot?
<details>
<summary>Answer</summary>
The Storage Account has "Public network access: Disabled", so it only accepts connections via the Private Endpoint. The Azure VM resolves the FQDN to the private IP (10.0.2.x) via the Private DNS Zone, while your local machine resolves to the public IP — which is blocked.
</details>

---

### Exercise 5: Explore Effective Routes

1. In Azure Portal, go to the VM's NIC → **Effective routes**
2. Look for routes to the Private Endpoint subnet

**❓ Exam Question:** Does traffic to the Private Endpoint go through a gateway?
<details>
<summary>Answer</summary>
No. Traffic to Private Endpoints stays within the Azure backbone network. The Private Endpoint is essentially a NIC with a private IP in your VNet, so traffic routes directly within the VNet.
</details>

---

### Exercise 6: Examine the Private Endpoint

1. Go to the Private Endpoint resource in the portal
2. Click on **DNS configuration**
3. **Observe:**
   - The FQDN registered
   - The Private DNS Zone it's linked to
   - The A record created

4. Click on **Network interface**
5. **Note the Private IP address** assigned from the PE subnet

---

## 🧠 AZ-700 Exam Scenarios

### Scenario 1: Hybrid DNS Resolution
> "Your on-premises servers need to resolve Private Endpoint FQDNs. What should you configure?"

**Answer Options:**
- A) Create a CNAME record on-premises
- B) Configure conditional forwarder for `blob.core.windows.net` to Azure DNS Private Resolver inbound endpoint
- C) Configure conditional forwarder for `privatelink.blob.core.windows.net`
- D) Peer the on-premises network with the Azure VNet

**Correct Answer: B**
- Forward `blob.core.windows.net` (NOT privatelink) to Azure DNS Private Resolver
- The CNAME chain (`storage.blob` → `storage.privatelink.blob`) is handled by Azure DNS

---

### Scenario 2: Multiple VNets
> "You have 3 VNets that need to resolve the same Private Endpoint. What's required?"

**Answer:** Create Virtual Network Links from the Private DNS Zone to all 3 VNets.

---

### Scenario 3: Missing DNS Resolution
> "An Azure VM can't resolve a Private Endpoint FQDN. The Private DNS Zone exists. What's missing?"

**Answer:** The VNet Link between the Private DNS Zone and the VM's VNet.

---

## 🧹 Cleanup

**IMPORTANT:** Delete resources when done to avoid charges!

```powershell
.\cleanup.ps1
```

Or manually:
```powershell
Remove-AzResourceGroup -Name "rg-az700-lab02" -Force
```

---

## 📚 Documentation References

- [Private Endpoints Overview](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
- [Azure Private DNS](https://learn.microsoft.com/en-us/azure/dns/private-dns-overview)
- [Private Endpoint DNS Integration](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns)
- [DNS for Private Endpoints](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-dns-integration)

---

## 💰 Cost Estimate

| Resource | Approximate Cost |
|----------|------------------|
| Windows VM (Standard_B2s) | ~£0.04/hour |
| Private Endpoint | ~£0.008/hour |
| Storage Account | ~£0.02/GB/month |
| Public IP | ~£0.004/hour |
| **Total (running)** | **~£4-5/day** |

**Tip:** Deallocate the VM when not in use to reduce costs!
```powershell
Stop-AzVM -ResourceGroupName "rg-az700-lab02" -Name "vm-lab02-test" -Force
```
