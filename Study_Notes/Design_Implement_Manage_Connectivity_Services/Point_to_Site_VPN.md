---
tags:
  - AZ-700
  - azure/networking
  - domain/connectivity
  - point-to-site
  - p2s-vpn
  - openvpn
  - ikev2
  - sstp
  - entra-id-auth
  - radius
  - certificate-auth
  - always-on-vpn
aliases:
  - P2S VPN
  - Point-to-Site VPN
created: 2025-01-01
updated: 2026-02-07
---

# Point-to-Site (P2S) VPN

> [!info] Related Notes
> - [[VPN_Gateway]] — P2S runs on a VPN Gateway resource
> - [[Virtual_WAN]] — P2S VPN in Virtual WAN (User VPN)
> - [[VNet_Subnets_IP_Addressing]] — Client address pool configuration
> - [[NSG_ASG_Firewall]] — NSG rules for P2S client traffic

## Overview

Point-to-Site VPN enables individual clients (laptops, desktops, mobile devices) to securely connect to Azure virtual networks from anywhere. Unlike Site-to-Site VPN, P2S doesn't require a VPN device or public IP address on the client side.

### Key Concepts

| Concept | Description |
|---------|-------------|
| **P2S VPN** | Individual client-to-VNet connection |
| **VPN Client** | Software on user device (native or Azure VPN) |
| **Tunnel Protocol** | OpenVPN, IKEv2, or SSTP |
| **Authentication** | Certificate, RADIUS, or Microsoft Entra ID |
| **Address Pool** | IP range assigned to connecting clients |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      Point-to-Site VPN Architecture                              │
│                                                                                  │
│    REMOTE USERS                                                                  │
│    ┌──────────────┐   ┌──────────────┐   ┌──────────────┐                       │
│    │   Windows    │   │    macOS     │   │    Linux     │                       │
│    │   Laptop     │   │   MacBook    │   │   Desktop    │                       │
│    │              │   │              │   │              │                       │
│    │ VPN Client:  │   │ VPN Client:  │   │ VPN Client:  │                       │
│    │ • IKEv2      │   │ • IKEv2      │   │ • OpenVPN    │                       │
│    │ • SSTP       │   │ • OpenVPN    │   │ • strongSwan │                       │
│    │ • OpenVPN    │   │              │   │              │                       │
│    └──────┬───────┘   └──────┬───────┘   └──────┬───────┘                       │
│           │                  │                  │                                │
│           └──────────────────┼──────────────────┘                                │
│                              │                                                   │
│                              ▼                                                   │
│                    ┌─────────────────────┐                                      │
│                    │     INTERNET        │                                      │
│                    │   (Encrypted VPN    │                                      │
│                    │    Tunnels)         │                                      │
│                    └─────────┬───────────┘                                      │
│                              │                                                   │
│                              ▼                                                   │
│  ┌───────────────────────────────────────────────────────────────────────────┐  │
│  │                         AZURE                                              │  │
│  │                                                                            │  │
│  │   ┌────────────────────────────────────────────────────────────────────┐  │  │
│  │   │                    VPN GATEWAY                                      │  │  │
│  │   │                    (GatewaySubnet)                                  │  │  │
│  │   │                                                                     │  │  │
│  │   │  P2S Configuration:                                                 │  │  │
│  │   │  ┌──────────────────────────────────────────────────────────────┐  │  │  │
│  │   │  │ • Address Pool: 172.16.0.0/24                                │  │  │  │
│  │   │  │ • Tunnel Type: OpenVPN / IKEv2                               │  │  │  │
│  │   │  │ • Authentication: Certificate / Entra ID / RADIUS            │  │  │  │
│  │   │  └──────────────────────────────────────────────────────────────┘  │  │  │
│  │   └────────────────────────────────────────────────────────────────────┘  │  │
│  │                              │                                             │  │
│  │                              ▼                                             │  │
│  │   ┌────────────────────────────────────────────────────────────────────┐  │  │
│  │   │                    VIRTUAL NETWORK (10.0.0.0/16)                   │  │  │
│  │   │                                                                     │  │  │
│  │   │   ┌──────────────┐   ┌──────────────┐   ┌──────────────────────┐  │  │  │
│  │   │   │  Web Tier    │   │  App Tier    │   │   Database Tier      │  │  │  │
│  │   │   │  10.0.1.0/24 │   │  10.0.2.0/24 │   │   10.0.3.0/24        │  │  │  │
│  │   │   └──────────────┘   └──────────────┘   └──────────────────────┘  │  │  │
│  │   └────────────────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## Tunnel Protocols

