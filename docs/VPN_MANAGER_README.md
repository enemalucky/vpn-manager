# AWS Site-to-Site VPN Manager

## Overview

VPN Manager is a focused tool for AWS Site-to-Site VPN configuration, monitoring, and automated remediation. It provides:

- **Configuration Generation**: Auto-generate IPsec, FRR, and VTI configurations
- **Automated Connectivity Testing**: Ping remote devices when VPN is up
- **Continuous Health Monitoring**: Monitor tunnels, BGP, VTI, and routing
- **Automated Remediation**: Automatically fix common issues
- **Email Notifications**: Alert on issues and status changes
- **Systemd Integration**: Run as a background service

## Features

### 1. Configuration Management
- Generate production-ready VPN configurations
- Support for multiple tunnels
- AWS best practices built-in
- Easy PSK management
- **Automatic policy routing configuration for AWS EC2**

### 2. Health Monitoring
- IPsec tunnel status
- BGP session monitoring
- VTI interface checks
- Routing table validation
- Log analysis for issues

### 3. Connectivity Testing
- Automated ping tests to remote networks
- Latency measurement
- Packet loss detection
- Triggered on tunnel up events

### 4. Auto-Remediation
- Restart services automatically
- Bring up down interfaces
- Recreate missing VTI interfaces
- Fix common configuration issues

### 5. Email Notifications
- Alert on critical issues
- Health status reports
- Connectivity test results
- Remediation actions taken

### 6. AWS EC2 Compatibility
- **Automatic policy routing rules** to handle AWS EC2 table 220
- Ensures BGP traffic uses VTI interfaces
- Persistent across reboots
- No manual configuration needed

## Installation

### Prerequisites

```bash
# Install required packages
sudo apt-get update
sudo apt-get install -y strongswan frr python3 python3-pip

# Install Python dependencies (if any)
# pip3 install -r requirements.txt
```

### Install VPN Manager

```bash
# Copy script to system location
sudo cp vpn_manager.py /usr/local/bin/
sudo chmod +x /usr/local/bin/vpn_manager.py

# Create configuration directory
sudo mkdir -p /etc/vpn
sudo mkdir -p /var/log/vpn

# Copy systemd service
sudo cp vpn-manager.service /etc/systemd/system/
sudo systemctl daemon-reload
```

## Quick Start

### 1. Initial Setup

```bash
# Interactive setup
sudo vpn_manager.py --setup --interactive
```

This will:
1. Gather VPN configuration (IPs, ASNs, PSKs)
2. Generate configuration files
3. Setup VTI interfaces
4. Restart services
5. Save configuration

### 2. Configure Email Notifications

```bash
# Copy example config
sudo cp email_config.json.example /etc/vpn/email_config.json

# Edit with your SMTP settings
sudo nano /etc/vpn/email_config.json
```

Example configuration:
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

### 3. Run Health Check

```bash
# One-time health check with auto-fix
sudo vpn_manager.py --monitor --auto-fix --notify
```

### 4. Enable Continuous Monitoring

```bash
# Enable and start service
sudo systemctl enable vpn-manager
sudo systemctl start vpn-manager

# Check status
sudo systemctl status vpn-manager

# View logs
sudo journalctl -u vpn-manager -f
```

## Usage

### Commands

#### Setup
```bash
# Interactive setup
sudo vpn_manager.py --setup --interactive

# Non-interactive (requires config file)
sudo vpn_manager.py --setup --config /etc/vpn/config.json
```

#### Monitoring
```bash
# One-time health check
sudo vpn_manager.py --monitor

# With auto-fix enabled
sudo vpn_manager.py --monitor --auto-fix

# With email notifications
sudo vpn_manager.py --monitor --auto-fix --notify

# Without auto-fix
sudo vpn_manager.py --monitor --no-auto-fix
```

#### Connectivity Testing
```bash
# Test connectivity to remote networks
vpn_manager.py --test-connectivity
```

#### Status
```bash
# Show current VPN status
vpn_manager.py --status
```

#### Daemon Mode
```bash
# Run continuously (5-minute intervals)
sudo vpn_manager.py --daemon --interval 300

# Custom interval (10 minutes)
sudo vpn_manager.py --daemon --interval 600
```

### Configuration File

Location: `/etc/vpn/config.json`

