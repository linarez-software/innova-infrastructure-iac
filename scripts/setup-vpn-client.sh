#!/bin/bash
# VPN Client Setup Script for Innova OpenVPN
# This script helps administrators set up VPN access for team members

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
VPN_SERVER_ZONE=""
VPN_SERVER_NAME=""
GCP_PROJECT=""
CLIENT_NAME=""
ACTION=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 [OPTIONS] ACTION CLIENT_NAME"
    echo ""
    echo "Actions:"
    echo "  add       Add a new VPN user and download their configuration"
    echo "  revoke    Revoke access for an existing VPN user"
    echo "  list      List active VPN connections"
    echo "  status    Show VPN server status"
    echo "  download  Download existing client configuration"
    echo ""
    echo "Options:"
    echo "  -p, --project PROJECT_ID    GCP Project ID"
    echo "  -z, --zone ZONE             GCP Zone (e.g., us-central1-a)"
    echo "  -s, --server SERVER_NAME    VPN server instance name"
    echo "  -e, --environment ENV       Environment (staging/production)"
    echo "  -h, --help                  Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -p my-project -z us-central1-a -e production add john.doe"
    echo "  $0 -p my-project -z us-central1-a -e production revoke john.doe"
    echo "  $0 -p my-project -z us-central1-a -e production list"
    echo "  $0 -p my-project -z us-central1-a -e production download john.doe"
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

check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v gcloud &> /dev/null; then
        error "gcloud CLI is required but not installed."
        error "Install it from: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        warn "terraform is not installed. Some features may not work."
    fi
    
    success "Dependencies check passed"
}

get_terraform_outputs() {
    log "Getting Terraform outputs..."
    
    local env_dir=""
    if [ "$ENVIRONMENT" = "staging" ]; then
        env_dir="$PROJECT_ROOT/environments/staging"
    elif [ "$ENVIRONMENT" = "production" ]; then
        env_dir="$PROJECT_ROOT/environments/production"
    else
        error "Invalid environment: $ENVIRONMENT"
        exit 1
    fi
    
    if [ -d "$env_dir" ] && [ -f "$env_dir/.terraform/terraform.tfstate" ]; then
        cd "$env_dir"
        
        if [ -z "$GCP_PROJECT" ]; then
            GCP_PROJECT=$(terraform output -raw project_id 2>/dev/null || echo "")
        fi
        
        if [ -z "$VPN_SERVER_ZONE" ]; then
            VPN_SERVER_ZONE=$(terraform output -raw zone 2>/dev/null || echo "")
        fi
        
        if [ -z "$VPN_SERVER_NAME" ]; then
            VPN_SERVER_NAME="vpn-$ENVIRONMENT"
        fi
        
        cd "$SCRIPT_DIR"
    fi
}

validate_config() {
    if [ -z "$GCP_PROJECT" ]; then
        error "GCP Project ID is required. Use -p or set in terraform outputs."
        exit 1
    fi
    
    if [ -z "$VPN_SERVER_ZONE" ]; then
        error "GCP Zone is required. Use -z or set in terraform outputs."
        exit 1
    fi
    
    if [ -z "$VPN_SERVER_NAME" ]; then
        VPN_SERVER_NAME="vpn-$ENVIRONMENT"
    fi
    
    log "Configuration:"
    log "  Project: $GCP_PROJECT"
    log "  Zone: $VPN_SERVER_ZONE"
    log "  Server: $VPN_SERVER_NAME"
    log "  Environment: $ENVIRONMENT"
}

ssh_to_vpn() {
    local command="$1"
    log "Executing on VPN server: $command"
    gcloud compute ssh "$VPN_SERVER_NAME" \
        --zone="$VPN_SERVER_ZONE" \
        --project="$GCP_PROJECT" \
        --command="$command"
}