### Protocol Comparison

| Protocol | Port | OS Support | Authentication | Use Case |
|----------|------|------------|----------------|----------|
| **OpenVPN** | TCP 443 / UDP 1194 | Windows, macOS, Linux, iOS, Android | All methods | Most versatile, recommended |
| **IKEv2** | UDP 500, 4500 | Windows, macOS, iOS | Certificate, Entra ID | Fast reconnection (mobile) |
| **SSTP** | TCP 443 | Windows only | Certificate, RADIUS | Firewall-friendly (Windows) |

### Protocol Selection Guide

```
┌────────────────────────────────────────────────────────────────────────┐
│                    P2S Protocol Selection                               │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  What OS does the client use?                                          │
│                    │                                                    │
│         ┌─────────┼─────────┐                                          │
│         │         │         │                                          │
│      Windows   macOS/iOS  Linux/Android                                │
│         │         │         │                                          │
│         │         │         │                                          │
│         ▼         ▼         ▼                                          │
│    ┌─────────┐ ┌─────────┐ ┌─────────┐                                │
│    │OpenVPN  │ │ IKEv2   │ │ OpenVPN │                                │
│    │ IKEv2   │ │ OpenVPN │ │ (only)  │                                │
│    │ SSTP    │ └─────────┘ └─────────┘                                │
│    └─────────┘                                                         │
│                                                                         │
│  ⚠️  SSTP = Windows only, Certificate/RADIUS auth only                │
│  ⚠️  IKEv2 = Best for mobile (fast reconnect after network change)    │
│  ✅  OpenVPN = Most versatile, supports all auth methods              │
│                                                                         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Authentication Methods

### Comparison Table

| Method | Setup Complexity | OS Support | MFA | Conditional Access | Enterprise Scale |
|--------|-----------------|------------|-----|-------------------|------------------|
| **Azure Certificate** | Medium | All | ❌ | ❌ | Small/Medium |
| **RADIUS** | High | All | ✅ | ❌ | Enterprise |
| **Microsoft Entra ID** | Low | OpenVPN only | ✅ | ✅ | Enterprise |

### Microsoft Entra ID Authentication (Recommended)

```
┌────────────────────────────────────────────────────────────────────────┐
│                    Entra ID Authentication Flow                         │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   User                        Entra ID                    VPN Gateway  │
│     │                            │                            │        │
│     │  1. Connect VPN            │                            │        │
│     │────────────────────────────┼───────────────────────────►│        │
│     │                            │                            │        │
│     │  2. Redirect to login      │                            │        │
│     │◄───────────────────────────┼────────────────────────────│        │
│     │                            │                            │        │
│     │  3. Authenticate + MFA     │                            │        │
│     │───────────────────────────►│                            │        │
│     │                            │                            │        │
│     │  4. Token issued           │                            │        │
│     │◄───────────────────────────│                            │        │
│     │                            │                            │        │
│     │  5. Token validated, tunnel established                 │        │
│     │◄───────────────────────────────────────────────────────►│        │
│     │                            │                            │        │
│                                                                         │
│   Benefits:                                                            │
│   • Native MFA support                                                 │
│   • Conditional Access policies                                        │
│   • No certificate management                                          │
│   • User/group-based access control                                    │
│   • Works with OpenVPN protocol only                                   │
│                                                                         │
└────────────────────────────────────────────────────────────────────────┘
```

### Certificate Authentication

```
┌────────────────────────────────────────────────────────────────────────┐
│                    Certificate Chain                                    │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│                    ┌─────────────────────────┐                         │
│                    │     Root Certificate    │                         │
│                    │   (Self-signed or CA)   │                         │
│                    │                         │                         │
│                    │  Upload PUBLIC KEY to   │                         │
│                    │  VPN Gateway P2S config │                         │
│                    └───────────┬─────────────┘                         │
│                                │                                        │
│                    Signs (generates)                                   │
│                                │                                        │
│              ┌─────────────────┼─────────────────┐                     │
│              ▼                 ▼                 ▼                     │
│   ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐      │
│   │ Client Cert 1    │ │ Client Cert 2    │ │ Client Cert 3    │      │
│   │                  │ │                  │ │                  │      │
│   │ Install on       │ │ Install on       │ │ Install on       │      │
│   │ User1's device   │ │ User2's device   │ │ User3's device   │      │
│   │                  │ │                  │ │                  │      │
│   │ (PRIVATE + PUBLIC│ │ (PRIVATE + PUBLIC│ │ (PRIVATE + PUBLIC│      │
│   │  keys)           │ │  keys)           │ │  keys)           │      │
│   └──────────────────┘ └──────────────────┘ └──────────────────┘      │
│                                                                         │
│   ⚠️  Keep root private key SECURE - needed to generate client certs  │
│   ⚠️  Can revoke individual client certs via thumbprint               │
│                                                                         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Configuration Best Practices

