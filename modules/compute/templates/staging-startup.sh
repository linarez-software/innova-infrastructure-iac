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

# Install and configure NGINX
echo "Installing and configuring NGINX..."
apt-get install -y nginx

# Create basic NGINX configuration for staging
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
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
    
    # Default location for application
    location / {
        return 503 "Application not configured";
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

# Configure firewall
ufw --force enable
ufw allow ssh
ufw allow http
ufw allow https

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
echo ""
echo "Storage locations:"
echo "- Application data: /opt/app-data/"
echo "- Static files: /var/www/static/"
echo "- Logs: /opt/app-data/logs/"
echo ""
echo "Management scripts:"
echo "- Monitor: /opt/scripts/staging-monitor.sh"
echo "- Backup: /opt/scripts/staging-backup.sh"
echo ""
echo "Next steps:"
echo "1. Configure your application to connect to PostgreSQL"
echo "2. Update NGINX configuration for your specific application"
echo "3. Deploy your application code"
echo "4. Test the staging environment"