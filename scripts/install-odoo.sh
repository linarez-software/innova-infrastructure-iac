#!/bin/bash
# Odoo v18 Installation Script for c4-standard-4-lssd (Production)
# Optimized for 7 workers on 4 vCPUs, 15 GB RAM with local SSD

set -e

# Configuration variables
ODOO_VERSION="${1:-18.0}"
ODOO_USER="${2:-odoo}"
ODOO_HOME="/opt/odoo"
ODOO_CONFIG="/etc/odoo/odoo.conf"
ODOO_LOG_DIR="/mnt/disks/ssd/odoo-logs"
ODOO_DATA_DIR="/mnt/disks/ssd/odoo-data"

echo "Starting Odoo v${ODOO_VERSION} installation optimized for c4-standard-4-lssd..."

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get upgrade -y

# Install system dependencies
apt-get install -y \
    wget \
    ca-certificates \
    curl \
    dirmngr \
    fonts-noto-cjk \
    gnupg \
    libssl-dev \
    node-less \
    npm \
    python3-num2words \
    python3-pip \
    python3-phonenumbers \
    python3-pyldap \
    python3-qrcode \
    python3-renderpm \
    python3-setuptools \
    python3-slugify \
    python3-vobject \
    python3-watchdog \
    python3-xlrd \
    python3-xlwt \
    xz-utils \
    build-essential \
    python3-dev \
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
    git \
    nginx \
    supervisor \
    redis-server

# Install wkhtmltopdf (for PDF generation)
cd /tmp
wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.jammy_amd64.deb
apt-get install -y ./wkhtmltox_0.12.6.1-2.jammy_amd64.deb

# Create Odoo user
useradd -m -d $ODOO_HOME -U -r -s /bin/bash $ODOO_USER

# Clone Odoo repository
echo "Cloning Odoo v${ODOO_VERSION}..."
git clone --depth 1 --branch ${ODOO_VERSION} --single-branch https://github.com/odoo/odoo.git $ODOO_HOME/odoo

# Setup Python virtual environment
python3 -m pip install --upgrade pip
pip3 install virtualenv
sudo -u $ODOO_USER virtualenv $ODOO_HOME/venv

# Activate virtual environment and install dependencies
sudo -u $ODOO_USER bash -c "source $ODOO_HOME/venv/bin/activate && pip install --upgrade pip"
sudo -u $ODOO_USER bash -c "source $ODOO_HOME/venv/bin/activate && pip install wheel"
sudo -u $ODOO_USER bash -c "source $ODOO_HOME/venv/bin/activate && pip install -r $ODOO_HOME/odoo/requirements.txt"

# Setup local SSD directories (if available)
if [ -b /dev/nvme0n1 ]; then
    echo "Setting up local SSD storage..."
    mkfs.ext4 -F /dev/nvme0n1
    mkdir -p /mnt/disks/ssd
    mount /dev/nvme0n1 /mnt/disks/ssd
    echo "/dev/nvme0n1 /mnt/disks/ssd ext4 defaults,nofail 0 0" >> /etc/fstab
    
    # Create Odoo directories on SSD
    mkdir -p $ODOO_LOG_DIR $ODOO_DATA_DIR
    mkdir -p /mnt/disks/ssd/odoo-sessions
    chown -R $ODOO_USER:$ODOO_USER /mnt/disks/ssd/odoo-*
else
    # Fallback to standard directories
    ODOO_LOG_DIR="/var/log/odoo"
    ODOO_DATA_DIR="/var/lib/odoo"
fi

# Create necessary directories
mkdir -p /etc/odoo $ODOO_LOG_DIR $ODOO_DATA_DIR
chown -R $ODOO_USER:$ODOO_USER /etc/odoo $ODOO_LOG_DIR $ODOO_DATA_DIR $ODOO_HOME

# Create Odoo configuration file optimized for 7 workers
cat > $ODOO_CONFIG << EOF
[options]
; This is the password that allows database operations:
admin_passwd = \${ODOO_ADMIN_PASSWD:-admin}

