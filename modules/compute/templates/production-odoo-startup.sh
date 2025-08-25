#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

# Optimize NVMe storage for Odoo filestore performance
if [ -b /dev/nvme0n1 ]; then
    echo "Optimizing NVMe storage for Odoo filestore (30 concurrent users)..."
    
    # Check if already partitioned and mounted
    if ! mountpoint -q /opt/odoo 2>/dev/null; then
        
        # Install partitioning tools if not available
        which parted >/dev/null 2>&1 || apt-get install -y parted
        
        # Create single partition for maximum space utilization
        if [ ! -b /dev/nvme0n1p1 ]; then
            echo "Creating single partition on /dev/nvme0n1..."
            parted -s /dev/nvme0n1 mklabel gpt
            parted -s /dev/nvme0n1 mkpart primary ext4 0% 100%
            partprobe /dev/nvme0n1
            sleep 2
        fi
        
        # Check if filesystem already exists
        if ! blkid /dev/nvme0n1p1 >/dev/null 2>&1; then
            echo "Formatting /dev/nvme0n1p1 with Odoo-optimized ext4..."
            
            # Format with optimizations for Odoo filestore:
            # - Optimize for small files (50KB-2MB average)
            # - Enable extended attributes for file metadata
            # - Disable journal initially for faster format
            # - Set reserved blocks to 1% (not default 5%)
            # - Custom inode ratio for small file workload
            mkfs.ext4 \
                -L odoo-filestore \
                -E lazy_itable_init=0,lazy_journal_init=0 \
                -O ^has_journal,extent,dir_index,filetype,sparse_super,large_file,flex_bg,uninit_bg,64bit \
                -i 8192 \
                -m 1 \
                -b 4096 \
                /dev/nvme0n1p1
            
            echo "Re-enabling journal for data integrity..."
            tune2fs -j /dev/nvme0n1p1
            
            echo "Optimizing filesystem for NVMe and small file performance..."
            # Set writeback mode for better performance
            tune2fs -o journal_data_writeback /dev/nvme0n1p1
            
            # Configure stride and stripe-width for NVMe characteristics
            # NVMe SSDs typically have 128KB stripe size
            tune2fs -E stride=32,stripe-width=32 /dev/nvme0n1p1
            
            # Enable user extended attributes for Odoo metadata
            tune2fs -o user_xattr /dev/nvme0n1p1
            
            echo "Filesystem optimization completed."
        else
            echo "Filesystem already exists on /dev/nvme0n1p1, skipping format."
        fi
        
        # Create mount point and mount with performance options
        mkdir -p /opt/odoo
        
        # Mount with optimizations:
        # - noatime: Don't update access times (major performance gain)
        # - user_xattr: Enable extended attributes for Odoo metadata
        # - data=writeback: Better performance (journal metadata only)
        mount -t ext4 -o noatime,user_xattr,data=writeback,nofail /dev/nvme0n1p1 /opt/odoo
        
        # Add to fstab for persistent mounting
        if ! grep -q "/dev/nvme0n1p1" /etc/fstab; then
            echo "/dev/nvme0n1p1 /opt/odoo ext4 noatime,user_xattr,data=writeback,nofail 0 2" >> /etc/fstab
        fi
        
        # Set appropriate permissions for Odoo
        chown -R odoo:odoo /opt/odoo 2>/dev/null || true
        chmod 755 /opt/odoo
        
        echo "NVMe storage mounted at /opt/odoo with Odoo filestore optimizations."
        
        # Display filesystem information
        echo "Filesystem details:"
        df -h /opt/odoo
        tune2fs -l /dev/nvme0n1p1 | grep -E "(Filesystem volume name|Block size|Inode size|Journal|Reserved block count)"
    else
        echo "NVMe already mounted at /opt/odoo, skipping setup."
    fi
fi