add_vpn_user() {
    local username="$1"
    
    log "Adding VPN user: $username"
    
    # Validate username
    if [[ ! "$username" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        error "Invalid username. Use only letters, numbers, dots, underscores, and hyphens."
        exit 1
    fi
    
    # Add user on VPN server
    if ssh_to_vpn "sudo /opt/scripts/manage-vpn-users.sh add $username"; then
        success "User $username added successfully"
        
        # Download configuration
        log "Downloading VPN configuration for $username..."
        
        local config_file="${username}-vpn-config.ovpn"
        if gcloud compute scp "$VPN_SERVER_NAME:/opt/vpn-configs/${username}.ovpn" "./$config_file" \
            --zone="$VPN_SERVER_ZONE" \
            --project="$GCP_PROJECT"; then
            success "Configuration downloaded: $config_file"
            
            echo ""
            echo "Next steps:"
            echo "1. Send $config_file to the user securely"
            echo "2. Instruct them to import it into their OpenVPN client"
            echo "3. Delete the local config file after sending: rm $config_file"
        else
            error "Failed to download configuration file"
        fi
    else
        error "Failed to add user $username"
        exit 1
    fi
}

revoke_vpn_user() {
    local username="$1"
    
    warn "Revoking VPN access for user: $username"
    read -p "Are you sure? This action cannot be undone. (yes/no): " confirm
    
    if [ "$confirm" = "yes" ]; then
        if ssh_to_vpn "sudo /opt/scripts/manage-vpn-users.sh revoke $username"; then
            success "User $username access revoked successfully"
        else
            error "Failed to revoke user $username"
            exit 1
        fi
    else
        log "Revocation cancelled"
    fi
}

list_vpn_users() {
    log "Listing active VPN connections..."
    ssh_to_vpn "sudo /opt/scripts/manage-vpn-users.sh list"
}

show_vpn_status() {
    log "Getting VPN server status..."
    ssh_to_vpn "sudo /opt/scripts/vpn-monitor.sh"
}

download_config() {
    local username="$1"
    
    log "Downloading VPN configuration for $username..."
    
    local config_file="${username}-vpn-config.ovpn"
    if gcloud compute scp "$VPN_SERVER_NAME:/opt/vpn-configs/${username}.ovpn" "./$config_file" \
        --zone="$VPN_SERVER_ZONE" \
        --project="$GCP_PROJECT"; then
        success "Configuration downloaded: $config_file"
    else
        error "Failed to download configuration. User may not exist."
        exit 1
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--project)
            GCP_PROJECT="$2"
            shift 2
            ;;
        -z|--zone)
            VPN_SERVER_ZONE="$2"
            shift 2
            ;;
        -s|--server)
            VPN_SERVER_NAME="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        add|revoke|list|status|download)
            ACTION="$1"
            shift
            ;;
        -*)
            error "Unknown option $1"
            usage
            exit 1
            ;;
        *)
            if [ -z "$CLIENT_NAME" ] && [ "$ACTION" != "list" ] && [ "$ACTION" != "status" ]; then
                CLIENT_NAME="$1"
            else
                error "Unexpected argument: $1"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate arguments
if [ -z "$ACTION" ]; then
    error "Action is required"
    usage
    exit 1
fi

if [ -z "$CLIENT_NAME" ] && [ "$ACTION" != "list" ] && [ "$ACTION" != "status" ]; then
    error "Client name is required for action: $ACTION"
    usage
    exit 1
fi

if [ -z "$ENVIRONMENT" ]; then
    ENVIRONMENT="production"
    warn "Environment not specified, defaulting to: $ENVIRONMENT"
fi

# Main execution
main() {
    log "Innova VPN Client Management Script"
    log "=================================="
    
    check_dependencies
    get_terraform_outputs
    validate_config
    
    case "$ACTION" in
        add)
            add_vpn_user "$CLIENT_NAME"
            ;;
        revoke)
            revoke_vpn_user "$CLIENT_NAME"
            ;;
        list)
            list_vpn_users
            ;;
        status)
            show_vpn_status
            ;;
        download)
            download_config "$CLIENT_NAME"
            ;;
        *)
            error "Unknown action: $ACTION"
            usage
            exit 1
            ;;
    esac
}

main "$@"