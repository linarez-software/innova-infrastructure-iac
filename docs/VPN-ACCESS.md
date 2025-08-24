# VPN Access Guide

Complete guide for setting up and managing VPN access to the Innova Odoo infrastructure.

## 🔐 Security Model

The infrastructure has been secured with **zero external access** except for:
- **HTTPS (port 443)**: Public access to Odoo web interface
- **HTTP (port 80)**: Redirects to HTTPS  
- **OpenVPN (UDP 1194)**: VPN server access

**All administrative access requires VPN connection.**

### Access Requirements

| Service | Access Method | Required |
|---------|---------------|----------|
| Odoo Web Interface | Direct HTTPS | ❌ VPN Not Required |
| SSH to servers | VPN Connection | ✅ VPN Required |
| Database access | VPN Connection | ✅ VPN Required |
| Administrative tasks | VPN Connection | ✅ VPN Required |

## 🖥️ VPN Server Specifications

### Instance Configuration
- **Instance Type**: e2-micro (cost-optimized)
- **vCPUs**: 1 shared core
- **Memory**: 1 GB
- **Storage**: 10 GB standard persistent disk
- **Monthly Cost**: ~$6 USD

### VPN Configuration
- **Protocol**: OpenVPN (UDP)
- **Port**: 1194
- **Client Subnet**: 10.8.0.0/24
- **Max Concurrent Clients**: 5
- **Encryption**: AES-256-CBC with SHA-256 auth
- **Certificate Authority**: RSA 2048-bit

## 🚀 Quick Setup

### 1. Deploy VPN Server

The VPN server is automatically deployed with the infrastructure:

```bash
# Deploy staging with VPN
cd environments/staging
terraform apply

# Deploy production with VPN  
cd environments/production
terraform apply
```

### 2. Get VPN Server Details

```bash
# Get VPN server IP
terraform output vpn_server_ip

# Get connection info
terraform output vpn_connection_info
```

### 3. Create VPN Users

Use the included management script:

```bash
# Add a new user
./scripts/setup-vpn-client.sh -p YOUR_PROJECT -z us-central1-a -e production add john.doe

# List active connections
./scripts/setup-vpn-client.sh -p YOUR_PROJECT -z us-central1-a -e production list

# Revoke user access
./scripts/setup-vpn-client.sh -p YOUR_PROJECT -z us-central1-a -e production revoke john.doe
```

## 👥 User Management

### Adding New Users

#### Method 1: Using the Management Script (Recommended)

```bash
./scripts/setup-vpn-client.sh -p YOUR_PROJECT -z us-central1-a -e production add username
```

This will:
1. Generate client certificate
2. Create OpenVPN configuration file
3. Download the `.ovpn` file locally
4. Upload backup to GCS bucket

#### Method 2: Manual Process

```bash
# SSH to VPN server
gcloud compute ssh vpn-production --zone=us-central1-a

# Add user
sudo /opt/scripts/manage-vpn-users.sh add username

# Download configuration
gcloud compute scp vpn-production:/opt/vpn-configs/username.ovpn . --zone=us-central1-a
```

### Distributing Client Configurations

**Security Best Practices:**

1. **Secure Transfer**: Send `.ovpn` files via encrypted email or secure file sharing
2. **Temporary Access**: Delete local copies after distribution
3. **User Instructions**: Provide clear setup instructions
4. **Verification**: Confirm successful connection before considering setup complete

#### Client Setup Instructions Template

```
Subject: VPN Access Configuration - Innova Infrastructure

Hi [Name],

Please find your VPN configuration file attached. To set up access:

1. Install OpenVPN client:
   - Windows: OpenVPN GUI or OpenVPN Connect
   - macOS: Tunnelblick or OpenVPN Connect  
   - Linux: OpenVPN package
   - Mobile: OpenVPN Connect app

2. Import the attached .ovpn file into your client

3. Connect to VPN using your client

4. Once connected, you can access:
   - SSH to servers via internal IPs
   - Database management tools
   - Internal monitoring dashboards

5. Delete this email and the .ovpn file after importing

For support, contact the infrastructure team.

Best regards,
IT Team
```

