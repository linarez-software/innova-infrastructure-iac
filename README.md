# Innova Infrastructure as Code (IaC)

Terraform infrastructure for deploying **Odoo v18 ERP Platform** on **Google Cloud Platform (GCP)** with optimized performance for 30 concurrent users.

## 🏗️ Architecture Overview

This project provides a complete IaC solution for deploying Odoo v18 with **secure VPN-only access** and two distinct environments:

### Staging Environment
- **Single VM deployment** (e2-standard-2: 2 vCPUs, 8 GB RAM)
- Odoo + PostgreSQL on same instance
- Cost-optimized for development and testing
- 2 Odoo workers for basic functionality

### Production Environment  
- **Dual VM architecture** optimized for performance
- **Odoo Server**: c4-standard-4-lssd (4 vCPUs, 15 GB RAM + Local SSD)
- **Database Server**: n2-highmem-4 (4 vCPUs, 32 GB RAM)
- **7 Odoo workers** optimized for 30 concurrent users
- Redis caching, PgBouncer connection pooling
- NGINX reverse proxy with SSL/TLS

### Security Architecture
- **OpenVPN Server**: e2-micro instance for secure admin access
- **Zero External Access**: SSH and database access only via VPN
- **5 VPN Users Maximum**: Cost-optimized for small teams
- **Public Access**: Only HTTPS (443) and HTTP (80) for Odoo web interface

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

### Installation

```bash
# Clone the repository
git clone https://github.com/elinarezv/innova-infrastructure-iac.git
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

| Environment | Component | Instance Type | vCPUs | RAM | Storage | Workload |
|-------------|-----------|---------------|-------|-----|---------|----------|
| **Staging** | All-in-one | e2-standard-2 | 2 | 8 GB | 20 GB SSD | Development |
| **Production** | Odoo Server | c4-standard-4-lssd | 4 | 15 GB | 30 GB + Local SSD | 30 users |
| **Production** | Database | n2-highmem-4 | 4 | 32 GB | 100 GB SSD | Dedicated DB |
| **Both** | VPN Server | e2-micro | 1 | 1 GB | 10 GB Standard | 5 VPN users |

## ⚡ Performance Optimization

### Odoo Configuration (Production)
```ini
workers = 7                    # Optimized for 4 vCPUs
max_cron_threads = 2
limit_memory_hard = 1677721600 # 1.6GB per worker  
limit_memory_soft = 1342177280 # 1.28GB per worker
db_maxconn = 64               # Connection pooling
```

### PostgreSQL Configuration (Production)
```conf
shared_buffers = 8GB          # 25% of 32GB RAM
effective_cache_size = 24GB   # 75% of 32GB RAM
work_mem = 256MB              # Complex queries
maintenance_work_mem = 2GB    # Maintenance ops
max_connections = 100         # With PgBouncer pooling
```

### NGINX Configuration
- **HTTP/2** enabled for modern performance
- **Connection pooling** to Odoo (32 keepalive connections)
- **Static file caching** (1 year expiry)
- **Gzip compression** for text assets
- **Rate limiting** on login/API endpoints
- **SSL/TLS** with Let's Encrypt

## 🔧 Configuration

### Required Variables

#### Staging (`environments/staging/terraform.tfvars`)
```hcl
project_id = "your-gcp-project-id"
region     = "us-central1"  
zone       = "us-central1-a"
odoo_admin_passwd = "your-secure-password"
db_password       = "your-db-password"
```

#### Production (`environments/production/terraform.tfvars`)  
```hcl
project_id                    = "your-gcp-project-id"
production_odoo_instance_type = "c4-standard-4-lssd"
production_db_instance_type   = "n2-highmem-4"
domain_name                   = "your-domain.com"
ssl_email                     = "admin@your-domain.com" 
allowed_ssh_ips              = ["YOUR.IP.RANGE/24"]
odoo_admin_passwd            = "strong-production-password"
db_password                  = "strong-db-password"
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
- **Odoo application metrics**
- **Local SSD performance** tracking

### Alert Policies
- **High CPU usage** (>80% for 5 minutes)
- **High memory usage** (>90% for 5 minutes)  
- **Disk space usage** (>85%)
- **Instance downtime** detection
- **Database connection failures**
- **Local SSD performance degradation**

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
- **[NVME-OPTIMIZATION.md](docs/NVME-OPTIMIZATION.md)** - NVMe storage optimization for filestore
- **[SECURITY.md](docs/SECURITY.md)** - Security best practices  
- **[MONITORING.md](docs/MONITORING.md)** - Monitoring setup
- **[BACKUP.md](docs/BACKUP.md)** - Backup and disaster recovery
- **[PERFORMANCE.md](docs/PERFORMANCE.md)** - Performance tuning guide

## 🔍 Useful Commands

```bash
# Setup VPN access (REQUIRED for SSH)
./scripts/setup-vpn-client.sh -p PROJECT_ID -z us-central1-a -e production add username
./scripts/setup-vpn-client.sh -p PROJECT_ID -z us-central1-a -e production list

# SSH to instances (VPN connection required)
gcloud compute ssh odoo-production --zone=us-central1-a
gcloud compute ssh db-production --zone=us-central1-a
gcloud compute ssh vpn-production --zone=us-central1-a

# View logs  
journalctl -u odoo -f
tail -f /var/log/nginx/odoo_access.log

# Monitor PostgreSQL
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;"

# Check Odoo status
systemctl status odoo
systemctl status nginx

# Run backups manually
/backup/postgresql/backup.sh
```

## 🎯 Key Features

✅ **Production-ready** architecture with dual VM setup  
✅ **Performance optimized** for 30 concurrent users  
✅ **Cost-effective** staging environment  
✅ **Secure VPN access** with OpenVPN server (5 users)
✅ **Zero external admin access** except Odoo web interface
✅ **Automated SSL** with Let's Encrypt  
✅ **Optimized NVMe SSD** with ext4 tuning for Odoo filestore  
✅ **Connection pooling** with PgBouncer  
✅ **Redis caching** for session management  
✅ **Comprehensive monitoring** and alerting  
✅ **Automated backups** with retention policies  
✅ **Infrastructure as Code** with Terraform modules  

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)  
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/elinarezv/innova-infrastructure-iac/issues)
- **Documentation**: [Wiki](https://github.com/elinarezv/innova-infrastructure-iac/wiki)
- **Discussions**: [GitHub Discussions](https://github.com/elinarezv/innova-infrastructure-iac/discussions)

---

**Built with ❤️ for Odoo v18 deployments on GCP**