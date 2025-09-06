# Networking Specifications

## Naming Conventions

### 🏗️ **Naming Pattern**
```
Format: {environment}-{resource-type}-{description}
Environment: staging | production
Resource Type: network, subnet, firewall, address, etc.
```

## VPC Network Configuration

### 📊 **VPC Network**
```yaml
Name: staging-vpc
Full Resource Name: projects/deep-wares-246918/global/networks/staging-vpc
CIDR: 10.0.0.0/24
Region: us-central1
Routing Mode: REGIONAL
Auto Create Subnetworks: false
```

### 🌐 **Subnet Configuration**
```yaml
Name: staging-subnet
Full Resource Name: projects/deep-wares-246918/regions/us-central1/subnetworks/staging-subnet
IP CIDR Range: 10.0.0.0/24
Region: us-central1
Network: staging-vpc
Private Google Access: true
```

### 📍 **Static IP Addresses**
```yaml
VPN Server:
  Name: staging-vpn-ip
  Type: EXTERNAL
  Region: us-central1
  Purpose: VPN server external access

Application Server:
  Name: staging-app-ip
  Type: EXTERNAL  
  Region: us-central1
  Purpose: Web application external access
  
Jenkins Server:
  Name: staging-jenkins-ip
  Type: EXTERNAL
  Region: us-central1
  Purpose: CI/CD tools external access (firewall-protected)
```

## Firewall Rules

### 🔐 **Ingress Rules (Public Access)**

#### 1. Web Application Access
```yaml
Name: staging-allow-http-https
Network: staging-vpc
Direction: INGRESS
Priority: 1000
Action: ALLOW
Protocols: 
  - TCP: [80, 443]
Source Ranges: ["0.0.0.0/0"]
Target Tags: ["web-server"]
Description: "Allow HTTP and HTTPS access to web application"
```

#### 2. VPN Server Access
```yaml
Name: staging-allow-vpn-server
Network: staging-vpc
Direction: INGRESS
Priority: 1000
Action: ALLOW
Protocols:
  - UDP: [1194]
Source Ranges: ["0.0.0.0/0"] 
Target Tags: ["vpn-server"]
Description: "Allow OpenVPN access to VPN server"
```

### 🔒 **Ingress Rules (VPN-Only Access)**

#### 3. SSH Access (VPN Only)
```yaml
Name: staging-allow-ssh-vpn-only
Network: staging-vpc
Direction: INGRESS
Priority: 1000
Action: ALLOW
Protocols:
  - TCP: [22]
Source Ranges: ["10.8.0.0/24"]
Target Tags: ["ssh-server"]
Description: "Allow SSH access only from VPN clients"
```

#### 4. Jenkins Web Interface (VPN Only)
```yaml
Name: staging-allow-jenkins-web
Network: staging-vpc  
Direction: INGRESS
Priority: 1000
Action: ALLOW
Protocols:
  - TCP: [8080]
Source Ranges: ["10.8.0.0/24"]
Target Tags: ["jenkins-server"]
Description: "Allow Jenkins web interface access from VPN clients only"
```

#### 5. Development Tools (VPN Only)
```yaml
Name: staging-allow-dev-tools
Network: staging-vpc
Direction: INGRESS
Priority: 1000
Action: ALLOW
Protocols:
  - TCP: [8025, 5050]
Source Ranges: ["10.8.0.0/24"]
Target Tags: ["dev-tools"]
Description: "Allow access to Mailhog and pgAdmin from VPN clients only"
```

### 🏠 **Ingress Rules (Internal Communication)**

#### 6. Internal Subnet Communication
```yaml
Name: staging-allow-internal-subnet
Network: staging-vpc
Direction: INGRESS
Priority: 1000
Action: ALLOW
Protocols:
  - TCP: [0-65535]
  - UDP: [0-65535]  
  - ICMP
Source Ranges: ["10.0.0.0/24"]
Target Tags: [] # Apply to all instances
Description: "Allow all communication within internal subnet"
```

#### 7. VPN Client Communication
```yaml
Name: staging-allow-vpn-clients
Network: staging-vpc
Direction: INGRESS
Priority: 1000
Action: ALLOW
Protocols:
  - TCP: [0-65535]
  - UDP: [0-65535]
  - ICMP
Source Ranges: ["10.8.0.0/24"]
Target Tags: [] # Apply to all instances  
Description: "Allow all communication from VPN clients to internal resources"
```

#### 8. Database Access (Internal + VPN)
```yaml
Name: staging-allow-postgresql
Network: staging-vpc
Direction: INGRESS
Priority: 1000
Action: ALLOW
Protocols:
  - TCP: [5432]
Source Ranges: ["10.0.0.0/24", "10.8.0.0/24"]
Target Tags: ["database-server"]
Description: "Allow PostgreSQL access from internal subnet and VPN clients"
```

