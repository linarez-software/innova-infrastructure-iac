#!/bin/bash
# NGINX Configuration Script for Odoo v18 on c4-standard-4-lssd
# Optimized for high-performance compute instances with 7-worker load balancing

set -e

# Configuration variables
DOMAIN_NAME="${1:-localhost}"
SSL_EMAIL="${2:-admin@example.com}"
ODOO_WORKERS="${3:-7}"

echo "Configuring NGINX for Odoo with ${ODOO_WORKERS} workers..."

# Update system
export DEBIAN_FRONTEND=noninteractive
apt-get update

# Install NGINX and SSL tools
apt-get install -y \
    nginx \
    certbot \
    python3-certbot-nginx \
    openssl

# Stop NGINX for configuration
systemctl stop nginx

# Create optimized NGINX configuration
cat > /etc/nginx/nginx.conf << EOF
# NGINX Configuration optimized for c4-standard-4-lssd (4 vCPUs)
user www-data;
worker_processes auto;
worker_rlimit_nofile 65535;
pid /run/nginx.pid;

# Load dynamic modules
include /etc/nginx/modules-enabled/*.conf;

events {
    worker_connections 4096;
    use epoll;
    multi_accept on;
    accept_mutex off;
}

http {
    ##
    # Basic Settings
    ##
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    keepalive_requests 1000;
    types_hash_max_size 2048;
    server_tokens off;
    client_max_body_size 100M;
    client_body_buffer_size 128k;
    client_header_buffer_size 3m;
    large_client_header_buffers 4 256k;

    # Timeouts
    client_body_timeout 60s;
    client_header_timeout 60s;
    send_timeout 60s;

    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    ##
    # Logging Settings
    ##
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for" '
                    'rt=\$request_time uct="\$upstream_connect_time" '
                    'uht="\$upstream_header_time" urt="\$upstream_response_time"';

    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log warn;

    ##
    # Gzip Settings
    ##
    gzip on;
    gzip_vary on;
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
    gzip_min_length 1000;

    ##
    # Rate Limiting
    ##
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=login:10m rate=1r/s;

    ##
    # Upstream Configuration for Odoo (${ODOO_WORKERS} workers)
    ##
    upstream odoo {
        server 127.0.0.1:8069 weight=1 max_fails=3 fail_timeout=30s;
        keepalive 32;
    }

    upstream odoochat {
        server 127.0.0.1:8072 weight=1 max_fails=3 fail_timeout=30s;
        keepalive 16;
    }

    ##
    # Proxy Settings
    ##
    proxy_buffering on;
    proxy_buffer_size 128k;
    proxy_buffers 4 256k;
    proxy_busy_buffers_size 256k;
    proxy_temp_file_write_size 256k;
    proxy_connect_timeout 30s;
    proxy_send_timeout 120s;
    proxy_read_timeout 720s;
    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;

    # Proxy headers
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-Host \$server_name;

    ##
    # Cache Configuration
    ##
    proxy_cache_path /var/cache/nginx levels=1:2 keys_zone=odoo_cache:10m max_size=1g 
                     inactive=60m use_temp_path=off;

    ##
    # Security Headers
    ##
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;

    ##
    # Include additional configurations
    ##
    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/sites-enabled/*;
}
EOF

# Create Odoo site configuration
cat > /etc/nginx/sites-available/odoo << EOF
server {
    listen 80;
    server_name ${DOMAIN_NAME} www.${DOMAIN_NAME};

    # Redirect to HTTPS (will be configured by certbot)
    # return 301 https://\$server_name\$request_uri;

    # Temporary HTTP configuration (before SSL)
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN_NAME} www.${DOMAIN_NAME};

    # SSL configuration (will be managed by certbot)
    # ssl_certificate /etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/${DOMAIN_NAME}/privkey.pem;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Access and error logs
    access_log /var/log/nginx/odoo_access.log main;
    error_log /var/log/nginx/odoo_error.log;

    # Rate limiting for login
    location ~ ^/web/(login|session) {
        limit_req zone=login burst=5 nodelay;
        proxy_pass http://odoo;
        include /etc/nginx/proxy_params;
    }

    # Rate limiting for API calls
    location ~ ^/web/dataset/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://odoo;
        include /etc/nginx/proxy_params;
    }

    # Long polling for real-time features
    location /longpolling {
        proxy_pass http://odoochat;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_http_version 1.1;
        proxy_set_header X-Forwarded-Proto https;
        proxy_set_header X-Forwarded-Port 443;
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
        proxy_redirect off;
    }

    # Static files with aggressive caching
    location ~* ^/web/static/.*\\.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot|otf)\$ {
        proxy_cache odoo_cache;
        proxy_cache_valid 200 302 1h;
        proxy_cache_valid 404 1m;
        proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
        proxy_cache_lock on;
        
        expires 1y;
        add_header Cache-Control "public, immutable";
        add_header X-Cache-Status \$upstream_cache_status;
        
        proxy_pass http://odoo;
        include /etc/nginx/proxy_params;
    }

    # Image files
    location ~* ^/web/image/.*\\.(png|jpg|jpeg|gif|svg)\$ {
        proxy_cache odoo_cache;
        proxy_cache_valid 200 1h;
        expires 1h;
        add_header Cache-Control "public";
        proxy_pass http://odoo;
        include /etc/nginx/proxy_params;
    }

    # CSS and JS files
    location ~* ^/web/content/.*\\.(css|js)\$ {
        proxy_cache odoo_cache;
        proxy_cache_valid 200 1h;
        expires 1h;
        proxy_pass http://odoo;
        include /etc/nginx/proxy_params;
    }

    # File downloads
    location ~* ^/web/content/.*\\.(pdf|doc|docx|xls|xlsx|zip|rar)\$ {
        proxy_buffering off;
        proxy_pass http://odoo;
        include /etc/nginx/proxy_params;
    }

    # WebSocket support for real-time features
    location /websocket {
        proxy_pass http://odoochat;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Default location for all other requests
    location / {
        # Security headers for main application
        add_header X-Frame-Options "SAMEORIGIN";
        add_header X-Content-Type-Options "nosniff";
        
        proxy_pass http://odoo;
        include /etc/nginx/proxy_params;
        
        # Handle timeouts gracefully
        proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
    }

    # Health check endpoint
    location /nginx-health {
        access_log off;
        return 200 "healthy\\n";
        add_header Content-Type text/plain;
    }
}
EOF

# Create proxy parameters file
cat > /etc/nginx/proxy_params << EOF
proxy_set_header Host \$http_host;
proxy_set_header X-Real-IP \$remote_addr;
proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
proxy_set_header X-Forwarded-Proto \$scheme;
proxy_redirect off;
proxy_buffering on;
proxy_connect_timeout 30s;
proxy_send_timeout 120s;
proxy_read_timeout 720s;
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/odoo /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Create cache directory
mkdir -p /var/cache/nginx
chown -R www-data:www-data /var/cache/nginx

# Test NGINX configuration
nginx -t

# Start NGINX
systemctl start nginx
systemctl enable nginx

# Configure SSL with Let's Encrypt (if domain is not localhost)
if [ "$DOMAIN_NAME" != "localhost" ] && [ ! -z "$SSL_EMAIL" ]; then
    echo "Configuring SSL with Let's Encrypt..."
    
    # Ensure NGINX is running for the challenge
    systemctl start nginx
    
    # Get SSL certificate
    certbot --nginx -d ${DOMAIN_NAME} -d www.${DOMAIN_NAME} \\
        --non-interactive \\
        --agree-tos \\
        --email ${SSL_EMAIL} \\
        --redirect
    
    # Set up automatic renewal
    echo "0 12 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'" | crontab -
    
    echo "SSL certificate obtained and configured successfully!"
else
    echo "Skipping SSL configuration (localhost domain or no email provided)"
fi

# Create log rotation for NGINX
cat > /etc/logrotate.d/nginx << EOF
/var/log/nginx/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 www-data adm
    sharedscripts
    prerotate
        if [ -d /etc/logrotate.d/httpd-prerotate ]; then \\
            run-parts /etc/logrotate.d/httpd-prerotate; \\
        fi
    endscript
    postrotate
        invoke-rc.d nginx rotate >/dev/null 2>&1
    endscript
}
EOF

# Create NGINX monitoring script
cat > /usr/local/bin/nginx-monitor.sh << 'EOF'
#!/bin/bash
# NGINX Monitoring Script

echo "NGINX Status:"
systemctl status nginx --no-pager -l

echo -e "\nNGINX Configuration Test:"
nginx -t

echo -e "\nActive Connections:"
curl -s http://localhost/nginx-health || echo "Health check endpoint not responding"

echo -e "\nTop 10 IP Addresses by Requests (last 1000 lines):"
tail -n 1000 /var/log/nginx/access.log | awk '{print $1}' | sort | uniq -c | sort -rn | head -10

echo -e "\nResponse Time Statistics (last 1000 requests):"
tail -n 1000 /var/log/nginx/odoo_access.log | awk '{print $(NF-3)}' | grep -E '^[0-9]+\.[0-9]+$' | awk '{
    sum += $1
    count++
    if ($1 > max) max = $1
    if (min == "" || $1 < min) min = $1
} END {
    if (count > 0) {
        print "Requests: " count
        print "Average: " sum/count "s"
        print "Min: " min "s"
        print "Max: " max "s"
    } else {
        print "No timing data found"
    }
}'

echo -e "\nHTTP Status Codes (last 1000 requests):"
tail -n 1000 /var/log/nginx/odoo_access.log | awk '{print $9}' | sort | uniq -c | sort -rn

echo -e "\nSSL Certificate Status:"
if [ -f "/etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem" ]; then
    openssl x509 -in "/etc/letsencrypt/live/${DOMAIN_NAME}/fullchain.pem" -text -noout | grep -E "(Not Before|Not After)"
else
    echo "No SSL certificate found"
fi
EOF

chmod +x /usr/local/bin/nginx-monitor.sh

# Create performance tuning script
cat > /usr/local/bin/nginx-optimize.sh << 'EOF'
#!/bin/bash
# NGINX Performance Optimization Script

# Adjust worker connections based on system limits
WORKER_CONNECTIONS=$(ulimit -n)
if [ $WORKER_CONNECTIONS -gt 4096 ]; then
    WORKER_CONNECTIONS=4096
fi

echo "Optimizing NGINX for current system..."
echo "Worker connections: $WORKER_CONNECTIONS"

# Update system limits for NGINX
cat > /etc/security/limits.d/nginx.conf << EOL
www-data soft nofile 65535
www-data hard nofile 65535
EOL

# Optimize kernel parameters for web server
cat >> /etc/sysctl.d/99-nginx.conf << EOL
# NGINX optimizations
net.core.somaxconn = 65535
net.ipv4.tcp_max_syn_backlog = 8192
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_tw_reuse = 1
net.core.netdev_max_backlog = 5000
EOL

sysctl -p /etc/sysctl.d/99-nginx.conf

systemctl reload nginx

echo "NGINX optimization completed."
EOF

chmod +x /usr/local/bin/nginx-optimize.sh

# Run optimization
/usr/local/bin/nginx-optimize.sh

echo "NGINX configuration completed successfully!"
echo ""
echo "Configuration Summary:"
echo "  - Domain: ${DOMAIN_NAME}"
echo "  - SSL Email: ${SSL_EMAIL}"
echo "  - Odoo Workers: ${ODOO_WORKERS}"
echo "  - Max Client Body Size: 100M"
echo "  - Worker Connections: 4096 per worker"
echo "  - Keepalive: 32 connections to Odoo, 16 to longpolling"
echo ""
echo "Performance Features:"
echo "  - HTTP/2 enabled"
echo "  - Gzip compression configured"
echo "  - Static file caching (1 year expiry)"
echo "  - Proxy caching for web assets"
echo "  - Rate limiting on login and API endpoints"
echo "  - Security headers configured"
echo "  - Connection pooling to upstream"
echo ""
echo "Monitoring:"
echo "  - Health check: http://${DOMAIN_NAME}/nginx-health"
echo "  - Monitor script: /usr/local/bin/nginx-monitor.sh"
echo "  - Optimize script: /usr/local/bin/nginx-optimize.sh"
echo ""
echo "SSL Configuration:"
if [ "$DOMAIN_NAME" != "localhost" ]; then
    echo "  - Let's Encrypt certificate configured"
    echo "  - Automatic renewal scheduled"
    echo "  - HTTPS redirect enabled"
else
    echo "  - SSL not configured (localhost domain)"
fi
echo ""
echo "Log Files:"
echo "  - Access log: /var/log/nginx/odoo_access.log"
echo "  - Error log: /var/log/nginx/odoo_error.log"
echo "  - NGINX error log: /var/log/nginx/error.log"
EOF