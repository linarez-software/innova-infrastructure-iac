#!/bin/bash
# Enhanced VPN user creation with SSH key management
# Usage: ./create-vpn-user.sh USERNAME [SSH_PUBLIC_KEY_PATH]

set -e

# Configuration
PROJECT_ID="${PROJECT_ID:-deep-wares-246918}"
ZONE="${ZONE:-us-central1-a}"
USERNAME="${1}"
SSH_KEY_PATH="${2:-~/.ssh/id_rsa.pub}"
VPN_INSTANCE="vpn-staging"
APP_INSTANCE="app-staging"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validation
if [ -z "$USERNAME" ]; then
    log_error "Username is required"
    echo "Usage: $0 USERNAME [SSH_PUBLIC_KEY_PATH]"
    echo "Example: $0 john ~/.ssh/id_rsa.pub"
    exit 1
fi

# Expand tilde in SSH key path
SSH_KEY_PATH=$(eval echo "$SSH_KEY_PATH")

if [ ! -f "$SSH_KEY_PATH" ]; then
    log_error "SSH public key not found at: $SSH_KEY_PATH"
    echo "Generate SSH key pair with: ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa"
    exit 1
fi

log_info "Creating VPN user: $USERNAME"
log_info "Project: $PROJECT_ID"
log_info "Zone: $ZONE"
log_info "SSH Key: $SSH_KEY_PATH"

# Step 1: Add SSH key to project metadata
log_info "Step 1: Adding SSH key to project metadata..."

# Read the public key and format it correctly
SSH_PUBLIC_KEY_CONTENT=$(cat "$SSH_KEY_PATH")
SSH_KEY_ENTRY="$USERNAME:$SSH_PUBLIC_KEY_CONTENT"

# Get existing SSH keys
EXISTING_KEYS=$(gcloud compute project-info describe --format="value(commonInstanceMetadata.items[key=ssh-keys].value)" 2>/dev/null || echo "")

# Create new SSH keys metadata
if [ -z "$EXISTING_KEYS" ]; then
    NEW_SSH_KEYS="$SSH_KEY_ENTRY"
else
    # Check if user already exists
    if echo "$EXISTING_KEYS" | grep -q "^$USERNAME:"; then
        log_warn "SSH key for user $USERNAME already exists, updating..."
        NEW_SSH_KEYS=$(echo "$EXISTING_KEYS" | grep -v "^$USERNAME:" | grep -v "^$")
        NEW_SSH_KEYS="$NEW_SSH_KEYS"$'\n'"$SSH_KEY_ENTRY"
    else
        NEW_SSH_KEYS="$EXISTING_KEYS"$'\n'"$SSH_KEY_ENTRY"
    fi
fi

# Write to temporary file
TEMP_SSH_FILE=$(mktemp)
echo "$NEW_SSH_KEYS" | grep -v "^$" > "$TEMP_SSH_FILE"

# Update project metadata
gcloud compute project-info add-metadata --metadata-from-file ssh-keys="$TEMP_SSH_FILE"

# Cleanup
rm "$TEMP_SSH_FILE"

log_info "SSH key added to project metadata"

# Step 2: Wait for metadata propagation
log_info "Step 2: Waiting for metadata propagation..."
sleep 10

# Step 3: Create VPN certificate on VPN server
log_info "Step 3: Creating VPN certificate on VPN server..."

gcloud compute ssh "$VPN_INSTANCE" --zone="$ZONE" --project="$PROJECT_ID" --command="sudo /opt/scripts/manage-vpn-users.sh add $USERNAME" || {
    log_error "Failed to create VPN certificate. Retrying..."
    sleep 30
    gcloud compute ssh "$VPN_INSTANCE" --zone="$ZONE" --project="$PROJECT_ID" --command="sudo /opt/scripts/manage-vpn-users.sh add $USERNAME"
}

# Step 4: Download VPN configuration
log_info "Step 4: Downloading VPN configuration..."

