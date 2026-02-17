# AZ-700: Designing and Implementing Microsoft Azure Networking Solutions

Hands-on labs and study notes for the [AZ-700 certification exam](https://learn.microsoft.com/en-us/credentials/certifications/azure-network-engineer-associate/).

## Labs

Each lab deploys a real Azure environment using **Bicep IaC templates** and includes guided exercises.

| Lab | Topic | Key Concepts |
|-----|-------|-------------|
| [Application Gateway + ASG](Labs/Lab_AppGateway_ASG/) | Application Delivery | App Gateway v2, ASGs, NSG rules, health probes |
| [Private Endpoint + DNS](Labs/Lab02_PrivateEndpoint_DNS/) | Private Access | Private Endpoints, Private DNS Zones, split-brain DNS |
| [Hub-Spoke Peering](Labs/Lab04_HubSpoke_Peering/) | Core Networking | VNet Peering, UDR, NVA, IP Forwarding |
| [VPN Gateway](Labs/Lab05_VPN_Gateway/) | Connectivity | S2S VPN, BGP, IPsec/IKEv2, GatewaySubnet |
| [Private Link & Service Endpoints](Labs/PrivateLink_ServiceEndpoints/) | Private Access | Private Link Service, Service Endpoints, Private Endpoints |

## Quick Start — Deploy from Anywhere

### Prerequisites
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) or [Azure PowerShell](https://learn.microsoft.com/en-us/powershell/azure/install-azure-powershell)
- An Azure subscription with Contributor access

### Option A: Azure CloudShell (zero install)

1. Open [Azure CloudShell](https://shell.azure.com) in your browser
2. Clone and deploy:
   ```bash
   git clone https://github.com/me-mysel/AZ-700.git
   cd AZ-700/Labs/<lab-folder>
   az deployment group create \
     --resource-group <your-rg> \
     --template-file main.bicep \
     --parameters adminPassword='<YourPassword123!>'
   ```

### Option B: Local machine with Azure CLI

```bash
git clone https://github.com/me-mysel/AZ-700.git
cd AZ-700/Labs/<lab-folder>
az login
./deploy.ps1  # PowerShell deploy script (handles RG creation + parameters)
```

### Option C: One-click Deploy to Azure

Some labs include a **Deploy to Azure** button in their README that opens the Azure Portal with the template pre-loaded. These require the Bicep templates to be compiled to ARM JSON — see [Enabling Deploy to Azure Buttons](#enabling-deploy-to-azure-buttons) below.

---

## Cleanup

Every lab includes a `cleanup.ps1` script to tear down all resources and avoid charges:

```powershell
cd Labs/<lab-folder>
./cleanup.ps1
```

---

## Enabling Deploy to Azure Buttons

To enable one-click deployment buttons, compile each lab's Bicep to ARM JSON:

```bash
# From the repo root
az bicep build --file Labs/Lab_AppGateway_ASG/main.bicep
az bicep build --file Labs/Lab02_PrivateEndpoint_DNS/main.bicep
az bicep build --file Labs/Lab04_HubSpoke_Peering/main.bicep
az bicep build --file Labs/Lab05_VPN_Gateway/main.bicep
az bicep build --file Labs/PrivateLink_ServiceEndpoints/main.bicep
```

Then commit and push the generated `.json` files. The Deploy to Azure buttons in each lab's README will work automatically.

---

## Study Notes

The [Study_Notes/](Study_Notes/) folder contains topic-organized notes covering all AZ-700 exam domains:

- **Core Networking** — VNets, Subnets, IP Addressing, Peering, Routing, DNS
- **Connectivity Services** — VPN Gateway, ExpressRoute, Virtual WAN
- **Application Delivery** — Load Balancer, App Gateway, Front Door, Traffic Manager
- **Network Security** — NSG, ASG, Azure Firewall, WAF, Bastion
- **Private Access** — Private Endpoints, Private Link Service, Service Endpoints

## License

Personal learning repository. Bicep templates are provided as-is for educational purposes.
