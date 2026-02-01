# VPN IP Architecture Guide

## Visual Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         AWS Site-to-Site VPN                            │
└─────────────────────────────────────────────────────────────────────────┘

                    OUTSIDE IPs                    INSIDE IPs
                   (Public IPs)                  (BGP Peering)

┌──────────────┐                              ┌──────────────┐
│              │  IPsec Tunnel 1              │              │
│  On-Premises │◄────────────────────────────►│     AWS      │
│   Gateway    │                              │   Virtual    │
│              │  IPsec Tunnel 2              │   Private    │
│ 203.0.113.10 │◄────────────────────────────►│   Gateway    │
│              │                              │              │
└──────────────┘                              └──────────────┘
      │                                              │
      │                                              │
      └──────────────────┬───────────────────────────┘
                         │
                         ▼

┌─────────────────────────────────────────────────────────────────────────┐
│                           TUNNEL 1 DETAILS                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Outside IPs (IPsec):                                                   │
│  ┌─────────────────┐                        ┌─────────────────┐        │
│  │  On-Premises    │                        │      AWS        │        │
│  │  203.0.113.10   │◄──────IPsec──────────►│   52.1.2.3      │        │
│  └─────────────────┘                        └─────────────────┘        │
│                                                                         │
│  Inside IPs (BGP):                                                      │
│  ┌─────────────────┐                        ┌─────────────────┐        │
│  │  On-Premises    │                        │      AWS        │        │
│  │ 169.254.11.1/30 │◄───────BGP───────────►│ 169.254.11.2/30 │        │
│  └─────────────────┘                        └─────────────────┘        │
│                                                                         │
│  CIDR Block: 169.254.11.0/30                                            │
│  ├── 169.254.11.0 (Network - not usable)                                │
│  ├── 169.254.11.1 (On-Premises BGP IP) ← You configure this            │
│  ├── 169.254.11.2 (AWS BGP IP) ← AWS uses this                         │
│  └── 169.254.11.3 (Broadcast - not usable)                              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                           TUNNEL 2 DETAILS                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Outside IPs (IPsec):                                                   │
│  ┌─────────────────┐                        ┌─────────────────┐        │
│  │  On-Premises    │                        │      AWS        │        │
│  │  203.0.113.10   │◄──────IPsec──────────►│   52.1.2.4      │        │
│  └─────────────────┘                        └─────────────────┘        │
│                                                                         │
│  Inside IPs (BGP):                                                      │
│  ┌─────────────────┐                        ┌─────────────────┐        │
│  │  On-Premises    │                        │      AWS        │        │
│  │ 169.254.12.1/30 │◄───────BGP───────────►│ 169.254.12.2/30 │        │
│  └─────────────────┘                        └─────────────────┘        │
│                                                                         │
│  CIDR Block: 169.254.12.0/30                                            │
│  ├── 169.254.12.0 (Network - not usable)                                │
│  ├── 169.254.12.1 (On-Premises BGP IP) ← You configure this            │
│  ├── 169.254.12.2 (AWS BGP IP) ← AWS uses this                         │
│  └── 169.254.12.3 (Broadcast - not usable)                              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## IP Address Types

### 1. Outside IPs (Public/External)

**Purpose**: Establish IPsec tunnels over the internet

| Side | IP Address | Description |
|------|------------|-------------|
| On-Premises | 203.0.113.10 | Your public IP (Customer Gateway) |
| AWS Tunnel 1 | 52.1.2.3 | AWS endpoint for tunnel 1 |
| AWS Tunnel 2 | 52.1.2.4 | AWS endpoint for tunnel 2 |

**Used by**: IPsec (StrongSwan)

### 2. Inside IPs (Private/Internal)

**Purpose**: BGP peering inside the encrypted tunnels