gcloud compute scp "$VPN_INSTANCE:/opt/vpn-configs/$USERNAME.ovpn" "./$USERNAME-staging.ovpn" --zone="$ZONE" --project="$PROJECT_ID" 2>/dev/null || {
    log_warn "Direct download failed. Trying alternative method..."
    
    # Try to download from GCS bucket if configured
    if gsutil ls "gs://$PROJECT_ID-staging-vpn-configs/" &>/dev/null; then
        gsutil cp "gs://$PROJECT_ID-staging-vpn-configs/$USERNAME.ovpn" "./$USERNAME-staging.ovpn" 2>/dev/null || {
            log_error "Failed to download VPN configuration"
            log_info "Manual download required: gcloud compute scp $VPN_INSTANCE:/opt/vpn-configs/$USERNAME.ovpn . --zone=$ZONE"
        }
    else
        log_error "Failed to download VPN configuration"
        log_info "Manual download required: gcloud compute scp $VPN_INSTANCE:/opt/vpn-configs/$USERNAME.ovpn . --zone=$ZONE"
    fi
}

# Step 5: Test SSH access to both servers
log_info "Step 5: Testing SSH access..."

# Test VPN server access
log_info "Testing SSH access to VPN server..."
if gcloud compute ssh "$VPN_INSTANCE" --zone="$ZONE" --project="$PROJECT_ID" --command="echo 'SSH to VPN server successful'" 2>/dev/null; then
    log_info "✓ SSH access to VPN server working"
else
    log_warn "✗ SSH access to VPN server failed"
fi

# Test app server access (this will fail until VPN is connected)
log_info "Testing SSH access to app server (requires VPN connection)..."
if gcloud compute ssh "$APP_INSTANCE" --zone="$ZONE" --project="$PROJECT_ID" --internal-ip --command="echo 'SSH to app server successful'" 2>/dev/null; then
    log_info "✓ SSH access to app server working (VPN connected)"
else
    log_warn "✗ SSH access to app server requires VPN connection"
fi

# Get server information
VPN_IP=$(gcloud compute instances describe "$VPN_INSTANCE" --zone="$ZONE" --project="$PROJECT_ID" --format='value(networkInterfaces[0].accessConfigs[0].natIP)')
APP_IP=$(gcloud compute instances describe "$APP_INSTANCE" --zone="$ZONE" --project="$PROJECT_ID" --format='value(networkInterfaces[0].networkIP)')

# Summary
log_info "========================================="
log_info "VPN User Creation Complete!"
log_info "========================================="
echo ""
echo "User: $USERNAME"
echo "VPN Server IP: $VPN_IP"
echo "App Server Internal IP: $APP_IP"
echo ""

if [ -f "./$USERNAME-staging.ovpn" ]; then
    echo "✓ VPN Configuration: ./$USERNAME-staging.ovpn"
else
    echo "✗ VPN Configuration: Download required"
fi

echo ""
echo "SSH Access Commands:"
echo "  VPN Server: gcloud compute ssh $VPN_INSTANCE --zone=$ZONE"
echo "  App Server: ssh $USERNAME@$APP_IP (after VPN connection)"
echo "  App Server (gcloud): gcloud compute ssh $APP_INSTANCE --zone=$ZONE --internal-ip"
echo ""
echo "VPN Connection:"
echo "1. Install OpenVPN client"
echo "2. Import ./$USERNAME-staging.ovpn file"
echo "3. Connect to VPN"
echo "4. Access internal servers using their internal IPs"
echo ""
echo "Test connectivity after VPN connection:"
echo "  ping $APP_IP"
echo "  ssh $USERNAME@$APP_IP"
echo ""
echo "VPN Management Commands:"
echo "  List connections: gcloud compute ssh $VPN_INSTANCE --zone=$ZONE --command='sudo /opt/scripts/manage-vpn-users.sh list'"
echo "  Monitor VPN: gcloud compute ssh $VPN_INSTANCE --zone=$ZONE --command='sudo /opt/scripts/vpn-monitor.sh'"
echo "  Revoke access: gcloud compute ssh $VPN_INSTANCE --zone=$ZONE --command='sudo /opt/scripts/manage-vpn-users.sh revoke $USERNAME'"