# CLAUDE.md Template for New Repository

This file provides comprehensive guidance to Claude Code (claude.ai/code) when working with the application deployed on the GCP infrastructure.

## Infrastructure Overview

This application runs on a Google Cloud Platform infrastructure deployed via Terraform with the following architecture:

### Production Environment
- **Application Server**: c4-standard-4-lssd (4 vCPUs, 16GB RAM, 375GB NVMe SSD)
  - Optimized NVMe storage at `/opt/app-data` for file-intensive operations
  - NGINX reverse proxy with HTTP/2 and SSL/TLS
  - Health monitoring and performance tracking
- **Database Server**: n2-highmem-4 (4 vCPUs, 32GB RAM, 100GB SSD)
  - PostgreSQL 15 with performance tuning
  - 8GB shared buffers, 24GB effective cache
  - Automated daily backups to GCS (30-day retention)
- **Jenkins CI/CD Server**: e2-standard-4 (4 vCPUs, 16GB RAM, 100GB persistent SSD)
  - Complete CI/CD pipeline management
  - Docker support for containerized builds
  - Automated deployments to staging and production
  - VPN-only access for security
  - Persistent storage for build artifacts and workspace
- **VPN Server**: e2-micro for secure admin access
  - OpenVPN with certificate-based authentication
  - All SSH, database, and Jenkins access requires VPN connection

### Staging Environment
- **Combined Server**: e2-standard-2 (2 vCPUs, 8GB RAM, 50GB SSD)
  - Application and PostgreSQL on same instance
  - Basic monitoring and 7-day backup retention
  - Cost-optimized for development/testing

### Network Architecture
- **VPC**: Custom VPC with public and private subnets
- **Firewall Rules**:
  - HTTPS/HTTP (443/80): Public access for web traffic
  - SSH (22): Only from VPN subnet (10.8.0.0/24)
  - PostgreSQL (5432): Internal communication only
  - Jenkins (8080): Only from VPN subnet (10.8.0.0/24)
  - Jenkins Agent (50000): Internal and VPN subnet access
  - Application ports: Configured based on application needs
- **Load Balancing**: NGINX handles SSL termination and request routing

## Application Deployment Context

### File Storage
- **Production**: NVMe-optimized storage at `/opt/app-data`
  - Mount options: `noatime,user_xattr,data=writeback`
  - Ideal for file uploads, caches, and temporary data
  - **WARNING**: Local SSD is ephemeral - implement GCS backups for persistence
- **Staging**: Standard persistent disk at `/opt/app-data`

### Database Connection
```bash
# Production database connection (from app server or via VPN)
PGHOST=db-production.c.PROJECT_ID.internal
PGPORT=5432
PGDATABASE=app_db
PGUSER=app_user
# Password stored in environment variables or secrets

# Staging database connection (local)
PGHOST=localhost
PGPORT=5432
PGDATABASE=app_db
PGUSER=app_user
```

### Environment Variables
The application should read configuration from:
- `/etc/app/config.env` - Main configuration file
- System environment variables
- GCP Secret Manager (if implemented)

## Essential Commands for Development

### SSH Access (VPN Required)
```bash
# First, connect to VPN using provided .ovpn file
# Then SSH to instances
gcloud compute ssh app-production --zone=us-central1-a
gcloud compute ssh db-production --zone=us-central1-a
gcloud compute ssh jenkins-production --zone=us-central1-a
gcloud compute ssh app-staging --zone=us-central1-a
```

### Application Management
```bash
# Check application status
sudo systemctl status app-service

# View application logs
sudo journalctl -u app-service -f
tail -f /var/log/app/application.log

# Restart application
sudo systemctl restart app-service

# Deploy new version
cd /opt/app
git pull origin main
# Run deployment script specific to your application
sudo systemctl restart app-service
```

