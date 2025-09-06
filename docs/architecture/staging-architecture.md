# Staging Environment Architecture

## Overview
The staging environment is designed to provide a cost-effective, secure, and development-friendly infrastructure that mirrors production patterns while optimizing for development workflows and cost efficiency.

## Architecture Principles

### 🎯 Core Objectives
- **Cost Optimization**: Minimal resource usage while maintaining functionality
- **Security First**: Production-like security patterns with VPN-only admin access
- **Development Friendly**: Easy access to development and debugging tools
- **Production Simulation**: Similar architecture patterns to production
- **Fast Iteration**: Quick deployment and testing cycles

### 🏗️ Design Patterns
- **Consolidated Architecture**: Single VM hosts multiple services
- **Security Zones**: Clear separation between public and admin access
- **Infrastructure as Code**: Fully automated deployment and management
- **Monitoring Integration**: Comprehensive observability from day one

## Infrastructure Components

### 🖥️ Compute Resources

#### Application Server (`app-staging`)
- **Instance Type**: `e2-standard-2` (2 vCPU, 8GB RAM)
- **OS**: Ubuntu 22.04 LTS
- **Storage**: 80GB Standard Persistent Disk
- **Network**: Internal IP `10.0.0.3`, Static External IP
- **Services Hosted**:
  - Odoo Application Server
  - PostgreSQL Database
  - Redis Cache
  - NGINX Reverse Proxy

#### VPN Server (`vpn-staging`)
- **Instance Type**: `e2-micro` (0.25-2 vCPU, 1GB RAM)
- **OS**: Ubuntu 22.04 LTS  
- **Storage**: 10GB Standard Persistent Disk
- **Network**: Internal IP `10.0.0.2`, Static External IP
- **Services**:
  - OpenVPN Server (max 5 concurrent connections)
  - Certificate Management
  - Admin Access Gateway

#### Jenkins Server (`jenkins-staging`) [Optional]
- **Instance Type**: `e2-small` (0.5-2 vCPU, 2GB RAM)
- **OS**: Ubuntu 22.04 LTS
- **Storage**: 30GB Standard Persistent Disk
- **Network**: Internal IP `10.0.0.4`, Static External IP
- **Services**:
  - Jenkins Controller
  - Build Agents
  - Artifact Storage
  - Development Tools:
    - Mailhog (Email Testing)
    - pgAdmin (Database Administration)

### 🌐 Networking Architecture

#### VPC Configuration
- **Network Name**: `staging-vpc`
- **Subnet Name**: `staging-subnet`
- **CIDR Block**: `10.0.0.0/24` (254 available IPs)
- **Region**: `us-central1`
- **Project**: `deep-wares-246918`
- **Routing**: Regional routing mode

#### VPN Network
- **VPN Subnet**: `10.8.0.0/24` (VPN client tunnel network)
- **Protocol**: OpenVPN UDP
- **Port**: 1194
- **Authentication**: Certificate-based
- **Encryption**: AES-256-CBC with SHA256 auth

#### External Connectivity
- **Internet Gateway**: Implicit (Google Cloud default)
- **Direct Internet Access**: All servers have static external IPs
- **Reverse Proxy**: NGINX on application server handles all web traffic
- **Static IP Addresses**:
  - `staging-vpn-ip`: Reserved for OpenVPN access
  - `staging-app-ip`: Reserved for web application access
  - `staging-jenkins-ip`: Reserved for CI/CD access (firewall-protected)

### 🔒 Security Architecture

#### Firewall Rules
Priority | Name | Direction | Protocol | Ports | Source | Target Tags
---------|------|-----------|----------|--------|--------|------------
1000     | staging-allow-http-https | Ingress | TCP | 80,443 | 0.0.0.0/0 | web-server
1000     | staging-allow-vpn-server | Ingress | UDP | 1194 | 0.0.0.0/0 | vpn-server  
1000     | staging-allow-ssh-vpn-only | Ingress | TCP | 22 | 10.8.0.0/24 | ssh-server
1000     | staging-allow-jenkins-web | Ingress | TCP | 8080 | 10.8.0.0/24 | jenkins-server
1000     | staging-allow-dev-tools | Ingress | TCP | 8025,5050 | 10.8.0.0/24 | dev-tools
1000     | staging-allow-internal-subnet | Ingress | ALL | ALL | 10.0.0.0/24 | ALL
1000     | staging-allow-vpn-clients | Ingress | ALL | ALL | 10.8.0.0/24 | ALL
1000     | staging-allow-postgresql | Ingress | TCP | 5432 | 10.0.0.0/24,10.8.0.0/24 | database-server
1000     | staging-allow-redis | Ingress | TCP | 6379 | 10.0.0.0/24,10.8.0.0/24 | cache-server
1000     | staging-deny-direct-app-ports | Ingress | TCP | 8000-8999 | 0.0.0.0/0 | app-server


