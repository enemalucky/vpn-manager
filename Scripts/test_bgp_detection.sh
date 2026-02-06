#!/bin/bash

# Test BGP Detection Logic
# This script tests if BGP session detection works correctly

echo "Testing BGP Detection Logic"
echo "=============================="
echo ""

# Get BGP output
BGP_OUTPUT=$(vtysh -c "show ip bgp summary" 2>/dev/null || vtysh -c "show bgp summary" 2>/dev/null || echo "")

if [ -z "$BGP_OUTPUT" ]; then
    echo "❌ Cannot get BGP output from vtysh"
    exit 1
fi

echo "BGP Summary Output:"
echo "-------------------"
echo "$BGP_OUTPUT"
echo ""
echo "-------------------"
echo ""

# Method 1: Look for lines with uptime (established sessions show uptime like "01:23:45" or "1d2h3m")
echo "Method 1: Detecting established sessions by uptime pattern"
ESTABLISHED_COUNT=$(echo "$BGP_OUTPUT" | grep -E "169\.254\." | grep -v "Connect" | grep -v "Active" | grep -v "Idle" | grep -v "never" | grep -E "[0-9]+:[0-9]+:[0-9]+|[0-9]+d[0-9]+h" | wc -l)
echo "Established sessions found: $ESTABLISHED_COUNT"
echo ""

# Method 2: Look for numeric values in State/PfxRcd column (established sessions have numbers, not text)
echo "Method 2: Detecting by numeric prefix count"
NUMERIC_COUNT=$(echo "$BGP_OUTPUT" | grep -E "169\.254\." | awk '{print $(NF-1)}' | grep -E "^[0-9]+$" | wc -l)
echo "Sessions with numeric prefix count: $NUMERIC_COUNT"
echo ""

# Show the actual neighbor lines
echo "Neighbor lines from BGP output:"
echo "$BGP_OUTPUT" | grep -E "169\.254\."
echo ""

# Detailed analysis
echo "Detailed Analysis:"
echo "------------------"
while IFS= read -r line; do
    if echo "$line" | grep -qE "169\.254\."; then
        NEIGHBOR=$(echo "$line" | awk '{print $1}')
        STATE=$(echo "$line" | awk '{print $(NF-1)}')
        
        echo "Neighbor: $NEIGHBOR"
        echo "  State/PfxRcd: $STATE"
        
        if echo "$line" | grep -qE "[0-9]+:[0-9]+:[0-9]+|[0-9]+d[0-9]+h"; then
            echo "  Status: ✓ ESTABLISHED (has uptime)"
        elif echo "$line" | grep -q "Connect"; then
            echo "  Status: ✗ Connecting"
        elif echo "$line" | grep -q "Active"; then
            echo "  Status: ✗ Active (trying to connect)"
        elif echo "$line" | grep -q "Idle"; then
            echo "  Status: ✗ Idle"
        elif echo "$line" | grep -q "never"; then
            echo "  Status: ✗ Never connected"
        elif echo "$STATE" | grep -qE "^[0-9]+$"; then
            echo "  Status: ✓ ESTABLISHED (has numeric prefix count)"
        else
            echo "  Status: ? Unknown"
        fi
        echo ""
    fi
done <<< "$BGP_OUTPUT"

echo "=============================="
echo "Summary:"
echo "  Method 1 (uptime pattern): $ESTABLISHED_COUNT established"
echo "  Method 2 (numeric count): $NUMERIC_COUNT established"
echo ""

if [ "$ESTABLISHED_COUNT" -gt 0 ] || [ "$NUMERIC_COUNT" -gt 0 ]; then
    echo "✓ BGP detection logic is working"
    exit 0
else
    echo "⚠️  No established sessions detected"
    echo "    This could mean:"
    echo "    1. BGP is not actually established yet"
    echo "    2. The detection logic needs adjustment"
    exit 1
fi
