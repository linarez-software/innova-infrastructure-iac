#!/bin/bash
# Production Application Server Startup Script
# Configures application server with NVMe optimization and monitoring

set -e
exec > >(tee /var/log/startup-script.log)
exec 2>&1

echo "Starting production application server configuration..."

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
    nvme-cli \
    fio \
    bc \
    parted

# Configure timezone
timedatectl set-timezone UTC

# Optimize NVMe storage for file storage performance
if [ -b /dev/nvme0n1 ]; then
    echo "Configuring NVMe storage optimization..."
    
    # Check if already partitioned
    if ! parted -s /dev/nvme0n1 print | grep -q "Number.*Start.*End"; then
        echo "Creating single partition on /dev/nvme0n1..."
        parted -s /dev/nvme0n1 mklabel gpt
        parted -s /dev/nvme0n1 mkpart primary ext4 0% 100%
        partprobe /dev/nvme0n1
        sleep 2
    fi
    
    # Format if not already formatted
    if ! blkid /dev/nvme0n1p1 >/dev/null 2>&1; then
        echo "Formatting NVMe with optimized ext4..."
        mkfs.ext4 \
            -L app-storage \
            -E lazy_itable_init=0,lazy_journal_init=0 \
            -O ^has_journal,extent,dir_index,filetype,sparse_super,large_file,flex_bg,uninit_bg,64bit \
            -i 8192 \
            -m 1 \
            -b 4096 \
            /dev/nvme0n1p1
        
        # Re-enable journal with performance mode
        tune2fs -j /dev/nvme0n1p1
        tune2fs -o journal_data_writeback /dev/nvme0n1p1
        tune2fs -E stride=32,stripe-width=32 /dev/nvme0n1p1
        tune2fs -o user_xattr /dev/nvme0n1p1
    fi
    
    # Create mount point and mount
    mkdir -p /opt/app-data
    if ! mountpoint -q /opt/app-data; then
        mount -t ext4 -o noatime,user_xattr,data=writeback,nofail /dev/nvme0n1p1 /opt/app-data
        
        # Add to fstab if not already there
        if ! grep -q "/dev/nvme0n1p1" /etc/fstab; then
            echo "/dev/nvme0n1p1 /opt/app-data ext4 noatime,user_xattr,data=writeback,nofail 0 2" >> /etc/fstab
        fi
    fi
    
    # Create application directories
    mkdir -p /opt/app-data/{storage,logs,sessions,cache}
    chmod 755 /opt/app-data
    chown -R www-data:www-data /opt/app-data
    
    echo "NVMe optimization completed"
else
    echo "No NVMe device found, using standard storage"
    mkdir -p /opt/app-data/{storage,logs,sessions,cache}
    chmod 755 /opt/app-data
    chown -R www-data:www-data /opt/app-data
fi

# Install and configure NGINX
echo "Installing and configuring NGINX..."
apt-get install -y nginx

# Create basic NGINX configuration
cat > /etc/nginx/sites-available/app <<'EOF'
server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    
    # Static files from NVMe storage
    location /static/ {
        alias /opt/app-data/storage/;
        expires 1y;
        add_header Cache-Control "public, immutable";
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

# Configure NGINX for performance
cat > /etc/nginx/nginx.conf <<'EOF'
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 1024;
    use epoll;
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1000;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/json
        application/javascript
        application/xml+rss
        application/atom+xml
        image/svg+xml;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Start and enable NGINX
systemctl enable nginx
systemctl start nginx

# Install PostgreSQL client for database connections
apt-get install -y postgresql-client-15

# Configure firewall
ufw --force enable
ufw allow ssh
ufw allow http
ufw allow https

# Create performance monitoring scripts
mkdir -p /opt/scripts

cat > /opt/scripts/system-monitor.sh <<'EOF'
#!/bin/bash
# System Performance Monitor

echo "=== System Performance Report ==="
echo "Date: $(date)"
echo ""

echo "=== CPU Usage ==="
top -bn1 | grep "Cpu(s)" | awk '{print "CPU Load: " $2 " user, " $4 " system, " $8 " idle"}'
echo ""

echo "=== Memory Usage ==="
free -h
echo ""

echo "=== Disk Usage ==="
df -h
echo ""

if [ -b /dev/nvme0n1 ]; then
    echo "=== NVMe Performance ==="
    iostat -x 1 1 | grep nvme0n1
    echo ""
    
    echo "=== NVMe SMART Data ==="
    nvme smart-log /dev/nvme0n1 | grep -E "(temperature|available_spare|percentage_used)"
    echo ""
fi

echo "=== Network Connections ==="
ss -tuln
echo ""

echo "=== System Load ==="
uptime
echo ""
EOF

chmod +x /opt/scripts/system-monitor.sh

# Create backup script for application data
cat > /opt/scripts/backup-app-data.sh <<'EOF'
#!/bin/bash
# Application Data Backup Script

BACKUP_DIR="/opt/backups"
APP_DATA_DIR="/opt/app-data"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

echo "Starting application data backup..."
echo "Date: $(date)"

# Backup application data
tar -czf "$BACKUP_DIR/app-data-$DATE.tar.gz" -C /opt app-data/ 2>/dev/null || echo "Warning: Some files may not be accessible"

# Keep only last 7 days of backups
find $BACKUP_DIR -name "app-data-*.tar.gz" -mtime +7 -delete

echo "Backup completed: app-data-$DATE.tar.gz"
ls -lh $BACKUP_DIR/app-data-*.tar.gz 2>/dev/null || echo "No backups found"
EOF

chmod +x /opt/scripts/backup-app-data.sh

# Setup log rotation
cat > /etc/logrotate.d/app-data <<'EOF'
/opt/app-data/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 www-data www-data
    postrotate
        systemctl reload nginx > /dev/null 2>&1 || true
    endscript
}
EOF

# Configure system limits for performance
cat >> /etc/security/limits.conf <<'EOF'
# Application server limits
www-data soft nofile 65536
www-data hard nofile 65536
www-data soft nproc 4096
www-data hard nproc 4096
EOF

# Set up cron jobs
cat > /etc/cron.d/app-maintenance <<'EOF'
# Application maintenance cron jobs
0 2 * * * root /opt/scripts/backup-app-data.sh >> /var/log/backup.log 2>&1
*/15 * * * * root /opt/scripts/system-monitor.sh >> /var/log/system-monitor.log 2>&1
0 3 * * 0 root find /var/log -name "*.log" -mtime +30 -delete
EOF

# Configure swap if not enough memory
if [ $(free -m | awk '/^Mem:/{print $2}') -lt 8192 ]; then
    echo "Configuring swap file..."
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    echo 'vm.swappiness=10' >> /etc/sysctl.conf
fi

# Final system optimization
sysctl -w net.core.somaxconn=1024
sysctl -w net.ipv4.tcp_max_syn_backlog=2048
echo 'net.core.somaxconn = 1024' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_max_syn_backlog = 2048' >> /etc/sysctl.conf

# Create application user if it doesn't exist
if ! id -u appuser >/dev/null 2>&1; then
    useradd -r -s /bin/false -d /opt/app-data appuser
    usermod -a -G www-data appuser
fi

echo "Production application server configuration completed successfully!"
echo "NVMe storage mounted at: /opt/app-data"
echo "NGINX configured and running"
echo "Monitoring scripts available in /opt/scripts/"
echo ""
echo "Next steps:"
echo "1. Configure your application to use /opt/app-data for file storage"
echo "2. Update NGINX configuration for your specific application"
echo "3. Set up SSL certificates if using a domain"
echo "4. Configure application-specific services"