### Configure P2S with Microsoft Entra ID Authentication

```powershell
# Prerequisites:
# 1. Register Azure VPN application in Entra ID tenant
# 2. Grant admin consent for the application
# 3. Get Tenant ID and Azure VPN Application ID

# Configure P2S on existing VPN Gateway
$gateway = Get-AzVirtualNetworkGateway -Name "vpn-gw-prod" -ResourceGroupName "rg-networking"

$tenantId = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$audience = "41b23e61-6c1e-4545-b367-cd054e0ed4b4"  # Azure VPN Enterprise App ID (fixed)

Set-AzVirtualNetworkGateway `
    -VirtualNetworkGateway $gateway `
    -VpnClientAddressPool "172.16.0.0/24" `
    -VpnClientProtocol "OpenVPN" `
    -VpnAuthenticationType "AAD" `
    -AadTenantUri "https://login.microsoftonline.com/$tenantId/" `
    -AadIssuerUri "https://sts.windows.net/$tenantId/" `
    -AadAudienceId $audience
```

### Configure P2S with Certificate Authentication

```powershell
# Generate self-signed root certificate (run on admin workstation)
$rootCert = New-SelfSignedCertificate `
    -Type Custom `
    -KeySpec Signature `
    -Subject "CN=P2SRootCert" `
    -KeyExportPolicy Exportable `
    -HashAlgorithm sha256 `
    -KeyLength 2048 `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyUsageProperty Sign `
    -KeyUsage CertSign

# Generate client certificate signed by root
$clientCert = New-SelfSignedCertificate `
    -Type Custom `
    -DnsName "P2SClientCert" `
    -KeySpec Signature `
    -Subject "CN=P2SClientCert" `
    -KeyExportPolicy Exportable `
    -HashAlgorithm sha256 `
    -KeyLength 2048 `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -Signer $rootCert `
    -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")

# Export root certificate public key (for Azure)
$rootCertBase64 = [System.Convert]::ToBase64String($rootCert.RawData)

# Configure VPN Gateway with certificate
$gateway = Get-AzVirtualNetworkGateway -Name "vpn-gw-prod" -ResourceGroupName "rg-networking"

$p2sRootCert = New-AzVpnClientRootCertificate `
    -Name "P2SRootCert" `
    -PublicCertData $rootCertBase64

Set-AzVirtualNetworkGateway `
    -VirtualNetworkGateway $gateway `
    -VpnClientAddressPool "172.16.0.0/24" `
    -VpnClientProtocol "IKEv2", "OpenVPN" `
    -VpnAuthenticationType "Certificate" `
    -VpnClientRootCertificates $p2sRootCert
```

### Configure P2S with RADIUS

```powershell
# Configure VPN Gateway for RADIUS authentication
$gateway = Get-AzVirtualNetworkGateway -Name "vpn-gw-prod" -ResourceGroupName "rg-networking"