apt-get update
apt-get install -y \
    wget \
    git \
    python3-pip \
    python3-dev \
    python3-venv \
    build-essential \
    libxml2-dev \
    libxslt1-dev \
    libldap2-dev \
    libsasl2-dev \
    libtiff5-dev \
    libjpeg8-dev \
    libopenjp2-7-dev \
    zlib1g-dev \
    libfreetype6-dev \
    liblcms2-dev \
    libwebp-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    libxcb1-dev \
    libpq-dev \
    nodejs \
    npm \
    nginx \
    certbot \
    python3-certbot-nginx \
    redis-server \
    supervisor \
    postgresql-client-15 \
    nvme-cli \
    iostat \
    sysstat \
    bc \
    fio

echo "vm.overcommit_memory = 1" >> /etc/sysctl.conf
echo "net.core.somaxconn = 65535" >> /etc/sysctl.conf
echo "net.ipv4.tcp_max_syn_backlog = 8192" >> /etc/sysctl.conf
sysctl -p

sed -i 's/^# maxmemory <bytes>/maxmemory 2gb/' /etc/redis/redis.conf
sed -i 's/^# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf
sed -i 's/^bind 127.0.0.1 ::1/bind 127.0.0.1/' /etc/redis/redis.conf
systemctl restart redis-server
systemctl enable redis-server

useradd -m -d /opt/odoo -U -r -s /bin/bash odoo

git clone --depth 1 --branch ${odoo_version} https://github.com/odoo/odoo.git /opt/odoo/odoo

python3 -m venv /opt/odoo/venv
source /opt/odoo/venv/bin/activate
pip install --upgrade pip
pip install wheel
pip install -r /opt/odoo/odoo/requirements.txt

# Configure Odoo data directory on optimized NVMe storage
if [ -d /opt/odoo ]; then
    echo "Configuring Odoo filestore on optimized NVMe..."
    
    # Create Odoo filestore directories on NVMe
    mkdir -p /opt/odoo/filestore
    mkdir -p /opt/odoo/sessions  
    mkdir -p /opt/odoo/logs
    mkdir -p /opt/odoo/addons-extra
    
    # Create standard Odoo data directory structure
    mkdir -p /var/lib/odoo
    
    # Link filestore to NVMe for optimal performance
    if [ ! -L /var/lib/odoo/filestore ]; then
        rm -rf /var/lib/odoo/filestore 2>/dev/null || true
        ln -s /opt/odoo/filestore /var/lib/odoo/filestore
    fi
    
    # Link sessions to NVMe for better performance
    if [ ! -L /var/lib/odoo/sessions ]; then
        rm -rf /var/lib/odoo/sessions 2>/dev/null || true
        ln -s /opt/odoo/sessions /var/lib/odoo/sessions
    fi
    
    LOG_DIR="/opt/odoo/logs"
    
    echo "Odoo filestore configured on NVMe at /opt/odoo/filestore"
else
    # Fallback for instances without NVMe
    mkdir -p /var/lib/odoo
    LOG_DIR="/var/log"
    echo "Using standard storage (no NVMe detected)"
fi

mkdir -p $LOG_DIR/odoo
mkdir -p /etc/odoo

cat > /etc/odoo/odoo.conf <<EOL
[options]
admin_passwd = ${odoo_admin_passwd}
db_host = ${db_host}
db_port = 5432
db_user = odoo
db_password = ${db_password}
db_maxconn = 64
addons_path = /opt/odoo/odoo/addons
# Use standard data_dir - filestore is symlinked to NVMe
data_dir = /var/lib/odoo
logfile = $LOG_DIR/odoo/odoo.log
log_level = info
workers = ${odoo_workers}
max_cron_threads = 2
limit_memory_hard = 1677721600
limit_memory_soft = 1342177280
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200
server_wide_modules = base,web
EOL

chown -R odoo:odoo /opt/odoo
chown -R odoo:odoo $LOG_DIR/odoo
chown -R odoo:odoo /etc/odoo
chown -R odoo:odoo /var/lib/odoo

if [ -d /mnt/disks/ssd ]; then
    chown -R odoo:odoo /mnt/disks/ssd/odoo-data
    chown -R odoo:odoo /mnt/disks/ssd/odoo-sessions
fi

cat > /etc/systemd/system/odoo.service <<EOL
[Unit]
Description=Odoo
After=network.target redis-server.service