### Database Operations
```bash
# Connect to production database (from app server)
sudo -u postgres psql -h db-production.c.PROJECT_ID.internal -d app_db

# Connect to staging database (local)
sudo -u postgres psql -d app_db

# Backup database manually
sudo -u postgres pg_dump app_db | gzip > /backup/app_db_$(date +%Y%m%d).sql.gz

# Restore database
gunzip -c backup.sql.gz | sudo -u postgres psql app_db
```

### File Storage Management
```bash
# Check NVMe storage usage (production)
df -h /opt/app-data
iostat -x 1  # Monitor I/O performance

# Sync files to GCS backup
gsutil -m rsync -r /opt/app-data gs://PROJECT_ID-app-backups/files/

# Clean up old temporary files
find /opt/app-data/temp -type f -mtime +7 -delete
```

### Monitoring and Debugging
```bash
# System resource monitoring
htop
sudo /opt/scripts/system-monitor.sh

# Check NGINX status and logs
sudo systemctl status nginx
tail -f /var/log/nginx/access.log
tail -f /var/log/nginx/error.log

# Database performance
sudo -u postgres psql -c "SELECT * FROM pg_stat_activity;"
sudo -u postgres psql -c "SELECT * FROM pg_stat_database;"

# Application performance profiling
# Add profiling commands specific to your application stack
```

### Jenkins CI/CD Management
```bash
# Check Jenkins status
sudo systemctl status jenkins

# View Jenkins logs
sudo journalctl -u jenkins -f
tail -f /var/log/jenkins/jenkins.log

# Restart Jenkins
sudo systemctl restart jenkins

# Access Jenkins web interface (via VPN)
# Navigate to: http://JENKINS_INTERNAL_IP:8080/jenkins
# Or: https://jenkins.your-domain.com (if domain configured)

# Install Jenkins plugins via CLI
sudo -u jenkins java -jar /var/lib/jenkins/war/WEB-INF/jenkins-cli.jar -s http://localhost:8080/jenkins/ -auth admin:PASSWORD install-plugin PLUGIN_NAME

# Create Jenkins job from command line
curl -X POST "http://localhost:8080/jenkins/createItem?name=NEW_JOB_NAME" \
  --user admin:PASSWORD \
  --header "Content-Type: application/xml" \
  --data @job-config.xml

# Trigger Jenkins build
curl -X POST "http://localhost:8080/jenkins/job/JOB_NAME/build" \
  --user admin:PASSWORD

# Backup Jenkins data
sudo tar -czf /backup/jenkins-backup-$(date +%Y%m%d).tar.gz -C /var/lib/jenkins .

# Monitor Jenkins disk usage
df -h /var/lib/jenkins
sudo du -sh /var/lib/jenkins/workspace/*
```

### SSL Certificate Management
```bash
# Renew SSL certificate
sudo certbot renew

# Check certificate status
sudo certbot certificates

# Update domain/certificate
sudo ./scripts/setup-ssl.sh -d new-domain.com -e admin@new-domain.com
```

## Development Workflow

### Local Development Setup
1. Connect to VPN for database access
2. Set up SSH tunnel for database if needed:
   ```bash
   ssh -L 5432:db-production.c.PROJECT_ID.internal:5432 app-production
   ```
3. Configure local environment variables to match production/staging

### Deployment Process

1. **Jenkins Pipeline Setup**:
   ```bash
   # Connect to Jenkins (via VPN)
   # Access Jenkins web UI at http://JENKINS_IP:8080/jenkins
   
   # Create deployment pipeline job
   # Configure pipeline script or Jenkinsfile from repository
   # Set up credentials for GitHub, staging, and production access
   ```

2. **Automated Staging Deployment via Jenkins**:
   ```groovy
   // Example Jenkinsfile for staging deployment
   pipeline {
       agent any
       stages {
           stage('Build') {
               steps {
                   sh 'docker build -t myapp:${BUILD_NUMBER} .'
               }
           }
           stage('Deploy to Staging') {
               steps {
                   sshagent(['staging-deploy-key']) {
                       sh '''
                           ssh -o StrictHostKeyChecking=no user@staging-server "
                           cd /opt/app &&
                           git pull origin main &&
                           docker-compose up -d --build
                           "
                       '''
                   }
               }
           }
       }
   }
   ```

