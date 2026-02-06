#!/bin/bash
#
# Complete VPN Verification Script
# Checks IPsec, VTI, Routing, and BGP
#

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║              Complete VPN Status Verification                 ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

# 1. Check IPsec Status
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. IPsec Tunnel Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ipsec status | grep -E "Tunnel|ESTABLISHED|INSTALLED" || echo "No tunnels found"

TUNNEL1_UP=$(ipsec status | grep -c "Tunnel1.*ESTABLISHED")
TUNNEL2_UP=$(ipsec status | grep -c "Tunnel2.*ESTABLISHED")

print_status $TUNNEL1_UP "Tunnel 1 IPsec"
print_status $TUNNEL2_UP "Tunnel 2 IPsec"

# 2. Check VTI Interfaces
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. VTI Interface Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ip addr show vti1 2>/dev/null | grep -E "vti1|inet "
ip addr show vti2 2>/dev/null | grep -E "vti2|inet "

VTI1_UP=$(ip link show vti1 2>/dev/null | grep -c "UP")
VTI2_UP=$(ip link show vti2 2>/dev/null | grep -c "UP")

print_status $VTI1_UP "VTI1 Interface"
print_status $VTI2_UP "VTI2 Interface"

# 3. Check Policy Routing
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Policy Routing Rules"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
ip rule show | grep -E "169.254|priority 100"

RULE1=$(ip rule show | grep -c "169.254.55.52/30")
RULE2=$(ip rule show | grep -c "169.254.253.48/30")

print_status $RULE1 "Policy rule for Tunnel 1"
print_status $RULE2 "Policy rule for Tunnel 2"

# 4. Check Route Lookup
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Route Lookup (Should use VTI, not table 220)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Route to 169.254.55.53:"
ip route get 169.254.55.53
echo ""
echo "Route to 169.254.253.49:"
ip route get 169.254.253.49

ROUTE1_OK=$(ip route get 169.254.55.53 | grep -c "dev vti1")
ROUTE2_OK=$(ip route get 169.254.253.49 | grep -c "dev vti2")

print_status $ROUTE1_OK "Route to Tunnel 1 uses VTI"
print_status $ROUTE2_OK "Route to Tunnel 2 uses VTI"

# 5. Test Connectivity
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. Connectivity Test"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Pinging 169.254.55.53 (Tunnel 1):"
ping -c 3 -W 2 169.254.55.53 | tail -2

echo ""
echo "Pinging 169.254.253.49 (Tunnel 2):"
ping -c 3 -W 2 169.254.253.49 | tail -2

PING1_OK=$(ping -c 3 -W 2 169.254.55.53 | grep -c "3 received")
PING2_OK=$(ping -c 3 -W 2 169.254.253.49 | grep -c "3 received")

print_status $PING1_OK "Ping to Tunnel 1"
print_status $PING2_OK "Ping to Tunnel 2"

# 6. Check VTI Traffic Counters
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. VTI Traffic Counters"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "vti1:"
ip -s link show vti1 | grep -A 2 "RX:"
echo ""
echo "vti2:"
ip -s link show vti2 | grep -A 2 "RX:"

VTI1_TX=$(ip -s link show vti1 | grep "TX:" -A 1 | tail -1 | awk '{print $2}')
VTI2_TX=$(ip -s link show vti2 | grep "TX:" -A 1 | tail -1 | awk '{print $2}')

if [ "$VTI1_TX" -gt 0 ]; then
    print_status 0 "VTI1 has outgoing traffic"
else
    print_status 1 "VTI1 has NO outgoing traffic"
fi

if [ "$VTI2_TX" -gt 0 ]; then
    print_status 0 "VTI2 has outgoing traffic"
else
    print_status 1 "VTI2 has NO outgoing traffic"
fi

# 7. Check FRR Status
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. FRR/BGP Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
systemctl is-active frr >/dev/null 2>&1
FRR_RUNNING=$?
print_status $FRR_RUNNING "FRR Service"

# 8. Check BGP Sessions
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8. BGP Session Status"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
BGP_OUTPUT=$(vtysh -c "show ip bgp summary" 2>/dev/null || vtysh -c "show bgp summary" 2>/dev/null || echo "Cannot connect to vtysh")
echo "$BGP_OUTPUT"

# Check for established sessions - look for uptime, not "Connect", "Active", "Idle", or "never"
BGP1_UP=$(echo "$BGP_OUTPUT" | grep "169.254.55.53" | grep -v "Connect" | grep -v "Active" | grep -v "Idle" | grep -v "never" | grep -E "[0-9]+:[0-9]+:[0-9]+|[0-9]+d[0-9]+h" | wc -l)
BGP2_UP=$(echo "$BGP_OUTPUT" | grep "169.254.253.49" | grep -v "Connect" | grep -v "Active" | grep -v "Idle" | grep -v "never" | grep -E "[0-9]+:[0-9]+:[0-9]+|[0-9]+d[0-9]+h" | wc -l)

print_status $BGP1_UP "BGP Session Tunnel 1"
print_status $BGP2_UP "BGP Session Tunnel 2"

# 9. Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "9. Overall Status Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

TOTAL_CHECKS=14
PASSED_CHECKS=$((TUNNEL1_UP + TUNNEL2_UP + VTI1_UP + VTI2_UP + RULE1 + RULE2 + ROUTE1_OK + ROUTE2_OK + PING1_OK + PING2_OK + FRR_RUNNING + BGP1_UP + BGP2_UP))

if [ "$VTI1_TX" -gt 0 ]; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
fi

echo ""
echo "Checks Passed: $PASSED_CHECKS / $TOTAL_CHECKS"
echo ""

if [ $PASSED_CHECKS -eq $TOTAL_CHECKS ]; then
    echo -e "${GREEN}🎉 All checks passed! VPN is fully operational!${NC}"
elif [ $PASSED_CHECKS -ge 10 ]; then
    echo -e "${YELLOW}⚠️  Most checks passed. Minor issues detected.${NC}"
else
    echo -e "${RED}❌ Multiple issues detected. VPN needs troubleshooting.${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