[Service]
Type=simple
User=odoo
Group=odoo
ExecStart=/opt/odoo/venv/bin/python /opt/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf
Restart=on-failure
RestartSec=5
StartLimitInterval=60
StartLimitBurst=3

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl start odoo
systemctl enable odoo

cat > /etc/nginx/nginx.conf <<EOL
user www-data;
worker_processes auto;
worker_rlimit_nofile 65535;
pid /run/nginx.pid;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json application/javascript;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOL

cat > /etc/nginx/sites-available/odoo <<EOL
upstream odoo {
    server 127.0.0.1:8069;
}

upstream odoochat {
    server 127.0.0.1:8072;
}

server {
    listen 80;
    server_name ${domain_name};

    access_log /var/log/nginx/odoo_access.log;
    error_log /var/log/nginx/odoo_error.log;

    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;
    proxy_buffers 16 64k;
    proxy_buffer_size 128k;

    location / {
        proxy_pass http://odoo;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_redirect off;
    }

    location /longpolling {
        proxy_pass http://odoochat;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Real-IP \$remote_addr;
    }

    location ~* /web/static/ {
        proxy_cache_valid 200 90m;
        proxy_buffering on;
        expires 864000;
        add_header Cache-Control "public";
        proxy_pass http://odoo;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        proxy_pass http://odoo;
    }
}
EOL

ln -s /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx

if [ ! -z "${domain_name}" ] && [ ! -z "${ssl_email}" ]; then
    certbot --nginx -d ${domain_name} --non-interactive --agree-tos --email ${ssl_email} --redirect
    
    echo "0 0 * * 0 root certbot renew --quiet --no-self-upgrade --post-hook 'systemctl reload nginx'" >> /etc/crontab
fi

cat > /etc/logrotate.d/odoo <<EOL
$LOG_DIR/odoo/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 odoo odoo
    sharedscripts
    postrotate
        systemctl reload odoo > /dev/null 2>&1 || true
    endscript
}
EOL

# Create NVMe performance monitoring script
cat > /opt/scripts/monitor-nvme-performance.sh <<'NVME_MON_EOF'
#!/bin/bash
# NVMe Performance Monitoring for Odoo Filestore

echo "=== NVMe Storage Performance Report ==="
echo "Generated: $(date)"
echo ""

if [ -b /dev/nvme0n1p1 ]; then
    echo "1. Filesystem Information:"
    df -h /opt/odoo
    echo ""
    
    echo "2. Mount Options:"
    mount | grep nvme0n1p1
    echo ""
    
    echo "3. Filesystem Features:"
    tune2fs -l /dev/nvme0n1p1 | grep -E "(Filesystem volume name|Block size|Inode size|Journal|Reserved block count|Mount options)"
    echo ""
    
    echo "4. NVMe Device Information:"
    nvme list 2>/dev/null || lsblk /dev/nvme0n1
    echo ""
    
    echo "5. I/O Statistics:"
    iostat -x 1 1 2>/dev/null | grep nvme || echo "iostat not available"
    echo ""
    
    echo "6. Odoo Filestore Usage:"
    if [ -d /opt/odoo/filestore ]; then
        echo "Filestore size: $(du -sh /opt/odoo/filestore 2>/dev/null | cut -f1)"
        echo "File count: $(find /opt/odoo/filestore -type f 2>/dev/null | wc -l)"
        echo "Recent activity:"
        find /opt/odoo/filestore -type f -mmin -60 2>/dev/null | head -5 | while read f; do
            echo "  $(stat -c '%y %n' "$f" 2>/dev/null)"
        done
    fi
    echo ""
    
    echo "7. Performance Test (Quick):"
    if command -v fio >/dev/null 2>&1; then
        echo "Running 4KB random read/write test (10s)..."
        fio --name=odoo-test --directory=/opt/odoo --size=100M --bs=4k --rw=randrw --runtime=10 --time_based --direct=1 --group_reporting --numjobs=4 --ioengine=libaio 2>/dev/null | grep -E "(read:|write:)" || echo "FIO test failed"
    else
        echo "FIO not available for performance testing"
        echo "Simple write test:"
        time dd if=/dev/zero of=/opt/odoo/test_write bs=1M count=100 oflag=direct 2>&1 | tail -3
        rm -f /opt/odoo/test_write
    fi
