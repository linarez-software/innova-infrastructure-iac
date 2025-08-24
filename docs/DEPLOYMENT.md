# Deployment Guide

Comprehensive step-by-step guide for deploying Odoo v18 infrastructure on GCP using this Terraform project.

## 📋 Prerequisites

### 1. Required Tools

Ensure you have the following tools installed:

```bash
# Terraform (version 1.5+)
terraform --version

# Google Cloud SDK
gcloud --version

# Git
git --version
```

### 2. GCP Setup

#### Enable Required APIs
```bash
gcloud services enable compute.googleapis.com
gcloud services enable iam.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable logging.googleapis.com
```

#### Set Up Authentication
```bash
# Authenticate with GCP
gcloud auth login

# Set default project
gcloud config set project YOUR-PROJECT-ID

# Create application default credentials
gcloud auth application-default login
```

#### Create Terraform State Bucket
```bash
# Create GCS bucket for Terraform state
gsutil mb gs://YOUR-PROJECT-ID-terraform-state

# Enable versioning
gsutil versioning set on gs://YOUR-PROJECT-ID-terraform-state
```

## 🏗️ Deployment Process

### Phase 1: Repository Setup

```bash
# Clone the repository
git clone https://github.com/elinarezv/innova-infrastructure-iac.git
cd innova-infrastructure-iac

# Verify structure
tree -L 3
```

### Phase 2: Staging Deployment

#### Configure Staging Environment

```bash
cd environments/staging

# Copy example configuration
cp terraform.tfvars.example terraform.tfvars

# Edit configuration
nano terraform.tfvars
```

**Required staging configuration:**
```hcl
project_id = "your-gcp-project-id"
region     = "us-central1"
zone       = "us-central1-a"

# Security (restrict SSH access)
allowed_ssh_ips = ["YOUR.IP.RANGE/24"]

# Credentials (change these!)
odoo_admin_passwd = "staging-secure-password"
db_password       = "staging-db-password"

# Optional domain
domain_name = "staging.your-domain.com"
ssl_email   = "admin@your-domain.com"
```

#### Deploy Staging

```bash
# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply infrastructure
terraform apply
```

#### Verify Staging Deployment

```bash
# Get outputs
terraform output

# SSH to instance
gcloud compute ssh odoo-staging --zone=us-central1-a

# Check services
sudo systemctl status odoo
sudo systemctl status nginx
sudo systemctl status postgresql
```

### Phase 3: Production Deployment

#### Configure Production Environment

```bash
cd ../production

# Copy example configuration  
cp terraform.tfvars.example terraform.tfvars

# Edit configuration carefully
nano terraform.tfvars
```

**Required production configuration:**
```hcl
project_id = "your-gcp-project-id"
region     = "us-central1"
zone       = "us-central1-a"

# High-performance instances
production_odoo_instance_type = "c4-standard-4-lssd"
production_db_instance_type   = "n2-highmem-4"

# Security (IMPORTANT: restrict access)
allowed_ssh_ips = [
  "203.0.113.0/24",  # Office network
  "198.51.100.0/24"  # Admin network
]

# Domain and SSL (REQUIRED)
domain_name = "your-domain.com"
ssl_email   = "admin@your-domain.com"

# Strong passwords (minimum 12 characters)
odoo_admin_passwd = "Production-Strong-Password-123!"
db_password       = "Production-DB-Password-123!"

# Performance tuning
odoo_workers = 7  # Optimized for 4 vCPUs

# Production features
enable_monitoring     = true
enable_backups       = true
backup_retention_days = 30
```

#### Deploy Production

```bash
# Initialize Terraform
terraform init

# Review planned changes carefully
terraform plan

# Apply with confirmation
terraform apply
```

#### Verify Production Deployment

```bash
# Get outputs
terraform output

# Test connectivity
curl -I https://your-domain.com

# SSH to Odoo server
gcloud compute ssh odoo-production --zone=us-central1-a

# SSH to database server
gcloud compute ssh db-production --zone=us-central1-a
```

## 🔍 Post-Deployment Verification

### 1. Application Health Checks

#### Odoo Server (Production)
```bash
# SSH to Odoo server
gcloud compute ssh odoo-production --zone=us-central1-a

# Check Odoo service
sudo systemctl status odoo
journalctl -u odoo -f --since "5 minutes ago"

# Check NGINX
sudo systemctl status nginx
sudo nginx -t

# Check Redis
sudo systemctl status redis-server
redis-cli ping

# Verify local SSD mount
df -h /mnt/disks/ssd
```

#### Database Server (Production)
```bash  
# SSH to database server
gcloud compute ssh db-production --zone=us-central1-a

# Check PostgreSQL
sudo systemctl status postgresql
sudo -u postgres psql -c "SELECT version();"

# Check PgBouncer
sudo systemctl status pgbouncer
psql -h localhost -p 6432 -U postgres -c "SHOW pools;"

# Verify data disk mount
df -h /mnt/data

# Test connectivity from Odoo server
telnet <ODOO_SERVER_IP> 5432
telnet <ODOO_SERVER_IP> 6432
```

### 2. Performance Verification

#### Database Performance
```bash
# PostgreSQL configuration
sudo -u postgres psql -c "SHOW shared_buffers;"
sudo -u postgres psql -c "SHOW effective_cache_size;" 
sudo -u postgres psql -c "SHOW work_mem;"

# Connection pooling
psql -h localhost -p 6432 -U postgres -c "SHOW STATS;"
```

