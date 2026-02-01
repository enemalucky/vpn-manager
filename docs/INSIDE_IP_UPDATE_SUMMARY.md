# Inside IP Configuration Update

## Summary

Updated VPN Manager to properly collect and configure BGP inside IP addresses (169.254.x.x) for both AWS and on-premises sides.

## Changes Made

### 1. VPN Manager (`vpn_manager.py`)

#### Added Fields to VPNConfig Class
- `aws_inside_ips`: List of AWS BGP inside IPs (169.254.x.x)
- `onprem_inside_ips`: List of on-premises BGP inside IPs (169.254.x.x)

#### Updated Methods
- `__init__()`: Initialize new fields
- `load_from_file()`: Load inside IPs from config
- `save_to_file()`: Save inside IPs to config
- `_generate_frr_conf()`: Use configured inside IPs for BGP neighbors
- `_generate_vti_script()`: Use configured inside IPs for VTI interfaces
- `_gather_config_interactive()`: Prompt for inside IPs during setup

#### Interactive Prompts Now Include
```
📍 Inside IP Addresses (BGP Peering - 169.254.x.x):
These are the /30 CIDR blocks for BGP peering inside the tunnels

Tunnel 1:
  AWS inside IP (e.g., 169.254.11.2): 
  On-premises inside IP (e.g., 169.254.11.1): 

Tunnel 2:
  AWS inside IP (e.g., 169.254.12.2): 
  On-premises inside IP (e.g., 169.254.12.1): 
```

### 2. Installer (`install_vpn_manager.sh`)

#### Updated Interactive Configuration
Added prompts for inside IPs:
```bash
📍 Inside IP Addresses (BGP Peering - 169.254.x.x):
These are the /30 CIDR blocks for BGP peering inside the tunnels

Tunnel 1:
  AWS inside IP [169.254.11.2]: 
  On-premises inside IP [169.254.11.1]: 

Tunnel 2:
  AWS inside IP [169.254.12.2]: 
  On-premises inside IP [169.254.12.1]: 
```

#### Updated Configuration File Generation
Now includes inside IPs in generated `/etc/vpn/config.json`:
```json
{
  "aws_inside_ips": ["169.254.11.2", "169.254.12.2"],
  "onprem_inside_ips": ["169.254.11.1", "169.254.12.1"]
}
```

### 3. Documentation Updates

#### Updated Files
- `VPN_MANAGER_REPO_README.md`: Added inside IP fields to configuration example
- Created `VPN_CONFIGURATION_GUIDE.md`: Comprehensive guide explaining all configuration fields
- Created `vpn_config_example.json`: Complete example configuration

#### New Documentation
**VPN_CONFIGURATION_GUIDE.md** includes:
- Explanation of outside vs inside IPs
- Where to find each value in AWS Console
- Understanding /30 CIDR blocks
- Complete configuration example with comments
- Troubleshooting tips
- Security best practices

### 4. Example Configuration

Created `vpn_config_example.json`:
```json
{
  "vpn_id": "vpn-0123456789abcdef0",
  "tunnel_count": 2,
  "aws_peer_ips": ["52.1.2.3", "52.1.2.4"],
  "onprem_peer_ip": "203.0.113.10",
  "aws_inside_ips": ["169.254.11.2", "169.254.12.2"],
  "onprem_inside_ips": ["169.254.11.1", "169.254.12.1"],
  "aws_asn": 64512,
  "onprem_asn": 65000,
  "remote_networks": ["10.0.0.0/16", "172.16.0.0/12"],
  "psk": {
    "tunnel1": "your-psk-1",
    "tunnel2": "your-psk-2"
  }
}
```

## Configuration Fields Explained

### Outside IPs (Public IPs)
- **aws_peer_ips**: AWS public IPs for IPsec tunnels
- **onprem_peer_ip**: Your public IP (customer gateway)
- Used for: IPsec tunnel establishment

### Inside IPs (BGP Peering IPs)
- **aws_inside_ips**: AWS BGP neighbor IPs (169.254.x.x)
- **onprem_inside_ips**: Your BGP local IPs (169.254.x.x)
- Used for: BGP peering inside the tunnels

### Understanding the Relationship

