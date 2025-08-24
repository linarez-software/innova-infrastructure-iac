#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

if [ -b /dev/nvme0n1 ]; then
    mkfs.ext4 /dev/nvme0n1
    mkdir -p /mnt/disks/ssd
    mount /dev/nvme0n1 /mnt/disks/ssd
    echo "/dev/nvme0n1 /mnt/disks/ssd ext4 defaults,nofail 0 0" >> /etc/fstab
    chmod 777 /mnt/disks/ssd
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
    postgresql-client-15

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

if [ -d /mnt/disks/ssd ]; then
    mkdir -p /mnt/disks/ssd/odoo-data
    mkdir -p /mnt/disks/ssd/odoo-sessions
    ln -s /mnt/disks/ssd/odoo-data /var/lib/odoo
    LOG_DIR="/mnt/disks/ssd"
else
    mkdir -p /var/lib/odoo
    LOG_DIR="/var/log"
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

echo "Production Odoo ${odoo_version} installation completed successfully!"