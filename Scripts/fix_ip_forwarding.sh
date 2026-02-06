#!/bin/bash

# Fix IP Forwarding - Enable in both kernel and FRR
# This is critical for VPN gateway functionality

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                               ║${NC}"
echo -e "${BLUE}║              Fix IP Forwarding for VPN Gateway                ║${NC}"
echo -e "${BLUE}║                                                               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root${NC}"
    exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Current Status"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

CURRENT_FORWARDING=$(cat /proc/sys/net/ipv4/ip_forward)
echo "Kernel IP forwarding: $CURRENT_FORWARDING"

if [ -f /etc/frr/frr.conf ]; then
    if grep -q "^no ip forwarding" /etc/frr/frr.conf; then
        echo -e "FRR configuration: ${RED}DISABLED (no ip forwarding)${NC}"
        FRR_STATUS="disabled"
    elif grep -q "^ip forwarding" /etc/frr/frr.conf; then
        echo -e "FRR configuration: ${GREEN}ENABLED${NC}"
        FRR_STATUS="enabled"
    else
        echo -e "FRR configuration: ${YELLOW}NOT SET${NC}"
        FRR_STATUS="not_set"
    fi
else
    echo -e "FRR configuration: ${RED}NOT FOUND${NC}"
    FRR_STATUS="not_found"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Applying Fixes"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# 1. Enable in kernel immediately
echo "1. Enabling IP forwarding in kernel..."
sysctl -w net.ipv4.ip_forward=1
echo -e "   ${GREEN}✓ Enabled${NC}"

# 2. Make persistent in sysctl.conf
echo "2. Making persistent in /etc/sysctl.conf..."
if grep -q "^#net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    echo -e "   ${GREEN}✓ Uncommented existing line${NC}"
elif grep -q "^net.ipv4.ip_forward=0" /etc/sysctl.conf; then
    sed -i 's/^net.ipv4.ip_forward=0/net.ipv4.ip_forward=1/' /etc/sysctl.conf
    echo -e "   ${GREEN}✓ Changed 0 to 1${NC}"
elif ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    echo -e "   ${GREEN}✓ Added new line${NC}"
else
    echo -e "   ${GREEN}✓ Already configured${NC}"
fi

# 3. Fix FRR configuration file
if [ -f /etc/frr/frr.conf ]; then
    echo "3. Fixing FRR configuration file..."
    
    # Backup first
    cp /etc/frr/frr.conf /etc/frr/frr.conf.backup-$(date +%Y%m%d-%H%M%S)
    
    if grep -q "^no ip forwarding" /etc/frr/frr.conf; then
        sed -i 's/^no ip forwarding/ip forwarding/' /etc/frr/frr.conf
        echo -e "   ${GREEN}✓ Changed 'no ip forwarding' to 'ip forwarding'${NC}"
    elif ! grep -q "^ip forwarding" /etc/frr/frr.conf; then
        # Add after frr version line
        sed -i '/^frr version/a ip forwarding' /etc/frr/frr.conf
        echo -e "   ${GREEN}✓ Added 'ip forwarding' line${NC}"
    else
        echo -e "   ${GREEN}✓ Already configured${NC}"
    fi
else
    echo -e "   ${YELLOW}⚠️  FRR config not found${NC}"
fi

# 4. Apply via vtysh for immediate effect
echo "4. Applying via vtysh..."
if command -v vtysh &> /dev/null; then
    vtysh << EOF
configure terminal
ip forwarding
write memory
exit
EOF
    echo -e "   ${GREEN}✓ Applied via vtysh${NC}"
else
    echo -e "   ${YELLOW}⚠️  vtysh not available${NC}"
fi

# 5. Restart FRR to ensure changes take effect
echo "5. Restarting FRR service..."
if systemctl is-active --quiet frr; then
    systemctl restart frr
    echo -e "   ${GREEN}✓ FRR restarted${NC}"
    
    # Wait a moment for BGP to re-establish
    echo "   Waiting 10 seconds for BGP to re-establish..."
    sleep 10
else
    echo -e "   ${YELLOW}⚠️  FRR service not running${NC}"
fi

# 6. Install IP forwarding enforcement service
echo "6. Installing IP forwarding enforcement service..."

# Create script
cat > /usr/local/bin/ensure_ip_forwarding.sh << 'EOFSCRIPT'
#!/bin/bash
# Ensure IP Forwarding Stays Enabled
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
logger "VPN Gateway: IP forwarding enabled"
exit 0
EOFSCRIPT

chmod +x /usr/local/bin/ensure_ip_forwarding.sh

# Create systemd service
cat > /etc/systemd/system/vpn-ip-forwarding.service << 'EOFSERVICE'
[Unit]
Description=Ensure IP Forwarding for VPN Gateway
After=frr.service
Requires=frr.service
PartOf=frr.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/ensure_ip_forwarding.sh
ExecStartPost=/bin/sleep 2
ExecStartPost=/usr/local/bin/ensure_ip_forwarding.sh

[Install]
WantedBy=multi-user.target
EOFSERVICE

systemctl daemon-reload
systemctl enable vpn-ip-forwarding.service
systemctl start vpn-ip-forwarding.service

echo -e "   ${GREEN}✓ IP forwarding enforcement service installed and started${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Verification"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

NEW_FORWARDING=$(cat /proc/sys/net/ipv4/ip_forward)
echo "Kernel IP forwarding: $NEW_FORWARDING"

if [ "$NEW_FORWARDING" = "1" ]; then
    echo -e "${GREEN}✓ Kernel: IP forwarding is ENABLED${NC}"
else
    echo -e "${RED}✗ Kernel: IP forwarding is still DISABLED${NC}"
fi

echo ""
echo "sysctl.conf setting:"
grep "^net.ipv4.ip_forward" /etc/sysctl.conf || echo "Not found"

echo ""
if [ -f /etc/frr/frr.conf ]; then
    echo "FRR configuration:"
    grep "ip forwarding" /etc/frr/frr.conf || echo "Not found"
fi

echo ""
echo "Testing connectivity to AWS inside IPs..."
for ip in 169.254.55.53 169.254.253.49; do
    if ip route get $ip &>/dev/null; then
        echo -n "  Ping $ip: "
        if ping -c 2 -W 2 $ip &>/dev/null; then
            echo -e "${GREEN}✓ Success${NC}"
        else
            echo -e "${RED}✗ Failed${NC}"
        fi
    fi
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Summary"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ "$NEW_FORWARDING" = "1" ]; then
    echo -e "${GREEN}✓ IP forwarding is now enabled!${NC}"
    echo ""
    echo "Changes applied:"
    echo "  1. Kernel: IP forwarding enabled"
    echo "  2. sysctl.conf: Made persistent across reboots"
    echo "  3. FRR config: IP forwarding enabled"
    echo "  4. FRR service: Restarted with new configuration"
    echo ""
    echo "Next steps:"
    echo "  1. Test ping from on-premises server to AWS VPC"
    echo "  2. Verify BGP routes: vtysh -c 'show ip route bgp'"
    echo "  3. Check BGP status: vtysh -c 'show bgp summary'"
else
    echo -e "${RED}✗ IP forwarding could not be enabled${NC}"
    echo ""
    echo "Manual steps required:"
    echo "  1. Check system logs: journalctl -xe"
    echo "  2. Verify sysctl: sysctl -a | grep ip_forward"
    echo "  3. Check FRR logs: journalctl -u frr -n 50"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