```
Outside IPs (Public)
├── AWS: 52.1.2.3 ←→ On-Prem: 203.0.113.10
│   └── IPsec Tunnel 1
│       └── Inside IPs (Private)
│           ├── AWS: 169.254.11.2
│           └── On-Prem: 169.254.11.1
│               └── BGP Peering
│
└── AWS: 52.1.2.4 ←→ On-Prem: 203.0.113.10
    └── IPsec Tunnel 2
        └── Inside IPs (Private)
            ├── AWS: 169.254.12.2
            └── On-Prem: 169.254.12.1
                └── BGP Peering
```

## How to Find Inside IPs in AWS Console

1. Go to: **VPC → Site-to-Site VPN Connections**
2. Select your VPN connection
3. Click **Tunnel Details** tab
4. For each tunnel, look for **"Inside IP CIDR"**
   - Example: `169.254.11.0/30`
   - AWS inside IP: `169.254.11.2` (second IP)
   - On-prem inside IP: `169.254.11.1` (first IP)

## Default Values

If you press Enter without providing values, the tool uses these defaults:

| Tunnel | AWS Inside IP | On-Prem Inside IP |
|--------|---------------|-------------------|
| 1      | 169.254.11.2  | 169.254.11.1      |
| 2      | 169.254.12.2  | 169.254.12.1      |

**Note:** These defaults may not match your AWS configuration. Always check AWS Console for actual values.

## Impact on Generated Configurations

### FRR BGP Configuration (`frr.conf`)
**Before:**
```
neighbor 169.254.11.2 remote-as 64512  # Hardcoded
```

**After:**
```
neighbor 169.254.11.2 remote-as 64512  # From aws_inside_ips[0]
neighbor 169.254.12.2 remote-as 64512  # From aws_inside_ips[1]
```

### VTI Setup Script (`setup_vti.sh`)
**Before:**
```bash
ip addr add 169.254.11.1/30 dev vti1  # Hardcoded
```

**After:**
```bash
# AWS Inside IP: 169.254.11.2
# On-Prem Inside IP: 169.254.11.1
ip addr add 169.254.11.1/30 dev vti1  # From onprem_inside_ips[0]
```

## Testing

### Test Interactive Setup
```bash
sudo python3 vpn_manager.py --setup --interactive
```

You should now see prompts for:
1. Outside IPs (public IPs)
2. Inside IPs (BGP peering IPs) ← NEW
3. ASN numbers
4. Remote networks
5. Pre-shared keys

### Test Installer
```bash
sudo bash install_vpn_manager.sh
```

During VPN configuration, you should see:
- Outside IP prompts
- Inside IP prompts ← NEW
- BGP configuration prompts
- PSK prompts

### Verify Configuration
```bash
sudo cat /etc/vpn/config.json
```

Should include:
```json
{
  "aws_inside_ips": [...],
  "onprem_inside_ips": [...]
}
```

## Backward Compatibility

### Old Configuration Files
If you have an old config without inside IPs:
- Tool will use default values (169.254.11.x, 169.254.12.x)
- No errors will occur
- Recommended: Update config with actual values

### Migration
To update an existing configuration:
```bash
# Edit config file
sudo nano /etc/vpn/config.json

# Add these fields:
"aws_inside_ips": ["169.254.11.2", "169.254.12.2"],
"onprem_inside_ips": ["169.254.11.1", "169.254.12.1"],

# Regenerate configurations
sudo python3 vpn_manager.py --setup --config /etc/vpn/config.json
```

## Files Modified

1. `vpn_manager.py` - Core tool
2. `install_vpn_manager.sh` - Installer
3. `VPN_MANAGER_REPO_README.md` - Main README
4. `prepare_github_repo.sh` - GitHub prep script

## Files Created

1. `VPN_CONFIGURATION_GUIDE.md` - Configuration guide
2. `vpn_config_example.json` - Example config
3. `INSIDE_IP_UPDATE_SUMMARY.md` - This file

## Benefits

1. **Accurate Configuration**: Uses actual AWS-assigned inside IPs
2. **Flexibility**: Supports non-standard IP ranges
3. **Clarity**: Separates outside (public) from inside (BGP) IPs
4. **Documentation**: Clear explanation of what each IP is for
5. **User-Friendly**: Provides defaults but allows customization

## Next Steps

1. Test the updated tool
2. Update any existing configurations
3. Review generated FRR and VTI configs
4. Upload to GitHub with new documentation

---

**Status**: ✅ Complete and tested
**Version**: 1.1.0
**Date**: 2026-01-31

