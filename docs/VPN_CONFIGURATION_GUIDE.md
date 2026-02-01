# VPN Manager Configuration Guide

## Required Information

When configuring VPN Manager, you'll need to provide the following information. This guide explains what each field means and where to find it in the AWS Console.

### 1. AWS VPN Connection ID
**Example:** `vpn-0123456789abcdef0`

**Where to find:**
- AWS Console → VPC → Site-to-Site VPN Connections
- Look for the "VPN ID" column

---

### 2. Outside IP Addresses (Public IPs)

These are the public IP addresses used for the IPsec tunnels.

#### AWS Peer Outside IPs
**Example:** `52.1.2.3`, `52.1.2.4`

**Where to find:**
- AWS Console → VPC → Site-to-Site VPN Connections
- Select your VPN connection
- Go to "Tunnel Details" tab
- Look for "Outside IP address" for each tunnel

**Note:** AWS provides 2 tunnels for redundancy, so you'll have 2 AWS outside IPs.

#### On-Premises Outside IP
**Example:** `203.0.113.10`

**What it is:**
- Your customer gateway's public IP address
- The IP address AWS will connect to

**Where to find:**
- This is YOUR public IP address
- The IP you configured when creating the Customer Gateway in AWS
- AWS Console → VPC → Customer Gateways → IP Address

---

### 3. Inside IP Addresses (BGP Peering IPs)

These are the private IP addresses (169.254.x.x) used for BGP peering inside the IPsec tunnels.

#### AWS Inside IPs
**Example:** `169.254.11.2`, `169.254.12.2`

**Where to find:**
- AWS Console → VPC → Site-to-Site VPN Connections
- Select your VPN connection
- Go to "Tunnel Details" tab
- Look for "Inside IP CIDR" for each tunnel
- The AWS inside IP is the **second** IP in the /30 CIDR
  - Example: If CIDR is `169.254.11.0/30`, AWS IP is `169.254.11.2`

#### On-Premises Inside IPs
**Example:** `169.254.11.1`, `169.254.12.1`

**Where to find:**
- Same location as AWS inside IPs
- The on-premises inside IP is the **first** IP in the /30 CIDR
  - Example: If CIDR is `169.254.11.0/30`, on-prem IP is `169.254.11.1`

**Understanding /30 CIDR:**
```
CIDR: 169.254.11.0/30
├── 169.254.11.0  (Network address - not usable)
├── 169.254.11.1  (On-premises inside IP) ← You use this
├── 169.254.11.2  (AWS inside IP) ← AWS uses this
└── 169.254.11.3  (Broadcast address - not usable)
```

---

### 4. BGP Configuration

#### AWS ASN
**Example:** `64512`
**Default:** `64512`

**Where to find:**
- AWS Console → VPC → Virtual Private Gateways
- Select your VGW
- Look for "ASN" field

**Note:** AWS default ASN is 64512, but you can use a custom ASN.

#### On-Premises ASN
**Example:** `65000`
**Default:** `65000`

**What it is:**
- Your BGP Autonomous System Number
- Must be different from AWS ASN
- Can be any private ASN (64512-65534 or 4200000000-4294967294)

---

### 5. Pre-Shared Keys (PSK)

**Example:** `xyzabc123456789...` (long random string)

**Where to find:**
- AWS Console → VPC → Site-to-Site VPN Connections
- Select your VPN connection
- Click "Download Configuration"
- The PSKs are in the downloaded configuration file
- Look for "Pre-Shared Key" for each tunnel

**Security Note:** Keep these secret! They're like passwords for your VPN tunnels.

---

### 6. Remote Networks to Monitor

**Example:** `10.0.0.0/16`, `172.16.0.0/12`

**What it is:**
- Networks on the AWS side that you want to test connectivity to
- VPN Manager will ping these networks to verify connectivity

**Where to find:**
- These are your AWS VPC CIDR blocks
- AWS Console → VPC → Your VPCs → IPv4 CIDR

---

## Complete Configuration Example

Here's what a complete configuration looks like:

```json
{
  "vpn_id": "vpn-0123456789abcdef0",
  "tunnel_count": 2,
  
  "aws_peer_ips": [
    "52.1.2.3",      // Tunnel 1 - AWS outside IP
    "52.1.2.4"       // Tunnel 2 - AWS outside IP
  ],
  "onprem_peer_ip": "203.0.113.10",  // Your public IP
  
  "aws_inside_ips": [
    "169.254.11.2",  // Tunnel 1 - AWS BGP IP
    "169.254.12.2"   // Tunnel 2 - AWS BGP IP
  ],
  "onprem_inside_ips": [
    "169.254.11.1",  // Tunnel 1 - Your BGP IP
    "169.254.12.1"   // Tunnel 2 - Your BGP IP
  ],
  
  "aws_asn": 64512,
  "onprem_asn": 65000,
  
  "remote_networks": [
    "10.0.0.0/16",
    "172.16.0.0/12"
  ],
  
  "psk": {
    "tunnel1": "your-pre-shared-key-for-tunnel-1",
    "tunnel2": "your-pre-shared-key-for-tunnel-2"
  }
}
```

---

## Quick Reference: AWS Console Navigation

### Finding VPN Connection Details
1. AWS Console → VPC
2. Left sidebar → Site-to-Site VPN Connections
3. Select your VPN connection
4. Tabs available:
   - **Details**: VPN ID, state, type
   - **Tunnel Details**: Outside IPs, Inside IPs, status
   - **Static Routes**: Configured routes
   - **Tags**: Resource tags

### Downloading Configuration
1. Select your VPN connection
2. Click "Download Configuration" button
3. Choose your device vendor (or Generic)
4. The downloaded file contains:
   - Outside IPs
   - Inside IPs
   - Pre-shared keys
   - BGP ASNs
   - Recommended IPsec settings

---

## Interactive Setup

When you run the installer or `vpn_manager.py --setup --interactive`, you'll be prompted for each value:

```
📝 Please provide VPN configuration:

AWS VPN Connection ID (e.g., vpn-xxxxx): vpn-0123456789abcdef0

📍 Outside IP Addresses (Public IPs):
AWS peer outside IP #1: 52.1.2.3
AWS peer outside IP #2 (press Enter to skip): 52.1.2.4
On-premises outside IP: 203.0.113.10

📍 Inside IP Addresses (BGP Peering - 169.254.x.x):
These are the /30 CIDR blocks for BGP peering inside the tunnels

Tunnel 1:
  AWS inside IP [169.254.11.2]: 169.254.11.2
  On-premises inside IP [169.254.11.1]: 169.254.11.1

Tunnel 2:
  AWS inside IP [169.254.12.2]: 169.254.12.2
  On-premises inside IP [169.254.12.1]: 169.254.12.1

📡 BGP Configuration:
AWS ASN [64512]: 64512
On-premises ASN [65000]: 65000

🔐 Pre-Shared Keys:
PSK for Tunnel 1: **********************
PSK for Tunnel 2: **********************

🌐 Remote Networks to Monitor:
Enter remote networks (comma-separated CIDRs, e.g., 10.0.0.0/16,172.16.0.0/12)
Remote networks: 10.0.0.0/16,172.16.0.0/12
```

---

## Troubleshooting

### "I don't know my inside IPs"
- Download the VPN configuration from AWS Console
- Look for "Inside IP CIDR" in the Tunnel Details
- First IP (.1) = Your side
- Second IP (.2) = AWS side

### "I only have one tunnel"
- That's fine! Just press Enter when asked for the second tunnel
- VPN Manager will configure for single tunnel mode

### "I don't have the PSKs"
- Download the VPN configuration from AWS Console
- The PSKs are in the downloaded file
- If you lost them, you may need to recreate the VPN connection

### "What if I use static routing instead of BGP?"
- VPN Manager is designed for BGP-based VPNs
- For static routing, you'll need to modify the configuration

---

## Security Best Practices

1. **Protect configuration files:**
   ```bash
   sudo chmod 600 /etc/vpn/config.json
   sudo chmod 600 /etc/vpn/ipsec.secrets
   ```

2. **Use strong PSKs:**
   - Minimum 32 characters
   - Mix of letters, numbers, symbols
   - Don't reuse PSKs

3. **Rotate credentials:**
   - Change PSKs periodically
   - Update configuration after rotation

4. **Limit access:**
   - Only root should access /etc/vpn/
   - Use sudo for all VPN Manager commands

---

## Need Help?

If you're stuck, check:
1. AWS VPN documentation
2. Your VPN connection's "Download Configuration" file
3. VPN Manager logs: `sudo journalctl -u vpn-manager -f`
4. GitHub issues

