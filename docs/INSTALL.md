# VPN Manager - Installation Guide

## One-Command Installation

Install VPN Manager with a single command:

```bash
sudo bash install_vpn_manager.sh
```

## What the Installer Does

### Automatic Steps
1. ✅ Checks prerequisites (Python3, systemd)
2. ✅ Creates required directories (`/etc/vpn`, `/var/log/vpn`)
3. ✅ Installs VPN Manager to `/usr/local/bin/`
4. ✅ Installs systemd service
5. ✅ Creates email configuration template

### Interactive Steps (Optional)
6. 📝 **VPN Configuration** (can skip and configure later)
   - AWS VPN Connection ID
   - AWS peer IPs
   - On-premises peer IP
   - ASN numbers
   - Remote networks to monitor
   - Pre-shared keys

7. 📧 **Email Configuration** (can skip and configure later)
   - SMTP server settings
   - Email credentials
   - Notification recipients

8. 🚀 **Service Setup** (can skip and start later)
   - Enable service
   - Start service

## Installation Output

```
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║           AWS Site-to-Site VPN Manager Installer              ║
║                                                               ║
║  Automated VPN Configuration, Monitoring & Remediation        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

🚀 Starting installation...

[1/8] Checking prerequisites...
✅ Prerequisites OK

[2/8] Creating directories...
✅ Directories created

[3/8] Installing VPN Manager...
✅ VPN Manager installed to /usr/local/bin/

[4/8] Installing systemd service...
✅ Systemd service installed

[5/8] Creating email configuration template...
✅ Email configuration template created

[6/8] VPN Configuration Setup
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Do you want to configure VPN now? (y/n): 
```

## Prerequisites

The installer checks for:
- **Python 3** - Required for VPN Manager
- **systemd** - Required for service management

If missing, install with:
```bash
sudo apt-get update
sudo apt-get install -y python3 systemd
```

## Files Installed

| File | Location | Purpose |
|------|----------|---------|
| VPN Manager | `/usr/local/bin/vpn_manager.py` | Main tool |
| Systemd Service | `/etc/systemd/system/vpn-manager.service` | Service definition |
| VPN Config | `/etc/vpn/config.json` | VPN settings |
| Email Config | `/etc/vpn/email_config.json` | Email settings |
| Logs | `/var/log/vpn/` | Health reports |

## Post-Installation

### If You Skipped VPN Configuration

Configure VPN later:
```bash
sudo vpn_manager.py --setup --interactive
```

Or manually edit:
```bash
sudo nano /etc/vpn/config.json
```

### If You Skipped Email Configuration

Configure email later:
```bash
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
  "from_addr": "vpn@your-domain.com",
  "to_addrs": ["admin@your-domain.com"],
  "subject_prefix": "[VPN Manager]"
}
```

### If You Skipped Service Setup

Enable and start service:
```bash
sudo systemctl enable vpn-manager
sudo systemctl start vpn-manager
```

## Verification

### Check Installation

```bash
# Verify VPN Manager is installed
which vpn_manager.py

# Check version/help
vpn_manager.py --help

# Verify service is installed
systemctl status vpn-manager
```

### Test VPN Manager

```bash
# Check VPN status
sudo vpn_manager.py --status

# Run health check
sudo vpn_manager.py --monitor

# Test connectivity
sudo vpn_manager.py --test-connectivity
```

### View Logs

```bash
# Service logs
sudo journalctl -u vpn-manager -f

# Health reports
ls -la /var/log/vpn/
```

## Uninstallation

To remove VPN Manager:

```bash
# Stop and disable service
sudo systemctl stop vpn-manager
sudo systemctl disable vpn-manager

# Remove files
sudo rm /usr/local/bin/vpn_manager.py
sudo rm /etc/systemd/system/vpn-manager.service
sudo rm -rf /etc/vpn
sudo rm -rf /var/log/vpn

# Reload systemd
sudo systemctl daemon-reload
```

## Troubleshooting

### Installer Fails at Prerequisites

**Error**: Missing dependencies

**Solution**:
```bash
sudo apt-get update
sudo apt-get install -y python3 systemd
```

### Installer Can't Find vpn_manager.py

**Error**: vpn_manager.py not found in current directory

