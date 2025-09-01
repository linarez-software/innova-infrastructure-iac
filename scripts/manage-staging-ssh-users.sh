#!/bin/bash
# Script to manage SSH users on staging machine for developers without GCP access
# This script should be run locally and will configure SSH access through VPN

set -e

# Configuration
PROJECT_ID="${PROJECT_ID:-deep-wares-246918}"
ZONE="${ZONE:-us-central1-a}"
INSTANCE_NAME="app-staging"
VPN_SUBNET="10.8.0.0/24"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Function to display usage
usage() {
    cat << EOF
Usage: $0 <action> <username> [options]

Actions:
    add <username>              Add a new SSH user
    remove <username>           Remove an SSH user
    list                        List all SSH users
    generate-key <username>     Generate SSH key pair for a user
    test <username>             Test SSH connection for a user

Options:
    -k, --key-file <path>       Path to public SSH key file (for 'add' action)
    -g, --generate              Generate SSH key pair if not provided (for 'add' action)
    -h, --help                  Show this help message

Examples:
    $0 add john.doe -g                    # Add user and generate SSH key
    $0 add jane.doe -k ~/.ssh/jane.pub    # Add user with existing key
    $0 remove john.doe                    # Remove user
    $0 list                                # List all users
    $0 test john.doe                      # Test SSH connection

Prerequisites:
    1. User must be connected to VPN (10.8.0.0/24 subnet)
    2. Script executor must have gcloud access to manage the instance
    3. Developers will need their private key and VPN connection to SSH

EOF
    exit 1
}

# Function to check if user has gcloud access
check_gcloud_access() {
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI is not installed"
        exit 1
    fi
    
    if ! gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" &> /dev/null; then
        print_error "Cannot access instance $INSTANCE_NAME. Check your gcloud credentials."
        exit 1
    fi
}

# Function to generate SSH key pair
generate_ssh_key() {
    local username=$1
    local key_dir="./ssh-keys"
    local key_path="$key_dir/${username}_staging"
    
    mkdir -p "$key_dir"
    
    if [ -f "$key_path" ]; then
        print_warning "SSH key already exists for $username at $key_path"
        read -p "Overwrite? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    print_info "Generating SSH key pair for $username..."
    ssh-keygen -t ed25519 -f "$key_path" -C "${username}@staging" -N ""
    
    print_info "SSH key pair generated:"
    echo "  Private key: $key_path"
    echo "  Public key: ${key_path}.pub"
    
    echo "$key_path"
}

# Function to add SSH user
add_ssh_user() {
    local username=$1
    local public_key_file=$2
    local generate_key=$3
    
    # Validate username
    if [[ ! "$username" =~ ^[a-z][-a-z0-9]*$ ]]; then
        print_error "Invalid username. Use lowercase letters, numbers, and hyphens only."
        exit 1
    fi
    
    # Handle SSH key
    if [ "$generate_key" = true ]; then
        key_path=$(generate_ssh_key "$username")
        if [ $? -ne 0 ]; then
            print_error "Failed to generate SSH key"
            exit 1
        fi
        public_key_file="${key_path}.pub"
    fi
    
    if [ ! -f "$public_key_file" ]; then
        print_error "Public key file not found: $public_key_file"
        exit 1
    fi
    
    # Read the public key
    public_key=$(cat "$public_key_file")
    
    print_info "Adding SSH user $username to staging instance..."
    
    # Create the user and add SSH key using gcloud SSH
    gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" --command="
        set -e
        
        # Create user if doesn't exist
        if ! id -u $username >/dev/null 2>&1; then
            echo 'Creating user $username...'
            sudo useradd -m -s /bin/bash $username
            sudo usermod -aG sudo $username
            echo 'User created successfully'
        else
            echo 'User $username already exists'
        fi
        
        # Set up SSH directory
        sudo mkdir -p /home/$username/.ssh
        sudo chmod 700 /home/$username/.ssh
        
        # Add the SSH key
        echo '$public_key' | sudo tee /home/$username/.ssh/authorized_keys > /dev/null
        sudo chmod 600 /home/$username/.ssh/authorized_keys
        sudo chown -R $username:$username /home/$username/.ssh
        
        echo 'SSH key added successfully'
        
        # Set a random password (user will use SSH key, not password)
        password=\$(openssl rand -base64 12)
        echo \"$username:\$password\" | sudo chpasswd
        
        echo 'User configuration completed'
    " 2>/dev/null || {
        print_error "Failed to add user to instance"
        exit 1
    }
    
    # Get instance IP
    INSTANCE_IP=$(gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" --format="get(networkInterfaces[0].networkIP)")
    
    print_info "✅ User $username added successfully!"
    echo
    echo "========================================="
    echo "SSH Access Information for $username"
    echo "========================================="
    echo "1. First, connect to VPN using the provided .ovpn file"
    echo "2. Then SSH to staging using:"
    echo "   ssh $username@$INSTANCE_IP"
    echo
    if [ "$generate_key" = true ]; then
        echo "3. Private key location: $key_path"
        echo "   Share this private key securely with $username"
        echo
        echo "Example SSH command:"
        echo "   ssh -i $key_path $username@$INSTANCE_IP"
    else
        echo "3. Use the private key corresponding to: $public_key_file"
    fi
    echo "========================================="
}

