#!/bin/bash
# VTI Setup Script for AWS-S2S-VPN

# Tunnel 1 VTI
ip tunnel add vti1 mode vti local 52.21.9.119 remote 3.33.130.199 key 100
ip link set vti1 up
ip addr add 169.254.191.146/30/30 dev vti1
sysctl -w net.ipv4.conf.vti1.disable_policy=1
sysctl -w net.ipv4.conf.vti1.rp_filter=0

# Tunnel 2 VTI
ip tunnel add vti2 mode vti local 52.21.9.119 remote 166.117.27.198 key 200
ip link set vti2 up
ip addr add 169.254.225.46/30/30 dev vti2
sysctl -w net.ipv4.conf.vti2.disable_policy=1
sysctl -w net.ipv4.conf.vti2.rp_filter=0

# Enable IP forwarding
sysctl -w net.ipv4.ip_forward=1

echo "VTI interfaces configured successfully"