3. **Production Deployment via Jenkins**:
   ```bash
   # Create release tag
   git tag -a v1.0.0 -m "Release version 1.0.0"
   git push origin v1.0.0
   
   # Trigger production deployment job in Jenkins
   # Or use manual deployment:
   
   # SSH to production app server
   gcloud compute ssh app-production --zone=us-central1-a
   
   # Deploy with zero-downtime strategy
   cd /opt/app
   git fetch --tags
   git checkout v1.0.0
   # Run deployment scripts
   sudo systemctl reload app-service  # Or rolling restart
   ```

4. **Manual Staging Deployment** (alternative):
   ```bash
   # Push code to staging branch
   git push origin develop:staging
   
   # SSH to staging server
   gcloud compute ssh app-staging --zone=us-central1-a
   
   # Deploy and test
   cd /opt/app
   git pull origin staging
   # Run deployment scripts
   sudo systemctl restart app-service
   ```

### Testing on Infrastructure
```bash
# Health check endpoints
curl https://your-domain.com/health
curl https://your-domain.com/api/status

# Jenkins health check
curl http://JENKINS_IP:8080/jenkins/login (via VPN)

# Load testing (from external machine)
ab -n 1000 -c 10 https://your-domain.com/

# Jenkins build testing
# Access Jenkins web UI and trigger test builds
# Or use Jenkins CLI to run builds programmatically
```

## Application-Specific Configuration

### Web Server Integration
NGINX is configured as reverse proxy at:
- Configuration: `/etc/nginx/sites-available/app`
- Upstream backend: `localhost:8000` (adjust port as needed)
- Static files: `/opt/app/static`
- Media files: `/opt/app-data/media`

### Database Schema Management
```bash
# Run migrations (example for common frameworks)
# Django
python manage.py migrate

# Rails
rails db:migrate

# Node.js with Sequelize
npx sequelize-cli db:migrate

# Custom SQL migrations
psql -U app_user -d app_db -f migrations/001_initial.sql
```

### Environment-Specific Settings
```python
# Example: Detecting environment in application
import os

ENVIRONMENT = os.getenv('APP_ENV', 'development')

if ENVIRONMENT == 'production':
    DATABASE_HOST = 'db-production.c.PROJECT_ID.internal'
    DEBUG = False
    USE_NVME_STORAGE = True
    STORAGE_PATH = '/opt/app-data'
elif ENVIRONMENT == 'staging':
    DATABASE_HOST = 'localhost'
    DEBUG = True
    USE_NVME_STORAGE = False
    STORAGE_PATH = '/opt/app-data'
```

## Performance Optimization Guidelines

### NVMe Storage Best Practices
- Use for temporary files, caches, and uploads
- Implement async I/O for better performance
- Batch write operations when possible
- Monitor disk usage - NVMe fills up faster due to high throughput
- Implement cleanup routines for old files

### Database Optimization
- Use connection pooling (max connections: 200)
- Implement query caching where appropriate
- Use indexes effectively
- Monitor slow queries in pg_stat_statements
- Consider read replicas for heavy read workloads

### Application Scaling
- Horizontal scaling ready (load balancer configured)
- Use Redis/Memcached for session storage (not local files)
- Implement health checks for auto-scaling
- Design for stateless operation where possible

## Security Considerations

### Access Control
- **Never expose SSH publicly** - Always use VPN
- Implement application-level authentication
- Use GCP IAM for service-to-service auth
- Rotate database passwords regularly
- Store secrets in environment variables or Secret Manager

### Data Protection
- Enable database SSL connections
- Implement application-level encryption for sensitive data
- Regular backups to GCS with lifecycle policies
- Use HTTPS for all external communication
- Implement rate limiting at application level

