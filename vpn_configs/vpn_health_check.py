#!/usr/bin/env python3
"""
VPN Health Check Script
Monitors tunnel status, BGP sessions, and connectivity
"""

import subprocess
import json
import time
import smtplib
from email.mime.text import MIMEText
from datetime import datetime

CONFIG = {
    "vpn_name": "AWS-S2S-VPN",
    "aws": {
        "tunnel1_ip": "169.254.191.145/30",
        "tunnel2_ip": "169.254.225.45/30",
        "tunnel1_outside_ip": "3.33.130.199",
        "tunnel2_outside_ip": "166.117.27.198",
        "bgp_asn": 64512,
        "vpc_cidr": [
            "10.16.0.0/16"
        ]
    },
    "onprem": {
        "public_ip": "52.21.9.119",
        "tunnel1_ip": "169.254.191.146/30",
        "tunnel2_ip": "169.254.225.46/30",
        "bgp_asn": 65016,
        "local_networks": [
            "192.168.8.0/21"
        ]
    },
    "ipsec": {
        "psk_tunnel1": "J.gSuQOmmam_ucXt_zTUX2B1FF7x4mxZ",
        "psk_tunnel2": "8KjO741NUOXudt7fzK7r0Quw_EWXgZ3R",
        "ike_version": 2,
        "dpd_delay": 10,
        "dpd_timeout": 30,
        "phase1_encryption": "aes256-sha256-modp2048",
        "phase2_encryption": "aes256-sha256-modp2048"
    },
    "bgp": {
        "keepalive": 10,
        "holdtime": 30,
        "enable_bfd": true,
        "enable_graceful_restart": true,
        "max_paths": 4
    },
    "monitoring": {
        "health_check_interval": 60,
        "ping_targets": [
            "10.0.1.10",
            "10.0.2.10"
        ],
        "alert_email": "admin@example.com"
    }
}

def check_ipsec_status():
    """Check IPsec tunnel status"""
    try:
        result = subprocess.run(['ipsec', 'status'], capture_output=True, text=True)
        tunnels = {}
        for line in result.stdout.split('\n'):
            if 'ESTABLISHED' in line:
                tunnel_name = line.split('[')[0].strip()
                tunnels[tunnel_name] = 'UP'
            elif 'tunnel1' in line.lower() or 'tunnel2' in line.lower():
                if 'tunnel1' not in tunnels:
                    tunnels['tunnel1'] = 'DOWN'
                if 'tunnel2' not in tunnels:
                    tunnels['tunnel2'] = 'DOWN'
        return tunnels
    except Exception as e:
        print(f"Error checking IPsec status: {e}")
        return {}

def check_bgp_status():
    """Check BGP neighbor status"""
    try:
        result = subprocess.run(['vtysh', '-c', 'show bgp summary json'], 
                              capture_output=True, text=True)
        bgp_data = json.loads(result.stdout)
        neighbors = {}
        
        if 'ipv4Unicast' in bgp_data:
            peers = bgp_data['ipv4Unicast'].get('peers', {})
            for peer_ip, peer_info in peers.items():
                state = peer_info.get('state', 'Unknown')
                neighbors[peer_ip] = {
                    'state': state,
                    'uptime': peer_info.get('peerUptimeMsec', 0) / 1000,
                    'prefixes_received': peer_info.get('prefixReceivedCount', 0)
                }
        return neighbors
    except Exception as e:
        print(f"Error checking BGP status: {e}")
        return {}

def check_connectivity():
    """Check connectivity to AWS resources"""
    results = {}
    for target in CONFIG['monitoring']['ping_targets']:
        try:
            result = subprocess.run(['ping', '-c', '3', '-W', '2', target],
                                  capture_output=True, text=True)
            results[target] = 'UP' if result.returncode == 0 else 'DOWN'
        except Exception as e:
            results[target] = 'ERROR'
    return results

def send_alert(subject, message):
    """Send email alert"""
    # Implement email alerting based on your SMTP configuration
    print(f"ALERT: {subject}\n{message}")

def main():
    print(f"VPN Health Check - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)
    
    # Check IPsec tunnels
    print("\nIPsec Tunnel Status:")
    tunnels = check_ipsec_status()
    for tunnel, status in tunnels.items():
        print(f"  {tunnel}: {status}")
        if status == 'DOWN':
            send_alert(f"VPN Tunnel Down: {tunnel}", 
                      f"Tunnel {tunnel} is currently down")
    
    # Check BGP sessions
    print("\nBGP Neighbor Status:")
    neighbors = check_bgp_status()
    for peer, info in neighbors.items():
        print(f"  {peer}: {info['state']} (Prefixes: {info['prefixes_received']})")
        if info['state'] != 'Established':
            send_alert(f"BGP Session Down: {peer}", 
                      f"BGP session with {peer} is {info['state']}")
    
    # Check connectivity
    print("\nConnectivity Tests:")
    connectivity = check_connectivity()
    for target, status in connectivity.items():
        print(f"  {target}: {status}")
        if status != 'UP':
            send_alert(f"Connectivity Issue: {target}", 
                      f"Cannot reach {target}")
    
    print("\n" + "=" * 60)

if __name__ == '__main__':
    main()
