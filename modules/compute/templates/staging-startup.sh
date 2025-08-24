#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive

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
    supervisor

wget -q -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list
apt-get update
apt-get install -y postgresql-${postgresql_version} postgresql-client-${postgresql_version} postgresql-contrib-${postgresql_version}

systemctl start postgresql
systemctl enable postgresql

sudo -u postgres psql <<EOF
ALTER USER postgres PASSWORD '${db_password}';
CREATE USER odoo WITH PASSWORD '${db_password}';
ALTER USER odoo CREATEDB;
EOF

sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /etc/postgresql/${postgresql_version}/main/postgresql.conf
echo "host    all             all             10.0.0.0/24            md5" >> /etc/postgresql/${postgresql_version}/main/pg_hba.conf
systemctl restart postgresql

useradd -m -d /opt/odoo -U -r -s /bin/bash odoo

git clone --depth 1 --branch ${odoo_version} https://github.com/odoo/odoo.git /opt/odoo/odoo

python3 -m venv /opt/odoo/venv
source /opt/odoo/venv/bin/activate
pip install --upgrade pip
pip install wheel
pip install -r /opt/odoo/odoo/requirements.txt

mkdir -p /var/log/odoo
mkdir -p /etc/odoo
mkdir -p /var/lib/odoo

cat > /etc/odoo/odoo.conf <<EOL
[options]
admin_passwd = ${odoo_admin_passwd}
db_host = localhost
db_port = 5432
db_user = odoo
db_password = ${db_password}
addons_path = /opt/odoo/odoo/addons
data_dir = /var/lib/odoo
logfile = /var/log/odoo/odoo.log
log_level = info
workers = ${odoo_workers}
max_cron_threads = 2
limit_memory_hard = 1677721600
limit_memory_soft = 1342177280
limit_request = 8192
limit_time_cpu = 600
limit_time_real = 1200
EOL

chown -R odoo:odoo /opt/odoo
chown -R odoo:odoo /var/log/odoo
chown -R odoo:odoo /etc/odoo
chown -R odoo:odoo /var/lib/odoo

cat > /etc/systemd/system/odoo.service <<EOL
[Unit]
Description=Odoo
After=network.target postgresql.service

[Service]
Type=simple
User=odoo
Group=odoo
ExecStart=/opt/odoo/venv/bin/python /opt/odoo/odoo/odoo-bin -c /etc/odoo/odoo.conf
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl start odoo
systemctl enable odoo

cat > /etc/nginx/sites-available/odoo <<EOL
server {
    listen 80;
    server_name ${domain_name};

    access_log /var/log/nginx/odoo_access.log;
    error_log /var/log/nginx/odoo_error.log;

    proxy_read_timeout 720s;
    proxy_connect_timeout 720s;
    proxy_send_timeout 720s;

    proxy_set_header X-Forwarded-Host \$host;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Real-IP \$remote_addr;

    location / {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:8069;
    }

    location /longpolling {
        proxy_pass http://127.0.0.1:8072;
    }

    location ~* /web/static/ {
        proxy_cache_valid 200 90m;
        proxy_buffering on;
        expires 864000;
        proxy_pass http://127.0.0.1:8069;
    }

    gzip_types text/css text/scss text/plain text/xml application/xml application/json application/javascript;
    gzip on;
}
EOL

ln -s /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl restart nginx

if [ ! -z "${domain_name}" ] && [ ! -z "${ssl_email}" ]; then
    certbot --nginx -d ${domain_name} --non-interactive --agree-tos --email ${ssl_email} --redirect
fi

echo "Odoo ${odoo_version} installation completed successfully!"