### Revoking Access

```bash
# Revoke user access
./scripts/setup-vpn-client.sh -p YOUR_PROJECT -z us-central1-a -e production revoke username
```

This will:
1. Revoke the client certificate
2. Update Certificate Revocation List (CRL)
3. Restart OpenVPN server
4. Immediately disconnect the user

## 🔧 VPN Server Management

### Monitoring VPN Status

```bash
# Check server status
./scripts/setup-vpn-client.sh -p YOUR_PROJECT -z us-central1-a -e production status

# SSH to VPN server for detailed monitoring
gcloud compute ssh vpn-production --zone=us-central1-a
sudo /opt/scripts/vpn-monitor.sh
```

### Server Maintenance

#### View Active Connections
```bash
sudo /opt/scripts/manage-vpn-users.sh list
```

#### Check Server Logs
```bash
sudo tail -f /var/log/openvpn/server.log
sudo journalctl -u openvpn@server -f
```

#### Restart VPN Service
```bash
sudo systemctl restart openvpn@server
sudo systemctl status openvpn@server
```

#### Backup Configurations
```bash
# Configurations are automatically backed up to GCS
gsutil ls gs://YOUR-PROJECT-production-vpn-configs/

# Manual backup
sudo tar -czf vpn-backup-$(date +%Y%m%d).tar.gz /etc/openvpn/easy-rsa/pki/
```

## 🛠️ Client Configuration

### OpenVPN Client Installation