```json
{
  "vpn_id": "vpn-0123456789abcdef0",
  "tunnel_count": 2,
  "aws_peer_ips": [
    "52.1.2.3",
    "52.1.2.4"
  ],
  "onprem_peer_ip": "10.0.1.1",
  "aws_asn": 64512,
  "onprem_asn": 65000,
  "remote_networks": [
    "10.0.0.0/16",
    "172.16.0.0/12"
  ],
  "psk": {
    "tunnel1": "your-psk-for-tunnel1",
    "tunnel2": "your-psk-for-tunnel2"
  }
}
```

## Health Checks Performed

### 1. IPsec Tunnel Status
- Checks if tunnels are ESTABLISHED
- Detects tunnel down conditions
- Auto-remediation: Restart StrongSwan

### 2. BGP Session Status
- Monitors BGP neighbor states
- Detects session failures
- Auto-remediation: Restart FRR

### 3. VTI Interface Status
- Checks if VTI interfaces exist
- Verifies interfaces are UP
- Auto-remediation: Bring up or recreate interfaces

### 4. Routing Table
- Verifies routes via VTI interfaces
- Detects missing routes
- Auto-remediation: Restart BGP

### 5. Log Analysis
- Scans recent logs for errors
- Detects authentication failures
- Identifies encryption mismatches
- Finds connection issues

## Connectivity Testing

VPN Manager automatically tests connectivity to configured remote networks:

```json
"remote_networks": [
  "10.0.0.0/16",
  "172.16.0.0/12",
  "192.168.1.0/24"
]
```

For each network:
- Pings the first IP in the range
- Measures latency
- Detects packet loss
- Reports failures

Tests are triggered:
- On tunnel up events (via updown script)
- During health monitoring cycles
- On-demand via `--test-connectivity`

## Auto-Remediation

VPN Manager can automatically fix common issues:

| Issue | Auto-Fix Action |
|-------|----------------|
| Tunnel Down | Restart StrongSwan |
| BGP Down | Restart FRR |
| VTI Down | Bring up interface |
| VTI Missing | Recreate VTI interfaces |
| No Routes | Restart BGP |

Enable with `--auto-fix` (enabled by default).

Disable with `--no-auto-fix` for manual intervention.

## Email Notifications

### When Notifications Are Sent

- Critical issues detected
- Degraded VPN status
- Connectivity test failures
- After auto-remediation attempts

### Email Content

- Overall health status
- List of issues with severity
- Connectivity test results
- Remediation actions taken
- Timestamp and details

### Severity Levels

- **CRITICAL**: Tunnel down, BGP down, authentication failures
- **WARNING**: Degraded status, connectivity issues
- **INFO**: Healthy status, successful tests

## Systemd Service

### Service Management

```bash
# Enable service
sudo systemctl enable vpn-manager

# Start service
sudo systemctl start vpn-manager

# Stop service
sudo systemctl stop vpn-manager

# Restart service
sudo systemctl restart vpn-manager

# Check status
sudo systemctl status vpn-manager

# View logs
sudo journalctl -u vpn-manager -f
```

### Service Configuration

Edit `/etc/systemd/system/vpn-manager.service`:

```ini
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/vpn_manager.py --daemon --interval 300 --auto-fix --notify
```

Change `--interval` to adjust monitoring frequency.

## Generated Files

### Configuration Files

Location: `/etc/vpn/`

- `ipsec.conf` - StrongSwan IPsec configuration
- `ipsec.secrets` - Pre-shared keys
- `frr.conf` - FRR BGP configuration
- `setup_vti.sh` - VTI interface setup script
- `aws-updown.sh` - IPsec updown handler

### Log Files

Location: `/var/log/vpn/`

- `vpn_health_YYYYMMDD_HHMMSS.json` - Health check reports

### System Logs

```bash
# VPN Manager logs
sudo journalctl -u vpn-manager

# StrongSwan logs
sudo journalctl -u strongswan

# FRR logs
sudo journalctl -u frr
```

## Troubleshooting

### VPN Manager Not Starting

```bash
# Check service status
sudo systemctl status vpn-manager

# Check logs
sudo journalctl -u vpn-manager -n 50

# Verify script is executable
ls -l /usr/local/bin/vpn_manager.py

# Test manually
sudo /usr/local/bin/vpn_manager.py --monitor
```

### Email Notifications Not Working

```bash
# Check email configuration
sudo cat /etc/vpn/email_config.json

# Test SMTP connection
telnet smtp.gmail.com 587

# Check logs for email errors
sudo journalctl -u vpn-manager | grep -i email
```