| Tunnel | Side | IP Address | CIDR Block |
|--------|------|------------|------------|
| 1 | On-Premises | 169.254.11.1 | 169.254.11.0/30 |
| 1 | AWS | 169.254.11.2 | 169.254.11.0/30 |
| 2 | On-Premises | 169.254.12.1 | 169.254.12.0/30 |
| 2 | AWS | 169.254.12.2 | 169.254.12.0/30 |

**Used by**: BGP (FRR), VTI interfaces

## Configuration Mapping

### VPN Manager Configuration
```json
{
  "aws_peer_ips": ["52.1.2.3", "52.1.2.4"],
  "onprem_peer_ip": "203.0.113.10",
  "aws_inside_ips": ["169.254.11.2", "169.254.12.2"],
  "onprem_inside_ips": ["169.254.11.1", "169.254.12.1"]
}
```

### Generated IPsec Configuration
```
conn Tunnel1
    left=%defaultroute
    right=52.1.2.3          ← From aws_peer_ips[0]
    ...
```

### Generated FRR Configuration
```
router bgp 65000
 neighbor 169.254.11.2 remote-as 64512  ← From aws_inside_ips[0]
 neighbor 169.254.12.2 remote-as 64512  ← From aws_inside_ips[1]
```

### Generated VTI Configuration
```bash
# Tunnel 1
ip tunnel add vti1 mode vti local 0.0.0.0 remote 52.1.2.3 key 1
ip addr add 169.254.11.1/30 dev vti1  ← From onprem_inside_ips[0]

# Tunnel 2
ip tunnel add vti2 mode vti local 0.0.0.0 remote 52.1.2.4 key 2
ip addr add 169.254.12.1/30 dev vti2  ← From onprem_inside_ips[1]
```

## Traffic Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         TRAFFIC FLOW EXAMPLE                            │
└─────────────────────────────────────────────────────────────────────────┘

1. Application Traffic (e.g., ping 10.0.1.5)
   │
   ├─► Routing decision: Use VPN
   │
   ├─► Packet enters VTI interface (vti1)
   │   └─► Source: 169.254.11.1 (your BGP IP)
   │       Destination: 10.0.1.5 (AWS network)
   │
   ├─► IPsec encrypts packet
   │   └─► Outer IP: 203.0.113.10 → 52.1.2.3
   │       Inner IP: 169.254.11.1 → 10.0.1.5
   │
   ├─► Packet sent over internet
   │
   ├─► AWS receives and decrypts
   │
   └─► Packet delivered to 10.0.1.5

2. BGP Updates
   │
   ├─► BGP session: 169.254.11.1 ↔ 169.254.11.2
   │   └─► Runs inside IPsec tunnel
   │
   ├─► AWS advertises routes (e.g., 10.0.0.0/16)
   │
   └─► On-premises receives and installs routes
```

## Understanding /30 CIDR Blocks

A /30 CIDR block provides exactly 4 IP addresses:

```
Example: 169.254.11.0/30

Binary subnet mask: 11111111.11111111.11111111.11111100
                    └────────────────────────────┘└──┘
                              Network              Host
                             (30 bits)           (2 bits)

2 bits for host = 2² = 4 addresses

┌──────────────┬─────────────────┬──────────────────────────┐
│   Address    │      Type       │         Usage            │
├──────────────┼─────────────────┼──────────────────────────┤
│ 169.254.11.0 │ Network address │ Not usable (reserved)    │
│ 169.254.11.1 │ Host address    │ On-premises BGP IP       │
│ 169.254.11.2 │ Host address    │ AWS BGP IP               │
│ 169.254.11.3 │ Broadcast addr  │ Not usable (reserved)    │
└──────────────┴─────────────────┴──────────────────────────┘

Result: 2 usable IPs (perfect for point-to-point link)
```

## Common Scenarios

### Scenario 1: Standard AWS Configuration
```
AWS assigns:
- Tunnel 1: 169.254.11.0/30
- Tunnel 2: 169.254.12.0/30

