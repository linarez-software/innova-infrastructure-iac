# Staging Environment Requirements

## Functional Requirements

### 🎯 Primary Objectives
- **Development Platform**: Provide a production-like environment for development and testing
- **Cost Efficiency**: Maintain minimal operational costs while ensuring functionality
- **Security Validation**: Test security configurations before production deployment
- **Integration Testing**: Enable comprehensive application and infrastructure testing

### 🏗️ Infrastructure Requirements

#### Compute Requirements
| Component | Instance Type | vCPU | Memory | Storage | Justification |
|-----------|---------------|------|--------|---------|---------------|
| Application Server | e2-standard-2 | 2 | 8GB | 80GB | Sufficient for Odoo + PostgreSQL + Redis with file storage |
| VPN Server | e2-micro | 0.25-2 | 1GB | 10GB | Minimal requirements for OpenVPN |
| Jenkins Server | e2-small | 0.5-2 | 2GB | 30GB | Optional CI/CD for automation |

#### Network Requirements
- **VPC CIDR**: 10.0.0.0/24 (254 available IPs)
- **VPN CIDR**: 10.8.0.0/24 (254 VPN client IPs)
- **Static IP Addresses**: 3 static external IPs (VPN + Application + Jenkins servers)
- **Internet Access**: Required for updates and external integrations
- **Internal Communication**: Full connectivity between all services
- **External Access**: Web application accessible from internet

#### Storage Requirements
- **Database Storage**: 10GB minimum, expandable
- **Application Storage**: 5GB for application files
- **Log Storage**: 2GB with rotation
- **Temporary Storage**: Local storage for development data
- **Performance**: Standard persistent disk sufficient for staging workloads

### 🔒 Security Requirements

#### Access Control
- **Admin Access**: VPN-only SSH and administrative access
- **Application Access**: Public HTTP/HTTPS for testing
- **Database Access**: Internal and VPN-only access
- **Service-to-Service**: Authenticated internal communication

#### Authentication & Authorization
- **VPN Authentication**: Certificate-based OpenVPN
- **SSH Authentication**: Key-based with OS Login
- **Service Accounts**: Least-privilege Google Cloud IAM
- **Application Auth**: Standard Odoo authentication

#### Network Security
- **Firewall Rules**: Restrictive ingress, permissive egress
- **Encryption**: TLS for web traffic, encrypted VPN tunnels
- **Network Segmentation**: Clear separation of public/private services
- **Monitoring**: Security event logging and alerting

### 📊 Performance Requirements

#### Application Performance
- **Response Time**: < 2 seconds for typical web requests
- **Concurrent Users**: Support 10-20 concurrent users
- **Database Performance**: < 100ms for typical queries
- **Cache Performance**: Redis response time < 10ms

#### System Performance
- **CPU Utilization**: < 70% average, < 90% peak
- **Memory Utilization**: < 80% average, < 95% peak  
- **Disk I/O**: Sufficient for database and application needs
- **Network**: 100Mbps sufficient for staging workloads

#### Availability Requirements
- **Uptime Target**: 95% (acceptable for development environment)
- **Recovery Time**: < 30 minutes for full environment rebuild
- **Data Refresh**: Environment can be recreated from Infrastructure as Code
- **Maintenance Window**: Weekends acceptable for updates

## Technical Requirements

### 🖥️ Operating System & Software

#### Base System
- **OS**: Ubuntu 22.04 LTS (stable, long-term support)
- **Updates**: Monthly security updates
- **Monitoring Agent**: Google Cloud Monitoring agent
- **Logging**: Cloud Logging integration

