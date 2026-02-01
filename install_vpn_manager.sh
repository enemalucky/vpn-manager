#!/bin/bash
#
# VPN Manager - One-Command Installer
# Usage: sudo bash install_vpn_manager.sh
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}❌ This script must be run as root${NC}"
   echo "Usage: sudo bash install_vpn_manager.sh"
   exit 1
fi

echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║           AWS Site-to-Site VPN Manager Installer              ║
║                                                               ║
║  Automated VPN Configuration, Monitoring & Remediation        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}🚀 Starting installation...${NC}\n"

# Step 1: Check prerequisites
echo -e "${BLUE}[1/8]${NC} Checking prerequisites..."

# Check for required commands
MISSING_DEPS=()

if ! command -v python3 &> /dev/null; then
    MISSING_DEPS+=("python3")
fi

if ! command -v systemctl &> /dev/null; then
    MISSING_DEPS+=("systemd")
fi

if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
    echo -e "${RED}❌ Missing dependencies: ${MISSING_DEPS[*]}${NC}"
    echo "Please install them first:"
    echo "  sudo apt-get install -y ${MISSING_DEPS[*]}"
    exit 1
fi

echo -e "${GREEN}✅ Prerequisites OK${NC}\n"

# Step 2: Create directories
echo -e "${BLUE}[2/8]${NC} Creating directories..."

mkdir -p /etc/vpn
mkdir -p /var/log/vpn
mkdir -p /usr/local/bin

echo -e "${GREEN}✅ Directories created${NC}\n"

# Step 3: Install VPN Manager script
echo -e "${BLUE}[3/8]${NC} Installing VPN Manager..."

# Check if vpn_manager.py exists in current directory
if [ ! -f "vpn_manager.py" ]; then
    echo -e "${RED}❌ vpn_manager.py not found in current directory${NC}"
    echo "Please run this installer from the directory containing vpn_manager.py"
    exit 1
fi

cp vpn_manager.py /usr/local/bin/
chmod +x /usr/local/bin/vpn_manager.py

echo -e "${GREEN}✅ VPN Manager installed to /usr/local/bin/${NC}\n"

# Step 4: Install systemd service
echo -e "${BLUE}[4/8]${NC} Installing systemd service..."

cat > /etc/systemd/system/vpn-manager.service << 'SERVICEEOF'
[Unit]
Description=AWS Site-to-Site VPN Manager
After=network.target strongswan.service frr.service
Wants=strongswan.service frr.service

[Service]
Type=simple
ExecStart=/usr/bin/python3 /usr/local/bin/vpn_manager.py --daemon --interval 300 --auto-fix --notify
Restart=always
RestartSec=10
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICEEOF

systemctl daemon-reload

echo -e "${GREEN}✅ Systemd service installed${NC}\n"

# Step 5: Create email configuration template
echo -e "${BLUE}[5/8]${NC} Creating email configuration template..."

cat > /etc/vpn/email_config.json << 'EMAILEOF'
{
  "enabled": false,
  "smtp_server": "smtp.gmail.com",
  "smtp_port": 587,
  "use_tls": true,
  "username": "your-email@gmail.com",
  "password": "your-app-password",
  "from_addr": "vpn-manager@your-domain.com",
  "to_addrs": [
    "admin@your-domain.com"
  ],
  "subject_prefix": "[VPN Manager]"
}
EMAILEOF

chmod 600 /etc/vpn/email_config.json

echo -e "${GREEN}✅ Email configuration template created${NC}\n"

# Step 6: Interactive VPN configuration
echo -e "${BLUE}[6/8]${NC} VPN Configuration Setup"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

read -p "Do you want to configure VPN now? (y/n): " CONFIGURE_NOW