#### 9. Redis Access (Internal + VPN)
```yaml
Name: staging-allow-redis
Network: staging-vpc
Direction: INGRESS
Priority: 1000
Action: ALLOW
Protocols:
  - TCP: [6379]
Source Ranges: ["10.0.0.0/24", "10.8.0.0/24"]
Target Tags: ["cache-server"]
Description: "Allow Redis access from internal subnet and VPN clients"
```

### ❌ **Deny Rules (Security)**

#### 10. Deny Direct Application Ports
```yaml
Name: staging-deny-direct-app-ports
Network: staging-vpc
Direction: INGRESS
Priority: 1000
Action: DENY
Protocols:
  - TCP: [8000-8999, 3000-3999, 9000-9999]
Source Ranges: ["0.0.0.0/0"]
Target Tags: ["app-server"]
Description: "Deny direct access to application development ports"
```

## Network Tags

### 🏷️ **Server Tags**
```yaml
Application Server (app-staging):
  - web-server
  - ssh-server
  - database-server
  - cache-server
  - app-server

VPN Server (vpn-staging):
  - vpn-server
  - ssh-server

Jenkins Server (jenkins-staging):
  - jenkins-server
  - ssh-server
  - dev-tools
```

## VPN Network Configuration

### 🔐 **OpenVPN Network**
```yaml
VPN Subnet: 10.8.0.0/24
VPN Server IP: 10.8.0.1 (OpenVPN server internal VPN interface)
Client IP Range: 10.8.0.10 - 10.8.0.254
Max Concurrent Clients: 5
Protocol: UDP
Port: 1194
Encryption: AES-256-CBC
Authentication: SHA256
```

## Google Cloud Services Access

### ☁️ **Service Connectivity**
All servers connect to Google Cloud services via:
- **Cloud Storage**: For configurations and data
- **Cloud Monitoring**: For metrics and monitoring
- **Cloud Logging**: For centralized logging
- **IAM**: For service account authentication

## DNS Configuration

### 🌐 **External DNS (Optional)**
```yaml
VPN Server:
  DNS Name: vpn-staging.yourdomain.com
  IP: staging-vpn-ip (static)
  
Application Server:  
  DNS Name: app-staging.yourdomain.com
  IP: staging-app-ip (static)
  
Jenkins Server:
  DNS Name: jenkins-staging.yourdomain.com (optional)
  IP: staging-jenkins-ip (static)
```

### 🔍 **Internal DNS**
Google Cloud automatically provides internal DNS resolution:
- `app-staging.c.deep-wares-246918.internal`
- `vpn-staging.c.deep-wares-246918.internal`  
- `jenkins-staging.c.deep-wares-246918.internal`

## Security Groups & Access Matrix

### 📊 **Access Control Matrix**
| Service | Port | Public | VPN Only | Internal | Firewall Rule |
|---------|------|--------|----------|----------|---------------|
| HTTP | 80 | ✅ | ✅ | ✅ | staging-allow-http-https |
| HTTPS | 443 | ✅ | ✅ | ✅ | staging-allow-http-https |
| SSH | 22 | ❌ | ✅ | ✅ | staging-allow-ssh-vpn-only |
| OpenVPN | 1194 | ✅ | N/A | N/A | staging-allow-vpn-server |
| Jenkins | 8080 | ❌ | ✅ | ✅ | staging-allow-jenkins-web |
| Mailhog | 8025 | ❌ | ✅ | ✅ | staging-allow-dev-tools |
| pgAdmin | 5050 | ❌ | ✅ | ✅ | staging-allow-dev-tools |
| PostgreSQL | 5432 | ❌ | ✅ | ✅ | staging-allow-postgresql |
| Redis | 6379 | ❌ | ✅ | ✅ | staging-allow-redis |

## Implementation Notes

### 🔧 **Terraform Resource Names**
```hcl
# VPC Network
resource "google_compute_network" "staging_vpc" {
  name = "staging-vpc"
}

# Subnet  
resource "google_compute_subnetwork" "staging_subnet" {
  name = "staging-subnet"
}

# Static IPs
resource "google_compute_address" "staging_vpn_ip" {
  name = "staging-vpn-ip"
}

resource "google_compute_address" "staging_app_ip" {
  name = "staging-app-ip"
}

resource "google_compute_address" "staging_jenkins_ip" {
  name = "staging-jenkins-ip"
}

# Firewall Rules
resource "google_compute_firewall" "staging_allow_http_https" {
  name = "staging-allow-http-https"
}

# ... (additional firewall rules following same pattern)
```

### 📋 **Validation Checklist**
- [ ] All resource names follow naming convention
- [ ] Firewall rules have appropriate priorities
- [ ] Network tags are consistently applied
- [ ] VPN subnet doesn't overlap with VPC subnet
- [ ] Static IPs are properly reserved
- [ ] All required ports are covered by firewall rules
- [ ] Security rules follow least-privilege principle

This specification provides the exact naming and configuration for all networking components in the staging environment.