Set-AzVirtualNetworkGateway `
    -VirtualNetworkGateway $gateway `
    -VpnClientAddressPool "172.16.0.0/24" `
    -VpnClientProtocol "IKEv2", "OpenVPN" `
    -VpnAuthenticationType "Radius" `
    -RadiusServerAddress "10.0.5.4" `
    -RadiusServerSecret (ConvertTo-SecureString "RadiusSecret123!" -AsPlainText -Force)
```

### Download VPN Client Configuration

```powershell
# Generate VPN client package
$profile = New-AzVpnClientConfiguration `
    -ResourceGroupName "rg-networking" `
    -Name "vpn-gw-prod" `
    -AuthenticationMethod "EapTls"  # For certificate auth

# Output contains URL to download client package
$profile.VPNProfileSASUrl

# For Entra ID, download Azure VPN Client from Microsoft Store/App Store
```

---

## Exam Tips & Gotchas

### Critical Points (Commonly Tested)

- **OpenVPN required for Entra ID authentication** — IKEv2/SSTP don't support Entra ID
- **SSTP is Windows-only** — macOS, Linux, mobile require OpenVPN or IKEv2
- **IKEv2 best for mobile** — reconnects quickly after network changes (MOBIKE)
- **Address pool must NOT overlap** with VNet ranges or on-premises ranges
- **VPN Gateway SKU matters** — Basic SKU doesn't support P2S, need VpnGw1+
- **Route-based VPN required** — Policy-based doesn't support P2S
- **Max P2S connections vary by SKU** — VpnGw1: 250, VpnGw2: 500, etc.
- **Root certificate public key only** — upload to Azure (never private key)

### Exam Scenarios

| Scenario | Solution |
|----------|----------|
| Need MFA for remote VPN users | Use Entra ID authentication with Conditional Access |
| Support macOS and Linux users | Use OpenVPN or IKEv2 (not SSTP) |
| Mobile users losing connection on network switch | Use IKEv2 (MOBIKE support) |
| Block users from specific locations | Entra ID + Conditional Access (location-based) |
| Enterprise with existing RADIUS infrastructure | Configure RADIUS authentication |
| Revoke single user's VPN access | Revoke client certificate (cert auth) or disable user (Entra ID) |
| User needs to access VNet and on-premises | Configure split tunneling or forced tunneling |

### Common Gotchas

1. **Entra ID requires tenant admin consent** — must grant permissions for Azure VPN app
2. **Client certificates must chain to uploaded root** — invalid chain = connection fails
3. **RADIUS server must be reachable from VPN Gateway** — typically via VNet peering/VPN
4. **Always On VPN requires device tunnel** — machine certs, separate from user tunnel
5. **Azure VPN Client required for Entra ID** — native Windows VPN doesn't work

---

## Always On VPN Configuration

### Architecture for Always On VPN

