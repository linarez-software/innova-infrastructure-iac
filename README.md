# Innova Infrastructure as Code (IaC)

Terraform-based **generic application infrastructure platform** for **Google Cloud Platform (GCP)** with secure VPN-only administrative access. Deploy any web application with PostgreSQL backend in staging or production environments.

## 🏗️ Architecture Overview

This project provides a complete IaC solution for deploying application infrastructure with **secure VPN-only access** and two distinct environments:

### Staging Environment
- **Single VM deployment** (e2-standard-2: 2 vCPUs, 8 GB RAM)
- Combined application and database instance
- Cost-optimized for development and testing
- Basic resource allocation

### Production Environment  
- **Dual VM architecture** optimized for performance
- **Application Server**: n2-standard-4 (4 vCPUs, 16 GB RAM)
- **Database Server**: n2-highmem-4 (4 vCPUs, 32 GB RAM)
- Separate database instance for better resource isolation
- NGINX reverse proxy with SSL/TLS support
- Redis cache on application server

### Security Architecture
- **OpenVPN Server**: e2-micro instance for secure admin access
- **Zero External Access**: SSH and database access only via VPN
- **5 VPN Users Maximum**: Cost-optimized for small teams
- **Public Access**: Only HTTPS (443) and HTTP (80) for application interface

## 🚀 Quick Start

### Prerequisites

1. **GCP Account** with billing enabled
2. **Terraform >= 1.5.0** installed
3. **gcloud CLI** installed and authenticated
4. **Required GCP APIs** enabled:
   - Compute Engine API
   - IAM Service Account API  
   - Cloud Monitoring API
   - Cloud Logging API
   - Cloud KMS API (for production encryption)
   - Identity-Aware Proxy API

### Installation

```bash
# Clone the repository
git clone https://github.com/linarez-software/innova-infrastructure-iac.git
cd innova-infrastructure-iac

# Create GCS bucket for Terraform state
gsutil mb gs://YOUR-PROJECT-ID-terraform-state

# Configure staging environment
cd environments/staging
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration

# Initialize and deploy staging
terraform init
terraform plan
terraform apply

# Configure production environment  
cd ../production
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your production configuration

# Initialize and deploy production
terraform init
terraform plan  
terraform apply
```

## 📊 Instance Specifications

| Environment | Component | Instance Type | vCPUs | RAM | Storage | Purpose |
|-------------|-----------|---------------|-------|-----|---------|----------|
| **Staging** | All-in-one | e2-standard-2 | 2 | 8 GB | 20 GB SSD | Development |
| **Production** | App Server | n2-standard-4 | 4 | 16 GB | 30 GB SSD | Application |
| **Production** | Database | n2-highmem-4 | 4 | 32 GB | 100 GB SSD | PostgreSQL |
| **Both** | VPN Server | e2-micro | 1 | 1 GB | 10 GB Standard | 5 VPN users |

## ⚡ Performance Optimization

### PostgreSQL Configuration (Production)
```conf
shared_buffers = 8GB          # 25% of 32GB RAM
effective_cache_size = 24GB   # 75% of 32GB RAM
work_mem = 256MB              # Complex queries
maintenance_work_mem = 2GB    # Maintenance ops
max_connections = 100         # With connection pooling
```

### NGINX Configuration
- **HTTP/2** enabled for modern performance
- **Connection pooling** for application backends
- **Static file caching** (1 year expiry)
- **Gzip compression** for text assets
- **Rate limiting** on sensitive endpoints
- **SSL/TLS** with Let's Encrypt

## 🔧 Configuration

### Required Variables

#### Staging (`environments/staging/terraform.tfvars`)
```hcl
project_id = "your-gcp-project-id"
region     = "us-central1"  
zone       = "us-central1-a"
db_password = "your-db-password"
```

#### Production (`environments/production/terraform.tfvars`)  
```hcl
project_id                    = "your-gcp-project-id"
production_app_instance_type  = "n2-standard-4"     # 4 vCPUs, 16 GB RAM
production_db_instance_type   = "n2-highmem-4"      # 4 vCPUs, 32 GB RAM
domain_name                   = ""                   # Optional - leave empty for IP-only access
ssl_email                     = "admin@example.com"  # For monitoring alerts
allowed_ssh_ips              = ["203.0.113.0/24"]   # Your office/VPN IP range
db_password                  = "strong-db-password"
enable_monitoring            = true                  # Cloud Monitoring dashboards
enable_backups              = true                  # Automated daily backups
backup_retention_days       = 30                    # Keep backups for 30 days
```