#### Application Stack
```
┌─────────────────────────────────────┐
│           Application Layer          │
├─────────────────────────────────────┤
│ Odoo 16.0+ (Python/PostgreSQL)     │
│ NGINX (Reverse Proxy & Static)      │
│ Redis (Session & Cache)             │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│            Data Layer               │
├─────────────────────────────────────┤
│ PostgreSQL 14+ (Primary Database)   │
│ Cloud Storage (Backups & Files)     │
└─────────────────────────────────────┘
┌─────────────────────────────────────┐
│          Infrastructure             │
├─────────────────────────────────────┤
│ Google Cloud Platform               │
│ Ubuntu 22.04 LTS                   │
│ OpenVPN (Admin Access)              │
└─────────────────────────────────────┘
```

#### Development Tools (Jenkins Server)
- **CI/CD**: Jenkins Controller and build agents
- **Database Admin**: pgAdmin 4 (web interface on Jenkins server)
- **Email Testing**: Mailhog (SMTP testing on Jenkins server)
- **Monitoring**: Cloud Monitoring dashboards
- **Log Analysis**: Cloud Logging and local log tools

### 🌐 Network Architecture

#### VPC Configuration
```yaml
Network: staging-vpc
  CIDR: 10.0.0.0/24
  Region: us-central1
  Project: deep-wares-246918
  Subnets:
    - staging-subnet: 10.0.0.0/24
  
Static IP Addresses:
  - staging-vpn-ip: Reserved for VPN server
  - staging-app-ip: Reserved for application server
  - staging-jenkins-ip: Reserved for Jenkins server (firewall-protected)
  
VPN Network: 10.8.0.0/24
  Protocol: OpenVPN UDP
  Port: 1194
  Max Clients: 5
  
External Access:
  - Web Application: 80, 443 (Public, Static IP)
  - VPN Server: 1194 (Public, Static IP)
  - SSH: 22 (VPN-only)
```

#### DNS & Web Traffic
- **DNS**: External DNS management (not managed by infrastructure)
- **Reverse Proxy**: NGINX on application server handles all web traffic
- **SSL/TLS**: Let's Encrypt certificates for HTTPS
- **CDN**: Not required for staging environment

### 🔐 Security Specifications

#### Firewall Configuration
```yaml
Ingress Rules:
  staging-allow-http-https:
    ports: [80, 443]
    source: 0.0.0.0/0
    target: web-server
    
  staging-allow-vpn-server:
    ports: [1194]
    protocol: UDP
    source: 0.0.0.0/0
    target: vpn-server
    
  staging-allow-ssh-vpn-only:
    ports: [22]
    source: 10.8.0.0/24
    target: ssh-server
    
  staging-allow-jenkins-web:
    ports: [8080]
    source: 10.8.0.0/24
    target: jenkins-server
    
  staging-allow-dev-tools:
    ports: [8025, 5050]
    source: 10.8.0.0/24
    target: dev-tools
    
  staging-allow-internal-subnet:
    ports: ALL
    source: 10.0.0.0/24
    target: ALL
    
  staging-allow-vpn-clients:
    ports: ALL
    source: 10.8.0.0/24
    target: ALL
    
  staging-allow-postgresql:
    ports: [5432]
    source: [10.0.0.0/24, 10.8.0.0/24]
    target: database-server
    
  staging-allow-redis:
    ports: [6379]
    source: [10.0.0.0/24, 10.8.0.0/24]
    target: cache-server
    
  staging-deny-direct-app-ports:
    ports: [8000-8999]
    source: 0.0.0.0/0
    target: app-server
    action: DENY
```

#### Service Account Permissions
```yaml
app-staging-sa:
  roles:
    - roles/compute.instanceAdmin
    - roles/logging.logWriter
    - roles/monitoring.metricWriter
    - roles/storage.objectViewer
    
vpn-staging-sa:
  roles:
    - roles/compute.instanceAdmin
    - roles/logging.logWriter
    - roles/storage.admin
    
jenkins-staging-sa:
  roles:
    - roles/compute.admin
    - roles/container.admin
    - roles/source.admin
    - roles/secretmanager.secretAccessor
```

## Operational Requirements

### 📊 Monitoring & Alerting

