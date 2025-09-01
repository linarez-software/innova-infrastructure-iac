#!/bin/bash
# Staging Environment Startup Script
# Configures combined application and database server for development/testing

set -e
exec > >(tee /var/log/startup-script.log)
exec 2>&1

echo "Starting staging environment configuration..."

# System update
apt-get update
apt-get upgrade -y

# Install essential packages
apt-get install -y \
    curl \
    wget \
    gnupg \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    unzip \
    htop \
    iotop \
    sysstat \
    bc

# Configure timezone
timedatectl set-timezone UTC

# Install PostgreSQL
echo "Installing PostgreSQL..."
apt-get install -y postgresql-15 postgresql-contrib-15 postgresql-client-15

# Configure PostgreSQL
echo "Configuring PostgreSQL..."
systemctl start postgresql
systemctl enable postgresql

# Set PostgreSQL configuration for staging (optimized for 8GB RAM)
sudo -u postgres psql -c "ALTER USER postgres PASSWORD '${db_password}';"

# Create application database
sudo -u postgres createdb appdb || echo "Database may already exist"

# Configure PostgreSQL for staging environment
cat > /etc/postgresql/15/main/postgresql.conf <<'EOF'
# PostgreSQL Configuration - Staging Environment
# Optimized for e2-standard-2 (2 vCPUs, 8GB RAM)

# Connection settings
listen_addresses = 'localhost'
port = 5432
max_connections = 50

# Memory settings (optimized for 8GB RAM)
shared_buffers = 2GB
effective_cache_size = 6GB
work_mem = 64MB
maintenance_work_mem = 512MB

# Checkpoint settings
checkpoint_completion_target = 0.9
wal_buffers = 16MB

# Performance settings
random_page_cost = 1.1
effective_io_concurrency = 200

# Logging
log_destination = 'stderr'
logging_collector = on
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%Y-%m-%d.log'
log_rotation_age = 1d
log_min_duration_statement = 1000

# Autovacuum
autovacuum = on
autovacuum_max_workers = 2
EOF

# Configure PostgreSQL authentication
cat > /etc/postgresql/15/main/pg_hba.conf <<'EOF'
# PostgreSQL Client Authentication Configuration
local   all             postgres                                peer
local   all             all                                     md5
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
EOF

# Restart PostgreSQL with new configuration
systemctl restart postgresql

# Install Docker for Mailhog and pgAdmin
echo "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable docker
systemctl start docker

# Add www-data user to docker group
usermod -aG docker www-data

# Install Docker Compose
echo "Installing Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create directory for development tools
mkdir -p /opt/dev-tools
cd /opt/dev-tools

# Create Docker Compose configuration for Mailhog and pgAdmin
cat > docker-compose.yml <<EOF
version: '3.8'

services:
  mailhog:
    image: mailhog/mailhog:latest
    container_name: mailhog-staging
    ports:
      - "1025:1025"  # SMTP port
      - "8025:8025"  # Web UI port
    restart: unless-stopped
    environment:
      - MH_STORAGE=maildir
      - MH_MAILDIR_PATH=/home/mailhog
    volumes:
      - mailhog-data:/home/mailhog
    networks:
      - dev-tools

  pgadmin:
    image: dpage/pgadmin4:latest
    container_name: pgadmin-staging
    ports:
      - "5050:80"    # Web UI port
    restart: unless-stopped
    environment:
      - PGADMIN_DEFAULT_EMAIL=${pgadmin_email != "" ? pgadmin_email : "admin@staging.local"}
      - PGADMIN_DEFAULT_PASSWORD=${pgadmin_password != "" ? pgadmin_password : db_password}
      - PGADMIN_CONFIG_SERVER_MODE=False
      - PGADMIN_CONFIG_MASTER_PASSWORD_REQUIRED=False
    volumes:
      - pgadmin-data:/var/lib/pgadmin
    networks:
      - dev-tools
    depends_on:
      - mailhog

volumes:
  mailhog-data:
    driver: local
  pgadmin-data:
    driver: local

networks:
  dev-tools:
    driver: bridge
EOF

echo "Starting development tools (Mailhog and pgAdmin)..."
docker-compose up -d

# Wait for services to start
sleep 10

# Configure pgAdmin with database connection
echo "Configuring pgAdmin database connection..."
cat > /tmp/pgadmin_servers.json <<EOF
{
  "Servers": {
    "1": {
      "Name": "Staging PostgreSQL",
      "Group": "Servers",
      "Host": "host.docker.internal",
      "Port": 5432,
      "MaintenanceDB": "appdb",
      "Username": "postgres",
      "UseSSHTunnel": 0,
      "TunnelPort": 22,
      "TunnelAuthentication": 0
    }
  }
}
EOF

