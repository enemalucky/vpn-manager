#!/bin/bash
#
# Test Fresh VPN Manager Deployment
# This script tests the updated VPN Manager with automatic policy routing
#

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║         Test Fresh VPN Manager Deployment                    ║"
echo "║         (With Automatic Policy Routing)                       ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root (sudo)${NC}"
    exit 1
fi

# Check if this is AWS EC2
echo "🔍 Checking environment..."
if [ -f /sys/hypervisor/uuid ] && grep -q ec2 /sys/hypervisor/uuid 2>/dev/null; then
    echo -e "${GREEN}✅ Running on AWS EC2${NC}"
    IS_EC2=true
elif curl -s -m 2 http://169.254.169.254/latest/meta-data/instance-id >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Running on AWS EC2${NC}"
    IS_EC2=true
else
    echo -e "${YELLOW}⚠️  Not running on AWS EC2 (policy routing may not be needed)${NC}"
    IS_EC2=false
fi

# Check if VPN Manager is installed
echo ""
echo "🔍 Checking VPN Manager installation..."
if [ -f /usr/local/bin/vpn_manager.py ]; then
    echo -e "${GREEN}✅ VPN Manager is installed${NC}"
else
    echo -e "${RED}❌ VPN Manager not found${NC}"
    echo "Please run: sudo ./install_vpn_manager.sh"
    exit 1
fi

# Check if configuration exists
echo ""
echo "🔍 Checking VPN configuration..."
if [ -f /etc/vpn/config.json ]; then
    echo -e "${GREEN}✅ Configuration found${NC}"
    
    # Show inside IPs
    echo ""
    echo "📋 Inside IP Configuration:"
    python3 << 'EOF'
import json
with open('/etc/vpn/config.json') as f:
    config = json.load(f)
    print(f"  AWS Inside IPs: {', '.join(config.get('aws_inside_ips', []))}")
    print(f"  On-Prem Inside IPs: {', '.join(config.get('onprem_inside_ips', []))}")
EOF
else
    echo -e "${RED}❌ Configuration not found${NC}"
    echo "Please run VPN Manager setup first"
    exit 1
fi

# Check if VTI setup script exists
echo ""
echo "🔍 Checking VTI setup script..."
if [ -f /etc/vpn/setup_vti.sh ]; then
    echo -e "${GREEN}✅ VTI setup script found${NC}"
    
    # Check if it contains policy routing rules
    if grep -q "ip rule add" /etc/vpn/setup_vti.sh; then
        echo -e "${GREEN}✅ Script contains policy routing rules${NC}"
    else
        echo -e "${RED}❌ Script does NOT contain policy routing rules${NC}"
        echo "This is an old version. Please regenerate configuration."
        exit 1
    fi
else
    echo -e "${RED}❌ VTI setup script not found${NC}"
    exit 1
fi

# Show the policy routing section
echo ""
echo "📋 Policy Routing Configuration in VTI Script:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
grep -A 10 "policy routing" /etc/vpn/setup_vti.sh | head -15
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check current policy routing rules
echo ""
echo "🔍 Checking current policy routing rules..."
RULES=$(ip rule show | grep -c "169.254")
if [ $RULES -gt 0 ]; then
    echo -e "${GREEN}✅ Found $RULES policy routing rule(s)${NC}"
    ip rule show | grep "169.254"
else
    echo -e "${YELLOW}⚠️  No policy routing rules found${NC}"
    if [ "$IS_EC2" = true ]; then
        echo "This is required on AWS EC2. Rules should be added by VTI setup."
    fi
fi

# Check if VTI interfaces exist
echo ""
echo "🔍 Checking VTI interfaces..."
VTI_COUNT=$(ip link show | grep -c "vti")
if [ $VTI_COUNT -gt 0 ]; then
    echo -e "${GREEN}✅ Found $VTI_COUNT VTI interface(s)${NC}"
    ip link show | grep "vti" | head -5
else
    echo -e "${YELLOW}⚠️  No VTI interfaces found${NC}"
    echo "Run: sudo /etc/vpn/setup_vti.sh"
fi