### Auto-Remediation Not Working

```bash
# Check if auto-fix is enabled
sudo journalctl -u vpn-manager | grep "auto-remediation"

# Verify permissions (needs root)
sudo vpn_manager.py --monitor --auto-fix

# Check service restart permissions
sudo systemctl restart strongswan
sudo systemctl restart frr
```

### Connectivity Tests Failing

```bash
# Verify remote networks are configured
sudo cat /etc/vpn/config.json | grep remote_networks

# Test manually
ping -c 3 10.0.0.1

# Check routing
ip route show

# Verify VPN is up
sudo ipsec status
```

## Best Practices

### 1. Configuration
- Use strong, unique PSKs for each tunnel
- Configure remote networks for comprehensive testing
- Keep configuration file secure (600 permissions)

### 2. Monitoring
- Run as systemd service for continuous monitoring
- Set appropriate monitoring interval (5-10 minutes)
- Enable email notifications for critical alerts

### 3. Auto-Remediation
- Enable for common, safe fixes
- Monitor remediation actions in logs
- Disable for sensitive environments requiring manual intervention

### 4. Email Notifications
- Configure multiple recipients
- Use app-specific passwords for Gmail
- Test email configuration before production

### 5. Logging
- Rotate log files regularly
- Monitor disk space in /var/log/vpn/
- Review logs periodically for patterns

## Security Considerations

### File Permissions

```bash
# Configuration files
sudo chmod 600 /etc/vpn/config.json
sudo chmod 600 /etc/vpn/email_config.json
sudo chmod 600 /etc/ipsec.secrets

# Scripts
sudo chmod 755 /usr/local/bin/vpn_manager.py
sudo chmod 755 /etc/vpn/*.sh
```

### PSK Management

- Never commit PSKs to version control
- Use strong, random PSKs (32+ characters)
- Rotate PSKs periodically
- Store securely (encrypted filesystem, secrets manager)

### Email Security

- Use TLS for SMTP connections
- Use app-specific passwords (not account passwords)
- Limit email recipients to authorized personnel
- Consider using internal SMTP relay

## Integration

### With Monitoring Systems

```bash
# Export metrics to JSON
vpn_manager.py --monitor --no-notify > /var/lib/monitoring/vpn_status.json

# Parse for specific metrics
jq '.health.status' /var/log/vpn/vpn_health_*.json
```

### With Alerting Systems

```bash
# Check for critical issues
if vpn_manager.py --monitor | grep -q "CRITICAL"; then
  # Trigger alert
  alert-system notify "VPN Critical Issue"
fi
```

### With Configuration Management

```bash
# Ansible playbook
- name: Deploy VPN Manager
  copy:
    src: vpn_manager.py
    dest: /usr/local/bin/
    mode: '0755'

- name: Configure VPN
  template:
    src: config.json.j2
    dest: /etc/vpn/config.json
    mode: '0600'
```

## FAQ

**Q: How often should monitoring run?**
A: 5-10 minutes is recommended. Adjust based on your SLA requirements.

**Q: Will auto-remediation cause service interruptions?**
A: Brief interruptions (5-10 seconds) may occur during service restarts.

**Q: Can I run multiple VPN Managers?**
A: No, only one instance should manage a VPN gateway.

**Q: What if auto-remediation fails?**
A: Email notification is sent, and manual intervention is required.

**Q: How do I add more remote networks to test?**
A: Edit `/etc/vpn/config.json` and add to `remote_networks` array.

**Q: Can I customize remediation actions?**
A: Yes, modify the `AutoRemediation` class in `vpn_manager.py`.

## Support

### Documentation
- This README
- Inline code comments
- System logs

### Logs
```bash
# VPN Manager
sudo journalctl -u vpn-manager -f

# All VPN-related
sudo journalctl -u vpn-manager -u strongswan -u frr -f
```

### Testing
```bash
# Test configuration
sudo vpn_manager.py --status

# Test connectivity
sudo vpn_manager.py --test-connectivity

# Test monitoring
sudo vpn_manager.py --monitor --no-auto-fix
```

## Version History

- **1.0** (2026-01-31): Initial release
  - Configuration generation
  - Health monitoring
  - Auto-remediation
  - Email notifications
  - Systemd integration

## License

See project LICENSE file.