#### Windows
1. Download [OpenVPN GUI](https://openvpn.net/community-downloads/)
2. Install with administrator privileges
3. Copy `.ovpn` file to `C:\Program Files\OpenVPN\config\`
4. Right-click OpenVPN GUI → "Run as administrator"
5. Connect using the imported profile

#### macOS
1. Install [Tunnelblick](https://tunnelblick.net/) or [OpenVPN Connect](https://openvpn.net/vpn-client/)
2. Double-click `.ovpn` file to import
3. Connect using the imported configuration

#### Linux (Ubuntu/Debian)
```bash
# Install OpenVPN
sudo apt update
sudo apt install openvpn

# Connect using configuration
sudo openvpn --config username.ovpn

# Or install as system service
sudo cp username.ovpn /etc/openvpn/client/username.conf
sudo systemctl start openvpn-client@username
```

#### Mobile Devices
1. Install OpenVPN Connect app
2. Import `.ovpn` file via email or file sharing
3. Connect using the app

### Verifying Connection

Once connected to VPN:

```bash
# Check your VPN IP (should be 10.8.0.x)
ip route | grep tun0  # Linux/macOS
ipconfig | findstr "10.8.0"  # Windows

# Test SSH access to servers (replace with actual internal IPs)
ssh user@10.0.0.2  # Odoo server internal IP
ssh user@10.0.0.3  # Database server internal IP

# Test database connection
psql -h 10.0.0.3 -U odoo -d postgres  # Database server
```

## 🔒 Security Features

### Network Security
- **Firewall Rules**: SSH only allowed from VPN subnet (10.8.0.0/24)
- **Direct Odoo Access**: Blocked on ports 8069/8072
- **Database Access**: Only from internal network and VPN
- **Inter-VM Communication**: Secured within private subnet

### VPN Security
- **Strong Encryption**: AES-256-CBC with SHA-256 authentication
- **Certificate-based Authentication**: RSA 2048-bit certificates
- **TLS Authentication**: Additional HMAC authentication layer
- **Perfect Forward Secrecy**: Each session uses unique keys
- **Certificate Revocation**: Immediate access removal capability

### Access Control
- **Principle of Least Privilege**: Each service account has minimal required permissions
- **Network Segmentation**: VPN clients isolated from critical internal services
- **Audit Logging**: All VPN connections and authentication attempts logged
- **Session Management**: Configurable timeout and connection limits

## 📊 Monitoring and Alerts

### Built-in Monitoring

The VPN server includes monitoring for:
- **Connection Status**: Server uptime and service health
- **Active Users**: Current connections and session duration
- **Resource Usage**: CPU, memory, and network utilization
- **Authentication Events**: Successful and failed login attempts

### Cloud Monitoring Integration

VPN metrics are integrated with GCP Cloud Monitoring:
- **VM Health**: CPU, memory, disk usage alerts
- **Network Traffic**: Bandwidth utilization monitoring
- **Service Availability**: OpenVPN service uptime tracking
- **Security Events**: Failed authentication attempts

### Log Analysis

```bash
# Recent VPN connections
sudo tail -100 /var/log/openvpn/server.log | grep "peer info"

# Authentication failures  
sudo grep "TLS Error" /var/log/openvpn/server.log

# Connection statistics
sudo /opt/scripts/vpn-monitor.sh
```

## 💰 Cost Optimization

### Instance Sizing
- **e2-micro**: Sufficient for 5 concurrent users
- **Preemptible**: Not recommended for VPN (service interruption)
- **Regional**: Single zone deployment for cost savings

### Traffic Costs
- **Ingress**: Free (VPN client to server)
- **Egress**: Charged based on client location
- **Internal**: Free between GCP resources via VPN

### Monthly Cost Estimate
```
VPN Server (e2-micro):        ~$6.00
Static IP Address:            ~$1.50  
Egress Traffic (10GB):        ~$1.20
GCS Storage (configs):        ~$0.05
--------------------------------
Total Monthly Cost:           ~$8.75
```

## 🚨 Troubleshooting

### Common Issues

#### 1. VPN Connection Fails
```bash
# Check server status
gcloud compute ssh vpn-production --zone=us-central1-a --command="sudo systemctl status openvpn@server"

# Check firewall rules
gcloud compute firewall-rules list --filter="name~vpn"

# Verify client configuration
grep -E "(remote|port|proto)" username.ovpn
```

#### 2. SSH Access Denied After VPN Connection
```bash
# Verify VPN IP assignment
ip addr show tun0  # Should show 10.8.0.x

# Check SSH access from VPN subnet
gcloud compute firewall-rules describe innova-odoo-production-network-allow-ssh-vpn-only
```

#### 3. Cannot Access Internal Services
```bash
# Check internal routing
ip route | grep 10.0.0.0

# Verify internal firewall rules
gcloud compute firewall-rules list --filter="allow.ports:5432"
```

#### 4. High Resource Usage on VPN Server
```bash
# Check active connections
sudo /opt/scripts/manage-vpn-users.sh list

# Monitor resource usage
sudo /opt/scripts/vpn-monitor.sh

# Consider upgrading instance type if consistently high
```

### Getting Support

1. **Check Logs**: Start with VPN server and client logs
2. **Verify Configuration**: Ensure firewall rules and network settings
3. **Test Connectivity**: Use ping and telnet to diagnose network issues
4. **Escalate**: Contact infrastructure team with relevant logs and error messages

## 📚 Advanced Configuration

### Custom VPN Settings

To modify VPN server settings, edit the startup script template:
```bash
# Edit the OpenVPN template
vim modules/vpn/templates/openvpn-startup.sh

# Redeploy with changes
terraform apply
```

### Scaling Beyond 5 Users

To support more users:
1. **Upgrade Instance**: Change from e2-micro to e2-small or larger
2. **Increase Limits**: Update `max_vpn_clients` variable
3. **Monitor Performance**: Watch for resource constraints

### Integration with Identity Providers

For enterprise authentication:
1. **LDAP Integration**: Configure OpenVPN with LDAP backend
2. **RADIUS Authentication**: Use existing RADIUS infrastructure  
3. **Certificate Management**: Automate certificate lifecycle

## 📖 References

- [OpenVPN Documentation](https://openvpn.net/community-resources/)
- [GCP VPC Firewall Rules](https://cloud.google.com/vpc/docs/firewalls)
- [Terraform GCP Provider](https://registry.terraform.io/providers/hashicorp/google/latest)
- [VPN Security Best Practices](https://www.nist.gov/publications/guide-ipsec-vpns)