#!/bin/bash
# Deploy SSH key to all servers in the environment

set -e

PROJECT_ID="${PROJECT_ID:-deep-wares-246918}"
ZONE="${ZONE:-us-central1-a}"
USERNAME="${1}"
SSH_KEY_PATH="${2:-~/.ssh/id_rsa.pub}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

if [ -z "$USERNAME" ]; then
    log_error "Username is required"
    echo "Usage: $0 USERNAME [SSH_PUBLIC_KEY_PATH]"
    echo "Example: $0 john ~/.ssh/id_rsa.pub"
    exit 1
fi

# Expand tilde
SSH_KEY_PATH=$(eval echo "$SSH_KEY_PATH")

if [ ! -f "$SSH_KEY_PATH" ]; then
    log_error "SSH public key not found at: $SSH_KEY_PATH"
    exit 1
fi

SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH")

log_info "Deploying SSH key for user: $USERNAME"
log_info "SSH Key Path: $SSH_KEY_PATH"

# Get list of all instances
INSTANCES=$(gcloud compute instances list --zones=$ZONE --project=$PROJECT_ID --format="value(name)" --filter="status=RUNNING")

log_info "Found instances: $(echo $INSTANCES | tr '\n' ' ')"

# Function to add SSH key to a server
add_ssh_key_to_server() {
    local instance_name="$1"
    local use_internal="$2"
    
    log_info "Adding SSH key to $instance_name..."
    
    local ssh_flags=""
    if [ "$use_internal" = "true" ]; then
        ssh_flags="--internal-ip"
    fi
    
    local add_user_cmd="sudo useradd -m -s /bin/bash $USERNAME 2>/dev/null || echo 'User already exists'"
    local setup_ssh_cmd="sudo mkdir -p /home/$USERNAME/.ssh && sudo chmod 700 /home/$USERNAME/.ssh"
    local add_key_cmd="echo '$SSH_PUBLIC_KEY' | sudo tee /home/$USERNAME/.ssh/authorized_keys > /dev/null"
    local fix_perms_cmd="sudo chmod 600 /home/$USERNAME/.ssh/authorized_keys && sudo chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh"
    
    local full_cmd="$add_user_cmd && $setup_ssh_cmd && $add_key_cmd && $fix_perms_cmd && echo 'SSH key deployed successfully to $instance_name'"
    
    if gcloud compute ssh "$instance_name" --zone=$ZONE --project=$PROJECT_ID $ssh_flags --command="$full_cmd" 2>/dev/null; then
        log_info "✓ SSH key deployed to $instance_name"
    else
        log_error "✗ Failed to deploy SSH key to $instance_name"
        return 1
    fi
}

# Deploy to each instance
success_count=0
total_count=0

for instance in $INSTANCES; do
    total_count=$((total_count + 1))
    
    # Use internal IP for non-VPN servers (app-staging, jenkins-staging)
    # Use external IP for VPN server
    if [[ "$instance" == "vpn-"* ]]; then
        use_internal="false"
    else
        use_internal="true"
    fi
    
    if add_ssh_key_to_server "$instance" "$use_internal"; then
        success_count=$((success_count + 1))
    fi
done

echo ""
log_info "Deployment Summary:"
log_info "Successfully deployed to: $success_count/$total_count servers"

if [ $success_count -eq $total_count ]; then
    log_info "SSH key deployment completed successfully!"
    echo ""
    echo "You can now SSH to:"
    for instance in $INSTANCES; do
        internal_ip=$(gcloud compute instances describe "$instance" --zone=$ZONE --project=$PROJECT_ID --format='value(networkInterfaces[0].networkIP)')
        echo "  ssh $USERNAME@$internal_ip  # $instance"
    done
    echo ""
    echo "Note: Access to internal IPs (10.0.0.x) requires VPN connection"
else
    log_warn "Some deployments failed. Check the logs above."
fi