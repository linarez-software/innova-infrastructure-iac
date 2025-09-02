#!/bin/bash
# Micro OpenVPN Server Setup for ${max_vpn_clients} users
# Optimized for e2-micro instance

set -e

export DEBIAN_FRONTEND=noninteractive

echo "Installing OpenVPN server for environment: ${environment}"
echo "VPN Subnet: ${vpn_subnet_ip}/${vpn_subnet_mask}"
echo "Max clients: ${max_vpn_clients}"

# Update system
apt-get update
apt-get install -y \
    openvpn \
    easy-rsa \
    iptables \
    iptables-persistent \
    wget \
    curl \
    unzip \
    openssl

# Configure IP forwarding
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

# Set up Easy RSA for certificate management
mkdir -p /etc/openvpn/easy-rsa
cp -r /usr/share/easy-rsa/* /etc/openvpn/easy-rsa/
chown -R root:root /etc/openvpn/easy-rsa

cd /etc/openvpn/easy-rsa

# Initialize PKI (force if exists)
echo "yes" | ./easyrsa init-pki

# Build CA certificate
echo "innova-${environment}-vpn" | ./easyrsa --batch build-ca nopass

# Generate server certificate
./easyrsa --batch build-server-full server nopass

# Generate Diffie-Hellman parameters
./easyrsa --batch gen-dh

# Generate HMAC key
openvpn --genkey secret pki/ta.key

# Create server configuration
cat > /etc/openvpn/server.conf <<EOF
# OpenVPN Server Configuration for ${environment}
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
server ${vpn_subnet_ip} ${vpn_subnet_mask}
ifconfig-pool-persist /var/log/openvpn/ipp.txt

# Route internal network to VPN clients
push "route ${internal_subnet_ip} ${internal_subnet_mask}"

# DNS servers
push "dhcp-option DNS 8.8.8.8"
push "dhcp-option DNS 8.8.4.4"

# Client configuration
client-to-client
keepalive 10 120
max-clients ${max_vpn_clients}

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
EOF

# Create log directory
mkdir -p /var/log/openvpn
chown nobody:nogroup /var/log/openvpn

# Configure iptables for NAT and VPN routing
# Allow VPN clients to access internal network (10.0.0.0/24)
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -d 10.0.0.0/24 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o ens4 -j MASQUERADE

# Allow VPN traffic
iptables -A INPUT -i tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -j ACCEPT

# Allow VPN clients to reach internal network
iptables -A FORWARD -i tun+ -d 10.0.0.0/24 -j ACCEPT
iptables -A FORWARD -s 10.0.0.0/24 -o tun+ -j ACCEPT

# Standard forwarding rules
iptables -A FORWARD -i tun+ -o ens4 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i ens4 -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT

# Save iptables rules
iptables-save > /etc/iptables/rules.v4

# Create client configuration generation script
mkdir -p /opt/scripts
cat > /opt/scripts/generate-client-config.sh <<'SCRIPT_EOF'
#!/bin/bash
# Generate OpenVPN client configuration

if [ -z "$1" ]; then
    echo "Usage: $0 <client-name>"
    echo "Example: $0 user1"
    exit 1
fi

CLIENT_NAME="$1"
CONFIG_DIR="/opt/vpn-configs"
EASY_RSA_DIR="/etc/openvpn/easy-rsa"

# Create config directory
mkdir -p $CONFIG_DIR

# Check if client certificate exists
if [ ! -f "$EASY_RSA_DIR/pki/issued/$CLIENT_NAME.crt" ]; then
    echo "Client certificate not found. Generating..."
    cd $EASY_RSA_DIR
    echo "$CLIENT_NAME" | ./easyrsa build-client-full "$CLIENT_NAME" nopass
fi

# Generate client configuration
cat > "$CONFIG_DIR/$CLIENT_NAME.ovpn" <<EOF
client
dev tun
proto udp
remote $(curl -s https://ipinfo.io/ip) 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA256
cipher AES-256-CBC
verb 3
mute 20

# Embedded certificates and keys
<ca>
$(cat $EASY_RSA_DIR/pki/ca.crt)
</ca>

<cert>
$(cat $EASY_RSA_DIR/pki/issued/$CLIENT_NAME.crt | sed -n '/BEGIN CERTIFICATE/,/END CERTIFICATE/p')
</cert>

<key>
$(cat $EASY_RSA_DIR/pki/private/$CLIENT_NAME.key)
</key>

<tls-auth>
$(cat $EASY_RSA_DIR/pki/ta.key)
</tls-auth>
key-direction 1
EOF

echo "Client configuration generated: $CONFIG_DIR/$CLIENT_NAME.ovpn"
echo "Upload to GCS bucket..."

# Upload to GCS bucket
if command -v gsutil &> /dev/null; then
    gsutil cp "$CONFIG_DIR/$CLIENT_NAME.ovpn" "gs://${project_id}-${environment}-vpn-configs/"
    echo "Configuration uploaded to GCS bucket"
else
    echo "gsutil not available. Manual upload required."
fi

echo "Configuration ready for download"
SCRIPT_EOF

chmod +x /opt/scripts/generate-client-config.sh

# Create user management script
cat > /opt/scripts/manage-vpn-users.sh <<'MGMT_EOF'
#!/bin/bash
# VPN User Management Script

ACTION="$1"
USERNAME="$2"

case "$ACTION" in
    "add")
        if [ -z "$USERNAME" ]; then
            echo "Usage: $0 add <username>"
            exit 1
        fi
        echo "Adding VPN user: $USERNAME"
        /opt/scripts/generate-client-config.sh "$USERNAME"
        ;;
    "revoke")
        if [ -z "$USERNAME" ]; then
            echo "Usage: $0 revoke <username>"
            exit 1
        fi
        echo "Revoking VPN user: $USERNAME"
        cd /etc/openvpn/easy-rsa
        ./easyrsa revoke "$USERNAME"
        ./easyrsa gen-crl
        systemctl restart openvpn@server
        echo "User $USERNAME revoked and OpenVPN restarted"
        ;;
    "list")
        echo "Active VPN connections:"
        cat /var/log/openvpn/status.log | grep "CLIENT_LIST" | awk '{print $2, $3, $4}'
        ;;
    "status")
        systemctl status openvpn@server
        ;;
    *)
        echo "Usage: $0 {add|revoke|list|status} [username]"
        echo "  add <username>    - Add new VPN user"
        echo "  revoke <username> - Revoke VPN user access"
        echo "  list             - List active connections"
        echo "  status           - Show OpenVPN status"
        exit 1
        ;;
esac
MGMT_EOF

chmod +x /opt/scripts/manage-vpn-users.sh

# Generate initial admin client
echo "Generating admin client certificate..."
/opt/scripts/generate-client-config.sh "admin"

# Enable and start OpenVPN
systemctl enable openvpn@server
systemctl start openvpn@server

# Create monitoring script
cat > /opt/scripts/vpn-monitor.sh <<'MON_EOF'
#!/bin/bash
# VPN Monitoring Script

echo "OpenVPN Server Status:"
systemctl status openvpn@server --no-pager -l

echo -e "\nActive VPN Connections:"
if [ -f /var/log/openvpn/status.log ]; then
    echo "Connected Clients:"
    grep "CLIENT_LIST" /var/log/openvpn/status.log | awk '{printf "  %-15s %-15s %s\n", $2, $3, $5}' | head -${max_vpn_clients}
    echo ""
    echo "Connection Statistics:"
    grep "GLOBAL_STATS" /var/log/openvpn/status.log
else
    echo "  No status log found"
fi

echo -e "\nRecent Log Entries:"
tail -10 /var/log/openvpn/server.log 2>/dev/null || echo "  No server log found"

echo -e "\nSystem Resources:"
echo "Memory Usage:"
free -h

echo -e "\nDisk Usage:"
df -h /

echo -e "\nNetwork Interface Status:"
ip addr show tun0 2>/dev/null || echo "  VPN tunnel not active"
MON_EOF

chmod +x /opt/scripts/vpn-monitor.sh

# Configure logrotate
cat > /etc/logrotate.d/openvpn <<EOF
/var/log/openvpn/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 nobody nogroup
    postrotate
        systemctl reload openvpn@server > /dev/null 2>&1 || true
    endscript
}
EOF

# System optimization for micro instance
echo "Optimizing system for micro instance..."

# Reduce memory usage
echo "vm.swappiness = 60" >> /etc/sysctl.conf
echo "vm.vfs_cache_pressure = 50" >> /etc/sysctl.conf
sysctl -p

# Create startup verification script
cat > /opt/scripts/verify-vpn.sh <<'VERIFY_EOF'
#!/bin/bash
# Verify VPN installation

echo "OpenVPN Installation Verification"
echo "================================="

echo "1. Service Status:"
systemctl is-active openvpn@server && echo "  ✓ OpenVPN service is running" || echo "  ✗ OpenVPN service is not running"

echo "2. Network Configuration:"
grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf && echo "  ✓ IP forwarding enabled" || echo "  ✗ IP forwarding not enabled"

echo "3. Certificates:"
[ -f /etc/openvpn/easy-rsa/pki/ca.crt ] && echo "  ✓ CA certificate exists" || echo "  ✗ CA certificate missing"
[ -f /etc/openvpn/easy-rsa/pki/issued/server.crt ] && echo "  ✓ Server certificate exists" || echo "  ✗ Server certificate missing"

echo "4. Configuration:"
[ -f /etc/openvpn/server.conf ] && echo "  ✓ Server configuration exists" || echo "  ✗ Server configuration missing"

echo "5. Client Management:"
[ -x /opt/scripts/generate-client-config.sh ] && echo "  ✓ Client config script ready" || echo "  ✗ Client config script missing"
[ -x /opt/scripts/manage-vpn-users.sh ] && echo "  ✓ User management script ready" || echo "  ✗ User management script missing"

echo ""
echo "Admin client config should be available at: /opt/vpn-configs/admin.ovpn"
echo "To create additional users: sudo /opt/scripts/manage-vpn-users.sh add <username>"
echo "To monitor VPN: sudo /opt/scripts/vpn-monitor.sh"
VERIFY_EOF

chmod +x /opt/scripts/verify-vpn.sh

# Wait for service to start
sleep 10

# Run verification
/opt/scripts/verify-vpn.sh

echo ""
echo "OpenVPN server installation completed!"
echo "Server IP: $(curl -s https://ipinfo.io/ip)"
echo "VPN Subnet: ${vpn_subnet_ip}/${vpn_subnet_mask}"
echo "Max Clients: ${max_vpn_clients}"
echo ""
echo "Admin configuration generated. Run the following to download it:"
echo "  gcloud compute scp vpn-${environment}:/opt/vpn-configs/admin.ovpn . --zone=${zone}"
echo ""
echo "Management commands:"
echo "  sudo /opt/scripts/manage-vpn-users.sh add <username>"
echo "  sudo /opt/scripts/manage-vpn-users.sh list"
echo "  sudo /opt/scripts/vpn-monitor.sh"