#### Odoo Performance  
```bash
# Verify worker configuration
grep -E "(workers|limit_memory)" /etc/odoo/odoo.conf

# Check memory usage
ps aux | grep odoo
free -h

# Monitor connections
ss -tuln | grep -E "(8069|8072)"
```

### 3. Security Verification

#### Network Security
```bash
# Verify firewall rules
gcloud compute firewall-rules list --filter="network=innova-odoo-production-network"

# Test SSH restrictions
# Should fail from unauthorized IPs
ssh user@<INSTANCE_IP>

# Test internal connectivity
telnet <DB_INTERNAL_IP> 5432  # From Odoo server only
```

#### SSL/TLS Configuration
```bash
# Test SSL certificate
openssl s_client -connect your-domain.com:443 -servername your-domain.com

# Verify certificate auto-renewal
sudo crontab -l | grep certbot

# Test SSL strength
curl -I https://your-domain.com
```

## 🔧 Common Configuration Tasks

### 1. Domain Configuration

#### Update DNS Records
```
# A record for your domain
your-domain.com.     A    <EXTERNAL_IP>
www.your-domain.com. A    <EXTERNAL_IP>
```

#### Test Domain Resolution
```bash
dig your-domain.com
nslookup your-domain.com
```

### 2. Odoo Initial Setup

#### Access Odoo Web Interface
1. Navigate to `https://your-domain.com`
2. Create initial database
3. Configure admin user
4. Install required modules

#### Database Configuration
```sql
-- Connect to PostgreSQL
sudo -u postgres psql

-- Verify Odoo database
\l
\c odoo_database

-- Check table sizes
SELECT schemaname,tablename,attname,n_distinct,correlation 
FROM pg_stats 
ORDER BY n_distinct DESC LIMIT 10;
```

### 3. Monitoring Setup

#### Access Cloud Monitoring
1. Go to [Cloud Monitoring](https://console.cloud.google.com/monitoring)
2. View dashboards created by Terraform
3. Configure additional alerts if needed

#### Custom Monitoring
```bash
# Install monitoring agent (if needed)
curl -sSO https://dl.google.com/cloudagents/add-monitoring-agent-repo.sh
sudo bash add-monitoring-agent-repo.sh
sudo apt-get update
sudo apt-get install stackdriver-agent
```

## 📊 Performance Benchmarks

### Expected Performance Metrics

#### Staging Environment (e2-standard-2)
- **Concurrent Users**: 5-10
- **Response Time**: < 500ms (avg)
- **Memory Usage**: < 80%
- **CPU Usage**: < 60%

#### Production Environment (c4-standard-4-lssd + n2-highmem-4)
- **Concurrent Users**: 30+  
- **Response Time**: < 200ms (avg)
- **Odoo Memory**: < 75% (15GB)
- **DB Memory**: < 70% (32GB)
- **CPU Usage**: < 65%

### Performance Testing

#### Load Testing with Apache Bench
```bash
# Basic load test
ab -n 1000 -c 10 https://your-domain.com/

# Authenticated requests
ab -n 500 -c 5 -C "session_id=your_session_id" https://your-domain.com/web
```

#### Database Performance Test
```bash
# Connection test
pgbench -i -s 10 test_db
pgbench -c 10 -j 2 -t 1000 test_db
```

## 🚨 Troubleshooting

### Common Issues and Solutions

#### 1. Terraform Deployment Failures

**Issue**: Resource already exists
```bash
# Solution: Import existing resources
terraform import google_compute_instance.odoo_instance projects/PROJECT/zones/ZONE/instances/INSTANCE
```

**Issue**: Permission denied
```bash
# Solution: Check IAM roles
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member="user:your-email@domain.com" \
    --role="roles/editor"
```

#### 2. Application Issues

**Issue**: Odoo not starting
```bash
# Check logs
journalctl -u odoo -f
tail -f /var/log/odoo/odoo.log

# Verify configuration
sudo -u odoo /opt/odoo/venv/bin/python /opt/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf --test-enable
```

**Issue**: Database connection failed
```bash
# Test database connectivity
telnet DB_IP 5432
psql -h DB_IP -U odoo -d postgres

# Check PgBouncer
psql -h DB_IP -p 6432 -U odoo -d postgres
```

#### 3. Performance Issues

**Issue**: High memory usage
```bash
# Check Odoo workers
ps aux | grep odoo | wc -l
grep workers /etc/odoo/odoo.conf

# Adjust memory limits
sudo systemctl edit odoo
# Add: MemoryLimit=12G
```

**Issue**: Slow database queries
```bash  
# Enable slow query logging
sudo -u postgres psql -c "ALTER SYSTEM SET log_min_duration_statement = 200;"
sudo systemctl reload postgresql

# Monitor slow queries
tail -f /var/log/postgresql/postgresql-*.log | grep "duration:"
```

## 📚 Next Steps

After successful deployment:

1. **[SECURITY.md](SECURITY.md)** - Implement additional security measures
2. **[MONITORING.md](MONITORING.md)** - Set up comprehensive monitoring  
3. **[BACKUP.md](BACKUP.md)** - Configure backup and disaster recovery
4. **[PERFORMANCE.md](PERFORMANCE.md)** - Fine-tune performance settings

## 🆘 Support

If you encounter issues during deployment:

1. Check the [troubleshooting section](#-troubleshooting)
2. Review Terraform and application logs
3. Open an issue on [GitHub](https://github.com/elinarezv/innova-infrastructure-iac/issues)
4. Include relevant logs and configuration details