# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform Infrastructure as Code (IaC) project for deploying scalable application infrastructure on Google Cloud Platform. The infrastructure supports two environments (staging and production) with different scaling characteristics:

- **Staging**: Single e2-standard-2 VM with both application and PostgreSQL database
- **Production**: Dual VM architecture with c4-standard-4-lssd for applications (with NVMe optimization) and n2-highmem-4 for PostgreSQL
- **Security**: OpenVPN server (e2-micro) for secure admin access - SSH and database access only via VPN

## Essential Commands

### Initial Setup
```bash
# Create GCS bucket for Terraform state (one-time setup)
gsutil mb gs://YOUR-PROJECT-ID-terraform-state

# Configure credentials
gcloud auth application-default login
gcloud config set project YOUR-PROJECT-ID
```

### Terraform Deployment
```bash
# Deploy staging environment
cd environments/staging
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply

# Deploy production environment
cd environments/production
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with production values
terraform init
terraform plan
terraform apply
```

### VPN Management
```bash
# Enhanced VPN user creation (with SSH key management)
./scripts/create-vpn-user.sh USERNAME [SSH_PUBLIC_KEY_PATH]
# Example: ./scripts/create-vpn-user.sh john ~/.ssh/id_rsa.pub

# Alternative: Generate VPN client configuration only
./scripts/generate-vpn-client.sh PROJECT_ID ZONE USERNAME

# Manual VPN user management (on VPN server)
gcloud compute ssh vpn-staging --zone=us-central1-a --command="sudo /opt/scripts/manage-vpn-users.sh add USERNAME"

# Add SSH key to existing VPN user
gcloud compute ssh vpn-staging --zone=us-central1-a --command="sudo /opt/scripts/manage-vpn-users.sh add-ssh-key USERNAME 'ssh-rsa AAAAB...'"

# List active VPN connections and SSH users
gcloud compute ssh vpn-staging --zone=us-central1-a --command="sudo /opt/scripts/manage-vpn-users.sh list"

# List all VPN and SSH users
gcloud compute ssh vpn-staging --zone=us-central1-a --command="sudo /opt/scripts/manage-vpn-users.sh list-users"

# Revoke VPN and SSH access
gcloud compute ssh vpn-staging --zone=us-central1-a --command="sudo /opt/scripts/manage-vpn-users.sh revoke USERNAME"

# Download VPN configuration
gcloud compute scp vpn-staging:/opt/vpn-configs/USERNAME.ovpn . --zone=us-central1-a

# Monitor VPN status
gcloud compute ssh vpn-staging --zone=us-central1-a --command="sudo /opt/scripts/vpn-monitor.sh"
```

### SSL Certificate Setup
```bash
# Set up SSL certificate with Let's Encrypt
sudo ./scripts/setup-ssl.sh -d your-domain.com -e admin@your-domain.com
```

### SSH Access
```bash
# SSH to VPN server (requires project-level SSH keys configured)
gcloud compute ssh vpn-staging --zone=us-central1-a

# SSH to internal servers (requires VPN connection first)
# After connecting to VPN, use internal IPs:
ssh username@10.0.0.3  # App server staging
ssh username@10.0.0.4  # Jenkins server (if deployed)

# Alternative: Use gcloud with --internal-ip (requires VPN connection)
gcloud compute ssh app-staging --zone=us-central1-a --internal-ip

# Configure SSH keys for project
gcloud compute project-info add-metadata --metadata-from-file ssh-keys=~/.ssh/id_rsa.pub
```

### NVMe Optimization
```bash
# Run standalone NVMe optimization on production app server
sudo ./scripts/optimize-nvme-odoo.sh /dev/nvme0n1 /opt/app-data

# Monitor NVMe performance
sudo /opt/scripts/system-monitor.sh
```

### Monitoring and Troubleshooting
```bash
# Check service status
sudo systemctl status nginx
sudo systemctl status postgresql

# Monitor system resources
sudo /opt/scripts/system-monitor.sh

# Monitor NVMe performance (production app server)
iostat -x 1
nvme smart-log /dev/nvme0n1

# View NGINX logs
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# Database monitoring (on database server)
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;"
```

## Architecture Details

### Module Structure
The project uses a modular Terraform architecture with the following key modules:

1. **networking**: Creates VPC, subnets, and firewall rules. VPN-only SSH access (10.8.0.0/24), public HTTPS/HTTP for web applications
2. **compute**: Manages VM instances with environment-specific configurations and startup scripts
3. **database**: PostgreSQL configuration on dedicated VM (production) or shared VM (staging)
4. **security**: Service accounts, IAM roles, and KMS encryption
5. **monitoring**: Cloud Monitoring dashboards and alert policies
6. **vpn**: OpenVPN server configuration for secure admin access (5 concurrent users max)

### Critical Configuration Files

- **environments/{staging,production}/terraform.tfvars**: Environment-specific variables (passwords, instance types, domain)
- **modules/compute/templates/production-app-startup.sh**: Contains NVMe optimization, NGINX setup, and performance tuning
- **modules/compute/templates/production-db-startup.sh**: PostgreSQL optimization for high-performance workloads
- **modules/compute/templates/staging-startup.sh**: Combined app and database setup for development
- **modules/vpn/templates/openvpn-startup.sh**: OpenVPN server setup, certificate management, and SSH key integration
- **scripts/create-vpn-user.sh**: Enhanced VPN user creation with automatic SSH key management

### Performance Optimizations

#### NVMe Storage (Production App Server)
- Partition: Single GPT partition using 100% space
- Filesystem: ext4 with 4KB blocks, 8192 bytes/inode ratio, 1% reserved blocks
- Mount options: noatime, user_xattr, data=writeback
- Storage location: /opt/app-data for application file storage

#### PostgreSQL Tuning
- **Production**: shared_buffers: 8GB (25% of RAM), effective_cache_size: 24GB (75% of RAM)
- **Staging**: shared_buffers: 2GB (25% of RAM), effective_cache_size: 6GB (75% of RAM)
- Connection pooling and performance optimizations

#### NGINX Configuration
- HTTP/2 enabled for performance
- Security headers configured
- Static file caching and compression
- Health check endpoints

### Security Considerations

- **Zero external SSH**: All SSH access requires VPN connection
- **Firewall rules**: 
  - SSH (22): Only from VPN subnet (10.8.0.0/24)
  - PostgreSQL (5432): Internal only
  - HTTPS/HTTP (443/80): Public access for web applications
- **VPN**: Certificate-based authentication, 5 user limit
- **SSL/TLS**: Let's Encrypt integration for production domains

### Common Development Tasks

When modifying the infrastructure:

1. **Adding new firewall rules**: Update `modules/networking/main.tf`
2. **Changing instance types**: Modify terraform.tfvars in the respective environment
3. **Updating server configuration**: Edit startup scripts in `modules/compute/templates/`
4. **Adding VPN users**: Use the setup-vpn-client.sh script
5. **Setting up SSL**: Use the setup-ssl.sh script
6. **Optimizing NVMe**: Run optimize-nvme-odoo.sh or modify production-app-startup.sh

### Testing Changes

```bash
# Validate Terraform configuration
terraform validate

# Format Terraform files
terraform fmt -recursive

# Check what will change before applying
terraform plan -detailed-exitcode

# Apply only specific resources
terraform apply -target=module.production_infrastructure.module.compute
```

### Environment-Specific Notes

#### Staging Environment
- Single VM with combined application and database
- Basic monitoring and short backup retention
- Cost-optimized configuration
- Suitable for development and testing

#### Production Environment
- Dual VM architecture for better performance and separation
- NVMe storage optimization for file-intensive workloads
- Enhanced monitoring and alerting
- 30-day backup retention
- SSL/TLS required for production domains

### Destroying Infrastructure

```bash
# Destroy specific environment
cd environments/staging
terraform destroy

# Remove specific resources
terraform destroy -target=module.staging_infrastructure.module.compute.google_compute_instance.staging
```

## Important Notes

- **State Management**: Terraform state is stored in GCS bucket `${PROJECT_ID}-terraform-state`
- **VPN Requirement**: SSH and database access only available through VPN connection
- **NVMe is Ephemeral**: Local SSD data is lost on instance stop - application data should be backed up to GCS
- **Passwords**: Always change default passwords in terraform.tfvars before deployment
- **Domain/SSL**: Production requires valid domain name for Let's Encrypt SSL certificates
- **Application Deployment**: This infrastructure provides the foundation - application code deployment is handled separately