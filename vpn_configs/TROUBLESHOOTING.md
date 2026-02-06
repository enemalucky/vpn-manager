# VPN Troubleshooting Guide

Comprehensive troubleshooting guide for AWS Site-to-Site VPN with StrongSwan and FRR.

## Quick Diagnostics

Run these commands first to get an overview:

```bash
# Overall status
sudo /usr/local/bin/vpn_health_check.py

# IPsec status
sudo ipsec status

# BGP status
sudo vtysh -c "show bgp summary"

# VTI interfaces
ip addr show vti1
ip addr show vti2

# Recent logs
sudo journalctl -u strongswan --since "10 minutes ago"
sudo journalctl -u frr --since "10 minutes ago"
```

---

## Common Issues

### Issue 1: Tunnels Not Establishing

**Symptoms:**
```
sudo ipsec status
# Shows: no matching CHILD_SA found
```

**Possible Causes & Solutions:**

#### A. Wrong Pre-Shared Key
```bash
# Check secrets file
sudo cat /etc/ipsec.secrets

# Verify PSK matches AWS configuration
# Re-download AWS VPN config if unsure
```

**Fix:**
```bash
# Edit secrets file
sudo nano /etc/ipsec.secrets

# Update PSK, then restart
sudo ipsec restart
```

#### B. Firewall Blocking
```bash
# Check if ports are open
sudo netstat -tulpn | grep -E '500|4500'

# Test connectivity to AWS endpoint
nc -vzu <aws_tunnel_outside_ip> 500
nc -vzu <aws_tunnel_outside_ip> 4500
```

**Fix:**
```bash
# Allow IKE (UDP 500)
sudo iptables -A INPUT -p udp --dport 500 -j ACCEPT
sudo iptables -A OUTPUT -p udp --sport 500 -j ACCEPT

# Allow NAT-T (UDP 4500)
sudo iptables -A INPUT -p udp --dport 4500 -j ACCEPT
sudo iptables -A OUTPUT -p udp --sport 4500 -j ACCEPT

# Allow ESP (protocol 50)
sudo iptables -A INPUT -p esp -j ACCEPT
sudo iptables -A OUTPUT -p esp -j ACCEPT

# Save rules
sudo iptables-save > /etc/iptables/rules.v4
```

#### C. Wrong Outside IP Address
```bash
# Verify configuration
sudo grep "right=" /etc/ipsec.conf

# Should match AWS tunnel outside IPs
# Check AWS Console: VPC → Site-to-Site VPN Connections
```

**Fix:**
```bash
# Edit vpn_config.json
nano vpn_config.json

# Update tunnel1_outside_ip and tunnel2_outside_ip
# Regenerate configuration
python3 vpn_optimizer.py --generate

# Redeploy
sudo ./deploy_vpn.sh
```

#### D. NAT Issues
```bash
# Check if behind NAT
curl ifconfig.me

# If different from configured public IP, update
```

**Fix:**
```bash
# Update left= in ipsec.conf to use %any or %defaultroute
# Or configure NAT-T properly
```

---

### Issue 2: BGP Not Establishing

**Symptoms:**
```
sudo vtysh -c "show bgp summary"
# Shows: Active or Connect state (not Established)
```

**Possible Causes & Solutions:**

#### A. VTI Interfaces Down
```bash
# Check VTI status
ip addr show vti1
ip addr show vti2

# Should show: state UP
```

**Fix:**
```bash
# Bring up VTI interfaces
sudo ip link set vti1 up
sudo ip link set vti2 up

# Or run setup script
sudo /usr/local/bin/setup_vti.sh
```

#### B. Wrong BGP ASN
```bash
# Check configured ASN
sudo vtysh -c "show running-config" | grep "router bgp"

# Should match your on-prem ASN
# Check neighbor ASN
sudo vtysh -c "show running-config" | grep "remote-as"

# Should match AWS ASN (usually 64512)
```

**Fix:**
```bash
# Edit vpn_config.json
nano vpn_config.json

# Update bgp_asn values
# Regenerate and redeploy
python3 vpn_optimizer.py --generate
sudo cp vpn_configs/frr.conf /etc/frr/frr.conf
sudo systemctl restart frr
```

