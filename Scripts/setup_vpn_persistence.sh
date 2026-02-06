#!/bin/bash

# Setup VPN Persistence After Reboot
# Ensures all VPN components survive system reboots

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                               ║${NC}"
echo -e "${BLUE}║           Setup VPN Persistence After Reboot                  ║${NC}"
echo -e "${BLUE}║                                                               ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root${NC}"
    exit 1
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "1. Enable IP Forwarding Permanently"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Enable immediately
sysctl -w net.ipv4.ip_forward=1

# Make persistent in sysctl.conf
if grep -q "^#net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
elif ! grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi

# Enable in FRR configuration (remove "no ip forwarding" if present)
if [ -f /etc/frr/frr.conf ]; then
    if grep -q "^no ip forwarding" /etc/frr/frr.conf; then
        echo "Removing 'no ip forwarding' from FRR configuration..."
        sed -i 's/^no ip forwarding/ip forwarding/' /etc/frr/frr.conf
    elif ! grep -q "^ip forwarding" /etc/frr/frr.conf; then
        echo "Adding 'ip forwarding' to FRR configuration..."
        # Add after frr version line
        sed -i '/^frr version/a ip forwarding' /etc/frr/frr.conf
    fi
    
    # Also set via vtysh for immediate effect
    vtysh << EOF
configure terminal
ip forwarding
write memory
exit
EOF
fi

