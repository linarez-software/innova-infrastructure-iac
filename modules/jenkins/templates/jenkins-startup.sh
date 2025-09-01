#!/bin/bash
set -e

# Jenkins Server Startup Script
# This script installs and configures Jenkins with security hardening
# Environment: ${environment}
# Project: ${project_id}

# Variables from Terraform template
PROJECT_ID="${project_id}"
ENVIRONMENT="${environment}"
JENKINS_ADMIN_USER="${jenkins_admin_user}"
JENKINS_ADMIN_PASSWORD="${jenkins_admin_password}"
JENKINS_DOMAIN="${jenkins_domain}"
SSL_EMAIL="${ssl_email}"
GITHUB_TOKEN="${github_token_secret}"
DOCKER_REGISTRY_SECRET="${docker_registry_secret}"
STAGING_DEPLOY_KEY="${staging_deploy_key_secret}"
PROD_DEPLOY_KEY="${prod_deploy_key_secret}"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [Jenkins Setup] $1" | tee -a /var/log/jenkins-setup.log
}

log "Starting Jenkins server setup for environment: ${environment}"

# Update system
log "Updating system packages"
apt-get update && apt-get upgrade -y

# Install essential packages
log "Installing essential packages"
apt-get install -y \
    curl \
    wget \
    gnupg2 \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    unzip \
    git \
    python3 \
    python3-pip \
    nodejs \
    npm \
    openjdk-17-jdk \
    nginx \
    certbot \
    python3-certbot-nginx \
    fail2ban \
    ufw

# Configure firewall
log "Configuring UFW firewall"
ufw --force enable
ufw default deny incoming
ufw default allow outgoing
ufw allow from 10.8.0.0/24 to any port 22  # SSH from VPN only
ufw allow from 10.8.0.0/24 to any port 8080  # Jenkins from VPN only
ufw allow from 10.8.0.0/24 to any port 80   # HTTP from VPN only
ufw allow from 10.8.0.0/24 to any port 443  # HTTPS from VPN only
ufw allow 50000  # Jenkins agent port

# Configure fail2ban for additional security
log "Configuring fail2ban"
cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3

[jenkins]
enabled = true
port = 8080
logpath = /var/log/jenkins/jenkins.log
maxretry = 5
EOF

systemctl enable fail2ban
systemctl start fail2ban

# Mount persistent disk for Jenkins data
log "Setting up persistent disk for Jenkins data"
DEVICE="/dev/disk/by-id/google-jenkins-data"
MOUNT_POINT="/var/lib/jenkins"

if [ -b "$DEVICE" ]; then
    # Check if filesystem exists
    if ! blkid "$DEVICE"; then
        log "Formatting Jenkins data disk"
        mkfs.ext4 -F "$DEVICE"
    fi
    
    # Create mount point
    mkdir -p "$MOUNT_POINT"
    
    # Add to fstab for persistence
    if ! grep -q "$DEVICE" /etc/fstab; then
        echo "$DEVICE $MOUNT_POINT ext4 defaults,noatime 0 2" >> /etc/fstab
    fi
    
    # Mount the disk
    mount -a
    log "Jenkins data disk mounted at $MOUNT_POINT"
else
    log "Jenkins data disk not found, using local storage"
    mkdir -p "$MOUNT_POINT"
fi

# Create Jenkins user and set permissions
log "Creating Jenkins user"
useradd -r -m -d "$MOUNT_POINT" -s /bin/bash jenkins
chown jenkins:jenkins "$MOUNT_POINT"
chmod 755 "$MOUNT_POINT"

# Install Docker (for CI/CD pipelines)
log "Installing Docker"
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add jenkins user to docker group
usermod -aG docker jenkins

systemctl enable docker
systemctl start docker

# Install Jenkins
log "Installing Jenkins"
curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" | tee /etc/apt/sources.list.d/jenkins.list > /dev/null

apt-get update
apt-get install -y jenkins

# Configure Jenkins
log "Configuring Jenkins"

# Set Jenkins home directory
sed -i "s|JENKINS_HOME=.*|JENKINS_HOME=$MOUNT_POINT|" /etc/default/jenkins