### Monitoring and Alerts
- Set up application-specific metrics
- Configure error tracking (e.g., Sentry, GCP Error Reporting)
- Monitor for security events
- Set up alerts for:
  - High CPU/memory usage
  - Disk space running low
  - Database connection issues
  - Application errors spike

## Troubleshooting Guide

### Common Issues and Solutions

1. **Application won't start**:
   ```bash
   # Check logs
   sudo journalctl -u app-service -n 100
   # Check configuration
   sudo nginx -t
   # Verify database connection
   psql -h DATABASE_HOST -U app_user -d app_db -c "SELECT 1;"
   ```

2. **Database connection errors**:
   ```bash
   # Check PostgreSQL status
   sudo systemctl status postgresql
   # Check connection limits
   sudo -u postgres psql -c "SHOW max_connections;"
   # Review pg_hba.conf
   sudo cat /etc/postgresql/15/main/pg_hba.conf
   ```

3. **Storage full**:
   ```bash
   # Find large files
   sudo du -sh /opt/app-data/* | sort -h
   # Clean up logs
   sudo journalctl --vacuum-time=7d
   # Remove old backups
   find /backup -name "*.gz" -mtime +30 -delete
   ```

4. **Performance issues**:
   ```bash
   # Check system resources
   htop
   iostat -x 1
   # Database performance
   sudo -u postgres psql -c "SELECT * FROM pg_stat_activity WHERE state != 'idle';"
   # NGINX connections
   sudo nginx -V 2>&1 | grep worker_connections
   ```

## Infrastructure Maintenance

### Regular Tasks
- **Daily**: Check application logs, monitor metrics, review Jenkins builds
- **Weekly**: Review backup integrity, check disk usage, clean Jenkins workspace
- **Monthly**: Update system packages, review security logs, update Jenkins plugins
- **Quarterly**: Rotate credentials, update SSL certificates, review Jenkins job configurations

### Upgrade Procedures
```bash
# System updates (scheduled maintenance window)
sudo apt update && sudo apt upgrade

# PostgreSQL minor version updates
sudo apt install postgresql-15

# Jenkins updates
sudo apt update jenkins
sudo systemctl restart jenkins

# Application framework updates
# Follow framework-specific upgrade guides
```

## Cost Optimization Tips

1. **Use staging environment** for development/testing
2. **Schedule non-production instances** to shut down after hours
3. **Run Jenkins only when needed** - enable/disable based on deployment schedule
4. **Implement lifecycle policies** for GCS backups
5. **Clean Jenkins workspace** regularly to manage disk usage
6. **Monitor and optimize** database queries to reduce CPU usage
7. **Use Cloud CDN** for static assets if applicable
8. **Optimize Docker images** in Jenkins builds to reduce storage costs

## Important Notes

- **VPN is mandatory** for all administrative access (including Jenkins)
- **NVMe storage is ephemeral** - data lost on instance stop
- **Jenkins data is persistent** - stored on dedicated disk
- **Backup critical data** to GCS regularly (including Jenkins configurations)
- **Monitor costs** through GCP billing dashboard
- **Jenkins builds can be resource-intensive** - monitor CPU and memory usage
- **Follow security best practices** for application code and CI/CD pipelines
- **Document application-specific** deployment procedures and Jenkins job configurations

## Contact and Support

- **Infrastructure Issues**: Check Terraform state and GCP Console
- **Application Issues**: Review application logs and metrics
- **Jenkins/CI-CD Issues**: Check Jenkins logs and build history
- **Security Concerns**: Contact security team immediately
- **Performance Problems**: Use monitoring dashboards for diagnosis

---

Remember to customize this template with your specific application details, including:
- Actual port numbers and service names
- Framework-specific commands
- Application-specific environment variables
- Custom monitoring and alerting requirements
- Deployment automation scripts
- Jenkins job configurations and pipeline definitions
- CI/CD workflow specific to your application stack