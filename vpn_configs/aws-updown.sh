#!/bin/bash
# StrongSwan updown script for VTI interfaces
# Place in /etc/strongswan.d/aws-updown.sh

set -o nounset
set -o errexit

VTI_IF="${PLUTO_CONNECTION##*-}"

case "${PLUTO_VERB}" in
    up-client)
        # Tunnel is up
        if [ "${VTI_IF}" = "tunnel1" ]; then
            ip link set vti1 up
            vtysh -c "configure terminal" -c "interface vti1" -c "no shutdown"
        elif [ "${VTI_IF}" = "tunnel2" ]; then
            ip link set vti2 up
            vtysh -c "configure terminal" -c "interface vti2" -c "no shutdown"
        fi
        logger -t strongswan "VPN tunnel ${VTI_IF} is UP"
        ;;
    down-client)
        # Tunnel is down
        if [ "${VTI_IF}" = "tunnel1" ]; then
            vtysh -c "configure terminal" -c "interface vti1" -c "shutdown"
        elif [ "${VTI_IF}" = "tunnel2" ]; then
            vtysh -c "configure terminal" -c "interface vti2" -c "shutdown"
        fi
        logger -t strongswan "VPN tunnel ${VTI_IF} is DOWN"
        ;;
esac