#### Access Control Matrix
| Resource | Public Access | VPN Access | Internal Access |
|----------|---------------|------------|-----------------|
| Web Application (80,443) | ✅ | ✅ | ✅ |
| SSH (22) | ❌ | ✅ | ✅ |
| PostgreSQL (5432) | ❌ | ✅ | ✅ |
| Redis (6379) | ❌ | ✅ | ✅ |
| Jenkins (8080) | ❌ | ✅ | ✅ |
| Development Tools | ❌ | ✅ | ✅ |

#### Service Accounts
- `app-staging-sa@project.iam`: Application server service account
- `vpn-staging-sa@project.iam`: VPN server service account  
- `jenkins-staging-sa@project.iam`: Jenkins service account

### 💾 Storage & Data

#### Persistent Storage
- **Application Data**: Local disk storage on application server
- **Database**: PostgreSQL data directory on local persistent disk
- **Redis**: In-memory cache with optional persistence
- **Logs**: Local storage with Cloud Logging integration

#### Data Management
- **Development Data**: Ephemeral data, no backup required
- **Configuration Management**: Infrastructure configuration in Git
- **Recovery Strategy**: Complete environment rebuild from Infrastructure as Code

### 📊 Monitoring & Observability

#### Metrics Collection
- **System Metrics**: CPU, Memory, Disk, Network via Cloud Monitoring
- **Application Metrics**: Odoo performance metrics
- **Database Metrics**: PostgreSQL connection and query metrics
- **VPN Metrics**: Connection status and user activity

#### Logging Strategy
- **System Logs**: Cloud Logging integration
- **Application Logs**: Odoo and NGINX logs
- **Security Logs**: VPN access and authentication logs
- **Audit Logs**: Administrative actions and changes

#### Alerting
- **Resource Utilization**: CPU > 80%, Memory > 85%, Disk > 85%
- **Service Health**: Application downtime, database connection failures
- **Security Events**: Failed VPN connections, unusual access patterns

## Deployment Architecture

### 🚀 Application Deployment
1. **Infrastructure Provisioning**: Terraform creates all resources
2. **Base Configuration**: Startup scripts configure base system
3. **Service Installation**: Automated installation of all services
4. **Configuration Management**: Environment-specific configs applied
5. **Health Validation**: Automated health checks confirm deployment

### 🔄 Development Workflow
1. **Code Changes**: Developers make changes locally
2. **VPN Connection**: Connect to staging environment
3. **Testing**: Deploy and test changes in staging
4. **CI/CD Pipeline**: Jenkins automates testing and deployment
5. **Validation**: Comprehensive testing before production

### 📋 Maintenance Procedures
- **Regular Updates**: Monthly OS and security updates
- **Environment Refresh**: Weekly environment recreation for testing
- **Security Audits**: Monthly security configuration reviews
- **Performance Monitoring**: Continuous monitoring and optimization

## Cost Optimization

### 💰 Resource Sizing
- **Total Monthly Cost**: ~$50-70 USD (varies by usage)
- **Primary Costs**: Compute instances, static IPs, storage
- **Major Savings**: Removed Cloud Router + NAT (~$100/month savings)
- **Optimization**: Rightsize instances, scheduled shutdowns for dev

### 📊 Cost Breakdown (Estimated)
- **Application Server**: ~$30/month (e2-standard-2)
- **VPN Server**: ~$5/month (e2-micro)  
- **Jenkins Server**: ~$15/month (e2-small, optional)
- **Static IP Addresses**: ~$12/month (3 static IPs)
- **Storage & Networking**: ~$5-10/month (no NAT costs)
- **Monitoring & Logs**: ~$5-10/month

### 💡 **Cost Savings Analysis**
- **Removed**: Cloud Router (~$73/month) + Cloud NAT (~$33/month) = **$106/month savings**
- **Added**: 1 additional static IP (~$4/month)
- **Net Savings**: ~$102/month
- **New Total**: 50% cost reduction from original architecture

## Environment Specifications

### 🔧 Configuration Management
- **Environment Variables**: Stored in secure configuration management
- **Secrets Management**: Google Secret Manager integration
- **SSL/TLS**: Let's Encrypt certificates for HTTPS
- **DNS**: External DNS management (not included in this architecture)

### 🧪 Testing Capabilities
- **Load Testing**: Basic load testing capabilities
- **Integration Testing**: Full application stack testing
- **Security Testing**: VPN and firewall rule validation
- **Backup Testing**: Regular backup and restore validation

This staging architecture provides a robust, secure, and cost-effective platform for development and testing while maintaining production-like patterns and security controls.