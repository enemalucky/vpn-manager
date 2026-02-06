#!/bin/bash
#
# Fix VPN After Reboot - Complete Remediation
# This script fixes IP forwarding and policy routing to survive reboots
#

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║         Fix VPN After Reboot - Complete Solution             ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (sudo)"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1: Enable IP Forwarding Permanently"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check current state
CURRENT_FORWARDING=$(cat /proc/sys/net/ipv4/ip_forward)
echo "Current IP forwarding: $CURRENT_FORWARDING"

# Enable immediately
echo "Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1

# Check if line exists in sysctl.conf (commented or not)
if grep -q "^#net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "Uncommenting IP forwarding in /etc/sysctl.conf..."
    sed -i 's/^#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/' /etc/sysctl.conf
elif grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf; then
    echo "IP forwarding already enabled in /etc/sysctl.conf"
else
    echo "Adding IP forwarding to /etc/sysctl.conf..."
    echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
fi

# Verify
NEW_FORWARDING=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$NEW_FORWARDING" = "1" ]; then
    echo "✅ IP forwarding enabled: $NEW_FORWARDING"
else
    echo "❌ Failed to enable IP forwarding"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2: Restore Policy Routing Rules"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if VPN config exists to get inside IPs
if [ -f /etc/vpn/config.json ]; then
    echo "Reading VPN configuration..."
    
    # Extract inside IP subnets
    SUBNETS=$(python3 << 'EOF'
import json
try:
    with open('/etc/vpn/config.json') as f:
        config = json.load(f)
        for ip in config.get('onprem_inside_ips', []):
            parts = ip.split('.')
            last_octet = int(parts[3])
            subnet_base = (last_octet // 4) * 4
            print(f'{parts[0]}.{parts[1]}.{parts[2]}.{subnet_base}/30')
except Exception as e:
    print('')
EOF
)
    
    if [ -n "$SUBNETS" ]; then
        echo "Found inside IP subnets:"
        echo "$SUBNETS"
        echo ""
        
        # Remove any existing rules (ignore errors)
        echo "Removing old policy routing rules..."
        while IFS= read -r subnet; do
            ip rule del to $subnet table main priority 100 2>/dev/null || true
        done <<< "$SUBNETS"
        
        # Add new rules
        echo "Adding policy routing rules..."
        while IFS= read -r subnet; do
            ip rule add to $subnet table main priority 100
            echo "  ✅ Added rule for $subnet"
        done <<< "$SUBNETS"
        
        # Flush route cache
        ip route flush cache
        
        echo "✅ Policy routing rules configured"
    else
        echo "⚠️  Could not extract inside IPs from config"
        echo "Using default subnets..."
        
        # Fallback to default subnets
        ip rule del to 169.254.55.52/30 table main priority 100 2>/dev/null || true
        ip rule del to 169.254.253.48/30 table main priority 100 2>/dev/null || true
        
        ip rule add to 169.254.55.52/30 table main priority 100
        ip rule add to 169.254.253.48/30 table main priority 100
        ip route flush cache
        
        echo "✅ Default policy routing rules configured"
    fi
else
    echo "⚠️  VPN config not found at /etc/vpn/config.json"
    echo "Using default subnets..."
    
    # Use default subnets
    ip rule del to 169.254.55.52/30 table main priority 100 2>/dev/null || true
    ip rule del to 169.254.253.48/30 table main priority 100 2>/dev/null || true
    
    ip rule add to 169.254.55.52/30 table main priority 100
    ip rule add to 169.254.253.48/30 table main priority 100
    ip route flush cache
    
    echo "✅ Default policy routing rules configured"
fi

# Verify rules
echo ""
echo "Current policy routing rules:"
ip rule show | grep 169.254

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3: Make Policy Routing Rules Persistent"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create directory if needed
mkdir -p /etc/vpn

# Create script to apply rules on boot
cat > /etc/vpn/apply_policy_routing.sh << 'EOFSCRIPT'
#!/bin/bash
# Apply VPN policy routing rules
# Auto-generated by fix_vpn_after_reboot.sh

# Read configuration
if [ -f /etc/vpn/config.json ]; then
    SUBNETS=$(python3 << 'EOF'
import json
try:
    with open('/etc/vpn/config.json') as f:
        config = json.load(f)
        for ip in config.get('onprem_inside_ips', []):
            parts = ip.split('.')
            last_octet = int(parts[3])
            subnet_base = (last_octet // 4) * 4
            print(f'{parts[0]}.{parts[1]}.{parts[2]}.{subnet_base}/30')
except:
    pass
EOF
)
    
    if [ -n "$SUBNETS" ]; then
        # Remove old rules
        while IFS= read -r subnet; do
            ip rule del to $subnet table main priority 100 2>/dev/null || true
        done <<< "$SUBNETS"
        
        # Add new rules
        while IFS= read -r subnet; do
            ip rule add to $subnet table main priority 100
        done <<< "$SUBNETS"
    else
        # Fallback to defaults
        ip rule del to 169.254.55.52/30 table main priority 100 2>/dev/null || true
        ip rule del to 169.254.253.48/30 table main priority 100 2>/dev/null || true
        ip rule add to 169.254.55.52/30 table main priority 100
        ip rule add to 169.254.253.48/30 table main priority 100
    fi
else
    # Use defaults if no config
    ip rule del to 169.254.55.52/30 table main priority 100 2>/dev/null || true
    ip rule del to 169.254.253.48/30 table main priority 100 2>/dev/null || true
    ip rule add to 169.254.55.52/30 table main priority 100
    ip rule add to 169.254.253.48/30 table main priority 100
fi

# Flush route cache
ip route flush cache

logger "VPN policy routing rules applied"
EOFSCRIPT

chmod +x /etc/vpn/apply_policy_routing.sh
echo "✅ Created /etc/vpn/apply_policy_routing.sh"

# Create systemd service
cat > /etc/systemd/system/vpn-policy-routing.service << 'EOFSERVICE'
[Unit]
Description=VPN Policy Routing Rules
After=network.target
Before=frr.service strongswan.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash /etc/vpn/apply_policy_routing.sh

[Install]
WantedBy=multi-user.target
EOFSERVICE

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable vpn-policy-routing.service

echo "✅ Created and enabled vpn-policy-routing.service"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4: Verify Route Lookup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Test route lookup
echo "Testing route lookup to 169.254.55.53:"
ROUTE_OUTPUT=$(ip route get 169.254.55.53 2>&1)
echo "$ROUTE_OUTPUT"

if echo "$ROUTE_OUTPUT" | grep -q "dev vti"; then
    echo "✅ Route uses VTI interface (CORRECT)"
elif echo "$ROUTE_OUTPUT" | grep -q "table 220"; then
    echo "❌ Route still uses table 220 (WRONG)"
    echo "Policy routing rules may not be working"
else
    echo "⚠️  Unexpected route output"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5: Test Connectivity to AWS Inside IPs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Testing ping to 169.254.55.53:"
if ping -c 3 -W 2 169.254.55.53 >/dev/null 2>&1; then
    echo "✅ Ping successful"
else
    echo "❌ Ping failed"
fi

echo ""
echo "Testing ping to 169.254.253.49:"
if ping -c 3 -W 2 169.254.253.49 >/dev/null 2>&1; then
    echo "✅ Ping successful"
else
    echo "❌ Ping failed"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6: Restart FRR to Establish BGP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "Restarting FRR..."
systemctl restart frr

echo "Waiting 15 seconds for BGP to establish..."
sleep 15

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 7: Verify BGP Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "BGP Summary:"
vtysh -c "show bgp summary"

echo ""
BGP_ESTABLISHED=$(vtysh -c "show bgp summary" 2>/dev/null | grep -c "Established")
if [ $BGP_ESTABLISHED -gt 0 ]; then
    echo "✅ BGP Sessions Established: $BGP_ESTABLISHED"
else
    echo "⚠️  No BGP sessions established yet"
    echo "BGP may need more time or there may be other issues"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 8: Check BGP Routes"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "BGP Routes:"
vtysh -c "show ip route bgp"

echo ""
ROUTES=$(vtysh -c "show ip route bgp" 2>/dev/null | grep -c "via")
if [ $ROUTES -gt 0 ]; then
    echo "✅ BGP Routes Received: $ROUTES"
else
    echo "⚠️  No BGP routes received yet"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Configuration Applied:"
echo "  ✅ IP forwarding enabled and persistent"
echo "  ✅ Policy routing rules configured"
echo "  ✅ Systemd service created for persistence"
echo "  ✅ FRR restarted"
echo ""
echo "Current Status:"
echo "  - IP Forwarding: $(cat /proc/sys/net/ipv4/ip_forward)"
echo "  - Policy Rules: $(ip rule show | grep -c 169.254) configured"
echo "  - BGP Sessions: $BGP_ESTABLISHED established"
echo "  - BGP Routes: $ROUTES received"
echo ""

if [ $BGP_ESTABLISHED -gt 0 ] && [ $ROUTES -gt 0 ]; then
    echo "🎉 SUCCESS! VPN is fully operational and will survive reboots!"
    echo ""
    echo "Next steps:"
    echo "  1. Test connectivity to AWS VPC resources"
    echo "  2. Verify traffic flows through VPN"
    echo "  3. Run: ./verify_vpn_complete.sh for full verification"
elif [ $BGP_ESTABLISHED -gt 0 ]; then
    echo "⚠️  BGP is up but no routes received yet"
    echo ""
    echo "Possible causes:"
    echo "  - Route propagation not enabled on AWS VPN"
    echo "  - No routes being advertised from AWS VPC"
    echo "  - Wait a bit longer for routes to propagate"
else
    echo "⚠️  BGP not established yet"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Wait another 30 seconds and check: vtysh -c 'show bgp summary'"
    echo "  2. Check FRR logs: journalctl -u frr -n 50"
    echo "  3. Verify ping works: ping 169.254.55.53"
    echo "  4. Run full diagnosis: ./diagnose_vpn_traffic.sh"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
