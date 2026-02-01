# Ubuntu 18.04 FRR Installation Fix

## Issue

Ubuntu 18.04 (Bionic) doesn't have FRR in the default repositories, causing the installation to fail with:
```
E: Unable to locate package frr
```

## Solution

The installer and VPN Manager have been updated to automatically add the FRR repository for Ubuntu 18.04.

## What Was Fixed

### 1. Installer (`install_vpn_manager.sh`)
- Detects Ubuntu version
- Adds FRR repository for Ubuntu 18.04
- Installs FRR from official FRR repository

### 2. VPN Manager (`vpn_manager.py`)
- Detects Ubuntu version during setup
- Adds FRR repository if needed
- Handles installation automatically

## How It Works Now

### Automatic Installation

When you run the installer on Ubuntu 18.04:

```bash
sudo ./install_vpn_manager.sh
```

It will:
1. Detect Ubuntu 18.04
2. Add FRR GPG key
3. Add FRR repository
4. Update package list
5. Install FRR and FRR Python tools
6. Enable BGP daemon
7. Start services

### Manual Installation (If Needed)

If automatic installation fails, install FRR manually:

```bash
# Install prerequisites
sudo apt-get install -y curl gnupg lsb-release

# Add FRR GPG key
curl -s https://deb.frrouting.org/frr/keys.asc | sudo apt-key add -

# Add FRR repository
FRRVER="frr-stable"
echo "deb https://deb.frrouting.org/frr $(lsb_release -s -c) $FRRVER" | sudo tee /etc/apt/sources.list.d/frr.list

# Update and install
sudo apt-get update
sudo apt-get install -y frr frr-pythontools

# Enable BGP
sudo sed -i 's/bgpd=no/bgpd=yes/' /etc/frr/daemons

# Start FRR
sudo systemctl enable frr
sudo systemctl start frr

# Verify
sudo systemctl status frr
vtysh -c "show version"
```

## Try Again

Now that the installer is fixed, try running it again:

```bash
cd ~/vpn-manager
sudo ./install_vpn_manager.sh
```

You should see:
```
[2/9] Installing VPN software (StrongSwan, FRR)...
Installing: frr
  📦 Installing FRR...
  📝 Adding FRR repository for Ubuntu 18.04...
  ✅ FRR installed
  📝 Enabling BGP in FRR...
  ✅ BGP enabled
✅ VPN software installed
```

## Supported Ubuntu Versions

The installer now supports:
- ✅ Ubuntu 18.04 (Bionic) - Adds FRR repository
- ✅ Ubuntu 20.04 (Focal) - Uses default repos
- ✅ Ubuntu 22.04 (Jammy) - Uses default repos
- ✅ Debian 10+ - Uses default repos
- ✅ Amazon Linux 2 - Uses default repos

## Verification

After installation, verify FRR is working:

```bash
# Check FRR service
sudo systemctl status frr

# Check FRR version
vtysh -c "show version"

# Check BGP is enabled
sudo cat /etc/frr/daemons | grep bgpd

# Test vtysh
sudo vtysh -c "show running-config"
```

Expected output:
```
● frr.service - FRRouting
   Loaded: loaded (/lib/systemd/system/frr.service; enabled)
   Active: active (running)
```

## Troubleshooting

### GPG Key Error

If you get GPG key errors:
```bash
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys XXXXXXXX
```

### Repository Not Found

If repository URL fails:
```bash
# Try alternative mirror
echo "deb https://deb.frrouting.org/frr bionic frr-stable" | sudo tee /etc/apt/sources.list.d/frr.list
sudo apt-get update
```

### FRR Won't Start

Check logs:
```bash
sudo journalctl -u frr -n 50
```

Common issues:
- Config file syntax error
- Permissions issue
- Port already in use

### Still Having Issues?

1. Check Ubuntu version:
   ```bash
   lsb_release -a
   ```

2. Check if FRR repository was added:
   ```bash
   cat /etc/apt/sources.list.d/frr.list
   ```

3. Try manual installation (see above)

4. Check FRR documentation:
   https://docs.frrouting.org/en/latest/installation.html

## What's Next

After FRR is installed, continue with VPN setup:

```bash
sudo python3 vpn_manager.py --setup --interactive
```

This will:
1. Ask for your VPN configuration
2. Generate all config files
3. Deploy to system locations
4. Restart services
5. Show status

---

**Status**: ✅ Fixed in latest version
**Tested on**: Ubuntu 18.04 LTS
**Date**: 2026-02-01