```
┌────────────────────────────────────────────────────────────────────────┐
│                    Always On VPN Architecture                           │
├────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│    Windows Device                                                       │
│    ┌─────────────────────────────────────────────────────────────┐     │
│    │                                                              │     │
│    │   ┌─────────────────────┐    ┌─────────────────────┐       │     │
│    │   │   Device Tunnel     │    │    User Tunnel      │       │     │
│    │   │   (IKEv2)           │    │   (IKEv2/SSTP)      │       │     │
│    │   │                     │    │                     │       │     │
│    │   │ • Machine cert auth │    │ • User cert/Entra   │       │     │
│    │   │ • Connects at boot  │    │ • Connects at logon │       │     │
│    │   │ • No user context   │    │ • User-specific     │       │     │
│    │   │ • Domain join/GPO   │    │ • Full access       │       │     │
│    │   │ • Limited access    │    │                     │       │     │
│    │   └─────────────────────┘    └─────────────────────┘       │     │
│    │              │                          │                   │     │
│    └──────────────┼──────────────────────────┼───────────────────┘     │
│                   │                          │                         │
│                   └───────────┬──────────────┘                         │
│                               │                                        │
│                               ▼                                        │
│                    ┌─────────────────────┐                            │
│                    │    VPN Gateway      │                            │
│                    │    (Azure)          │                            │
│                    └─────────────────────┘                            │
│                                                                         │
│   Device Tunnel Requirements:                                          │
│   • Windows 10/11 Enterprise or Education                             │
│   • IKEv2 protocol only                                                │
│   • Machine certificate authentication                                 │
│   • Runs under SYSTEM context                                         │
│                                                                         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Azure Network Adapter (Windows Admin Center)

> **Exam Relevance**: The AZ-700 study guide specifically lists "Azure Network Adapter" under connectivity services. This feature provides a **one-click Point-to-Site VPN** from an on-premises Windows Server to Azure via Windows Admin Center.

### What Is Azure Network Adapter?

Azure Network Adapter is a **Windows Admin Center (WAC) feature** that creates a Point-to-Site VPN connection from an individual on-premises server to an Azure VNet. It automates the entire setup process — VNet gateway creation, root/client certificate generation, and VPN client configuration.

```
┌─────────────────────────────────────┐       ┌──────────────────────────────────────┐
│          ON-PREMISES                │       │              AZURE                   │
│                                     │       │                                      │
│  ┌────────────────────────────┐    │       │    ┌──────────────────────┐          │
│  │     Windows Server         │    │       │    │   VNet Gateway       │          │
│  │   (managed by WAC)         │    │       │    │   (auto-created)     │          │
│  │                            │────│──P2S──│───▶│   VpnGw1 SKU        │          │
│  │   Azure Network Adapter    │    │  VPN  │    │   IKEv2 + SSTP      │          │
│  │   (auto-configured)        │    │       │    └──────────┬───────────┘          │
│  └────────────────────────────┘    │       │               │                      │
│                                     │       │    ┌──────────▼───────────┐          │
│                                     │       │    │   Azure VNet         │          │
│                                     │       │    │   (target resources)  │          │
│                                     │       │    └──────────────────────┘          │
└─────────────────────────────────────┘       └──────────────────────────────────────┘
```

### How It Works (Automated Steps)

1. **WAC registers the server** with Azure (if not already registered)
2. **Creates/selects a VNet** and GatewaySubnet
3. **Deploys a VPN Gateway** (VpnGw1 SKU) — takes ~25-45 minutes
4. **Generates root + client certificates** (self-signed)
5. **Uploads root cert** to the VPN Gateway's P2S configuration
6. **Installs VPN client** on the on-premises server
7. **Establishes P2S VPN tunnel** — IKEv2 + SSTP

### Key Characteristics

| Property | Detail |
|----------|--------|
| **Management Tool** | Windows Admin Center |
| **Authentication** | Azure certificate (auto-generated) |
| **VPN Protocols** | IKEv2 + SSTP |
| **Gateway SKU** | VpnGw1 (auto-deployed) |
| **Target OS** | Windows Server (managed by WAC) |
| **Scope** | Single server → single VNet |
| **Use Case** | Quick server-to-Azure connectivity for admins |
| **Tunnel Type** | Point-to-Site (one server, not entire network) |

### Prerequisites

1. **Windows Admin Center** installed (gateway mode or desktop mode)
2. **Azure subscription** with Contributor access
3. **WAC registered with Azure** (Settings > Azure > Register)
4. **On-premises server** running Windows Server 2012 R2 or later
5. **Target Azure VNet** (or WAC creates one)

### Configuration via WAC

```powershell
# In Windows Admin Center:
# 1. Connect to the on-premises server
# 2. Navigate to: Network > Add Azure Network Adapter (+ Add)
# 3. Sign in to Azure (if not already)
# 4. Select subscription, resource group, VNet
# 5. WAC auto-creates:
#    - GatewaySubnet (/27) if not existing
#    - VPN Gateway (VpnGw1)
#    - Public IP for gateway
#    - P2S configuration with certificate auth
#    - VPN client on server
# 6. Wait ~25-45 minutes for gateway deployment
# 7. Connection is auto-established

