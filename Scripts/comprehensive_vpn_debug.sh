#!/bin/bash
#
# Comprehensive VPN Debugging Script
# Captures detailed information for troubleshooting
#

OUTPUT_FILE="/tmp/vpn_debug_$(date +%Y%m%d_%H%M%S).txt"

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║         Comprehensive VPN Debugging Tool                     ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Output will be saved to: $OUTPUT_FILE"
echo ""

# Redirect all output to file and console
exec > >(tee -a "$OUTPUT_FILE") 2>&1

echo "Debug started at: $(date)"
echo "Hostname: $(hostname)"
echo "IP Address: $(hostname -I)"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. IPTABLES MANGLE RULES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== MANGLE INPUT ==="
iptables -t mangle -L INPUT -n -v
echo ""
echo "=== MANGLE FORWARD ==="
iptables -t mangle -L FORWARD -n -v
echo ""
echo "=== MANGLE POSTROUTING ==="
iptables -t mangle -L POSTROUTING -n -v
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. IPTABLES FILTER RULES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
iptables -L -n -v
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. IPTABLES NAT RULES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
iptables -t nat -L -n -v
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. SOURCE/DESTINATION CHECK (AWS EC2)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
INSTANCE_ID=$(curl -s -m 2 http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null)
if [ -n "$INSTANCE_ID" ]; then
    echo "Instance ID: $INSTANCE_ID"
    aws ec2 describe-instance-attribute --instance-id $INSTANCE_ID --attribute sourceDestCheck --region us-east-1 2>/dev/null || echo "AWS CLI not available or not configured"
else
    echo "Not running on AWS EC2 or metadata service not accessible"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. IP FORWARDING AND KERNEL PARAMETERS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "IP Forwarding: $(cat /proc/sys/net/ipv4/ip_forward)"
echo ""
echo "RP Filter settings:"
sysctl -a 2>/dev/null | grep "\.rp_filter" | grep -E "vti|ens|eth|all|default"
echo ""
echo "Disable policy settings:"
sysctl -a 2>/dev/null | grep "disable_policy" | grep -E "vti|ens|eth"
echo ""
echo "Disable xfrm settings:"
sysctl -a 2>/dev/null | grep "disable_xfrm" | grep -E "vti|ens|eth"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. IPSEC STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
ipsec status
echo ""
echo "=== DETAILED STATUS ==="
ipsec statusall | head -150
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. XFRM STATE (IPsec SAs)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
ip xfrm state
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "8. XFRM POLICY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
ip xfrm policy
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "9. VTI INTERFACE DETAILS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
for vti in vti1 vti2; do
    if ip link show $vti >/dev/null 2>&1; then
        echo "=== $vti ==="
        ip -d link show $vti
        echo ""
        ip addr show $vti
        echo ""
        ip -s link show $vti
        echo ""
    fi
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "10. ROUTING TABLE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
ip route show
echo ""
echo "=== TABLE 220 (AWS EC2) ==="
ip route show table 220
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "11. POLICY ROUTING RULES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
ip rule show
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "12. BGP STATUS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
BGP_OUTPUT=$(vtysh -c "show ip bgp summary" 2>/dev/null || vtysh -c "show bgp summary" 2>/dev/null || echo "FRR/vtysh not available")
echo "$BGP_OUTPUT"

# Count established sessions
if [ "$BGP_OUTPUT" != "FRR/vtysh not available" ]; then
    BGP_ESTABLISHED=$(echo "$BGP_OUTPUT" | grep -E "169\.254\." | grep -v "Connect" | grep -v "Active" | grep -v "Idle" | grep -v "never" | grep -E "[0-9]+:[0-9]+:[0-9]+|[0-9]+d[0-9]+h" | wc -l)
    echo ""
    echo "BGP Sessions Established: $BGP_ESTABLISHED"
fi

echo ""
echo "=== BGP ROUTES ==="
vtysh -c "show ip route bgp" 2>/dev/null || echo "FRR/vtysh not available"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "13. IPSEC CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== /etc/ipsec.conf ==="
cat /etc/ipsec.conf
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "14. UPDOWN SCRIPT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [ -f /etc/ipsec.d/aws-updown.sh ]; then
    echo "=== /etc/ipsec.d/aws-updown.sh ==="
    cat /etc/ipsec.d/aws-updown.sh
elif [ -f /etc/ipsec-vti.sh ]; then
    echo "=== /etc/ipsec-vti.sh ==="
    cat /etc/ipsec-vti.sh
else
    echo "No updown script found"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "15. FRR CONFIGURATION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [ -f /etc/frr/frr.conf ]; then
    cat /etc/frr/frr.conf
else
    echo "FRR config not found"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "16. KERNEL LOGS (IPsec/VTI related)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
dmesg | grep -i "ipsec\|vti\|xfrm\|esp" | tail -50
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "17. SYSTEM LOGS (StrongSwan)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
journalctl -u strongswan -n 50 --no-pager
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "18. PACKET CAPTURE TEST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Starting packet capture on ens5 and vti1..."
echo "This will capture 10 packets or 10 seconds, whichever comes first"
echo ""

# Start captures in background
timeout 10 tcpdump -i ens5 -n -c 10 'host 52.223.2.21 or host 10.16.105.217' > /tmp/ens5_capture.txt 2>&1 &
PID1=$!

timeout 10 tcpdump -i vti1 -n -c 10 > /tmp/vti1_capture.txt 2>&1 &
PID2=$!

# Wait a moment for tcpdump to start
sleep 2

# Send test pings
echo "Sending 5 test pings to 10.16.105.217..."
ping -c 5 -W 2 10.16.105.217 > /tmp/ping_result.txt 2>&1

# Wait for captures to complete
sleep 3

# Show results
echo "=== PING RESULT ==="
cat /tmp/ping_result.txt
echo ""

echo "=== ENS5 CAPTURE (Physical Interface) ==="
cat /tmp/ens5_capture.txt 2>/dev/null || echo "No packets captured on ens5"
echo ""

echo "=== VTI1 CAPTURE (VTI Interface) ==="
cat /tmp/vti1_capture.txt 2>/dev/null || echo "No packets captured on vti1"
echo ""

# Cleanup
rm -f /tmp/ens5_capture.txt /tmp/vti1_capture.txt /tmp/ping_result.txt

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "19. INTERFACE STATISTICS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "=== ALL INTERFACES ==="
ip -s link show
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "20. ROUTE LOOKUP TEST"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Route to 10.16.105.217:"
ip route get 10.16.105.217
echo ""
echo "Route to 169.254.55.53 (AWS inside IP):"
ip route get 169.254.55.53
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Debug completed at: $(date)"
echo "Output saved to: $OUTPUT_FILE"
echo ""
echo "To view the full output:"
echo "  cat $OUTPUT_FILE"
echo ""
echo "To share this file:"
echo "  cat $OUTPUT_FILE | less"
echo ""