echo -e "${GREEN}✓ IP forwarding enabled in kernel and FRR${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "2. Add Static Routes to FRR Configuration"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Detect AWS inside IPs from VTI interfaces
if ip link show vti1 &>/dev/null && ip link show vti2 &>/dev/null; then
    VTI1_IP=$(ip addr show vti1 | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    VTI2_IP=$(ip addr show vti2 | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    
    if [ -n "$VTI1_IP" ] && [ -n "$VTI2_IP" ]; then
        # Calculate AWS peer IPs (subtract 1)
        AWS_IP1=$(echo $VTI1_IP | awk -F. '{print $1"."$2"."$3"."$4-1}')
        AWS_IP2=$(echo $VTI2_IP | awk -F. '{print $1"."$2"."$3"."$4-1}')
        
        echo "Detected AWS inside IPs:"
        echo "  Tunnel 1: $AWS_IP1"
        echo "  Tunnel 2: $AWS_IP2"
        
        # Check if static routes already exist in FRR config
        if grep -q "ip route $AWS_IP1/32 vti1" /etc/frr/frr.conf && \
           grep -q "ip route $AWS_IP2/32 vti2" /etc/frr/frr.conf; then
            echo -e "${GREEN}✓ Static routes already in FRR configuration${NC}"
        else
            echo "Adding static routes to FRR configuration..."
            
            # Backup FRR config
            cp /etc/frr/frr.conf /etc/frr/frr.conf.backup-$(date +%Y%m%d-%H%M%S)
            
            # Add static routes before "line vty" section
            if grep -q "^line vty" /etc/frr/frr.conf; then
                # Insert before "line vty"
                sed -i "/^line vty/i \\\n! Static routes for AWS inside IPs (critical for return traffic)\nip route $AWS_IP1/32 vti1\nip route $AWS_IP2/32 vti2\n" /etc/frr/frr.conf
            else
                # Append to end
                cat >> /etc/frr/frr.conf << EOF

! Static routes for AWS inside IPs (critical for return traffic)
ip route $AWS_IP1/32 vti1
ip route $AWS_IP2/32 vti2

line vty
exit
EOF
            fi
            
            echo -e "${GREEN}✓ Static routes added to /etc/frr/frr.conf${NC}"
        fi
        
        # Also add via vtysh for immediate effect
        vtysh << EOF
configure terminal
ip route $AWS_IP1/32 vti1
ip route $AWS_IP2/32 vti2
write memory
exit
EOF
        
        echo -e "${GREEN}✓ Static routes active and persistent${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not detect VTI IP addresses${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  VTI interfaces not found${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "3. Setup Policy Routing Persistence"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

mkdir -p /etc/vpn

# Create policy routing script
cat > /etc/vpn/apply_policy_routing.sh << 'EOFSCRIPT'
#!/bin/bash
# Apply VPN policy routing rules on boot

# Detect inside IP subnets from VTI interfaces
if ip link show vti1 &>/dev/null && ip link show vti2 &>/dev/null; then
    VTI1_IP=$(ip addr show vti1 | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    VTI2_IP=$(ip addr show vti2 | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
    
    if [ -n "$VTI1_IP" ] && [ -n "$VTI2_IP" ]; then
        # Calculate /30 subnets
        VTI1_PARTS=(${VTI1_IP//./ })
        VTI1_SUBNET_BASE=$(( (${VTI1_PARTS[3]} / 4) * 4 ))
        VTI1_SUBNET="${VTI1_PARTS[0]}.${VTI1_PARTS[1]}.${VTI1_PARTS[2]}.$VTI1_SUBNET_BASE/30"
        
        VTI2_PARTS=(${VTI2_IP//./ })
        VTI2_SUBNET_BASE=$(( (${VTI2_PARTS[3]} / 4) * 4 ))
        VTI2_SUBNET="${VTI2_PARTS[0]}.${VTI2_PARTS[1]}.${VTI2_PARTS[2]}.$VTI2_SUBNET_BASE/30"
        
        # Remove old rules
        ip rule del to $VTI1_SUBNET table main priority 100 2>/dev/null || true
        ip rule del to $VTI2_SUBNET table main priority 100 2>/dev/null || true
        
        # Add new rules
        ip rule add to $VTI1_SUBNET table main priority 100
        ip rule add to $VTI2_SUBNET table main priority 100
        
        ip route flush cache
        
        logger "VPN policy routing rules applied: $VTI1_SUBNET, $VTI2_SUBNET"
    fi
fi
EOFSCRIPT

chmod +x /etc/vpn/apply_policy_routing.sh

# Create systemd service
cat > /etc/systemd/system/vpn-policy-routing.service << 'EOFSERVICE'
[Unit]
Description=VPN Policy Routing Rules
After=network.target strongswan.service
Before=frr.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash /etc/vpn/apply_policy_routing.sh

[Install]
WantedBy=multi-user.target
EOFSERVICE

systemctl daemon-reload
systemctl enable vpn-policy-routing.service

echo -e "${GREEN}✓ Policy routing persistence configured${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "4. Setup IP Forwarding Enforcement Service"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Create script to ensure IP forwarding stays enabled
cat > /usr/local/bin/ensure_ip_forwarding.sh << 'EOFSCRIPT'
#!/bin/bash
# Ensure IP Forwarding Stays Enabled
sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
logger "VPN Gateway: IP forwarding enabled"
exit 0
EOFSCRIPT

chmod +x /usr/local/bin/ensure_ip_forwarding.sh

# Create systemd service that runs AFTER FRR
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

echo -e "${GREEN}✓ IP forwarding enforcement service configured${NC}"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "5. Configure Service Start Order"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Ensure proper service ordering
# Order: network → strongswan → policy-routing → frr → ip-forwarding

# Check if services exist and are enabled
for service in strongswan frr vpn-policy-routing vpn-ip-forwarding; do
    if systemctl is-enabled $service &>/dev/null; then
        echo -e "${GREEN}✓ $service is enabled${NC}"
    else
        if systemctl list-unit-files | grep -q "^$service.service"; then
            echo "Enabling $service..."
            systemctl enable $service
        fi
    fi
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "5. Verify Configuration"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo ""
echo "IP Forwarding:"
echo "  Current: $(cat /proc/sys/net/ipv4/ip_forward)"
echo "  Persistent: $(grep "^net.ipv4.ip_forward" /etc/sysctl.conf || echo "Not set")"

echo ""
echo "Static Routes in FRR:"
vtysh -c "show running-config" | grep "ip route 169.254" || echo "  None found"

echo ""
echo "Policy Routing Rules:"
ip rule show | grep 169.254 || echo "  None active (will be applied on next boot)"

echo ""
echo "Enabled Services:"
systemctl is-enabled strongswan 2>/dev/null && echo "  ✓ strongswan"
systemctl is-enabled frr 2>/dev/null && echo "  ✓ frr"
systemctl is-enabled vpn-policy-routing 2>/dev/null && echo "  ✓ vpn-policy-routing"
systemctl is-enabled vpn-ip-forwarding 2>/dev/null && echo "  ✓ vpn-ip-forwarding"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Summary"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${GREEN}✓ VPN persistence configured!${NC}"
echo ""
echo "What was configured:"
echo "  1. IP forwarding enabled in /etc/sysctl.conf"
echo "  2. Static routes added to /etc/frr/frr.conf"
echo "  3. Policy routing systemd service created"
echo "  4. IP forwarding enforcement service created"
echo "  5. Service start order configured"
echo ""
echo "On next reboot, the following will happen automatically:"
echo "  1. Network starts"
echo "  2. StrongSwan starts and establishes IPsec tunnels"
echo "  3. Policy routing rules are applied"
echo "  4. FRR starts and establishes BGP sessions"
echo "  5. IP forwarding is enforced (even if FRR tries to disable it)"
echo "  6. Static routes ensure traffic flows correctly"
echo ""
echo "To test reboot persistence:"
echo "  sudo reboot"
echo ""
echo "After reboot, verify with:"
echo "  sudo ./verify_vpn_complete.sh"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