# Function to remove SSH user
remove_ssh_user() {
    local username=$1
    
    print_info "Removing SSH user $username from staging instance..."
    
    gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" --command="
        set -e
        
        if id -u $username >/dev/null 2>&1; then
            # Kill user processes
            sudo pkill -u $username || true
            
            # Remove user
            sudo userdel -r $username
            echo 'User $username removed successfully'
        else
            echo 'User $username does not exist'
        fi
    " 2>/dev/null || {
        print_error "Failed to remove user from instance"
        exit 1
    }
    
    print_info "✅ User $username removed successfully!"
}

# Function to list SSH users
list_ssh_users() {
    print_info "Listing SSH users on staging instance..."
    
    gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" --command="
        echo '===== System Users with SSH Access ====='
        echo
        for user in \$(ls /home); do
            if [ -f /home/\$user/.ssh/authorized_keys ]; then
                echo \"User: \$user\"
                echo \"  SSH Keys: \$(wc -l < /home/\$user/.ssh/authorized_keys) key(s)\"
                echo \"  Last login: \$(lastlog -u \$user | tail -1 | awk '{\$1=\"\"; print \$0}')\"
                echo
            fi
        done
        echo '===== Instance Information ====='
        echo \"Internal IP: \$(hostname -I | awk '{print \$1}')\"
        echo \"Hostname: \$(hostname)\"
    " 2>/dev/null || {
        print_error "Failed to list users"
        exit 1
    }
}

# Function to test SSH connection
test_ssh_connection() {
    local username=$1
    local key_path="./ssh-keys/${username}_staging"
    
    INSTANCE_IP=$(gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" --format="get(networkInterfaces[0].networkIP)")
    
    print_info "Testing SSH connection for $username..."
    echo "Instance IP: $INSTANCE_IP"
    echo
    
    # Check if we're on VPN
    if ! ip route | grep -q "10.8.0.0"; then
        print_warning "You don't appear to be connected to VPN (10.8.0.0/24)"
        echo "Please connect to VPN first using: sudo openvpn --config your-vpn-config.ovpn"
    fi
    
    # Try to find the private key
    if [ ! -f "$key_path" ]; then
        print_warning "Default key path not found: $key_path"
        read -p "Enter path to private key: " key_path
    fi
    
    if [ ! -f "$key_path" ]; then
        print_error "Private key not found: $key_path"
        exit 1
    fi
    
    print_info "Attempting SSH connection..."
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -i "$key_path" "$username@$INSTANCE_IP" "echo '✅ SSH connection successful!'; hostname; whoami; date"
}

# Main script logic
main() {
    # Check for help flag
    if [ "$1" = "-h" ] || [ "$1" = "--help" ] || [ $# -eq 0 ]; then
        usage
    fi
    
    # Check gcloud access
    check_gcloud_access
    
    ACTION=$1
    shift
    
    case $ACTION in
        add)
            USERNAME=$1
            shift
            [ -z "$USERNAME" ] && usage
            
            GENERATE_KEY=false
            PUBLIC_KEY_FILE=""
            
            while [[ $# -gt 0 ]]; do
                case $1 in
                    -k|--key-file)
                        PUBLIC_KEY_FILE="$2"
                        shift 2
                        ;;
                    -g|--generate)
                        GENERATE_KEY=true
                        shift
                        ;;
                    *)
                        print_error "Unknown option: $1"
                        usage
                        ;;
                esac
            done
            
            if [ "$GENERATE_KEY" = false ] && [ -z "$PUBLIC_KEY_FILE" ]; then
                print_error "You must provide a public key file (-k) or generate one (-g)"
                usage
            fi
            
            add_ssh_user "$USERNAME" "$PUBLIC_KEY_FILE" "$GENERATE_KEY"
            ;;
            
        remove)
            USERNAME=$1
            [ -z "$USERNAME" ] && usage
            remove_ssh_user "$USERNAME"
            ;;
            
        list)
            list_ssh_users
            ;;
            
        generate-key)
            USERNAME=$1
            [ -z "$USERNAME" ] && usage
            generate_ssh_key "$USERNAME"
            ;;
            
        test)
            USERNAME=$1
            [ -z "$USERNAME" ] && usage
            test_ssh_connection "$USERNAME"
            ;;
            
        *)
            print_error "Unknown action: $ACTION"
            usage
            ;;
    esac
}

# Run main function
main "$@"