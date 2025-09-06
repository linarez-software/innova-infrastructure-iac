#!/bin/bash
# Fix VPN configuration for staging environment
# This script updates the existing VPN server to properly route to staging services

set -e

# Configuration
PROJECT_ID="${1:-deep-wares-246918}"
ZONE="${2:-us-central1-a}"
ENVIRONMENT="${3:-staging}"
VPN_INSTANCE="vpn-${ENVIRONMENT}"

echo "Fixing VPN configuration for ${ENVIRONMENT} environment"
echo "Project: ${PROJECT_ID}"
echo "Zone: ${ZONE}"
echo "VPN Instance: ${VPN_INSTANCE}"

# Create a temporary script to fix the VPN server
cat > /tmp/fix-vpn-routing.sh << 'EOF'
#!/bin/bash
set -e

echo "Updating VPN server configuration..."

# Update OpenVPN server configuration
sudo tee /etc/openvpn/server.conf > /dev/null << 'OVPN_EOF'
# OpenVPN Server Configuration for staging
port 1194
proto udp
dev tun

# Certificates and keys
ca easy-rsa/pki/ca.crt
cert easy-rsa/pki/issued/server.crt
key easy-rsa/pki/private/server.key
dh easy-rsa/pki/dh.pem
tls-auth easy-rsa/pki/ta.key 0

# Network configuration
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist /var/log/openvpn/ipp.txt

# Route internal network to VPN clients
push "route 10.0.0.0 255.255.255.0"

# DNS servers
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"
push "dhcp-option DNS 169.254.169.254"

# Client configuration
client-to-client
keepalive 10 120
max-clients 5

# Security
cipher AES-256-CBC
auth SHA256
user nobody
group nogroup
persist-key
persist-tun

# Logging
status /var/log/openvpn/status.log
log-append /var/log/openvpn/server.log
verb 3
mute 20

# Optimization for micro instance
sndbuf 0
rcvbuf 0
push "sndbuf 393216"
push "rcvbuf 393216"

# Connection limits for micro instance
duplicate-cn
script-security 2
OVPN_EOF

echo "Updating iptables rules..."

# Clear existing NAT rules
sudo iptables -t nat -F

# Configure proper NAT for VPN to internal network access
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -d 10.0.0.0/24 -o ens4 -j MASQUERADE
# Enable NAT for internet access from VPN
sudo iptables -t nat -A POSTROUTING -s 10.8.0.0/24 ! -d 10.0.0.0/24 -o ens4 -j MASQUERADE

# Clear existing FORWARD rules
sudo iptables -F FORWARD

# Allow all VPN traffic
sudo iptables -A FORWARD -i tun+ -j ACCEPT
sudo iptables -A FORWARD -o tun+ -j ACCEPT

# Allow VPN clients to reach internal network
sudo iptables -A FORWARD -i tun+ -d 10.0.0.0/24 -j ACCEPT
sudo iptables -A FORWARD -s 10.0.0.0/24 -o tun+ -j ACCEPT

# Allow forwarding for established connections
sudo iptables -A FORWARD -i tun+ -o ens4 -j ACCEPT
sudo iptables -A FORWARD -i ens4 -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT

# Save iptables rules
sudo iptables-save | sudo tee /etc/iptables/rules.v4 > /dev/null

# Ensure IP forwarding is enabled
echo 'net.ipv4.ip_forward=1' | sudo tee -a /etc/sysctl.conf > /dev/null
sudo sysctl -p

# Restart OpenVPN service
echo "Restarting OpenVPN service..."
sudo systemctl restart openvpn@server

# Wait for service to start
sleep 5

# Check service status
if sudo systemctl is-active openvpn@server > /dev/null; then
    echo "✓ OpenVPN service is running"
else
    echo "✗ OpenVPN service failed to start"
    sudo systemctl status openvpn@server
    exit 1
fi

# Display current iptables rules
echo ""
echo "Current NAT rules:"
sudo iptables -t nat -L -n -v

echo ""
echo "Current FORWARD rules:"
sudo iptables -L FORWARD -n -v

echo ""
echo "VPN server configuration updated successfully!"
echo ""
echo "VPN clients can now access:"
echo "  - SSH on staging server (10.0.0.x:22)"
echo "  - HTTP/HTTPS on staging server (10.0.0.x:80,443)"
echo "  - PostgreSQL on staging server (10.0.0.x:5432)"
echo "  - Redis on staging server (10.0.0.x:6379)"
echo "  - Development tools (10.0.0.x:8025,5050)"
echo ""
echo "Test connectivity from VPN client:"
echo "  ping 10.0.0.x  (staging server internal IP)"
EOF

# Upload and execute the fix script on the VPN server
echo ""
echo "Uploading fix script to VPN server..."
gcloud compute scp /tmp/fix-vpn-routing.sh ${VPN_INSTANCE}:/tmp/fix-vpn-routing.sh --zone=${ZONE} --project=${PROJECT_ID}

echo ""
echo "Executing fix script on VPN server..."
gcloud compute ssh ${VPN_INSTANCE} --zone=${ZONE} --project=${PROJECT_ID} --command="chmod +x /tmp/fix-vpn-routing.sh && /tmp/fix-vpn-routing.sh"

# Get the staging server internal IP
echo ""
echo "Getting staging server information..."
STAGING_IP=$(gcloud compute instances describe app-staging --zone=${ZONE} --project=${PROJECT_ID} --format='get(networkInterfaces[0].networkIP)')

echo ""
echo "========================================="
echo "VPN Fix Complete!"
echo "========================================="
echo ""
echo "Staging server internal IP: ${STAGING_IP}"
echo ""
echo "To test VPN connectivity:"
echo "1. Connect to VPN using your .ovpn configuration file"
echo "2. Test connectivity to staging server:"
echo "   - ping ${STAGING_IP}"
echo "   - ssh user@${STAGING_IP}"
echo "   - psql -h ${STAGING_IP} -U postgres -d your_database"
echo "   - Access web services: http://${STAGING_IP}"
echo ""
echo "If you need to generate a new VPN client config:"
echo "  ./scripts/setup-vpn-client.sh -p ${PROJECT_ID} -z ${ZONE} -e staging add username"

# Clean up
rm -f /tmp/fix-vpn-routing.sh