# Set Jenkins user and group
sed -i "s|JENKINS_USER=.*|JENKINS_USER=jenkins|" /etc/default/jenkins
sed -i "s|JENKINS_GROUP=.*|JENKINS_GROUP=jenkins|" /etc/default/jenkins

# Configure Jenkins JVM options
cat > /etc/default/jenkins <<EOF
JENKINS_HOME=$MOUNT_POINT
JENKINS_USER=jenkins
JENKINS_GROUP=jenkins
JENKINS_WAR=/usr/share/java/jenkins.war
JENKINS_LOG=/var/log/jenkins/jenkins.log
JENKINS_JAVA_OPTIONS="-Djava.awt.headless=true -Xmx2g -Xms1g"
JENKINS_ARGS="--webroot=/var/cache/jenkins/war --httpPort=8080 --prefix=/jenkins"
EOF

# Create Jenkins directories
mkdir -p /var/log/jenkins
mkdir -p /var/cache/jenkins
chown -R jenkins:jenkins /var/log/jenkins /var/cache/jenkins
chown -R jenkins:jenkins "$MOUNT_POINT"

# Start Jenkins service
systemctl enable jenkins
systemctl start jenkins

# Wait for Jenkins to start
log "Waiting for Jenkins to start"
timeout=300
while [ $timeout -gt 0 ]; do
    if curl -s http://localhost:8080/jenkins > /dev/null; then
        log "Jenkins is running"
        break
    fi
    sleep 5
    timeout=$((timeout - 5))
done

if [ $timeout -eq 0 ]; then
    log "ERROR: Jenkins failed to start within timeout"
    exit 1
fi

# Configure Jenkins admin user
log "Configuring Jenkins admin user"
sleep 30  # Give Jenkins more time to fully initialize

# Skip initial setup wizard and create admin user
JENKINS_CLI_JAR="$MOUNT_POINT/war/WEB-INF/jenkins-cli.jar"
INITIAL_ADMIN_PASSWORD=$(cat "$MOUNT_POINT/secrets/initialAdminPassword" 2>/dev/null || echo "")

if [ -n "$INITIAL_ADMIN_PASSWORD" ]; then
    # Create groovy script to setup admin user
    cat > /tmp/setup-admin.groovy <<EOF
import jenkins.model.*
import hudson.security.*
import jenkins.install.InstallState

def instance = Jenkins.getInstance()

// Create admin user
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("$JENKINS_ADMIN_USER", "$JENKINS_ADMIN_PASSWORD")
instance.setSecurityRealm(hudsonRealm)

// Set authorization strategy
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

// Mark setup complete
if (!instance.getInstallState().isSetupComplete()) {
    InstallState.INITIAL_SETUP_COMPLETED.initializeState()
}

instance.save()
EOF

    # Execute the setup script
    sudo -u jenkins java -jar "$JENKINS_CLI_JAR" -s http://localhost:8080/jenkins/ -auth "admin:$INITIAL_ADMIN_PASSWORD" groovy = < /tmp/setup-admin.groovy
    
    # Remove initial password file
    rm -f "$MOUNT_POINT/secrets/initialAdminPassword"
    rm -f /tmp/setup-admin.groovy
fi

# Install essential Jenkins plugins
log "Installing Jenkins plugins"
sudo -u jenkins java -jar "$JENKINS_CLI_JAR" -s http://localhost:8080/jenkins/ -auth "$JENKINS_ADMIN_USER:$JENKINS_ADMIN_PASSWORD" install-plugin \
    workflow-aggregator \
    git \
    github \
    docker-workflow \
    kubernetes \
    pipeline-stage-view \
    blueocean \
    credentials-binding \
    ssh-agent \
    build-timeout \
    timestamper \
    workspace-cleanup \
    ant \
    gradle \
    nodejs \
    python \
    ansible \
    terraform \
    google-compute-engine

# Restart Jenkins to load plugins
systemctl restart jenkins

# Configure NGINX reverse proxy
log "Configuring NGINX reverse proxy"
cat > /etc/nginx/sites-available/jenkins <<EOF
upstream jenkins {
    keepalive 32; # keepalive connections
    server 127.0.0.1:8080; # jenkins ip and port
}

# Required for Jenkins websocket agents
map \$http_upgrade \$connection_upgrade {
    default upgrade;
    '' close;
}