; Database settings
db_host = \${DB_HOST:-localhost}
db_port = \${DB_PORT:-5432}
db_user = \${DB_USER:-odoo}
db_password = \${DB_PASSWORD}
db_maxconn = 64
db_template = template0

; Odoo configuration optimized for c4-standard-4-lssd (4 vCPUs, 15 GB RAM)
workers = 7
max_cron_threads = 2
limit_memory_hard = 1677721600  ; 1.6GB per worker
limit_memory_soft = 1342177280  ; 1.28GB per worker
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200

; Performance optimizations
server_wide_modules = base,web
osv_memory_age_limit = 1.0
osv_memory_count_limit = False

; Paths
addons_path = $ODOO_HOME/odoo/addons
data_dir = $ODOO_DATA_DIR

; Logging
logfile = $ODOO_LOG_DIR/odoo.log
log_level = info
log_handler = :INFO
log_db = False
log_db_level = warning
logrotate = True

; Security
list_db = False
proxy_mode = True

; Session storage (on SSD if available)
session_dir = \${SESSION_DIR:-/tmp/sessions}

; HTTP
http_interface = 127.0.0.1
http_port = 8069
longpolling_port = 8072

; Email configuration
email_from = False
smtp_server = localhost
smtp_port = 25
smtp_ssl = False
smtp_user = False
smtp_password = False
EOF

# Set permissions
chown $ODOO_USER:$ODOO_USER $ODOO_CONFIG
chmod 640 $ODOO_CONFIG

# Create systemd service file
cat > /etc/systemd/system/odoo.service << EOF
[Unit]
Description=Odoo
Documentation=http://www.odoo.com
After=network.target postgresql.service

[Service]
Type=simple
SyslogIdentifier=odoo
PermissionsStartOnly=true
User=$ODOO_USER
Group=$ODOO_USER
ExecStart=$ODOO_HOME/venv/bin/python3 $ODOO_HOME/odoo/odoo-bin -c $ODOO_CONFIG
StandardOutput=journal+console
Environment=PATH="$ODOO_HOME/venv/bin:\$PATH"
KillMode=mixed
KillSignal=SIGINT
Restart=on-failure
RestartSec=18
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# Configure Redis for session storage and caching
sed -i 's/^# maxmemory <bytes>/maxmemory 2gb/' /etc/redis/redis.conf
sed -i 's/^# maxmemory-policy noeviction/maxmemory-policy allkeys-lru/' /etc/redis/redis.conf
sed -i 's/^bind 127.0.0.1 ::1/bind 127.0.0.1/' /etc/redis/redis.conf
systemctl enable redis-server
systemctl restart redis-server

# System optimizations for high-performance workload
echo "Applying system optimizations..."

# Kernel parameters
cat >> /etc/sysctl.conf << EOF

# Odoo performance optimizations
vm.overcommit_memory = 1
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_notsent_lowat = 16384
vm.swappiness = 10
EOF

sysctl -p

# Configure logrotate for Odoo logs
cat > /etc/logrotate.d/odoo << EOF
$ODOO_LOG_DIR/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 $ODOO_USER $ODOO_USER
    sharedscripts
    postrotate
        systemctl reload odoo > /dev/null 2>&1 || true
    endscript
}
EOF

# Enable and start Odoo service
systemctl daemon-reload
systemctl enable odoo

echo "Odoo v${ODOO_VERSION} installation completed successfully!"
echo "Configuration file: $ODOO_CONFIG"
echo "Log directory: $ODOO_LOG_DIR"
echo "Data directory: $ODOO_DATA_DIR"
echo ""
echo "To start Odoo:"
echo "  systemctl start odoo"
echo ""
echo "To check status:"
echo "  systemctl status odoo"
echo ""
echo "To view logs:"
echo "  journalctl -u odoo -f"
echo ""
echo "Performance features:"
echo "  - 7 workers optimized for 4 vCPUs"
echo "  - Memory limits: 1.6GB hard / 1.28GB soft per worker"
echo "  - Local SSD storage (if available): $ODOO_DATA_DIR"
echo "  - Redis caching with 2GB memory limit"
echo "  - System optimizations applied"