## 🔐 Security Features

### Network Security
- **VPC with custom subnets** and firewall rules
- **VPN-only SSH access** (10.8.0.0/24 subnet)
- **No external admin access** except via VPN
- **Internal-only** database communication (port 5432)
- **SSL/TLS encryption** with Let's Encrypt
- **OpenVPN server** with certificate-based authentication

### Access Control
- **Service accounts** with least-privilege IAM roles
- **KMS encryption** for production secrets
- **Audit logging** enabled
- **OS Login** for SSH key management

### Data Protection  
- **Automated backups** with 30-day retention
- **WAL archiving** for PostgreSQL
- **Snapshot policies** for persistent disks
- **GCS backup storage** with lifecycle management

## 📈 Monitoring & Alerting

### Cloud Monitoring Dashboards
- **VM metrics** (CPU, memory, disk, network)
- **PostgreSQL performance** on dedicated instance
- **Application metrics**
- **Local SSD performance** tracking

### Alert Policies
- **High CPU usage** (>80% for 5 minutes)
- **High memory usage** (>90% for 5 minutes)  
- **Disk space usage** (>85%)
- **Instance downtime** detection
- **Database connection failures**
- **Local SSD performance degradation**

## 📋 Post-Deployment Information

After successful deployment, Terraform will output:

### Staging Outputs
```
app_instance_ip = "X.X.X.X"
app_instance_name = "app-staging"
vpn_server_ip = "Y.Y.Y.Y"
vpn_config_bucket = "PROJECT_ID-staging-vpn-configs"
```

### Production Outputs
```
app_instance_ip = "X.X.X.X"
app_instance_name = "app-production"
db_instance_ip = "Z.Z.Z.Z"
db_instance_name = "db-production"
vpn_server_ip = "Y.Y.Y.Y"
vpn_config_bucket = "PROJECT_ID-production-vpn-configs"
```

## ⚠️ Important Notes

### Security Considerations
- **Change default passwords** immediately after deployment
- **VPN is mandatory** for all administrative access
- **No direct SSH** from public internet (blocked by firewall)
- **Database passwords** are stored in terraform.tfvars - keep secure
- **SSL certificates** require valid domain for production

### Operational Notes
- **VPN setup completes** ~2-3 minutes after instance creation
- **First VPN user** is "admin" - config auto-uploaded to GCS
- **PostgreSQL** runs on port 5432 (internal only)
- **Redis** runs on port 6379 (internal only) 
- **Monitoring alerts** sent to configured email address

### Limitations
- Maximum **5 concurrent VPN users** (e2-micro optimization)
- **Staging** uses single VM (app + database combined)
- **No auto-scaling** configured (manual scaling only)

## 💰 Cost Estimation

### Monthly Cost Estimates (us-central1)

| Environment | Instance Cost | Storage Cost | Network Cost | VPN Cost | Total Est. |
|-------------|---------------|--------------|--------------|----------|------------|
| **Staging** | ~$50 | ~$5 | ~$5 | ~$9 | **~$69/month** |
| **Production** | ~$180 | ~$25 | ~$10 | ~$9 | **~$224/month** |

*Estimates include VPN server (e2-micro) and static IP. Actual costs may vary based on usage patterns.*

## 📚 Documentation

- **[DEPLOYMENT.md](docs/DEPLOYMENT.md)** - Detailed deployment guide
- **[VPN-ACCESS.md](docs/VPN-ACCESS.md)** - VPN setup and user management
- **[STORAGE.md](docs/STORAGE.md)** - Storage configuration and optimization
- **[SECURITY.md](docs/SECURITY.md)** - Security best practices  
- **[MONITORING.md](docs/MONITORING.md)** - Monitoring setup
- **[BACKUP.md](docs/BACKUP.md)** - Backup and disaster recovery
- **[PERFORMANCE.md](docs/PERFORMANCE.md)** - Performance tuning guide

## 🔍 Useful Commands