#### System Monitoring
- **CPU Usage**: Alert if > 85% for 5+ minutes
- **Memory Usage**: Alert if > 90% for 5+ minutes
- **Disk Usage**: Alert if > 85% used
- **Network**: Monitor bandwidth utilization

#### Application Monitoring
- **Web Response Time**: Alert if > 5 seconds average
- **Database Connections**: Monitor connection pool usage
- **Error Rate**: Alert if > 5% error rate
- **Service Health**: Automated health checks

#### Security Monitoring
- **Failed Login Attempts**: Monitor SSH and VPN failures
- **Unusual Access Patterns**: Alert on suspicious activity
- **Certificate Expiration**: Alert 30 days before expiry
- **Firewall Violations**: Log and alert on blocked traffic

### 🔄 Environment Management

#### Data Strategy
```yaml
Development Data:
  approach: Ephemeral, no backups required
  refresh: Weekly environment recreation
  
Configuration Management:
  frequency: On every change
  location: Git repository
  
VPN Certificates:
  approach: Generated on deployment
  recreation: Automated via Infrastructure as Code
```

#### Recovery Procedures
- **Environment Recovery**: < 30 minutes using Infrastructure as Code
- **Configuration Recovery**: Immediate from Git repository  
- **Certificate Recovery**: < 5 minutes automated regeneration
- **Data Recovery**: Not applicable (development environment)

### 🚀 Deployment Requirements

#### Infrastructure Deployment
- **Method**: Terraform Infrastructure as Code
- **Validation**: Automated testing of deployed resources
- **Rollback**: Ability to destroy and recreate environment
- **Documentation**: All changes documented and version controlled

#### Application Deployment
- **Method**: Automated scripts or CI/CD pipeline
- **Testing**: Automated health checks post-deployment
- **Rollback**: Database and application rollback procedures
- **Zero-Downtime**: Not required for staging environment

## Compliance Requirements

### 🔒 Security Compliance
- **Data Protection**: No production data in staging environment
- **Access Logging**: All administrative access logged
- **Encryption**: Data in transit and at rest where applicable
- **Regular Updates**: Monthly security updates applied

### 📋 Operational Compliance
- **Change Management**: All infrastructure changes version controlled
- **Documentation**: Architecture and procedures documented
- **Testing**: Regular environment recreation testing
- **Monitoring**: Comprehensive monitoring and alerting

### 💰 Cost Compliance
- **Budget Target**: < $70/month total cost (reduced from $100)
- **Resource Optimization**: Right-sizing of instances
- **Static IP Management**: 3 static IPs for direct internet access (no NAT costs)
- **Major Savings**: Removed Cloud Router + NAT infrastructure (~$100/month saved)
- **Scheduling**: Optional shutdown schedules for cost savings (IPs retained)
- **Monitoring**: Cost monitoring and alerting

---

## Acceptance Criteria

### ✅ Infrastructure Deployment
- [ ] All compute instances deployed and healthy
- [ ] Network connectivity verified (internal and external)
- [ ] Firewall rules tested and validated
- [ ] VPN connectivity established and tested
- [ ] Monitoring and alerting configured

### ✅ Application Deployment
- [ ] Odoo application accessible via web browser
- [ ] Database connectivity and functionality verified
- [ ] Redis cache operational
- [ ] Development tools accessible via VPN
- [ ] SSL/TLS certificates configured and working

### ✅ Security Validation
- [ ] VPN-only SSH access enforced
- [ ] Public web access working correctly
- [ ] Internal service communication secured
- [ ] Service accounts configured with minimal permissions
- [ ] Security monitoring and alerting active

### ✅ Operational Readiness
- [ ] Environment recreation procedures tested
- [ ] Monitoring dashboards configured
- [ ] Alerting policies tested
- [ ] Documentation complete and accessible
- [ ] Recovery procedures tested and validated

This requirements document serves as the foundation for implementing the staging environment and validates that all necessary functionality is properly designed and implemented.