# AWS Site-to-Site VPN Manager

> Automated VPN configuration, monitoring, and remediation for AWS Site-to-Site VPN connections.

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)
[![Platform](https://img.shields.io/badge/platform-linux-lightgrey.svg)](https://www.linux.org/)

## Overview

VPN Manager is a production-ready tool that automates the complete lifecycle of AWS Site-to-Site VPN connections:

- **Configure**: Auto-generate IPsec, FRR BGP, and VTI configurations
- **Monitor**: Continuous health checks every 5 minutes
- **Test**: Automated connectivity testing to remote networks
- **Fix**: Automatically remediate common issues
- **Alert**: Email notifications for issues and status changes

## Features

### 🔧 Configuration Management
- Generate production-ready VPN configurations
- Support for multiple tunnels
- AWS best practices built-in
- Secure PSK management

### 🏥 Health Monitoring
- IPsec tunnel status
- BGP session monitoring
- VTI interface checks
- Routing table validation
- Log analysis for issues

### 🔗 Connectivity Testing
- Automated ping tests to remote networks
- Latency measurement
- Packet loss detection
- Triggered on tunnel up events

### 🛠️ Auto-Remediation
- Restart services automatically
- Bring up down interfaces
- Recreate missing VTI interfaces
- Fix routing issues

### 📧 Email Notifications
- Critical issue alerts
- Health status reports
- Connectivity test results
- Remediation actions

### 🚀 Systemd Integration
- Run as background service
- Automatic startup on boot
- Configurable monitoring intervals

## Quick Start

### One-Command Installation

```bash
# Clone repository
git clone https://github.com/your-org/vpn-manager.git
cd vpn-manager

# Install everything
sudo bash install_vpn_manager.sh
```

The installer will:
1. ✅ Check prerequisites
2. ✅ Install VPN Manager
3. ✅ Setup systemd service
4. ✅ Guide you through VPN configuration
5. ✅ Guide you through email setup
6. ✅ Start monitoring service

**Total time: 2-3 minutes**

### What You'll Be Asked

#### VPN Configuration (Optional)
- AWS VPN Connection ID
- AWS peer outside IPs (public IPs)
- On-premises outside IP (public IP)
- AWS inside IPs (BGP peering IPs - 169.254.x.x)
- On-premises inside IPs (BGP peering IPs - 169.254.x.x)
- ASN numbers (AWS and on-premises)
- Remote networks to monitor
- Pre-shared keys

#### Email Configuration (Optional)
- SMTP server settings
- Email credentials
- Notification recipients

You can skip any step and configure later!

## Requirements

### System Requirements
- **OS**: Linux (Ubuntu 20.04+, Amazon Linux 2, CentOS 7+, etc.)
- **Python**: 3.8 or higher
- **Init System**: systemd

### VPN Requirements
- **StrongSwan**: For IPsec tunnels
- **FRR**: For BGP routing

Install with:
```bash
sudo apt-get install -y strongswan frr  # Ubuntu/Debian
sudo yum install -y strongswan frr      # CentOS/RHEL
```

## Usage

### Check VPN Status
```bash
sudo vpn_manager.py --status
```

### Run Health Check
```bash
sudo vpn_manager.py --monitor
```

### Test Connectivity
```bash
sudo vpn_manager.py --test-connectivity
```

### View Service Logs
```bash
sudo journalctl -u vpn-manager -f
```

### Service Management
```bash
# Start service
sudo systemctl start vpn-manager

# Stop service
sudo systemctl stop vpn-manager

# Restart service
sudo systemctl restart vpn-manager

# Check status
sudo systemctl status vpn-manager
```

## Configuration

### VPN Configuration
Location: `/etc/vpn/config.json`

```json
{
  "vpn_id": "vpn-0123456789abcdef0",
  "tunnel_count": 2,
  "aws_peer_ips": ["52.1.2.3", "52.1.2.4"],
  "onprem_peer_ip": "10.0.1.1",
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

**Configuration Fields:**
- `aws_peer_ips`: AWS outside/public IPs for IPsec tunnels
- `onprem_peer_ip`: On-premises outside/public IP
- `aws_inside_ips`: AWS BGP inside IPs (169.254.x.x) for each tunnel
- `onprem_inside_ips`: On-premises BGP inside IPs (169.254.x.x) for each tunnel
- `aws_asn`: AWS BGP ASN
- `onprem_asn`: On-premises BGP ASN
- `remote_networks`: Networks to test connectivity
- `psk`: Pre-shared keys for each tunnel

### Email Configuration
Location: `/etc/vpn/email_config.json`

```json
{
  "enabled": true,
  "smtp_server": "smtp.gmail.com",
  "smtp_port": 587,
  "use_tls": true,
  "username": "your-email@gmail.com",
  "password": "your-app-password",
  "from_addr": "vpn-manager@your-domain.com",
  "to_addrs": ["admin@your-domain.com"],
  "subject_prefix": "[VPN Manager]"
}
```

## Documentation

- **[Installation Guide](docs/INSTALL.md)** - Detailed installation instructions
- **[Quick Start Guide](docs/VPN_MANAGER_QUICK_START.md)** - Get started in 5 minutes
- **[Complete Documentation](docs/VPN_MANAGER_README.md)** - Full feature documentation
- **[Summary](docs/VPN_MANAGER_SUMMARY.md)** - Feature overview and architecture

## Architecture

```
VPN Manager
├── Configuration Generation
│   ├── IPsec (StrongSwan)
│   ├── BGP (FRR)
│   └── VTI Interfaces
│
├── Health Monitoring (Every 5 min)
│   ├── IPsec Tunnels
│   ├── BGP Sessions
│   ├── VTI Interfaces
│   ├── Routing Table
│   └── Log Analysis
│
├── Connectivity Testing
│   ├── Ping Tests
│   ├── Latency Measurement
│   └── Packet Loss Detection
│
├── Auto-Remediation
│   ├── Service Restarts
│   ├── Interface Management
│   └── Configuration Fixes
│
└── Notifications
    ├── Email Alerts
    ├── Health Reports
    └── Status Updates
```

## How It Works

### Monitoring Cycle (Every 5 Minutes)
1. Check IPsec tunnel status
2. Check BGP session status
3. Check VTI interface status
4. Check routing table
5. Analyze recent logs
6. Test connectivity to remote networks
7. If issues found:
   - Attempt auto-remediation
   - Re-check health
   - Send email notification
8. Save health report

### Auto-Remediation
| Issue | Detection | Auto-Fix |
|-------|-----------|----------|
| Tunnel Down | `ipsec status` | Restart StrongSwan |
| BGP Down | `show bgp summary` | Restart FRR |
| VTI Down | `ip link show` | Bring up interface |
| VTI Missing | `ip link show` | Recreate interface |
| No Routes | `ip route show` | Restart BGP |

## Examples

### Example 1: Fresh Installation
```bash
# Install
sudo bash install_vpn_manager.sh

# Configure during installation (interactive)
# Service starts automatically

# Check status
sudo vpn_manager.py --status
```

### Example 2: Configure Later
```bash
# Install (skip configuration)
sudo bash install_vpn_manager.sh

# Configure VPN later
sudo vpn_manager.py --setup --interactive

# Start service
sudo systemctl start vpn-manager
```

### Example 3: Manual Monitoring
```bash
# One-time health check
sudo vpn_manager.py --monitor

# Test connectivity
sudo vpn_manager.py --test-connectivity

# View status
sudo vpn_manager.py --status
```

## Troubleshooting

### Service Won't Start
```bash
# Check service status
sudo systemctl status vpn-manager

# View logs
sudo journalctl -u vpn-manager -n 50

# Test manually
sudo vpn_manager.py --monitor
```

### Email Not Sending
```bash
# Check email configuration
sudo cat /etc/vpn/email_config.json

# Test SMTP connection
telnet smtp.gmail.com 587
```

### VPN Issues
```bash
# Check IPsec
sudo ipsec status

# Check BGP
sudo vtysh -c "show bgp summary"

# Check VTI
ip link show | grep vti

# Check routes
ip route show
```

## Security

### File Permissions
- Configuration files: **600** (root only)
- Executable: **755** (executable by all)
- Log directory: **755** (accessible by all)

### Best Practices
- Use strong, unique PSKs (32+ characters)
- Use app-specific passwords for email
- Rotate credentials regularly
- Restrict access to `/etc/vpn/` directory
- Monitor logs for suspicious activity

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Support

### Getting Help
1. Check the [documentation](docs/)
2. Review [troubleshooting guide](docs/VPN_MANAGER_README.md#troubleshooting)
3. Check system logs: `sudo journalctl -u vpn-manager -f`
4. Open an issue on GitHub

### Reporting Issues
When reporting issues, please include:
- OS and version
- Python version
- VPN Manager version
- Error messages
- Relevant logs

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- AWS for Site-to-Site VPN service
- StrongSwan project for IPsec implementation
- FRRouting project for BGP routing

## Roadmap

### Planned Features
- [ ] Web dashboard
- [ ] Metrics API
- [ ] Advanced analytics
- [ ] Custom remediation scripts
- [ ] Multi-VPN support
- [ ] Slack/Teams integration

### Version History
- **1.0.0** (2026-01-31): Initial release
  - Configuration generation
  - Health monitoring
  - Auto-remediation
  - Email notifications
  - Systemd integration

---

**Ready to get started?**

```bash
git clone https://github.com/your-org/vpn-manager.git
cd vpn-manager
sudo bash install_vpn_manager.sh
```

**Questions?** See the [documentation](docs/) or open an issue.

🚀 **VPN Manager - Set it and forget it!**