### VPN Management (Required for SSH Access)
```bash
# Add new VPN user
./scripts/setup-vpn-client.sh -p PROJECT_ID -z us-central1-a -e production add username

# List active VPN connections
./scripts/setup-vpn-client.sh -p PROJECT_ID -z us-central1-a -e production list

# Revoke VPN access
./scripts/setup-vpn-client.sh -p PROJECT_ID -z us-central1-a -e production revoke username

# Download VPN configuration from GCS
gsutil cp gs://PROJECT_ID-production-vpn-configs/username.ovpn ./
```

### Instance Access (VPN Required)
```bash
# SSH to instances (must be connected to VPN first)
gcloud compute ssh app-production --zone=us-central1-a
gcloud compute ssh db-production --zone=us-central1-a

# Use IAP tunnel if configured (alternative to VPN)
gcloud compute ssh app-production --zone=us-central1-a --tunnel-through-iap
```

### Application Management
```bash
# View application logs
sudo journalctl -u nginx -f
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# Restart services
sudo systemctl restart nginx
sudo systemctl restart postgresql
sudo systemctl restart redis-server

# Check service status
sudo systemctl status nginx
sudo systemctl status postgresql
sudo systemctl status redis-server
```

### Database Operations
```bash
# Connect to PostgreSQL
sudo -u postgres psql

# Monitor active connections
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;"

# Check database size
sudo -u postgres psql -c "SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname)) AS size FROM pg_database;"

# Run manual backup
sudo -u postgres pg_dump app_db > /backup/manual_backup_$(date +%Y%m%d).sql
```

### Monitoring & Troubleshooting
```bash
# Check system resources
htop
df -h
free -h

# Monitor network connections
sudo netstat -tulpn
sudo ss -tulpn

# Check firewall rules
sudo iptables -L -n -v

# View system logs
sudo journalctl -xe
sudo dmesg -T
```

## 🎯 Key Features

✅ **Production-ready** architecture with dual VM setup  
✅ **Performance optimized** infrastructure  
✅ **Cost-effective** staging environment  
✅ **Secure VPN access** with OpenVPN server (5 users)
✅ **Zero external admin access** except application web interface
✅ **Automated SSL** with Let's Encrypt  
✅ **High-performance storage** optimized for application workloads  
✅ **Connection pooling** with PgBouncer  
✅ **Comprehensive monitoring** and alerting  
✅ **Automated backups** with retention policies  
✅ **Infrastructure as Code** with Terraform modules  

## 🏗️ Module Structure

The infrastructure is organized into reusable Terraform modules:

```
modules/
├── networking/     # VPC, subnets, firewall rules, static IPs
├── compute/        # VM instances, startup scripts, boot disks
├── database/       # PostgreSQL setup, backups, storage policies
├── security/       # Service accounts, IAM roles, KMS encryption
├── monitoring/     # Cloud Monitoring dashboards, alert policies
└── vpn/           # OpenVPN server, client management scripts
```

Each module is independent and can be customized for specific requirements.

## 🔧 Troubleshooting

### Common Issues and Solutions

#### VPN Connection Issues
```bash
# Check VPN server status
gcloud compute instances describe vpn-production --zone=us-central1-a

# View VPN server logs
gcloud compute instances get-serial-port-output vpn-production --zone=us-central1-a

# Restart VPN server
gcloud compute instances stop vpn-production --zone=us-central1-a
gcloud compute instances start vpn-production --zone=us-central1-a
```

#### SSH Access Denied
```bash
# Ensure VPN is connected first
# Check firewall rules
gcloud compute firewall-rules list --filter="name:allow-ssh"

# Verify IAM permissions
gcloud projects get-iam-policy PROJECT_ID --flatten="bindings[].members" --filter="bindings.members:user:YOUR_EMAIL"
```

#### Terraform State Issues
```bash
# Refresh state
terraform refresh

# Import existing resources
terraform import module.MODULE_NAME.RESOURCE_TYPE.RESOURCE_NAME RESOURCE_ID

# Force unlock state
terraform force-unlock LOCK_ID
```

#### Application Not Accessible
```bash
# Check NGINX status
sudo systemctl status nginx

# Check firewall allows HTTP/HTTPS
gcloud compute firewall-rules list --filter="name:allow-http"

# Verify static IP is attached
gcloud compute addresses list
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)  
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/linarez-software/innova-infrastructure-iac/issues)
- **Documentation**: [Wiki](https://github.com/linarez-software/innova-infrastructure-iac/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/linarez-software/innova-infrastructure-iac/discussions)

---

**Built with ❤️ for scalable GCP deployments**