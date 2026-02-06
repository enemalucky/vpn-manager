# Policy Routing Fix for AWS EC2 VPN

## Problem Summary

The VPN tunnels were establishing correctly (IPsec UP, VTI interfaces UP), but BGP was failing to connect. The root cause was **AWS EC2 policy routing** sending traffic to 169.254.x.x addresses through the default gateway instead of the VTI interfaces.

## Root Cause Analysis

### What Was Happening

1. **IPsec tunnels**: ✅ ESTABLISHED
2. **VTI interfaces**: ✅ UP with correct IPs
3. **Main routing table**: ✅ Had correct routes to 169.254.x.x via VTI
4. **Policy routing**: ❌ Overriding main table, sending traffic to table 220 (default gateway)
5. **BGP**: ❌ Could not connect because packets never reached AWS

### Evidence

```bash
# Main routing table had correct routes
ip route show
169.254.55.52/30 dev vti1 proto kernel scope link src 169.254.55.54
169.254.55.53 dev vti1 scope link

# But route lookup showed traffic going to wrong table
ip route get 169.254.55.53
169.254.55.53 via 192.168.12.1 dev ens5 table 220 src 192.168.12.49
                                        ^^^^^^^^^ WRONG!
```

### Why This Happened

AWS EC2 instances use policy routing (table 220) to ensure traffic goes through the correct network interface. This is configured via `ip rule` commands that have higher priority than the main routing table.

When you try to reach 169.254.x.x addresses, the kernel checks policy routing rules first, and if no specific rule exists, it uses table 220 which sends everything to the default gateway.

### Symptoms

- VTI TX errors increasing (packets trying to go out but failing)
- IPsec bytes_o = 0 (no outgoing traffic)
- IPsec bytes_i > 0 (AWS sending traffic, but we can't reply)
- BGP state = Connect (trying to connect but timing out)
- Ping fails with 0% success rate

## The Solution

Add policy routing rules with **higher priority** than table 220 to force traffic to 169.254.x.x subnets to use the main routing table (where VTI routes are).

### Commands

```bash
# Add policy routing rules (priority 100 is higher than table 220's default)
ip rule add to 169.254.55.52/30 table main priority 100
ip rule add to 169.254.253.48/30 table main priority 100

# Flush route cache to apply changes
ip route flush cache
```

### Verification

```bash
# Check policy rules are in place
ip rule show | grep 169.254

# Verify route lookup now uses VTI
ip route get 169.254.55.53
# Should show: 169.254.55.53 dev vti1 scope link src 169.254.55.54

# Test connectivity
ping -c 5 169.254.55.53
```

## Scripts Provided

### 1. `fix_policy_routing.sh`
- Adds policy routing rules
- Tests connectivity
- Checks BGP status
- **Run this first to fix the issue**

### 2. `make_routing_persistent.sh`
- Creates systemd service to apply rules on boot
- Ensures rules persist across reboots
- **Run this after confirming the fix works**

### 3. `verify_vpn_complete.sh`
- Comprehensive verification of all VPN components
- Checks IPsec, VTI, routing, and BGP
- Color-coded status output
- **Run this to verify everything is working**

## Step-by-Step Fix

1. **Apply the fix:**
   ```bash
   sudo ./fix_policy_routing.sh
   ```

2. **Verify it works:**
   ```bash
   sudo ./verify_vpn_complete.sh
   ```

3. **Make it persistent:**
   ```bash
   sudo ./make_routing_persistent.sh
   ```

## Expected Results After Fix

- ✅ Ping to 169.254.55.53 succeeds
- ✅ Ping to 169.254.253.49 succeeds
- ✅ VTI TX counters increase (outgoing traffic)
- ✅ IPsec bytes_o increases (encrypted traffic going out)
- ✅ BGP state changes to "Established"
- ✅ BGP routes are exchanged

## If BGP Still Doesn't Work After Fix

If ping works but BGP still fails, check:

1. **AWS Security Group**: Must allow TCP port 179 inbound/outbound
2. **AWS Network ACLs**: Must allow TCP port 179 inbound/outbound
3. **BGP Configuration**: Verify ASN numbers match AWS configuration
4. **BGP Logs**: Check for authentication or configuration errors
   ```bash
   sudo journalctl -u frr -n 100
   vtysh -c "show bgp neighbors"
   ```

## Technical Details

### Policy Routing Priority

Lower priority numbers = higher priority:
- Priority 0: Local routes
- Priority 100: Our VTI rules (added by fix)
- Priority 32766: Main table (default)
- Priority 32767: Default table

AWS EC2 adds rules for table 220 with priority between 32766-32767, so our priority 100 rules take precedence.

### Why Not Modify Table 220?

Table 220 is managed by AWS and may be regenerated. Adding higher-priority rules to use the main table is the correct approach.

### VTI Marks and IPsec

The IPsec configuration uses marks (mark=1, mark=2) to bind IPsec SAs to VTI interfaces. This is separate from routing and works correctly. The routing issue was preventing packets from reaching the VTI interfaces in the first place.

## Integration with VPN Manager

The VPN Manager tool should be updated to automatically add these policy routing rules during deployment. This will be added in the next version.

## References

- AWS VPN Documentation: https://docs.aws.amazon.com/vpn/
- Linux Policy Routing: `man ip-rule`
- VTI Interfaces: https://wiki.strongswan.org/projects/strongswan/wiki/RouteBasedVPN
