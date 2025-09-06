#!/bin/bash
# Test VPN routing and SSH connectivity

echo "=== VPN Routing Test ==="
echo "1. Current VPN IP:"
ifconfig | grep -A 1 "utun" | grep "inet " | grep "10.8.0"

echo -e "\n2. Routes to internal network:"
netstat -rn | grep "10.0.0"

echo -e "\n3. Test ping to VPN server (10.0.0.2):"
ping -c 2 10.0.0.2

echo -e "\n4. Test ping to app server (10.0.0.3):"
ping -c 2 10.0.0.3

echo -e "\n5. Test SSH to app server:"
timeout 5 nc -zv 10.0.0.3 22 2>&1 | head -1

echo -e "\n6. Test SSH via gcloud:"
gcloud compute ssh app-staging --project=deep-wares-246918 --zone=us-central1-a --internal-ip --command='echo "SSH Success: $(hostname)"' 2>&1 | head -2

echo -e "\n=== Diagnostics ==="
echo "Your current external IP:"
curl -s ifconfig.me

echo -e "\nActive VPN tunnels:"
ifconfig | grep -E "^utun[0-9]+:" | head -5