# Copy server configuration to pgAdmin container (will be picked up on restart)
docker cp /tmp/pgadmin_servers.json pgadmin-staging:/pgadmin4/servers.json || echo "pgAdmin config will be manual"

# Install and configure NGINX
echo "Installing and configuring NGINX..."
apt-get install -y nginx

# Create basic NGINX configuration for staging with dev tools
cat > /etc/nginx/sites-available/app <<'EOF'
server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    # Static files
    location /static/ {
        alias /var/www/static/;
        expires 1h;
    }
    
    # Mailhog web interface
    location /mailhog/ {
        proxy_pass http://localhost:8025/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # pgAdmin web interface
    location /pgadmin/ {
        proxy_pass http://localhost:5050/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Script-Name /pgadmin;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Development tools status page
    location /dev-tools {
        return 200 '<!DOCTYPE html>
<html>
<head><title>Staging Development Tools</title></head>
<body>
    <h1>Staging Development Tools</h1>
    <ul>
        <li><a href="/mailhog/">Mailhog (Email Testing)</a> - Port 8025</li>
        <li><a href="/pgadmin/">pgAdmin (Database Admin)</a> - Port 5050</li>
    </ul>
    <p>Direct access:</p>
    <ul>
        <li>Mailhog: <a href="http://YOUR_IP:8025">http://YOUR_IP:8025</a></li>
        <li>pgAdmin: <a href="http://YOUR_IP:5050">http://YOUR_IP:5050</a></li>
        <li>SMTP Server: localhost:1025</li>
    </ul>
</body>
</html>';
        add_header Content-Type text/html;
    }
    
    # Default location for application
    location / {
        return 503 "Application not configured - Visit /dev-tools for development tools";
    }
}
EOF

# Enable the site
rm -f /etc/nginx/sites-enabled/default
ln -sf /etc/nginx/sites-available/app /etc/nginx/sites-enabled/app

# Start and enable NGINX
systemctl enable nginx
systemctl start nginx

# Create application directories
mkdir -p /var/www/{static,media,logs}
mkdir -p /opt/app-data/{storage,logs,sessions,cache}
chown -R www-data:www-data /var/www
chown -R www-data:www-data /opt/app-data
chmod 755 /opt/app-data

# Configure SSH users for developers (VPN access only)
echo "Configuring SSH users for developers..."

# Create a function to add SSH users
add_ssh_user() {
    local username=$1
    local ssh_key=$2
    
    if ! id -u "$username" >/dev/null 2>&1; then
        echo "Creating user $username..."
        useradd -m -s /bin/bash "$username"
        usermod -aG sudo "$username"
    fi
    
    # Set up SSH directory
    mkdir -p "/home/$username/.ssh"
    chmod 700 "/home/$username/.ssh"
    
    # Add the SSH key
    echo "$ssh_key" > "/home/$username/.ssh/authorized_keys"
    chmod 600 "/home/$username/.ssh/authorized_keys"
    chown -R "$username:$username" "/home/$username/.ssh"
    
    # Set a random password (users will use SSH keys)
    password=$(openssl rand -base64 12)
    echo "$username:$password" | chpasswd
    
    echo "User $username configured successfully"
}

# Add developer SSH users from Terraform variables
%{ for user in staging_ssh_users ~}
add_ssh_user "${user.username}" "${user.ssh_key}"
%{ endfor ~}

# Disable OS Login for staging to use traditional SSH
echo "Disabling OS Login for traditional SSH access..."
if [ -f /etc/ssh/sshd_config ]; then
    # Ensure password authentication is disabled (only SSH keys)
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    
    # Restart SSH service
    systemctl restart sshd || systemctl restart ssh
fi

# Configure firewall (SSH only from VPN)
ufw --force enable
ufw allow from 10.8.0.0/24 to any port 22  # SSH only from VPN
ufw allow http
ufw allow https
ufw allow 8025  # Mailhog web interface
ufw allow 5050  # pgAdmin web interface
ufw allow 1025  # SMTP port for Mailhog

# Create performance monitoring script for staging
mkdir -p /opt/scripts

cat > /opt/scripts/staging-monitor.sh <<'EOF'
#!/bin/bash
# Staging Environment Monitor

echo "=== Staging Environment Status ==="
echo "Date: $(date)"
echo ""

echo "=== System Resources ==="
echo "CPU Load: $(uptime | awk -F'load average:' '{ print $2 }')"
echo "Memory Usage:"
free -h | grep -E "Mem:|Swap:"
echo "Disk Usage:"
df -h / | tail -1
echo ""

echo "=== Service Status ==="
echo "NGINX: $(systemctl is-active nginx)"
echo "PostgreSQL: $(systemctl is-active postgresql)"
echo "Docker: $(systemctl is-active docker)"
echo "Mailhog Container: $(docker ps --format 'table {{.Names}}\t{{.Status}}' | grep mailhog-staging | awk '{print $2}' || echo 'Not Running')"
echo "pgAdmin Container: $(docker ps --format 'table {{.Names}}\t{{.Status}}' | grep pgadmin-staging | awk '{print $2}' || echo 'Not Running')"
echo ""

echo "=== Database Status ==="
sudo -u postgres psql -d appdb -c "SELECT version();" 2>/dev/null | head -3 || echo "Database connection failed"
echo ""

echo "=== Recent Log Entries ==="
echo "System logs (last 5 entries):"
journalctl --no-pager -n 5 -p err
echo ""
EOF

chmod +x /opt/scripts/staging-monitor.sh

# Create simple backup script for staging
cat > /opt/scripts/staging-backup.sh <<'EOF'
#!/bin/bash
# Simple Staging Backup Script

BACKUP_DIR="/opt/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

echo "Starting staging backup..."
echo "Date: $(date)"

# Backup database
echo "Backing up database..."
sudo -u postgres pg_dump appdb > "$BACKUP_DIR/appdb-$DATE.sql" 2>/dev/null || echo "Database backup failed"

# Backup application data
echo "Backing up application data..."
tar -czf "$BACKUP_DIR/app-data-$DATE.tar.gz" -C /opt app-data/ 2>/dev/null || echo "Warning: Some files may not be accessible"

# Keep only last 3 backups (staging doesn't need long retention)
find $BACKUP_DIR -name "*.sql" -mtime +3 -delete
find $BACKUP_DIR -name "app-data-*.tar.gz" -mtime +3 -delete

echo "Backup completed"
ls -lh $BACKUP_DIR/ 2>/dev/null || echo "No backups found"
EOF

chmod +x /opt/scripts/staging-backup.sh

# Setup log rotation for staging
cat > /etc/logrotate.d/staging-app <<'EOF'
/opt/app-data/logs/*.log {
    daily
    missingok
    rotate 3
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
}

/var/log/postgresql/*.log {
    daily
    missingok
    rotate 3
    compress
    delaycompress
    notifempty
}
EOF

# Set up basic cron jobs for staging
cat > /etc/cron.d/staging-maintenance <<'EOF'
# Staging maintenance - less frequent than production
0 4 * * * root /opt/scripts/staging-backup.sh >> /var/log/staging-backup.log 2>&1
0 */6 * * * root /opt/scripts/staging-monitor.sh >> /var/log/staging-monitor.log 2>&1
0 2 * * 0 root find /var/log -name "*.log" -mtime +7 -delete
EOF

# Create application user if it doesn't exist
if ! id -u appuser >/dev/null 2>&1; then
    useradd -r -s /bin/false -d /opt/app-data appuser
    usermod -a -G www-data appuser
fi

# Configure basic system optimization for staging
echo 'vm.swappiness=10' >> /etc/sysctl.conf
echo 'net.core.somaxconn = 512' >> /etc/sysctl.conf

# Apply sysctl settings
sysctl -p

echo "Staging environment configuration completed successfully!"
echo ""
echo "Services configured:"
echo "- PostgreSQL: Running on localhost:5432"
echo "- NGINX: Running on port 80"
echo "- Database: 'appdb' created and ready"
echo "- Docker: Running development tools"
echo "- Mailhog: Running on port 8025 (SMTP on 1025)"
echo "- pgAdmin: Running on port 5050"
echo ""
echo "Development Tools Access:"
echo "- Development Tools Page: http://YOUR_IP/dev-tools"
echo "- Mailhog Web UI: http://YOUR_IP:8025 or http://YOUR_IP/mailhog/"
echo "- pgAdmin Web UI: http://YOUR_IP:5050 or http://YOUR_IP/pgadmin/"
echo "- SMTP Server: localhost:1025 (for testing email)"
echo ""
echo "Database Connection (for pgAdmin):"
echo "- Host: host.docker.internal (from containers) or localhost"
echo "- Port: 5432"
echo "- Database: appdb"
echo "- Username: postgres"
echo "- Password: [db_password configured in terraform]"
echo ""
echo "Storage locations:"
echo "- Application data: /opt/app-data/"
echo "- Static files: /var/www/static/"
echo "- Logs: /opt/app-data/logs/"
echo "- Development tools: /opt/dev-tools/"
echo ""
echo "Management scripts:"
echo "- Monitor: /opt/scripts/staging-monitor.sh"
echo "- Backup: /opt/scripts/staging-backup.sh"
echo ""
echo "Next steps:"
echo "1. Configure your application to connect to PostgreSQL"
echo "2. Update NGINX configuration for your specific application"
echo "3. Deploy your application code"
echo "4. Configure email settings to use Mailhog SMTP (localhost:1025)"
echo "5. Test the staging environment and development tools"