# To verify the P2S connection:
Get-VpnConnection -Name "WAC-Created-VPN"
```

### Exam Tips — Network Adapter

> [!warning] Critical Exam Points
> 1. **Single server connectivity** — NOT a site-to-site solution (use S2S VPN for that)
> 2. **Certificate-based auth only** — Automated certificate management via WAC
> 3. **VpnGw1 minimum SKU** — Basic SKU does NOT support P2S with IKEv2
> 4. **WAC is mandatory** — Cannot configure Azure Network Adapter without WAC
> 5. **~25-45 minute deployment** — VPN Gateway provisioning time
> 6. **Difference from Azure Extended Network** — Network Adapter = L3 P2S VPN, Extended Network = L2 subnet stretch

### Comparison: Network Adapter vs Manual P2S vs S2S VPN

| Feature | Azure Network Adapter | Manual P2S VPN | Site-to-Site VPN |
|---------|----------------------|----------------|------------------|
| **Setup Tool** | WAC (one-click) | Portal/CLI/PowerShell | Portal/CLI/PowerShell |
| **Scope** | Single server | Multiple clients | Entire network |
| **Auth Setup** | Automated certs | Manual cert/Entra ID/RADIUS | PSK or certificates |
| **Gateway Deploy** | Automated | Manual | Manual |
| **VPN Client** | Auto-installed | Manual download | On-prem VPN device |
| **Use Case** | Quick admin access | Remote workers | Branch connectivity |
| **AZ-700 Focus** | Know it exists + WAC | Deep configuration | Deep configuration |

---

## Hands-On Lab Suggestions

### Lab: Configure P2S VPN with Entra ID

```powershell
# 1. Create resource group and VNet
New-AzResourceGroup -Name "rg-p2s-lab" -Location "uksouth"

$gwSubnet = New-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -AddressPrefix "10.0.255.0/27"
$workloadSubnet = New-AzVirtualNetworkSubnetConfig -Name "snet-workload" -AddressPrefix "10.0.1.0/24"

$vnet = New-AzVirtualNetwork `
    -Name "vnet-p2s-lab" `
    -ResourceGroupName "rg-p2s-lab" `
    -Location "uksouth" `
    -AddressPrefix "10.0.0.0/16" `
    -Subnet $gwSubnet, $workloadSubnet

# 2. Create public IP for VPN Gateway
$pip = New-AzPublicIpAddress `
    -Name "pip-vpn-gw" `
    -ResourceGroupName "rg-p2s-lab" `
    -Location "uksouth" `
    -AllocationMethod "Static" `
    -Sku "Standard"

# 3. Create VPN Gateway (takes 30-45 minutes)
$gwSubnet = Get-AzVirtualNetworkSubnetConfig -Name "GatewaySubnet" -VirtualNetwork $vnet
$gwIpConfig = New-AzVirtualNetworkGatewayIpConfig -Name "gwIpConfig" -SubnetId $gwSubnet.Id -PublicIpAddressId $pip.Id

$gateway = New-AzVirtualNetworkGateway `
    -Name "vpn-gw-p2s" `
    -ResourceGroupName "rg-p2s-lab" `
    -Location "uksouth" `
    -IpConfigurations $gwIpConfig `
    -GatewayType "Vpn" `
    -VpnType "RouteBased" `
    -GatewaySku "VpnGw1" `
    -VpnGatewayGeneration "Generation1"

# 4. Configure P2S with Entra ID (after gateway is created)
$tenantId = (Get-AzContext).Tenant.Id

Set-AzVirtualNetworkGateway `
    -VirtualNetworkGateway $gateway `
    -VpnClientAddressPool "172.16.0.0/24" `
    -VpnClientProtocol "OpenVPN" `
    -VpnAuthenticationType "AAD" `
    -AadTenantUri "https://login.microsoftonline.com/$tenantId/" `
    -AadIssuerUri "https://sts.windows.net/$tenantId/" `
    -AadAudienceId "41b23e61-6c1e-4545-b367-cd054e0ed4b4"

# 5. Download Azure VPN Client and connect
# - Install Azure VPN Client from Microsoft Store
# - Import configuration from portal
# - Connect and verify IP from address pool (172.16.0.x)
```

---