#### C. Wrong Tunnel IP Addresses
```bash
# Check configured IPs
ip addr show vti1
ip addr show vti2

# Should match AWS inside tunnel IPs
```

**Fix:**
```bash
# Edit vpn_config.json with correct inside IPs
# Regenerate VTI setup
python3 vpn_optimizer.py --generate
sudo /usr/local/bin/setup_vti.sh
sudo systemctl restart frr
```

#### D. BGP Not Enabled in FRR
```bash
# Check if BGP daemon is running
sudo systemctl status frr
cat /etc/frr/daemons | grep bgpd
```

**Fix:**
```bash
# Enable BGP daemon
sudo sed -i 's/bgpd=no/bgpd=yes/' /etc/frr/daemons
sudo systemctl restart frr
```

---

### Issue 3: Routes Not Being Received

**Symptoms:**
```
sudo vtysh -c "show ip route"
# Missing expected AWS routes
```

**Possible Causes & Solutions:**

#### A. BGP Not Advertising Routes
```bash
# Check what routes are being advertised
sudo vtysh -c "show ip bgp neighbors 169.254.10.1 advertised-routes"
```

**Fix:**
```bash
# Access FRR shell
sudo vtysh

# Add network statements
configure terminal
router bgp <your_asn>
address-family ipv4 unicast
network 192.168.0.0/16
exit
exit
write memory
```

#### B. Route Filtering
```bash
# Check route-maps
sudo vtysh -c "show running-config" | grep -A 10 "route-map"
```

**Fix:**
```bash
# Adjust route-maps if too restrictive
sudo vtysh
configure terminal
# Modify route-maps as needed
```

#### C. AWS Route Propagation Disabled
- Check AWS Console: VPC → Route Tables
- Ensure "Route Propagation" is enabled for VGW/TGW

---

### Issue 4: Connectivity Issues Despite Established Tunnels

**Symptoms:**
- IPsec: ESTABLISHED
- BGP: Established
- But can't ping AWS resources

**Possible Causes & Solutions:**

#### A. Routing Issues
```bash
# Check if routes exist
ip route show

# Should see routes via vti1/vti2
```

**Fix:**
```bash
# Check BGP routes
sudo vtysh -c "show ip route bgp"

# If routes in BGP but not in kernel:
sudo vtysh
configure terminal
ip protocol bgp route-map ALLOW-ALL
exit
write memory
```

#### B. Security Groups / NACLs
- Check AWS Console
- Ensure security groups allow traffic from on-prem CIDR
- Verify NACLs are not blocking

#### C. IPsec Policy Issues
```bash
# Check IPsec policies
ip xfrm policy
ip xfrm state

# Should show policies for 0.0.0.0/0
```

**Fix:**
```bash
# Disable policy checking on VTI
sudo sysctl -w net.ipv4.conf.vti1.disable_policy=1
sudo sysctl -w net.ipv4.conf.vti2.disable_policy=1

# Make persistent
echo "net.ipv4.conf.vti1.disable_policy=1" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.conf.vti2.disable_policy=1" | sudo tee -a /etc/sysctl.conf
```

#### D. MTU Issues
```bash
# Test with different packet sizes
ping -M do -s 1400 <aws_ip>
ping -M do -s 1300 <aws_ip>
```

**Fix:**
```bash
# Reduce MTU on VTI interfaces
sudo ip link set vti1 mtu 1400
sudo ip link set vti2 mtu 1400

# Enable MSS clamping
sudo iptables -t mangle -A FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
```

---

### Issue 5: Tunnel Flapping

**Symptoms:**
```
sudo journalctl -u strongswan -f
# Shows repeated up/down events
```

**Possible Causes & Solutions:**

#### A. DPD Too Aggressive
```bash
# Check current DPD settings
sudo grep dpd /etc/ipsec.conf
```

**Fix:**
```bash
# Edit vpn_config.json
nano vpn_config.json

# Increase DPD timers
"dpd_delay": 15,
"dpd_timeout": 45,

# Regenerate and redeploy
```

#### B. Network Instability
```bash
# Check packet loss to AWS
ping -c 100 <aws_tunnel_outside_ip>

# Check for high latency
mtr <aws_tunnel_outside_ip>
```