# If on EC2 and VTI exists, test route lookup
if [ "$IS_EC2" = true ] && [ $VTI_COUNT -gt 0 ]; then
    echo ""
    echo "🔍 Testing route lookup (AWS EC2 specific)..."
    
    # Get first inside IP from config
    FIRST_AWS_IP=$(python3 -c "
import json
with open('/etc/vpn/config.json') as f:
    config = json.load(f)
    ips = config.get('aws_inside_ips', [])
    print(ips[0] if ips else '')
")
    
    if [ -n "$FIRST_AWS_IP" ]; then
        echo "Testing route to: $FIRST_AWS_IP"
        ROUTE_OUTPUT=$(ip route get $FIRST_AWS_IP 2>&1)
        echo "$ROUTE_OUTPUT"
        
        if echo "$ROUTE_OUTPUT" | grep -q "dev vti"; then
            echo -e "${GREEN}✅ Route uses VTI interface (CORRECT)${NC}"
        elif echo "$ROUTE_OUTPUT" | grep -q "table 220"; then
            echo -e "${RED}❌ Route uses table 220 (WRONG - policy routing not working)${NC}"
            echo "Policy routing rules may not be applied correctly"
        else
            echo -e "${YELLOW}⚠️  Unexpected route output${NC}"
        fi
    fi
fi

# Check IPsec status
echo ""
echo "🔍 Checking IPsec status..."
if systemctl is-active --quiet strongswan; then
    echo -e "${GREEN}✅ StrongSwan is running${NC}"
    
    TUNNELS=$(ipsec status 2>/dev/null | grep -c "ESTABLISHED")
    if [ $TUNNELS -gt 0 ]; then
        echo -e "${GREEN}✅ $TUNNELS IPsec tunnel(s) established${NC}"
    else
        echo -e "${YELLOW}⚠️  No IPsec tunnels established${NC}"
    fi
else
    echo -e "${RED}❌ StrongSwan is not running${NC}"
fi

# Check FRR/BGP status
echo ""
echo "🔍 Checking BGP status..."
if systemctl is-active --quiet frr; then
    echo -e "${GREEN}✅ FRR is running${NC}"
    
    BGP_OUTPUT=$(vtysh -c "show bgp summary" 2>/dev/null)
    if echo "$BGP_OUTPUT" | grep -q "Established"; then
        SESSIONS=$(echo "$BGP_OUTPUT" | grep -c "Established")
        echo -e "${GREEN}✅ $SESSIONS BGP session(s) established${NC}"
    else
        echo -e "${YELLOW}⚠️  No BGP sessions established${NC}"
    fi
else
    echo -e "${RED}❌ FRR is not running${NC}"
fi

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

CHECKS_PASSED=0
CHECKS_TOTAL=6

# Count passed checks
[ -f /usr/local/bin/vpn_manager.py ] && CHECKS_PASSED=$((CHECKS_PASSED + 1))
[ -f /etc/vpn/config.json ] && CHECKS_PASSED=$((CHECKS_PASSED + 1))
grep -q "ip rule add" /etc/vpn/setup_vti.sh 2>/dev/null && CHECKS_PASSED=$((CHECKS_PASSED + 1))
[ $RULES -gt 0 ] && CHECKS_PASSED=$((CHECKS_PASSED + 1))
[ $VTI_COUNT -gt 0 ] && CHECKS_PASSED=$((CHECKS_PASSED + 1))
systemctl is-active --quiet strongswan && CHECKS_PASSED=$((CHECKS_PASSED + 1))

echo ""
echo "Checks Passed: $CHECKS_PASSED / $CHECKS_TOTAL"
echo ""

if [ $CHECKS_PASSED -eq $CHECKS_TOTAL ]; then
    echo -e "${GREEN}🎉 All checks passed! VPN Manager is properly configured with automatic policy routing!${NC}"
elif [ $CHECKS_PASSED -ge 4 ]; then
    echo -e "${YELLOW}⚠️  Most checks passed. Some components may need attention.${NC}"
else
    echo -e "${RED}❌ Multiple issues detected. Please review the output above.${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "For complete verification, run:"
echo "  sudo ./verify_vpn_complete.sh"
echo ""
