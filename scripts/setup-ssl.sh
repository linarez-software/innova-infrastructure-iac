#!/bin/bash
# SSL Certificate Setup Script using Let's Encrypt
# This script configures SSL certificates for the application

set -e

DOMAIN=""
EMAIL=""
WEBROOT="/var/www/html"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 -d DOMAIN -e EMAIL [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --domain DOMAIN     Domain name for SSL certificate"
    echo "  -e, --email EMAIL       Email address for Let's Encrypt"
    echo "  -w, --webroot PATH      Webroot path (default: /var/www/html)"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -d example.com -e admin@example.com"
}

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        -w|--webroot)
            WEBROOT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            error "Unknown option $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$DOMAIN" ]; then
    error "Domain is required"
    usage
    exit 1
fi

if [ -z "$EMAIL" ]; then
    error "Email is required"
    usage
    exit 1
fi

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "This script must be run as root"
    exit 1
fi

log "Setting up SSL certificate for $DOMAIN"

# Install certbot if not already installed
if ! command -v certbot &> /dev/null; then
    log "Installing certbot..."
    apt-get update
    apt-get install -y certbot python3-certbot-nginx
fi

# Create webroot directory if it doesn't exist
mkdir -p "$WEBROOT"

# Test NGINX configuration
log "Testing NGINX configuration..."
nginx -t || {
    error "NGINX configuration test failed"
    exit 1
}

# Obtain SSL certificate
log "Obtaining SSL certificate from Let's Encrypt..."
certbot --nginx \
    --non-interactive \
    --agree-tos \
    --email "$EMAIL" \
    --domains "$DOMAIN" \
    --redirect || {
    error "Failed to obtain SSL certificate"
    exit 1
}

# Test certificate renewal
log "Testing certificate auto-renewal..."
certbot renew --dry-run || {
    warn "Certificate renewal test failed - please check configuration"
}

# Set up auto-renewal cron job
log "Setting up auto-renewal cron job..."
cat > /etc/cron.d/certbot-renewal <<EOF
# Let's Encrypt certificate renewal
0 2 * * * root certbot renew --quiet --post-hook "systemctl reload nginx"
EOF

# Test HTTPS
log "Testing HTTPS connection..."
if curl -s -I "https://$DOMAIN" | grep -q "HTTP/.*200"; then
    success "HTTPS is working correctly"
else
    warn "HTTPS connection test failed - please verify manually"
fi

# Display certificate information
log "Certificate information:"
certbot certificates

success "SSL certificate setup completed successfully!"
echo ""
echo "Certificate details:"
echo "  Domain: $DOMAIN"
echo "  Email: $EMAIL"
echo "  Certificate location: /etc/letsencrypt/live/$DOMAIN/"
echo "  Auto-renewal: Configured (runs daily at 2 AM)"
echo ""
echo "Next steps:"
echo "1. Test your site at https://$DOMAIN"
echo "2. Update any application configurations to use HTTPS"
echo "3. Consider setting up HSTS headers for enhanced security"