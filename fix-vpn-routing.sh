#!/bin/bash
# VPN Routing Fix Script
# This script manually adds the route for staging servers via VPN

echo "VPN Routing Fix for Staging Environment"
echo "======================================"

# Check if connected to VPN
VPN_INTERFACE=$(ifconfig | grep -B 1 "10.8.0" | head -1 | cut -d: -f1)
if [[ -z "$VPN_INTERFACE" ]]; then
    echo "❌ Not connected to VPN. Please connect to staging VPN first."
    exit 1
fi

VPN_IP=$(ifconfig $VPN_INTERFACE | grep "inet 10.8.0" | awk '{print $4}')
echo "✅ VPN connected on interface: $VPN_INTERFACE"
echo "   VPN Gateway: $VPN_IP"

# Check current routing
echo ""
echo "Current routing to 10.0.0.2:"
route get 10.0.0.2

# Add route for staging subnet via VPN
echo ""
echo "Adding route for staging subnet (10.0.0.0/24) via VPN..."
sudo route add -net 10.0.0.0/24 $VPN_IP

if [[ $? -eq 0 ]]; then
    echo "✅ Route added successfully"
    echo ""
    echo "Testing connectivity to staging server..."
    ping -c 3 10.0.0.2
else
    echo "❌ Failed to add route. You may need to run this with sudo."
    exit 1
fi

echo ""
echo "Staging server should now be accessible at:"
echo "  Ping: ping 10.0.0.2"
echo "  SSH: ssh -i ~/.ssh/your-key your-user@10.0.0.2"
echo ""
echo "Note: This route will be lost when you disconnect/reconnect VPN."
echo "The permanent fix is to ensure VPN server pushes routes properly."