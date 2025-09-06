#!/bin/bash
# Manually add route to internal network through VPN

VPN_INTERFACE=$(ifconfig | grep -B 1 "10.8.0.6" | head -1 | cut -d: -f1)
echo "VPN Interface: $VPN_INTERFACE"

if [ -n "$VPN_INTERFACE" ]; then
    echo "Adding route to 10.0.0.0/24 via $VPN_INTERFACE"
    echo "Command that would be run:"
    echo "sudo route add -net 10.0.0.0/24 -interface $VPN_INTERFACE"
    echo ""
    echo "This requires sudo privileges. Please run:"
    echo "sudo route add -net 10.0.0.0/24 -interface $VPN_INTERFACE"
    echo ""
    echo "Then test with:"
    echo "ping -c 2 10.0.0.2"
    echo "ping -c 2 10.0.0.3"
else
    echo "VPN interface not found"
fi