**Fix:**
- Contact ISP if network issues
- Consider increasing DPD timers
- Check for local network issues

#### C. Competing Configurations
```bash
# Check for duplicate connections
sudo ipsec statusall | grep -i conn
```

**Fix:**
```bash
# Remove old configurations
sudo ipsec down <old_connection_name>
# Clean up /etc/ipsec.conf
```

---

### Issue 6: BFD Not Working

**Symptoms:**
```
sudo vtysh -c "show bfd peers"
# Shows: down or not found
```

**Possible Causes & Solutions:**

#### A. BFD Daemon Not Running
```bash
# Check if BFD is enabled
cat /etc/frr/daemons | grep bfdd
```

**Fix:**
```bash
# Enable BFD daemon
sudo sed -i 's/bfdd=no/bfdd=yes/' /etc/frr/daemons
sudo systemctl restart frr
```

#### B. BFD Not Configured on AWS Side
- AWS VGW/TGW may not support BFD
- Check AWS documentation for your gateway type

**Fix:**
- Disable BFD if not supported
- Edit vpn_config.json: `"enable_bfd": false`
- Regenerate configuration

---

### Issue 7: ECMP Not Load Balancing

**Symptoms:**
- Both tunnels up
- Traffic only using one tunnel

**Possible Causes & Solutions:**

#### A. ECMP Not Enabled
```bash
# Check BGP configuration
sudo vtysh -c "show running-config" | grep maximum-paths
```

**Fix:**
```bash
sudo vtysh
configure terminal
router bgp <your_asn>
address-family ipv4 unicast
maximum-paths 4
exit
exit
write memory
```

#### B. Routes Not Equal Cost
```bash
# Check route metrics
sudo vtysh -c "show ip route"

# Both paths should have same metric
```

**Fix:**
```bash
# Ensure both BGP sessions have same configuration
# Check for route-maps affecting metrics
```

#### C. Kernel Not Configured for Multipath
```bash
# Check kernel routing
ip route show

# Should show "nexthop" entries for both paths
```

**Fix:**
```bash
# Enable multipath in kernel
sudo sysctl -w net.ipv4.fib_multipath_hash_policy=1

# Make persistent
echo "net.ipv4.fib_multipath_hash_policy=1" | sudo tee -a /etc/sysctl.conf
```

---

## Advanced Debugging

### Enable Debug Logging

#### StrongSwan Debug
```bash
# Edit /etc/ipsec.conf
sudo nano /etc/ipsec.conf

# Add under config setup:
charondebug="ike 2, knl 2, cfg 2, net 2, esp 2, dmn 2, mgr 2"

# Restart
sudo ipsec restart

# Watch logs
sudo journalctl -u strongswan -f
```

#### FRR Debug
```bash
sudo vtysh

# Enable debugging
debug bgp updates
debug bgp neighbor-events
debug bfd network

# View logs
exit
sudo journalctl -u frr -f
```

### Packet Capture

#### Capture IKE Traffic
```bash
# Capture on public interface
sudo tcpdump -i eth0 -n 'udp port 500 or udp port 4500' -w ike.pcap

# Analyze with Wireshark
```

#### Capture ESP Traffic
```bash
# Capture ESP packets
sudo tcpdump -i eth0 -n 'proto 50' -w esp.pcap
```

#### Capture VTI Traffic
```bash
# Capture on VTI interface
sudo tcpdump -i vti1 -n -w vti1.pcap
```

### Check IPsec SA Details
```bash
# Detailed SA information
sudo ip xfrm state
sudo ip xfrm policy

# Check encryption/authentication algorithms
sudo ipsec statusall
```

---

## Performance Issues

### High Latency

**Check:**
```bash
# Ping through VTI
ping -I vti1 <aws_ip>

# Compare to direct ping
ping <aws_tunnel_outside_ip>
```

**Solutions:**
- Check for MTU issues
- Verify no packet fragmentation
- Check CPU usage on gateway
- Consider hardware acceleration

### Low Throughput

**Check:**
```bash
# Test bandwidth
iperf3 -c <aws_ip>

# Check CPU usage
top
```