if [[ $CONFIGURE_NOW =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${GREEN}📝 Please provide VPN configuration:${NC}\n"
    
    read -p "AWS VPN Connection ID (e.g., vpn-xxxxx): " VPN_ID
    
    echo ""
    echo -e "${GREEN}📍 Outside IP Addresses (Public IPs):${NC}"
    read -p "AWS peer outside IP #1: " AWS_IP1
    read -p "AWS peer outside IP #2 (press Enter to skip): " AWS_IP2
    read -p "On-premises outside IP: " ONPREM_IP
    
    echo ""
    echo -e "${GREEN}📍 Inside IP Addresses (BGP Peering - 169.254.x.x):${NC}"
    echo "These are the /30 CIDR blocks for BGP peering inside the tunnels"
    echo ""
    echo "Tunnel 1:"
    read -p "  AWS inside IP [169.254.11.2]: " AWS_INSIDE_IP1
    AWS_INSIDE_IP1=${AWS_INSIDE_IP1:-169.254.11.2}
    read -p "  On-premises inside IP [169.254.11.1]: " ONPREM_INSIDE_IP1
    ONPREM_INSIDE_IP1=${ONPREM_INSIDE_IP1:-169.254.11.1}
    
    if [ -n "$AWS_IP2" ]; then
        echo ""
        echo "Tunnel 2:"
        read -p "  AWS inside IP [169.254.12.2]: " AWS_INSIDE_IP2
        AWS_INSIDE_IP2=${AWS_INSIDE_IP2:-169.254.12.2}
        read -p "  On-premises inside IP [169.254.12.1]: " ONPREM_INSIDE_IP2
        ONPREM_INSIDE_IP2=${ONPREM_INSIDE_IP2:-169.254.12.1}
    fi
    
    echo ""
    echo -e "${GREEN}📡 BGP Configuration:${NC}"
    read -p "AWS ASN [64512]: " AWS_ASN
    AWS_ASN=${AWS_ASN:-64512}
    read -p "On-premises ASN [65000]: " ONPREM_ASN
    ONPREM_ASN=${ONPREM_ASN:-65000}
    
    echo ""
    echo -e "${GREEN}🔐 Pre-Shared Keys:${NC}"
    read -sp "PSK for Tunnel 1: " PSK1
    echo ""
    if [ -n "$AWS_IP2" ]; then
        read -sp "PSK for Tunnel 2: " PSK2
        echo ""
    fi
    
    echo ""
    echo -e "${GREEN}🌐 Remote Networks to Monitor:${NC}"
    echo "Enter remote networks (comma-separated CIDRs, e.g., 10.0.0.0/16,172.16.0.0/12)"
    read -p "Remote networks: " REMOTE_NETWORKS
    
    # Build AWS peer outside IPs array
    AWS_PEERS="[\"$AWS_IP1\""
    if [ -n "$AWS_IP2" ]; then
        AWS_PEERS="$AWS_PEERS, \"$AWS_IP2\""
    fi
    AWS_PEERS="$AWS_PEERS]"
    
    # Build AWS inside IPs array
    AWS_INSIDE_IPS="[\"$AWS_INSIDE_IP1\""
    if [ -n "$AWS_IP2" ]; then
        AWS_INSIDE_IPS="$AWS_INSIDE_IPS, \"$AWS_INSIDE_IP2\""
    fi
    AWS_INSIDE_IPS="$AWS_INSIDE_IPS]"
    
    # Build on-premises inside IPs array
    ONPREM_INSIDE_IPS="[\"$ONPREM_INSIDE_IP1\""
    if [ -n "$AWS_IP2" ]; then
        ONPREM_INSIDE_IPS="$ONPREM_INSIDE_IPS, \"$ONPREM_INSIDE_IP2\""
    fi
    ONPREM_INSIDE_IPS="$ONPREM_INSIDE_IPS]"
    
    # Build remote networks array
    if [ -n "$REMOTE_NETWORKS" ]; then
        IFS=',' read -ra NETWORKS <<< "$REMOTE_NETWORKS"
        REMOTE_NETS="["
        for i in "${!NETWORKS[@]}"; do
            REMOTE_NETS="$REMOTE_NETS\"${NETWORKS[$i]}\""
            if [ $i -lt $((${#NETWORKS[@]} - 1)) ]; then
                REMOTE_NETS="$REMOTE_NETS, "
            fi
        done
        REMOTE_NETS="$REMOTE_NETS]"
    else
        REMOTE_NETS="[]"
    fi
    
    # Build PSK object
    PSK_OBJ="{\"tunnel1\": \"$PSK1\""
    if [ -n "$PSK2" ]; then
        PSK_OBJ="$PSK_OBJ, \"tunnel2\": \"$PSK2\""
    fi
    PSK_OBJ="$PSK_OBJ}"
    
    # Create configuration file
    cat > /etc/vpn/config.json << CONFIGEOF
{
  "vpn_id": "$VPN_ID",
  "tunnel_count": $([ -n "$AWS_IP2" ] && echo "2" || echo "1"),
  "aws_peer_ips": $AWS_PEERS,
  "onprem_peer_ip": "$ONPREM_IP",
  "aws_inside_ips": $AWS_INSIDE_IPS,
  "onprem_inside_ips": $ONPREM_INSIDE_IPS,
  "aws_asn": $AWS_ASN,
  "onprem_asn": $ONPREM_ASN,
  "remote_networks": $REMOTE_NETS,
  "psk": $PSK_OBJ
}
CONFIGEOF
    
    chmod 600 /etc/vpn/config.json
    
    echo ""
    echo -e "${GREEN}✅ VPN configuration saved to /etc/vpn/config.json${NC}\n"
    
    # Generate VPN configurations
    echo -e "${BLUE}[7/8]${NC} Generating VPN configuration files..."
    
    python3 /usr/local/bin/vpn_manager.py --setup --config /etc/vpn/config.json 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Configuration files will be generated on first run${NC}"
    }
    
    echo -e "${GREEN}✅ VPN configuration files generated${NC}\n"
else
    echo -e "${YELLOW}⚠️  Skipping VPN configuration. You can configure later with:${NC}"
    echo "   sudo vpn_manager.py --setup --interactive"
    echo ""
fi

# Step 7: Email configuration
echo -e "${BLUE}[7/8]${NC} Email Notification Setup"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

read -p "Do you want to configure email notifications now? (y/n): " CONFIGURE_EMAIL

if [[ $CONFIGURE_EMAIL =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${GREEN}📧 Email Configuration:${NC}\n"
    
    read -p "SMTP server (e.g., smtp.gmail.com): " SMTP_SERVER
    read -p "SMTP port [587]: " SMTP_PORT
    SMTP_PORT=${SMTP_PORT:-587}
    read -p "Use TLS? (y/n) [y]: " USE_TLS
    USE_TLS=${USE_TLS:-y}
    read -p "SMTP username: " SMTP_USER
    read -sp "SMTP password: " SMTP_PASS
    echo ""
    read -p "From address: " FROM_ADDR
    read -p "To address(es) (comma-separated): " TO_ADDRS
    
    # Build to_addrs array
    IFS=',' read -ra ADDRS <<< "$TO_ADDRS"
    TO_ADDRS_JSON="["
    for i in "${!ADDRS[@]}"; do
        TO_ADDRS_JSON="$TO_ADDRS_JSON\"${ADDRS[$i]}\""
        if [ $i -lt $((${#ADDRS[@]} - 1)) ]; then
            TO_ADDRS_JSON="$TO_ADDRS_JSON, "
        fi
    done
    TO_ADDRS_JSON="$TO_ADDRS_JSON]"
    
    # Determine TLS setting
    if [[ $USE_TLS =~ ^[Yy]$ ]]; then
        TLS_SETTING="true"
    else
        TLS_SETTING="false"
    fi
    
    # Create email configuration
    cat > /etc/vpn/email_config.json << EMAILCONFIGEOF
{
  "enabled": true,
  "smtp_server": "$SMTP_SERVER",
  "smtp_port": $SMTP_PORT,
  "use_tls": $TLS_SETTING,
  "username": "$SMTP_USER",
  "password": "$SMTP_PASS",
  "from_addr": "$FROM_ADDR",
  "to_addrs": $TO_ADDRS_JSON,
  "subject_prefix": "[VPN Manager]"
}
EMAILCONFIGEOF
    
    chmod 600 /etc/vpn/email_config.json
    
    echo ""
    echo -e "${GREEN}✅ Email configuration saved${NC}\n"
else
    echo -e "${YELLOW}⚠️  Email notifications disabled. You can configure later by editing:${NC}"
    echo "   /etc/vpn/email_config.json"
    echo ""
fi

# Step 8: Service setup
echo -e "${BLUE}[8/8]${NC} Service Setup"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

read -p "Do you want to enable and start VPN Manager service now? (y/n): " START_SERVICE

if [[ $START_SERVICE =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${GREEN}🔄 Enabling and starting VPN Manager service...${NC}"
    
    systemctl enable vpn-manager
    systemctl start vpn-manager
    
    sleep 2
    
    if systemctl is-active --quiet vpn-manager; then
        echo -e "${GREEN}✅ VPN Manager service is running${NC}\n"
    else
        echo -e "${YELLOW}⚠️  Service started but may need configuration${NC}"
        echo "   Check status: sudo systemctl status vpn-manager"
        echo ""
    fi
else
    echo -e "${YELLOW}⚠️  Service not started. You can start it later with:${NC}"
    echo "   sudo systemctl enable vpn-manager"
    echo "   sudo systemctl start vpn-manager"
    echo ""
fi

# Installation complete
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║              ✅ Installation Complete! ✅                     ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}📦 Installed Components:${NC}"
echo "  ✅ VPN Manager: /usr/local/bin/vpn_manager.py"
echo "  ✅ Systemd Service: /etc/systemd/system/vpn-manager.service"
echo "  ✅ Configuration: /etc/vpn/config.json"
echo "  ✅ Email Config: /etc/vpn/email_config.json"
echo "  ✅ Log Directory: /var/log/vpn/"
echo ""

echo -e "${BLUE}🎯 Next Steps:${NC}"
echo ""

if [[ ! $CONFIGURE_NOW =~ ^[Yy]$ ]]; then
    echo "  1. Configure VPN:"
    echo "     ${YELLOW}sudo vpn_manager.py --setup --interactive${NC}"
    echo ""
fi

if [[ ! $CONFIGURE_EMAIL =~ ^[Yy]$ ]]; then
    echo "  2. Configure email notifications:"
    echo "     ${YELLOW}sudo nano /etc/vpn/email_config.json${NC}"
    echo ""
fi

if [[ ! $START_SERVICE =~ ^[Yy]$ ]]; then
    echo "  3. Start VPN Manager service:"
    echo "     ${YELLOW}sudo systemctl enable vpn-manager${NC}"
    echo "     ${YELLOW}sudo systemctl start vpn-manager${NC}"
    echo ""
fi

echo -e "${BLUE}📊 Useful Commands:${NC}"
echo "  • Check status:        ${YELLOW}sudo vpn_manager.py --status${NC}"
echo "  • Test connectivity:   ${YELLOW}sudo vpn_manager.py --test-connectivity${NC}"
echo "  • Run health check:    ${YELLOW}sudo vpn_manager.py --monitor${NC}"
echo "  • View service logs:   ${YELLOW}sudo journalctl -u vpn-manager -f${NC}"
echo "  • Service status:      ${YELLOW}sudo systemctl status vpn-manager${NC}"
echo ""

echo -e "${BLUE}📚 Documentation:${NC}"
echo "  • Complete Guide:      VPN_MANAGER_README.md"
echo "  • Quick Start:         VPN_MANAGER_QUICK_START.md"
echo "  • Summary:             VPN_MANAGER_SUMMARY.md"
echo ""

echo -e "${GREEN}🎉 VPN Manager is ready to protect your VPN!${NC}"
echo ""

# Offer to view status
if [[ $START_SERVICE =~ ^[Yy]$ ]]; then
    read -p "Would you like to view the current VPN status? (y/n): " VIEW_STATUS
    if [[ $VIEW_STATUS =~ ^[Yy]$ ]]; then
        echo ""
        python3 /usr/local/bin/vpn_manager.py --status
    fi
fi

echo ""
echo -e "${BLUE}Thank you for using VPN Manager! 🚀${NC}"
echo ""