## Cross-Service Relationships

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      P2S VPN Integration                                     │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │                        P2S VPN Gateway                                  │ │
│  │                                                                         │ │
│  │   Authentication ──────► Microsoft Entra ID (MFA, Conditional Access)  │ │
│  │                  ──────► RADIUS Server (NPS, third-party)              │ │
│  │                  ──────► Azure Key Vault (certificate storage)         │ │
│  │                                                                         │ │
│  │   Connectivity ────────► Virtual Network (resources)                   │ │
│  │               ────────► VNet Peering (peered networks)                 │ │
│  │               ────────► On-premises (via S2S/ER coexistence)           │ │
│  │                                                                         │ │
│  │   Security ───────────► NSGs (traffic filtering)                       │ │
│  │           ───────────► Azure Firewall (forced tunneling)               │ │
│  │           ───────────► Microsoft Defender for Cloud                    │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
│                                                                              │
│  Coexistence:                                                               │
│  • P2S + S2S on same gateway ✅                                            │
│  • P2S + ExpressRoute (separate gateways) ✅                               │
│  • P2S via Virtual WAN hub ✅                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Draw.io Diagrams

Save as `.drawio` file and open in VS Code with Draw.io extension:

```xml
<mxfile host="app.diagrams.net">
  <diagram name="P2S VPN" id="p2s-vpn-detailed">
    <mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1169" pageHeight="827" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        <mxCell id="users" value="Remote Users" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;verticalAlign=top;fontStyle=1" vertex="1" parent="1">
          <mxGeometry x="40" y="80" width="200" height="280" as="geometry" />
        </mxCell>
        <mxCell id="win" value="Windows&#xa;(IKEv2/SSTP/OpenVPN)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
          <mxGeometry x="60" y="120" width="160" height="50" as="geometry" />
        </mxCell>
        <mxCell id="mac" value="macOS/iOS&#xa;(IKEv2/OpenVPN)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="60" y="190" width="160" height="50" as="geometry" />
        </mxCell>
        <mxCell id="linux" value="Linux/Android&#xa;(OpenVPN)" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#fff2cc;strokeColor=#d6b656;" vertex="1" parent="1">
          <mxGeometry x="60" y="260" width="160" height="50" as="geometry" />
        </mxCell>
        <mxCell id="internet" value="Internet" style="ellipse;shape=cloud;whiteSpace=wrap;html=1;fillColor=#f5f5f5;strokeColor=#666666;" vertex="1" parent="1">
          <mxGeometry x="320" y="160" width="120" height="80" as="geometry" />
        </mxCell>
        <mxCell id="gateway" value="VPN Gateway&#xa;(P2S Enabled)&#xa;&#xa;Address Pool:&#xa;172.16.0.0/24" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#dae8fc;strokeColor=#6c8ebf;" vertex="1" parent="1">
          <mxGeometry x="520" y="120" width="140" height="120" as="geometry" />
        </mxCell>
        <mxCell id="auth" value="Authentication" style="rounded=0;whiteSpace=wrap;html=1;fillColor=#ffe6cc;strokeColor=#d79b00;verticalAlign=top;fontStyle=1" vertex="1" parent="1">
          <mxGeometry x="520" y="280" width="140" height="140" as="geometry" />
        </mxCell>
        <mxCell id="entra" value="Entra ID" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;" vertex="1" parent="1">
          <mxGeometry x="540" y="310" width="100" height="30" as="geometry" />
        </mxCell>
        <mxCell id="cert" value="Certificates" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;" vertex="1" parent="1">
          <mxGeometry x="540" y="350" width="100" height="30" as="geometry" />
        </mxCell>
        <mxCell id="radius" value="RADIUS" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#e1d5e7;strokeColor=#9673a6;" vertex="1" parent="1">
          <mxGeometry x="540" y="390" width="100" height="30" as="geometry" />
        </mxCell>
        <mxCell id="vnet" value="Azure VNet&#xa;10.0.0.0/16&#xa;&#xa;VMs, Databases,&#xa;App Services" style="rounded=1;whiteSpace=wrap;html=1;fillColor=#d5e8d4;strokeColor=#82b366;" vertex="1" parent="1">
          <mxGeometry x="740" y="140" width="140" height="100" as="geometry" />
        </mxCell>
        <mxCell id="e1" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="users" target="internet">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e2" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="internet" target="gateway">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e3" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;" edge="1" parent="1" source="gateway" target="vnet">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
        <mxCell id="e4" style="edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;dashed=1;" edge="1" parent="1" source="gateway" target="auth">
          <mxGeometry relative="1" as="geometry" />
        </mxCell>
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
```