**Solutions:**
```bash
# Enable hardware offloading if available
ethtool -K eth0 gso on
ethtool -K eth0 tso on

# Increase buffer sizes
sudo sysctl -w net.core.rmem_max=134217728
sudo sysctl -w net.core.wmem_max=134217728
```

### Packet Loss

**Check:**
```bash
# Extended ping test
ping -c 1000 -i 0.2 <aws_ip>

# Check interface errors
ip -s link show vti1
```

**Solutions:**
- Adjust MTU
- Check for network congestion
- Verify QoS settings

---

## Logs to Check

### StrongSwan Logs
```bash
# Recent logs
sudo journalctl -u strongswan --since "1 hour ago"

# Follow logs
sudo journalctl -u strongswan -f

# Search for errors
sudo journalctl -u strongswan | grep -i error
```

### FRR Logs
```bash
# Recent logs
sudo journalctl -u frr --since "1 hour ago"

# Follow logs
sudo journalctl -u frr -f

# BGP specific
sudo journalctl -u frr | grep -i bgp
```

### System Logs
```bash
# Kernel messages
dmesg | grep -i ipsec

# System log
sudo tail -f /var/log/syslog | grep -E 'ipsec|frr|bgp'
```

---

## Getting Help

### Information to Collect

When seeking help, gather:

1. **Configuration**
```bash
sudo ipsec statusall > ipsec_status.txt
sudo vtysh -c "show running-config" > frr_config.txt
ip addr show > interfaces.txt
ip route show > routes.txt
```

2. **Logs**
```bash
sudo journalctl -u strongswan --since "1 hour ago" > strongswan.log
sudo journalctl -u frr --since "1 hour ago" > frr.log
```

3. **AWS Configuration**
- VPN Connection ID
- VGW/TGW ID
- Downloaded VPN configuration

4. **Network Diagram**
- Topology
- IP addressing
- Routing

### AWS Support

If opening AWS support case:
```bash
# Collect VPN logs
python3 vpn-log-collector/vpn_log_collector.py --bucket <bucket> --case-id <case_id>
```

---

## Prevention

### Regular Maintenance

1. **Monitor Health**
```bash
# Check health daily
sudo /usr/local/bin/vpn_health_check.py
```

2. **Review Logs Weekly**
```bash
# Check for warnings
sudo journalctl -u strongswan --since "1 week ago" | grep -i warn
sudo journalctl -u frr --since "1 week ago" | grep -i warn
```

3. **Rotate PSKs Quarterly**
```bash
# Generate new PSK
openssl rand -base64 32

# Update in AWS and locally
# Test before removing old PSK
```

4. **Update Software**
```bash
# Keep packages updated
sudo apt-get update
sudo apt-get upgrade strongswan frr
```

### Monitoring Setup

Set up automated monitoring:
```bash
# Ensure health check timer is running
sudo systemctl status vpn-health-check.timer

# Configure email alerts in health check script
sudo nano /usr/local/bin/vpn_health_check.py
```

---

## Emergency Procedures

### Complete VPN Restart
```bash
# Stop services
sudo systemctl stop frr
sudo systemctl stop strongswan

# Clear VTI interfaces
sudo ip link delete vti1
sudo ip link delete vti2

# Restart services
sudo systemctl start strongswan
sudo /usr/local/bin/setup_vti.sh
sudo systemctl start frr

# Verify
sudo /usr/local/bin/vpn_health_check.py
```

### Rollback to Previous Configuration
```bash
# Find backup
ls -la /etc/vpn-backup-*

# Restore
BACKUP_DIR="/etc/vpn-backup-YYYYMMDD-HHMMSS"
sudo cp $BACKUP_DIR/ipsec.conf /etc/ipsec.conf
sudo cp $BACKUP_DIR/ipsec.secrets /etc/ipsec.secrets
sudo cp $BACKUP_DIR/frr.conf /etc/frr/frr.conf

# Restart
sudo systemctl restart strongswan
sudo systemctl restart frr
```

---

## Contact Information

- AWS Support: https://console.aws.amazon.com/support/
- StrongSwan Documentation: https://docs.strongswan.org/
- FRR Documentation: https://docs.frrouting.org/

Remember: Always test changes in a maintenance window and have a rollback plan!