Your configuration:
{
  "aws_inside_ips": ["169.254.11.2", "169.254.12.2"],
  "onprem_inside_ips": ["169.254.11.1", "169.254.12.1"]
}
```

### Scenario 2: Custom Inside CIDR
```
AWS assigns (custom):
- Tunnel 1: 169.254.100.0/30
- Tunnel 2: 169.254.101.0/30

Your configuration:
{
  "aws_inside_ips": ["169.254.100.2", "169.254.101.2"],
  "onprem_inside_ips": ["169.254.100.1", "169.254.101.1"]
}
```

### Scenario 3: Single Tunnel
```
AWS assigns:
- Tunnel 1: 169.254.11.0/30

Your configuration:
{
  "tunnel_count": 1,
  "aws_inside_ips": ["169.254.11.2"],
  "onprem_inside_ips": ["169.254.11.1"]
}
```

## Verification Commands

### Check VTI Interfaces
```bash
ip addr show vti1
# Should show: 169.254.11.1/30

ip addr show vti2
# Should show: 169.254.12.1/30
```

### Check BGP Neighbors
```bash
sudo vtysh -c "show bgp summary"
# Should show:
# Neighbor        V    AS MsgRcvd MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcd
# 169.254.11.2    4 64512     123     456        0    0    0 01:23:45            5
# 169.254.12.2    4 64512     124     457        0    0    0 01:23:46            5
```

### Check IPsec Tunnels
```bash
sudo ipsec status
# Should show:
# Tunnel1[1]: ESTABLISHED 1 hour ago, 203.0.113.10[%any]...52.1.2.3[52.1.2.3]
# Tunnel2[2]: ESTABLISHED 1 hour ago, 203.0.113.10[%any]...52.1.2.4[52.1.2.4]
```

### Test Connectivity
```bash
# Ping AWS inside IP
ping -c 3 169.254.11.2
ping -c 3 169.254.12.2

# Ping AWS network
ping -c 3 10.0.1.5
```

## Troubleshooting

### BGP Not Establishing
**Symptom**: BGP neighbors stuck in "Active" or "Connect" state

**Check**:
1. Are inside IPs correct?
   ```bash
   ip addr show vti1
   # Should match onprem_inside_ips[0]
   ```

2. Can you ping AWS inside IP?
   ```bash
   ping -c 3 169.254.11.2
   ```

3. Is IPsec tunnel up?
   ```bash
   sudo ipsec status
   ```

**Fix**: Verify inside IPs in `/etc/vpn/config.json` match AWS configuration

### VTI Interface Down
**Symptom**: VTI interface shows "DOWN"

**Check**:
```bash
ip link show vti1
```

**Fix**:
```bash
sudo ip link set vti1 up
# Or regenerate configuration
sudo /etc/vpn/setup_vti.sh
```

### Wrong Inside IPs Configured
**Symptom**: BGP never establishes, ping to AWS inside IP fails

**Fix**:
1. Check AWS Console for correct inside IPs
2. Update `/etc/vpn/config.json`
3. Regenerate configurations:
   ```bash
   sudo vpn_manager.py --setup --config /etc/vpn/config.json
   ```
4. Restart services:
   ```bash
   sudo systemctl restart strongswan frr
   ```

## Quick Reference

| What | Where to Find | Example |
|------|---------------|---------|
| AWS Outside IPs | VPC → VPN Connections → Tunnel Details → Outside IP | 52.1.2.3 |
| On-Prem Outside IP | Your public IP / Customer Gateway IP | 203.0.113.10 |
| AWS Inside IPs | VPC → VPN Connections → Tunnel Details → Inside IP CIDR (2nd IP) | 169.254.11.2 |
| On-Prem Inside IPs | VPC → VPN Connections → Tunnel Details → Inside IP CIDR (1st IP) | 169.254.11.1 |

---

**Remember**: 
- Outside IPs = Public IPs for IPsec
- Inside IPs = Private IPs for BGP
- Always use the actual values from AWS Console, not defaults!

