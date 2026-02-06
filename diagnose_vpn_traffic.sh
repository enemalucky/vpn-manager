#!/bin/bash
#
# Comprehensive VPN Traffic Diagnosis
# Identifies why traffic is not passing through VPN
#

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║           VPN Traffic Diagnosis Tool                         ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}❌ Please run as root (sudo)${NC}"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. IPsec Tunnel Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ipsec status
echo ""
TUNNELS_UP=$(ipsec status | grep -c "ESTABLISHED")
echo -e "${BLUE}Tunnels Established: $TUNNELS_UP${NC}"

if [ $TUNNELS_UP -eq 0 ]; then
    echo -e "${RED}❌ CRITICAL: No IPsec tunnels are up!${NC}"
    echo "Fix: Check IPsec configuration and restart strongswan"
    exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. BGP Session Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
BGP_OUTPUT=$(vtysh -c "show bgp summary" 2>/dev/null || vtysh -c "show ip bgp summary" 2>/dev/null)
echo "$BGP_OUTPUT"
echo ""

# Count established sessions - look for numeric values in State/PfxRcd column (not "Connect", "Active", "Idle")
BGP_UP=$(echo "$BGP_OUTPUT" | grep -E "169\.254\." | grep -v "Connect" | grep -v "Active" | grep -v "Idle" | grep -v "never" | grep -E "[0-9]+\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+[0-9]+\s+[0-9]+:[0-9]+:[0-9]+" | wc -l)
echo -e "${BLUE}BGP Sessions Established: $BGP_UP${NC}"

