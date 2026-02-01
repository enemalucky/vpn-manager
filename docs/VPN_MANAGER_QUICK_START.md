# VPN Manager - Quick Start Guide

## ONE-COMMAND INSTALLATION! 🚀

### Install Everything with One Command

```bash
sudo bash install_vpn_manager.sh
```

That's it! The installer will:
1. ✅ Check prerequisites
2. ✅ Create directories
3. ✅ Install VPN Manager
4. ✅ Install systemd service
5. ✅ Guide you through VPN configuration (interactive)
6. ✅ Guide you through email setup (interactive)
7. ✅ Enable and start the service
8. ✅ Show you the status

**Total time: 2-3 minutes**

### What the Installer Asks

#### VPN Configuration (Optional - can skip and configure later)
- AWS VPN Connection ID
- AWS peer IPs (from AWS console)
- On-premises peer IP
- ASN numbers (defaults: AWS=64512, On-prem=65000)
- Remote networks to monitor
- Pre-shared keys (from AWS config download)

#### Email Configuration (Optional - can skip and configure later)
- SMTP server (e.g., smtp.gmail.com)
- SMTP port (default: 587)
- Use TLS (default: yes)
- SMTP username
- SMTP password
- From address
- To address(es)

#### Service Setup
- Enable and start service now? (recommended: yes)

### Manual Installation (If Preferred)

<details>
<summary>Click to expand manual steps</summary>

```bash
# Copy files
sudo cp vpn_manager.py /usr/local/bin/
sudo chmod +x /usr/local/bin/vpn_manager.py

# Create directories
sudo mkdir -p /etc/vpn /var/log/vpn

# Install systemd service
sudo cp vpn-manager.service /etc/systemd/system/
sudo systemctl daemon-reload

# Configure VPN
sudo vpn_manager.py --setup --interactive

# Configure email
sudo cp email_config.json.example /etc/vpn/email_config.json
sudo nano /etc/vpn/email_config.json

# Enable service
sudo systemctl enable vpn-manager
sudo systemctl start vpn-manager
```
</details>

## Done! 🎉

Your VPN is now:
- ✅ Configured and running
- ✅ Continuously monitored (every 5 minutes)
- ✅ Auto-fixing common issues
- ✅ Sending email alerts

## Common Commands

```bash
# View logs
sudo journalctl -u vpn-manager -f

# Manual health check
sudo vpn_manager.py --monitor

# Test connectivity
sudo vpn_manager.py --test-connectivity

# Show status
sudo vpn_manager.py --status

# Restart service
sudo systemctl restart vpn-manager
```

## What Happens Automatically

### Every 5 Minutes
1. Check IPsec tunnels
2. Check BGP sessions
3. Check VTI interfaces
4. Check routing table
5. Analyze logs for errors
6. Test connectivity to remote networks
7. Auto-fix any issues found
8. Send email if problems detected

### When Issues Are Found
1. Issue detected (e.g., tunnel down)
2. Auto-remediation attempted (e.g., restart service)
3. Health re-checked after fix
4. Email notification sent
5. Report saved to `/var/log/vpn/`

## Monitoring Dashboard

Check health anytime:
```bash
sudo vpn_manager.py --status
```

Output shows:
- IPsec tunnel status
- BGP session status
- VTI interface status
- Recent issues
- Connectivity test results

## Email Alerts

You'll receive emails for:
- ❌ Critical: Tunnel down, BGP down, auth failures
- ⚠️  Warning: Degraded status, connectivity issues
- ✅ Info: Status updates, successful fixes

## Troubleshooting

### VPN Not Working
```bash
# Check all components
sudo vpn_manager.py --status

# View detailed logs
sudo journalctl -u strongswan -u frr -n 100

# Manual fix
sudo vpn_manager.py --monitor --auto-fix
```

### Email Not Sending
```bash
# Test email config
sudo cat /etc/vpn/email_config.json

# Check logs
sudo journalctl -u vpn-manager | grep -i email

# Verify SMTP
telnet smtp.gmail.com 587
```

### Service Not Running
```bash
# Check status
sudo systemctl status vpn-manager

# View errors
sudo journalctl -u vpn-manager -n 50

# Restart
sudo systemctl restart vpn-manager
```

## Next Steps

### 1. Customize Monitoring Interval

Edit `/etc/systemd/system/vpn-manager.service`:
```ini
ExecStart=/usr/bin/python3 /usr/local/bin/vpn_manager.py --daemon --interval 600
```
(Change 600 to desired seconds)

Then:
```bash
sudo systemctl daemon-reload
sudo systemctl restart vpn-manager
```

### 2. Add More Remote Networks

Edit `/etc/vpn/config.json`:
```json
"remote_networks": [
  "10.0.0.0/16",
  "172.16.0.0/12",
  "192.168.1.0/24"
]
```

### 3. Customize Auto-Remediation

Disable for specific environments:
```bash
# Edit service file
ExecStart=... --no-auto-fix
```

### 4. Set Up Log Rotation

Create `/etc/logrotate.d/vpn-manager`:
```
/var/log/vpn/*.json {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
}
```

## Configuration Files

| File | Purpose | Location |
|------|---------|----------|
| VPN Config | VPN settings | `/etc/vpn/config.json` |
| Email Config | SMTP settings | `/etc/vpn/email_config.json` |
| IPsec Config | StrongSwan | `/etc/ipsec.conf` |
| FRR Config | BGP | `/etc/frr/frr.conf` |
| Health Reports | Monitoring | `/var/log/vpn/*.json` |

## Support

**View Logs:**
```bash
sudo journalctl -u vpn-manager -f
```

**Test Manually:**
```bash
sudo vpn_manager.py --monitor --auto-fix
```

**Check Configuration:**
```bash
sudo cat /etc/vpn/config.json
```

**Full Documentation:**
See `VPN_MANAGER_README.md`

---

**Questions?** Check the full README or system logs.

**Working?** You're all set! VPN Manager is now protecting your VPN. 🚀