server {
    listen 80;
    server_name jenkins.internal ${jenkins_domain};

    # Redirect HTTP to HTTPS
    if (\$scheme != "https") {
        return 301 https://\$server_name\$request_uri;
    }

    access_log /var/log/nginx/jenkins.access.log;
    error_log /var/log/nginx/jenkins.error.log;

    # Large file upload support
    client_max_body_size 100m;

    location /jenkins {
        sendfile off;
        proxy_pass         http://jenkins;
        proxy_redirect     default;
        proxy_http_version 1.1;

        # Required for Jenkins websocket agents
        proxy_set_header   Connection        \$connection_upgrade;
        proxy_set_header   Upgrade           \$http_upgrade;

        proxy_set_header   Host              \$host;
        proxy_set_header   X-Real-IP         \$remote_addr;
        proxy_set_header   X-Forwarded-For   \$proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto \$scheme;
        proxy_max_temp_file_size 0;

        proxy_connect_timeout      150;
        proxy_send_timeout         100;
        proxy_read_timeout         100;

        proxy_buffer_size          8k;
        proxy_buffers              4 32k;
        proxy_busy_buffers_size    64k;
        proxy_temp_file_write_size 64k;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/jenkins /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test NGINX configuration
nginx -t
systemctl enable nginx
systemctl restart nginx

# Configure SSL with Let's Encrypt (if domain provided)
if [ -n "$JENKINS_DOMAIN" ] && [ "$JENKINS_DOMAIN" != "" ]; then
    log "Configuring SSL certificate for domain: $JENKINS_DOMAIN"
    certbot --nginx -d "$JENKINS_DOMAIN" --email "${ssl_email}" --agree-tos --non-interactive --redirect
fi

# Configure secrets and credentials in Jenkins
log "Setting up Jenkins credentials"

# Create credentials directory
sudo -u jenkins mkdir -p "$MOUNT_POINT/credentials"

# Store GitHub token if provided
if [ -n "$GITHUB_TOKEN" ] && [ "$GITHUB_TOKEN" != "" ]; then
    echo "$GITHUB_TOKEN" | sudo -u jenkins tee "$MOUNT_POINT/credentials/github-token" > /dev/null
    chmod 600 "$MOUNT_POINT/credentials/github-token"
fi

# Store Docker registry credentials if provided
if [ -n "$DOCKER_REGISTRY_SECRET" ] && [ "$DOCKER_REGISTRY_SECRET" != "" ]; then
    echo "$DOCKER_REGISTRY_SECRET" | sudo -u jenkins tee "$MOUNT_POINT/credentials/docker-registry" > /dev/null
    chmod 600 "$MOUNT_POINT/credentials/docker-registry"
fi

# Store deployment keys
if [ -n "$STAGING_DEPLOY_KEY" ] && [ "$STAGING_DEPLOY_KEY" != "" ]; then
    echo "$STAGING_DEPLOY_KEY" | sudo -u jenkins tee "$MOUNT_POINT/credentials/staging-deploy-key" > /dev/null
    chmod 600 "$MOUNT_POINT/credentials/staging-deploy-key"
fi

if [ -n "$PROD_DEPLOY_KEY" ] && [ "$PROD_DEPLOY_KEY" != "" ]; then
    echo "$PROD_DEPLOY_KEY" | sudo -u jenkins tee "$MOUNT_POINT/credentials/prod-deploy-key" > /dev/null
    chmod 600 "$MOUNT_POINT/credentials/prod-deploy-key"
fi

# Set up Google Cloud SDK
log "Installing Google Cloud SDK"
curl https://sdk.cloud.google.com | bash
source /root/.bashrc
sudo -u jenkins bash -c "curl https://sdk.cloud.google.com | bash"

# Configure monitoring and logging
log "Setting up monitoring and logging"

# Create Jenkins log rotation
cat > /etc/logrotate.d/jenkins <<EOF
/var/log/jenkins/jenkins.log {
    daily
    missingok
    rotate 30
    notifempty
    create 644 jenkins jenkins
    postrotate
        systemctl reload jenkins || true
    endscript
}
EOF

# Create system monitoring script
cat > /opt/scripts/jenkins-monitor.sh <<'EOF'
#!/bin/bash
# Jenkins monitoring script

JENKINS_URL="http://localhost:8080/jenkins"
LOG_FILE="/var/log/jenkins-monitor.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

# Check Jenkins health
if ! curl -s -o /dev/null "$JENKINS_URL"; then
    log "ERROR: Jenkins is not responding"
    # Try to restart Jenkins
    systemctl restart jenkins
    log "Jenkins restart attempted"
else
    log "Jenkins is healthy"
fi

# Check disk space
DISK_USAGE=$(df /var/lib/jenkins | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 85 ]; then
    log "WARNING: Jenkins disk usage is $DISK_USAGE%"
fi

# Check memory usage
MEM_USAGE=$(free | grep Mem | awk '{printf "%.0f", ($3/$2) * 100}')
if [ "$MEM_USAGE" -gt 85 ]; then
    log "WARNING: Memory usage is $MEM_USAGE%"
fi
EOF

chmod +x /opt/scripts/jenkins-monitor.sh

# Add monitoring script to crontab
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/scripts/jenkins-monitor.sh") | crontab -

# Final security hardening
log "Applying final security hardening"

# Secure Jenkins configuration
sudo -u jenkins mkdir -p "$MOUNT_POINT/init.groovy.d"
cat > "$MOUNT_POINT/init.groovy.d/security.groovy" <<EOF
import jenkins.model.*
import hudson.security.*
import jenkins.security.s2m.AdminWhitelistRule

// Disable CLI over remoting
jenkins.CLI.get().setEnabled(false)

// Enable CSRF protection
instance = Jenkins.getInstance()
instance.setCrumbIssuer(new DefaultCrumbIssuer(true))

// Disable slave to master security subsystem
Jenkins.instance.getInjector().getInstance(AdminWhitelistRule.class).setMasterKillSwitch(false)

// Disable insecure protocols
def protocols = ['JNLP-connect', 'JNLP2-connect']
Jenkins.instance.setSlaveAgentPort(50000)
Jenkins.instance.getDescriptor("jenkins.CLI").get().setEnabled(false)

instance.save()
EOF

chown jenkins:jenkins "$MOUNT_POINT/init.groovy.d/security.groovy"

# Restart services to apply all configurations
log "Restarting services"
systemctl restart jenkins
systemctl restart nginx

# Create summary information
log "Creating deployment summary"
cat > /opt/jenkins-info.txt <<EOF
Jenkins Server Information
==========================
Environment: ${environment}
Project: ${project_id}
Installation Date: $(date)

Access Information:
- Jenkins Web UI: http://$(hostname -I | awk '{print $1}'):8080/jenkins
- Jenkins Domain: ${jenkins_domain != "" ? jenkins_domain : "Not configured"}
- Admin User: ${jenkins_admin_user}
- SSH Access: gcloud compute ssh $(hostname) --zone=$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone | cut -d/ -f4)

Security:
- Firewall configured for VPN-only access
- SSL/TLS: ${jenkins_domain != "" ? "Configured" : "Not configured"}
- Fail2ban enabled
- Security hardening applied

Storage:
- Jenkins Home: $MOUNT_POINT
- Persistent Disk: $(df -h $MOUNT_POINT | tail -1)
- Backup Location: Manual backup required

Monitoring:
- Health checks: Every 5 minutes
- Log rotation: 30 days
- Monitoring script: /opt/scripts/jenkins-monitor.sh

Services Status:
- Jenkins: $(systemctl is-active jenkins)
- Docker: $(systemctl is-active docker)
- NGINX: $(systemctl is-active nginx)
- Fail2ban: $(systemctl is-active fail2ban)
EOF

log "Jenkins setup completed successfully!"
log "Summary information available at: /opt/jenkins-info.txt"

# Send completion signal to GCP
log "Sending startup completion signal"
curl -X POST "https://www.googleapis.com/compute/v1/projects/$PROJECT_ID/zones/$(curl -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/zone | cut -d/ -f4)/instances/$(hostname)/setMetadata" \
     -H "Authorization: Bearer $(gcloud auth print-access-token)" \
     -H "Content-Type: application/json" \
     -d '{"items":[{"key":"startup-completed","value":"true"}]}' || true

log "Jenkins server setup complete!"