if [ $BGP_UP -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No BGP sessions fully established yet${NC}"
    echo "Check if sessions show 'Connect', 'Active', or 'Idle' state"
else
    echo -e "${GREEN}✓ BGP sessions are established${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. BGP Routes Received"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
vtysh -c "show ip route bgp"
echo ""
ROUTES=$(vtysh -c "show ip route bgp" 2>/dev/null | grep -c "via")
echo -e "${BLUE}BGP Routes in Routing Table: $ROUTES${NC}"

if [ $ROUTES -eq 0 ]; then
    echo -e "${RED}❌ CRITICAL: No BGP routes received from AWS!${NC}"
    echo "Possible causes:"
    echo "  - BGP not advertising routes from AWS side"
    echo "  - Route propagation disabled on AWS VPN"
    echo "  - BGP filters blocking routes"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Complete Routing Table"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ip route show
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. VTI Interface Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ip addr show | grep -A 3 "vti"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. VTI Traffic Counters"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
for vti in vti1 vti2; do
    if ip link show $vti >/dev/null 2>&1; then
        echo "$vti:"
        ip -s link show $vti | grep -A 2 "RX:"
        echo ""
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. IPsec Traffic Statistics"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ip -s xfrm state | grep -E "src|dst|bytes|packets" | head -20
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8. IP Forwarding Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
FORWARDING=$(cat /proc/sys/net/ipv4/ip_forward)
echo "IPv4 Forwarding: $FORWARDING"

if [ "$FORWARDING" != "1" ]; then
    echo -e "${RED}❌ CRITICAL: IP forwarding is DISABLED!${NC}"
    echo "This prevents traffic from being routed through the VPN"
    echo "Fix: sysctl -w net.ipv4.ip_forward=1"
else
    echo -e "${GREEN}✅ IP forwarding is enabled${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "9. Source/Destination Check (AWS EC2)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if curl -s -m 2 http://169.254.169.254/latest/meta-data/instance-id >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Running on AWS EC2${NC}"
    echo "Source/Destination Check must be DISABLED for VPN gateway"
    echo ""
    echo "To check/disable:"
    echo "  AWS Console → EC2 → Select Instance → Actions → Networking → Change Source/Dest. Check → Disable"
    echo ""
    echo "Or using AWS CLI:"
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
    echo "  aws ec2 modify-instance-attribute --instance-id $INSTANCE_ID --no-source-dest-check"
else
    echo "Not running on AWS EC2 (or metadata service not accessible)"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "10. NAT/Masquerading Rules"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
iptables -t nat -L -n -v | grep -E "MASQUERADE|SNAT"
echo ""
NAT_RULES=$(iptables -t nat -L -n -v | grep -c "MASQUERADE\|SNAT")
if [ $NAT_RULES -eq 0 ]; then
    echo -e "${YELLOW}⚠️  No NAT/Masquerading rules found${NC}"
    echo "If this is a NAT gateway, you may need masquerading rules"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "11. Firewall Rules (iptables)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "FORWARD chain:"
iptables -L FORWARD -n -v | head -10
echo ""
DROP_RULES=$(iptables -L FORWARD -n -v | grep -c "DROP")
if [ $DROP_RULES -gt 0 ]; then
    echo -e "${RED}❌ WARNING: Found DROP rules in FORWARD chain${NC}"
    echo "These may be blocking VPN traffic"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "12. Test Connectivity to AWS VPC"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Try to get VPC CIDR from BGP routes
VPC_CIDR=$(vtysh -c "show ip route bgp" 2>/dev/null | grep "via" | head -1 | awk '{print $1}')

if [ -n "$VPC_CIDR" ]; then
    # Extract first IP from CIDR
    TEST_IP=$(echo $VPC_CIDR | cut -d'/' -f1)
    echo "Testing connectivity to AWS VPC: $TEST_IP"
    echo ""
    
    ping -c 5 -W 2 $TEST_IP
    PING_RESULT=$?
    
    if [ $PING_RESULT -eq 0 ]; then
        echo -e "${GREEN}✅ SUCCESS: Can reach AWS VPC!${NC}"
    else
        echo -e "${RED}❌ FAILED: Cannot reach AWS VPC${NC}"
        echo ""
        echo "Troubleshooting steps:"
        echo "1. Check if routes are in routing table"
        echo "2. Verify IP forwarding is enabled"
        echo "3. Check AWS Security Groups allow ICMP"
        echo "4. Verify Source/Dest check is disabled on EC2"
    fi
else
    echo -e "${YELLOW}⚠️  No BGP routes found to test${NC}"
    echo "Cannot determine AWS VPC CIDR to test"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "13. Traceroute to AWS VPC"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$TEST_IP" ]; then
    echo "Traceroute to $TEST_IP:"
    traceroute -n -m 5 $TEST_IP 2>/dev/null || echo "traceroute not installed"
else
    echo "No test IP available"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "14. Check AWS Security Groups (Reminder)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Verify AWS Security Groups allow traffic:"
echo ""
echo "On-Premises Gateway Security Group:"
echo "  - Inbound: Allow UDP 500, 4500 from AWS VPN endpoints"
echo "  - Inbound: Allow all traffic from VPC CIDR"
echo "  - Outbound: Allow all traffic"
echo ""
echo "AWS VPC Resources Security Groups:"
echo "  - Inbound: Allow traffic from on-premises CIDR"
echo "  - Example: Allow ICMP, TCP 22, TCP 80, TCP 443"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "15. Summary & Recommendations"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Analyze issues
ISSUES=()

if [ $TUNNELS_UP -eq 0 ]; then
    ISSUES+=("IPsec tunnels are down")
fi

if [ $BGP_UP -eq 0 ]; then
    ISSUES+=("BGP sessions not established")
fi

if [ $ROUTES -eq 0 ]; then
    ISSUES+=("No BGP routes received from AWS")
fi

if [ "$FORWARDING" != "1" ]; then
    ISSUES+=("IP forwarding is disabled")
fi

if [ ${#ISSUES[@]} -eq 0 ]; then
    echo -e "${GREEN}✅ All basic checks passed${NC}"
    echo ""
    echo "If traffic still doesn't work, check:"
    echo "  1. AWS Security Groups"
    echo "  2. AWS Network ACLs"
    echo "  3. Source/Destination Check on EC2 instance"
    echo "  4. Route propagation enabled on AWS VPN"
    echo "  5. Firewall rules on destination hosts"
else
    echo -e "${RED}❌ Found ${#ISSUES[@]} issue(s):${NC}"
    for issue in "${ISSUES[@]}"; do
        echo "  - $issue"
    done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
