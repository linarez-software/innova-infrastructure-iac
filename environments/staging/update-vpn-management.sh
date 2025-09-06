#!/bin/bash
# Deploy updated VPN management script to staging server

PROJECT_ID="deep-wares-246918"
ZONE="us-central1-a"
VPN_INSTANCE="vpn-staging"

echo "Deploying updated VPN management script..."

# Create the updated script content
cat > /tmp/manage-vpn-users.sh <<'SCRIPT_EOF'
#!/bin/bash
# VPN User Management Script with SSH Key Integration

ACTION="$1"
USERNAME="$2"
SSH_KEY="$3"

# Function to add SSH key to authorized_keys for a user
add_ssh_key() {
    local user="$1"
    local ssh_key="$2"
    
    if [ -n "$ssh_key" ]; then
        # Create user if doesn't exist
        if ! id "$user" &>/dev/null; then
            echo "Creating system user: $user"
            useradd -m -s /bin/bash "$user"
        fi
        
        # Create .ssh directory
        mkdir -p /home/$user/.ssh
        chmod 700 /home/$user/.ssh
        
        # Add SSH key to authorized_keys
        echo "$ssh_key" >> /home/$user/.ssh/authorized_keys
        chmod 600 /home/$user/.ssh/authorized_keys
        chown -R $user:$user /home/$user/.ssh
        
        echo "SSH key added for user: $user"
    else
        echo "No SSH key provided for user: $user"
    fi
}

case "$ACTION" in
    "add")
        if [ -z "$USERNAME" ]; then
            echo "Usage: $0 add <username> [ssh_public_key]"
            echo "Example: $0 add john 'ssh-rsa AAAAB3NzaC1yc2E...'"
            exit 1
        fi
        echo "Adding VPN user: $USERNAME"
        
        # Add SSH key if provided
        if [ -n "$SSH_KEY" ]; then
            add_ssh_key "$USERNAME" "$SSH_KEY"
        fi
        
        # Generate VPN configuration
        /opt/scripts/generate-client-config.sh "$USERNAME"
        
        echo "User $USERNAME added successfully"
        echo "  VPN config: /opt/vpn-configs/$USERNAME.ovpn"
        if [ -n "$SSH_KEY" ]; then
            echo "  SSH access: ssh $USERNAME@<server-ip>"
        fi
        ;;
    "add-ssh-key")
        if [ -z "$USERNAME" ] || [ -z "$SSH_KEY" ]; then
            echo "Usage: $0 add-ssh-key <username> <ssh_public_key>"
            echo "Example: $0 add-ssh-key john 'ssh-rsa AAAAB3NzaC1yc2E...'"
            exit 1
        fi
        echo "Adding SSH key for existing user: $USERNAME"
        add_ssh_key "$USERNAME" "$SSH_KEY"
        ;;
    "revoke")
        if [ -z "$USERNAME" ]; then
            echo "Usage: $0 revoke <username>"
            exit 1
        fi
        echo "Revoking VPN user: $USERNAME"
        
        # Revoke VPN certificate
        cd /etc/openvpn/easy-rsa
        ./easyrsa revoke "$USERNAME"
        ./easyrsa gen-crl
        
        # Remove SSH access (optional - comment out if you want to keep SSH access)
        if id "$USERNAME" &>/dev/null; then
            echo "Removing SSH access for user: $USERNAME"
            rm -f /home/$USERNAME/.ssh/authorized_keys
            # Optionally delete the user entirely: userdel -r "$USERNAME"
        fi
        
        # Remove VPN config
        rm -f /opt/vpn-configs/$USERNAME.ovpn
        
        systemctl restart openvpn@server
        echo "User $USERNAME revoked and OpenVPN restarted"
        ;;
    "list")
        echo "Active VPN connections:"
        if [ -f /var/log/openvpn/status.log ]; then
            cat /var/log/openvpn/status.log | grep "CLIENT_LIST" | awk '{printf "  %-15s %-15s %s\n", $2, $3, $4}'
        else
            echo "  No active connections or status file not found"
        fi
        
        echo ""
        echo "System users with SSH access:"
        ls -1 /home/ 2>/dev/null | grep -v lost+found | while read user; do
            if [ -f "/home/$user/.ssh/authorized_keys" ]; then
                echo "  $user (SSH enabled)"
            else
                echo "  $user"
            fi
        done
        ;;
    "list-users")
        echo "VPN Certificate Users:"
        ls -1 /etc/openvpn/easy-rsa/pki/issued/ 2>/dev/null | grep -v server.crt | sed 's/.crt$//' | sed 's/^/  /'
        
        echo ""
        echo "SSH Users:"
        ls -1 /home/ 2>/dev/null | grep -v lost+found | while read user; do
            if [ -f "/home/$user/.ssh/authorized_keys" ]; then
                key_count=$(wc -l < "/home/$user/.ssh/authorized_keys")
                echo "  $user ($key_count SSH key(s))"
            fi
        done
        ;;
    "status")
        systemctl status openvpn@server --no-pager
        ;;
    *)
        echo "Usage: $0 {add|add-ssh-key|revoke|list|list-users|status} [username] [ssh_key]"
        echo ""
        echo "Commands:"
        echo "  add <username> [ssh_key]     - Add new VPN user with optional SSH key"
        echo "  add-ssh-key <username> <key> - Add SSH key to existing user"
        echo "  revoke <username>            - Revoke VPN and SSH access"
        echo "  list                         - List active VPN connections and SSH users"
        echo "  list-users                   - List all VPN and SSH users"
        echo "  status                       - Show OpenVPN service status"
        echo ""
        echo "Examples:"
        echo "  $0 add john"
        echo "  $0 add john 'ssh-rsa AAAAB3NzaC1yc2E...'"
        echo "  $0 add-ssh-key john 'ssh-rsa AAAAB3NzaC1yc2E...'"
        echo "  $0 revoke john"
        exit 1
        ;;
esac
SCRIPT_EOF

# Upload the script to the VPN server
echo "Uploading updated script to VPN server..."
gcloud compute scp /tmp/manage-vpn-users.sh $VPN_INSTANCE:/tmp/manage-vpn-users.sh --zone=$ZONE --project=$PROJECT_ID

# Install the script on the VPN server
echo "Installing script on VPN server..."
gcloud compute ssh $VPN_INSTANCE --zone=$ZONE --project=$PROJECT_ID --command="sudo cp /tmp/manage-vpn-users.sh /opt/scripts/manage-vpn-users.sh && sudo chmod +x /opt/scripts/manage-vpn-users.sh && sudo rm /tmp/manage-vpn-users.sh"

echo "Updated VPN management script deployed successfully!"
echo ""
echo "You can now use the enhanced commands:"
echo "  sudo /opt/scripts/manage-vpn-users.sh add-ssh-key elinarezv 'your-ssh-key'"
echo "  sudo /opt/scripts/manage-vpn-users.sh list-users"

# Clean up local temp file
rm /tmp/manage-vpn-users.sh