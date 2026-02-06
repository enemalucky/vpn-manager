#!/bin/bash
#
# Fix Policy Routing for VTI Traffic
# This forces traffic to AWS inside IPs to use main routing table instead of table 220
#

echo "🔧 Fixing policy routing for VTI traffic..."

# Check current policy routing rules
echo ""
echo "📊 Current policy routing rules:"
ip rule show

echo ""
echo "📊 Current route lookup for AWS IPs:"
ip route get 169.254.55.53
ip route get 169.254.253.49

# Add policy routing rules with high priority to force VTI traffic to main table
echo ""
echo "➕ Adding policy routing rules..."

# Remove any existing rules for these subnets (ignore errors if they don't exist)
ip rule del to 169.254.55.52/30 table main priority 100 2>/dev/null || true
ip rule del to 169.254.253.48/30 table main priority 100 2>/dev/null || true

# Add new rules with priority 100 (higher priority than table 220)
ip rule add to 169.254.55.52/30 table main priority 100
ip rule add to 169.254.253.48/30 table main priority 100

echo "✅ Policy routing rules added"

# Flush route cache to apply changes
ip route flush cache

echo ""
echo "📊 New policy routing rules:"
ip rule show | grep -E "169.254|priority"

echo ""
echo "📊 New route lookup for AWS IPs:"
ip route get 169.254.55.53
ip route get 169.254.253.49

# Test connectivity
echo ""
echo "🔍 Testing connectivity to AWS inside IPs..."
echo ""
echo "Testing Tunnel 1 (169.254.55.53):"
ping -c 5 -W 2 169.254.55.53

echo ""
echo "Testing Tunnel 2 (169.254.253.49):"
ping -c 5 -W 2 169.254.253.49

# Check VTI traffic counters
echo ""
echo "📊 VTI traffic counters:"
echo "vti1:"
ip -s link show vti1 | grep -A 2 "RX:"
echo ""
echo "vti2:"
ip -s link show vti2 | grep -A 2 "RX:"

# Wait for BGP to establish
echo ""
echo "⏳ Waiting 15 seconds for BGP to establish..."
sleep 15

# Check BGP status
echo ""
echo "📊 BGP Status:"
vtysh -c "show bgp summary"

echo ""
echo "📊 BGP Neighbors Detail:"
vtysh -c "show bgp neighbors" | grep -E "BGP state|Connections established|Last reset"

echo ""
echo "✅ Policy routing fix complete!"
echo ""
echo "If ping works but BGP still doesn't establish, check:"
echo "  1. AWS Security Group allows TCP port 179"
echo "  2. AWS Network ACLs allow TCP port 179"
echo "  3. Check BGP logs: sudo journalctl -u frr -n 50"