**Solution**: Run installer from the directory containing `vpn_manager.py`:
```bash
cd /path/to/vpn-manager
sudo bash install_vpn_manager.sh
```

### Service Won't Start

**Error**: Service fails to start

**Solution**: Check configuration:
```bash
# View service status
sudo systemctl status vpn-manager

# Check logs
sudo journalctl -u vpn-manager -n 50

# Verify configuration
sudo cat /etc/vpn/config.json

# Test manually
sudo vpn_manager.py --monitor
```

### Permission Denied

**Error**: Permission denied errors

**Solution**: Ensure running as root:
```bash
sudo bash install_vpn_manager.sh
```

## Advanced Installation

### Custom Installation Directory

Edit `install_vpn_manager.sh` and change:
```bash
INSTALL_DIR="/usr/local/bin"  # Change this
CONFIG_DIR="/etc/vpn"          # And this
```

### Non-Interactive Installation

For automated deployments, pre-create configuration files:

```bash
# Create VPN config
cat > /tmp/vpn_config.json << EOF
{
  "vpn_id": "vpn-xxxxx",
  "tunnel_count": 2,
  "aws_peer_ips": ["52.1.2.3", "52.1.2.4"],
  "onprem_peer_ip": "10.0.1.1",
  "aws_asn": 64512,
  "onprem_asn": 65000,
  "remote_networks": ["10.0.0.0/16"],
  "psk": {
    "tunnel1": "your-psk-1",
    "tunnel2": "your-psk-2"
  }
}
EOF

# Run installer (answer 'n' to interactive prompts)
sudo bash install_vpn_manager.sh

# Copy pre-created config
sudo cp /tmp/vpn_config.json /etc/vpn/config.json
sudo chmod 600 /etc/vpn/config.json
```

### Docker Installation

For containerized deployment:

```dockerfile
FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y python3 systemd && \
    apt-get clean

COPY vpn_manager.py /usr/local/bin/
COPY install_vpn_manager.sh /tmp/

RUN chmod +x /usr/local/bin/vpn_manager.py && \
    bash /tmp/install_vpn_manager.sh

CMD ["/usr/bin/python3", "/usr/local/bin/vpn_manager.py", "--daemon"]
```

## Security Considerations

### File Permissions

The installer automatically sets secure permissions:
- `/etc/vpn/config.json` - 600 (root only)
- `/etc/vpn/email_config.json` - 600 (root only)
- `/usr/local/bin/vpn_manager.py` - 755 (executable)

### Sensitive Data

- **PSKs**: Stored encrypted in `/etc/vpn/config.json`
- **Email passwords**: Stored in `/etc/vpn/email_config.json`
- **Logs**: May contain sensitive info, stored in `/var/log/vpn/`

**Recommendations**:
- Use strong PSKs (32+ characters)
- Use app-specific passwords for email
- Rotate credentials regularly
- Restrict access to `/etc/vpn/` directory

## Support

### Documentation
- **Complete Guide**: `VPN_MANAGER_README.md`
- **Quick Start**: `VPN_MANAGER_QUICK_START.md`
- **Summary**: `VPN_MANAGER_SUMMARY.md`

### Getting Help

1. Check installation logs
2. Verify configuration files
3. Test manually
4. Review system logs
5. Check documentation

### Common Issues

| Issue | Solution |
|-------|----------|
| Service won't start | Check config files, verify permissions |
| Email not sending | Verify SMTP settings, check credentials |
| VPN not monitored | Ensure service is running, check logs |
| Permission errors | Run commands with sudo |

## Next Steps

After installation:

1. **Verify Installation**
   ```bash
   sudo vpn_manager.py --status
   ```

2. **Test Monitoring**
   ```bash
   sudo vpn_manager.py --monitor
   ```

3. **Check Service**
   ```bash
   sudo systemctl status vpn-manager
   ```

4. **View Logs**
   ```bash
   sudo journalctl -u vpn-manager -f
   ```

5. **Read Documentation**
   - See `VPN_MANAGER_README.md` for complete guide
   - See `VPN_MANAGER_QUICK_START.md` for quick reference

---

**Ready to install?**

```bash
sudo bash install_vpn_manager.sh
```

**Questions?** See the documentation or check system logs.

🚀 **Happy VPN Managing!**
