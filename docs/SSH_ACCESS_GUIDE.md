# SSH Access Guide for Staging Environment

This guide explains how to set up and manage SSH access to the staging environment for developers who don't have Google Cloud Platform access.

## Overview

The staging environment is configured with:
- **SSH access restricted to VPN connections only** (10.8.0.0/24 subnet)
- **Traditional SSH key authentication** (OS Login disabled for staging)
- **User management through Terraform** (persistent across destroy/apply cycles)
- **No password authentication** (SSH keys only)

## Architecture

```
Developer Machine → VPN Connection → Staging Server (10.0.0.2)
                     (10.8.0.0/24)      (SSH Port 22)
```

## For Administrators

### 1. Generate SSH Keys for Developers

Use the provided script to generate SSH key pairs for each developer:

```bash
# Generate SSH key for a developer
./scripts/generate-developer-ssh-key.sh john.doe

# This will create:
# - Private key: ./ssh-keys/developers/john.doe_staging
# - Public key: ./ssh-keys/developers/john.doe_staging.pub
# - Access package: ./ssh-keys/packages/john.doe_access_package/
```

### 2. Add Developer to Terraform Configuration

Edit `environments/staging/terraform.tfvars` and add the developer's SSH key:

```hcl
staging_ssh_users = [
  {
    username = "john.doe"
    ssh_key  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG... john.doe@staging"
  },
  {
    username = "jane.smith"
    ssh_key  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH... jane.smith@staging"
  }
]
```

### 3. Apply Terraform Changes

```bash
cd environments/staging
terraform plan
terraform apply
```

This will:
- Create user accounts on the staging server
- Configure SSH keys
- Set up proper permissions
- Apply firewall rules (SSH from VPN only)

### 4. Share Access Credentials

Provide each developer with:
1. Their private SSH key (`./ssh-keys/developers/USERNAME_staging`)
2. VPN configuration file (`scripts/*-vpn-config.ovpn`)
3. Access instructions (see "For Developers" section)

## For Developers

### Prerequisites

1. **OpenVPN client** installed on your machine
2. **SSH client** (built-in on Mac/Linux, use PuTTY on Windows)
3. **Access package** from your administrator containing:
   - Private SSH key
   - VPN configuration file

### Setup Instructions

#### 1. Set Up SSH Key

```bash
# Create SSH directory if it doesn't exist
mkdir -p ~/.ssh

# Copy your private key
cp staging_ssh_key ~/.ssh/staging_key
chmod 600 ~/.ssh/staging_key
```

#### 2. Configure SSH (Optional but Recommended)

Add to `~/.ssh/config`:

```
Host staging
    HostName 10.0.0.2
    User YOUR_USERNAME
    IdentityFile ~/.ssh/staging_key
    StrictHostKeyChecking no
```

#### 3. Connect to VPN

```bash
# Connect to VPN (keep this running)
sudo openvpn --config your-vpn-config.ovpn

# You should see "Initialization Sequence Completed"
# Your machine will now have access to 10.8.0.0/24 subnet
```

#### 4. SSH to Staging

```bash
# Using full command
ssh -i ~/.ssh/staging_key YOUR_USERNAME@10.0.0.2

# Or if you configured SSH config
ssh staging
```

### Common Commands

Once connected to staging:

```bash
# Check running services
sudo systemctl status nginx
sudo systemctl status postgresql
docker ps

# View application logs
tail -f /var/log/startup-script.log

# Access development tools
curl http://localhost/dev-tools

# Database access
sudo -u postgres psql -d appdb
```

## Firewall Rules

The staging environment enforces these SSH access rules:

| Rule | Source | Port | Description |
|------|--------|------|-------------|
| Allow SSH | 10.8.0.0/24 (VPN) | 22 | SSH access only from VPN subnet |
| Deny SSH | 0.0.0.0/0 (Internet) | 22 | No direct internet SSH access |

## Security Notes

1. **VPN Required**: SSH access is only possible when connected to VPN
2. **Key-Only Authentication**: Password authentication is disabled
3. **User Isolation**: Each developer has their own user account
4. **Audit Trail**: All SSH sessions are logged
5. **Terraform Managed**: Users are managed through code, not manually

## Troubleshooting

### Cannot Connect to VPN

```bash
# Check VPN connection
ip route | grep 10.8
# Should show: 10.8.0.0/24 via ...

# Test VPN connectivity
ping 10.8.0.1
```

### SSH Connection Refused

```bash
# Verify you're on VPN
ip addr show | grep 10.8

# Check if you can reach the server
ping 10.0.0.2

# Verify SSH key permissions
ls -la ~/.ssh/staging_key
# Should show: -rw------- (600)
```

### Permission Denied

```bash
# Ensure you're using the correct username
ssh -v -i ~/.ssh/staging_key YOUR_USERNAME@10.0.0.2

# Check if your user exists on the server (ask admin to verify)
```

### Lost SSH Key

Contact your administrator to generate a new key pair and update Terraform configuration.

## Managing Users (Admin Only)

### Add a New Developer

```bash
# 1. Generate SSH key
./scripts/generate-developer-ssh-key.sh new.developer

# 2. Add to terraform.tfvars
# 3. Run terraform apply
```

### Remove a Developer

```bash
# 1. Remove from staging_ssh_users in terraform.tfvars
# 2. Run terraform apply
# The user will be removed on next startup script execution
```

### Update SSH Key

```bash
# 1. Generate new key
./scripts/generate-developer-ssh-key.sh existing.developer

# 2. Update the ssh_key in terraform.tfvars
# 3. Run terraform apply
```

## Best Practices

1. **Regular Key Rotation**: Rotate SSH keys every 3-6 months
2. **Unique Keys**: Each developer should have their own unique key
3. **Secure Storage**: Store private keys securely (use password managers)
4. **VPN Hygiene**: Disconnect from VPN when not in use
5. **Access Reviews**: Regularly review and remove inactive users

## Infrastructure Code

All SSH user management is handled through Terraform:

- **Configuration**: `environments/staging/terraform.tfvars`
- **Variable Definition**: `variables.tf` → `staging_ssh_users`
- **Implementation**: `modules/compute/templates/staging-startup.sh`
- **Firewall Rules**: `modules/networking/main.tf`

Changes to SSH users require:
```bash
cd environments/staging
terraform plan   # Review changes
terraform apply  # Apply changes
```

## Support

For issues or questions:
1. Check this guide's troubleshooting section
2. Verify VPN and SSH key configuration
3. Contact your system administrator
4. Review Terraform logs if changes don't apply