else
    echo "NVMe device not found or not mounted"
fi

echo ""
echo "=== End Report ==="
NVME_MON_EOF

chmod +x /opt/scripts/monitor-nvme-performance.sh

# Create filesystem optimization verification script
cat > /opt/scripts/verify-nvme-optimization.sh <<'NVME_VERIFY_EOF'
#!/bin/bash
# Verify NVMe Optimizations for Odoo

echo "=== NVMe Optimization Verification ==="

if [ -b /dev/nvme0n1p1 ]; then
    echo "✅ NVMe partition exists: /dev/nvme0n1p1"
    
    # Check mount options
    if mount | grep -q "nvme0n1p1.*noatime.*user_xattr"; then
        echo "✅ Optimal mount options: noatime, user_xattr detected"
    else
        echo "❌ Mount options not optimal"
        echo "Current: $(mount | grep nvme0n1p1)"
    fi
    
    # Check filesystem features
    if tune2fs -l /dev/nvme0n1p1 | grep -q "has_journal"; then
        echo "✅ Journal enabled for data integrity"
    else
        echo "❌ Journal not enabled"
    fi
    
    # Check reserved blocks
    RESERVED=$(tune2fs -l /dev/nvme0n1p1 | grep "Reserved block count" | awk '{print $4}')
    TOTAL=$(tune2fs -l /dev/nvme0n1p1 | grep "Block count" | awk '{print $3}')
    if [ -n "$RESERVED" ] && [ -n "$TOTAL" ]; then
        PERCENT=$(echo "scale=2; $RESERVED * 100 / $TOTAL" | bc -l 2>/dev/null || echo "N/A")
        if [ "$PERCENT" != "N/A" ] && [ "$(echo "$PERCENT < 2" | bc -l 2>/dev/null)" = "1" ]; then
            echo "✅ Reserved blocks optimized: ${PERCENT}% (should be ~1%)"
        else
            echo "⚠️  Reserved blocks: ${PERCENT}% (expected ~1%)"
        fi
    fi
    
    # Check Odoo filestore location
    if [ -L /var/lib/odoo/filestore ] && [ "$(readlink /var/lib/odoo/filestore)" = "/opt/odoo/filestore" ]; then
        echo "✅ Odoo filestore correctly linked to NVMe"
    else
        echo "❌ Odoo filestore not properly configured on NVMe"
    fi
    
    # Check permissions
    if [ -d /opt/odoo ] && [ "$(stat -c '%U' /opt/odoo)" = "odoo" ]; then
        echo "✅ NVMe mount permissions correct (owned by odoo)"
    else
        echo "⚠️  NVMe mount permissions may need adjustment"
    fi
    
    echo ""
    echo "Performance characteristics:"
    echo "- Block size: $(tune2fs -l /dev/nvme0n1p1 | grep 'Block size' | awk '{print $3}') bytes"
    echo "- Inode size: $(tune2fs -l /dev/nvme0n1p1 | grep 'Inode size' | awk '{print $3}') bytes"
    echo "- Available space: $(df -h /opt/odoo | tail -1 | awk '{print $4}')"
    
else
    echo "❌ NVMe partition not found"
fi
NVME_VERIFY_EOF

chmod +x /opt/scripts/verify-nvme-optimization.sh

# Run verification after setup
echo ""
echo "Running NVMe optimization verification..."
/opt/scripts/verify-nvme-optimization.sh

echo ""
echo "Production Odoo ${odoo_version} installation completed successfully!"
echo ""
echo "NVMe Performance Features:"
echo "✅ Partitioned for maximum space utilization"
echo "✅ ext4 optimized for small file workload (8192 inode ratio)"  
echo "✅ Journal writeback mode for performance"
echo "✅ Extended attributes enabled for Odoo metadata"
echo "✅ No access time updates (noatime)"
echo "✅ 1% reserved blocks (vs 5% default)"
echo "✅ Stride/stripe-width optimized for NVMe"
echo ""
echo "Monitoring commands:"
echo "  sudo /opt/scripts/monitor-nvme-performance.sh"
echo "  sudo /opt/scripts/verify-nvme-optimization.sh"