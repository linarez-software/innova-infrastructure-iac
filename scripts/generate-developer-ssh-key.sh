#!/bin/bash
# Script to generate SSH keys for developers to access staging through VPN
# These keys should be added to terraform.tfvars in the staging_ssh_users variable

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if username is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <developer-username>"
    echo ""
    echo "Example: $0 john.doe"
    echo ""
    echo "This script will generate an SSH key pair for the developer"
    echo "and provide the configuration to add to terraform.tfvars"
    exit 1
fi

USERNAME=$1
KEY_DIR="./ssh-keys/developers"
KEY_PATH="$KEY_DIR/${USERNAME}_staging"

# Validate username
if [[ ! "$USERNAME" =~ ^[a-z][-a-z0-9._]*$ ]]; then
    print_error "Invalid username. Use lowercase letters, numbers, dots, hyphens, and underscores only."
    exit 1
fi

# Create directory for SSH keys
mkdir -p "$KEY_DIR"

# Check if key already exists
if [ -f "$KEY_PATH" ]; then
    print_warning "SSH key already exists for $USERNAME at $KEY_PATH"
    read -p "Do you want to overwrite it? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Using existing key..."
    else
        # Generate new SSH key pair
        print_info "Generating new SSH key pair for $USERNAME..."
        ssh-keygen -t ed25519 -f "$KEY_PATH" -C "${USERNAME}@staging" -N ""
    fi
else
    # Generate SSH key pair
    print_info "Generating SSH key pair for $USERNAME..."
    ssh-keygen -t ed25519 -f "$KEY_PATH" -C "${USERNAME}@staging" -N ""
fi

# Read the public key
PUBLIC_KEY=$(cat "${KEY_PATH}.pub")

# Create a Terraform configuration snippet
TFVARS_SNIPPET="  {
    username = \"$USERNAME\"
    ssh_key  = \"$PUBLIC_KEY\"
  },"

# Display results
echo ""
echo "========================================="
echo -e "${GREEN}SSH Key Generated Successfully!${NC}"
echo "========================================="
echo ""
echo -e "${BLUE}1. Private key location:${NC}"
echo "   $KEY_PATH"
echo ""
echo -e "${BLUE}2. Public key location:${NC}"
echo "   ${KEY_PATH}.pub"
echo ""
echo -e "${BLUE}3. Add this to your staging/terraform.tfvars file:${NC}"
echo ""
echo "staging_ssh_users = ["
echo "$TFVARS_SNIPPET"
echo "  # ... other users ..."
echo "]"
echo ""
echo -e "${BLUE}4. Share these files with $USERNAME:${NC}"
echo "   - Private key: $KEY_PATH"
echo "   - VPN config: scripts/*-vpn-config.ovpn"
echo ""
echo -e "${BLUE}5. Developer SSH access instructions:${NC}"
echo ""
cat << EOF
   a) Connect to VPN:
      sudo openvpn --config vpn-config.ovpn

   b) SSH to staging (after Terraform apply):
      ssh -i $KEY_PATH $USERNAME@<STAGING_INTERNAL_IP>
      
   Note: The internal IP will be shown after 'terraform apply'
         Typically it's 10.0.0.2 for staging
EOF
echo ""
echo "========================================="
echo -e "${YELLOW}IMPORTANT SECURITY NOTES:${NC}"
echo "========================================="
echo "1. Keep the private key secure and share it only with $USERNAME"
echo "2. The developer must be connected to VPN to access staging"
echo "3. SSH access is restricted to VPN subnet only (10.8.0.0/24)"
echo "4. Password authentication is disabled - only SSH keys work"
echo "========================================="

# Create a secure package for the developer
PACKAGE_DIR="./ssh-keys/packages/${USERNAME}_access_package"
mkdir -p "$PACKAGE_DIR"

# Copy files to package
cp "$KEY_PATH" "$PACKAGE_DIR/staging_ssh_key"
cp "${KEY_PATH}.pub" "$PACKAGE_DIR/staging_ssh_key.pub"

# Create README for the developer
cat > "$PACKAGE_DIR/README.txt" << EOF
Staging Environment SSH Access Package for $USERNAME
=====================================================

This package contains your SSH credentials for accessing the staging environment.

Files included:
- staging_ssh_key: Your private SSH key (KEEP THIS SECURE!)
- staging_ssh_key.pub: Your public SSH key (already configured on server)
- README.txt: This file

SETUP INSTRUCTIONS:
==================

1. Set proper permissions on your SSH key:
   chmod 600 staging_ssh_key

2. Get the VPN configuration file from your administrator

3. Connect to VPN:
   sudo openvpn --config your-vpn-config.ovpn

4. SSH to staging server (while connected to VPN):
   ssh -i staging_ssh_key $USERNAME@10.0.0.2

   Or add to your SSH config (~/.ssh/config):
   
   Host staging
       HostName 10.0.0.2
       User $USERNAME
       IdentityFile ~/path/to/staging_ssh_key
       StrictHostKeyChecking no
   
   Then simply: ssh staging

IMPORTANT NOTES:
===============
- You MUST be connected to VPN to access staging
- The staging internal IP is typically 10.0.0.2
- Your username is: $USERNAME
- Password authentication is disabled
- Keep your private key secure!

For issues, contact your system administrator.
EOF

print_info "Access package created at: $PACKAGE_DIR"
print_info "You can zip and send this package to $USERNAME"

# Optional: Create a zip file
if command -v zip &> /dev/null; then
    cd "$PACKAGE_DIR/.."
    zip -r "${USERNAME}_access_package.zip" "${USERNAME}_access_package"
    cd - > /dev/null
    print_info "Zip file created: ${PACKAGE_DIR}.zip"
fi