# VPN Configuration Installation Guide

## Prerequisites
- Ubuntu/Debian-based system (or adapt commands for your distro)
- Root/sudo access
- StrongSwan installed
- FRR installed

## Installation Steps

### 1. Install Required Packages
```bash
sudo apt-get update
sudo apt-get install -y strongswan strongswan-pki frr frr-pythontools
```

### 2. Backup Existing Configurations
```bash
sudo cp /etc/ipsec.conf /etc/ipsec.conf.backup
sudo cp /etc/ipsec.secrets /etc/ipsec.secrets.backup
sudo cp /etc/frr/frr.conf /etc/frr/frr.conf.backup
```

### 3. Deploy StrongSwan Configuration
```bash
sudo cp vpn_configs/ipsec.conf /etc/ipsec.conf
sudo cp vpn_configs/ipsec.secrets /etc/ipsec.secrets
sudo chmod 600 /etc/ipsec.secrets
sudo cp vpn_configs/aws-updown.sh /etc/strongswan.d/aws-updown.sh
sudo chmod 755 /etc/strongswan.d/aws-updown.sh
```

### 4. Setup VTI Interfaces
```bash
sudo cp vpn_configs/setup_vti.sh /usr/local/bin/setup_vti.sh
sudo chmod 755 /usr/local/bin/setup_vti.sh
sudo /usr/local/bin/setup_vti.sh
```

### 5. Make VTI Setup Persistent (systemd)
Create `/etc/systemd/system/vti-setup.service`:
```ini
[Unit]
Description=Setup VTI interfaces for AWS VPN
Before=strongswan.service frr.service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/setup_vti.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

Enable the service:
```bash
sudo systemctl daemon-reload
sudo systemctl enable vti-setup.service
```

### 6. Deploy FRR Configuration
```bash
# Enable BGP and BFD daemons
sudo sed -i 's/bgpd=no/bgpd=yes/' /etc/frr/daemons
sudo sed -i 's/bfdd=no/bfdd=yes/' /etc/frr/daemons

# Deploy configuration
sudo cp vpn_configs/frr.conf /etc/frr/frr.conf
sudo chown frr:frr /etc/frr/frr.conf
sudo chmod 640 /etc/frr/frr.conf
```

### 7. Deploy Health Check Monitoring
```bash
sudo cp vpn_configs/vpn_health_check.py /usr/local/bin/vpn_health_check.py
sudo chmod 755 /usr/local/bin/vpn_health_check.py

sudo cp vpn_configs/vpn-health-check.service /etc/systemd/system/
sudo cp vpn_configs/vpn-health-check.timer /etc/systemd/system/

sudo systemctl daemon-reload
sudo systemctl enable vpn-health-check.timer
sudo systemctl start vpn-health-check.timer
```

### 8. Start Services
```bash
# Start StrongSwan
sudo systemctl restart strongswan

# Start FRR
sudo systemctl restart frr

# Verify services are running
sudo systemctl status strongswan
sudo systemctl status frr
```

## Verification

### Check IPsec Tunnels
```bash
sudo ipsec status
sudo ipsec statusall
```

### Check VTI Interfaces
```bash
ip addr show vti1
ip addr show vti2
```

### Check BGP Status
```bash
sudo vtysh -c "show bgp summary"
sudo vtysh -c "show bgp neighbors"
sudo vtysh -c "show ip route"
```

### Check BFD Status (if enabled)
```bash
sudo vtysh -c "show bfd peers"
```

### Manual Health Check
```bash
sudo /usr/local/bin/vpn_health_check.py
```

### View Health Check Logs
```bash
sudo journalctl -u vpn-health-check.service -f
```

## Troubleshooting

### IPsec Issues
```bash
# Check logs
sudo journalctl -u strongswan -f

# Restart tunnel
sudo ipsec restart

# Check specific connection
sudo ipsec up AWS-S2S-VPN-tunnel1
```

### BGP Issues
```bash
# Access FRR shell
sudo vtysh

# Check BGP configuration
show running-config

# Reset BGP session
clear bgp *

# Debug BGP
debug bgp updates
debug bgp neighbor-events
```

### Connectivity Issues
```bash
# Test ping through VTI
ping -I vti1 169.254.191.145/30

# Check routing
ip route show

# Verify IPsec policies
ip xfrm policy
ip xfrm state
```

## AWS Console Configuration

Make sure your AWS VPN Connection is configured with:
- IKEv2
- Matching encryption algorithms
- BGP ASN: 64512
- Inside tunnel IPs matching this configuration

## Security Notes

1. **Protect secrets file**: Ensure `/etc/ipsec.secrets` has 600 permissions
2. **Rotate PSKs regularly**: Update pre-shared keys every 90 days
3. **Monitor logs**: Regularly check for security events
4. **Firewall rules**: Ensure UDP 500, 4500 and ESP (protocol 50) are allowed

## Performance Tuning

### Increase MTU if needed
```bash
ip link set vti1 mtu 1400
ip link set vti2 mtu 1400
```

### Enable TCP MSS clamping
```bash
iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
```

## Support

For issues or questions, check:
- StrongSwan logs: `journalctl -u strongswan`
- FRR logs: `journalctl -u frr`
- System logs: `/var/log/syslog`
