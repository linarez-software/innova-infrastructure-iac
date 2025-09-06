#!/bin/bash
# Generate VPN client configuration for staging

set -e

# Configuration
SERVICE_ACCOUNT_KEY_PATH="./terraform-vpn-manager.json"
PROJECT_ID="${1:-deep-wares-246918}"
ZONE="${2:-us-central1-a}"
USERNAME="${3:-admin}"
VPN_INSTANCE="vpn-staging"

echo "Generating VPN client configuration for user: ${USERNAME}"
echo "Project: ${PROJECT_ID}"
echo "Zone: ${ZONE}"

# SSH to VPN server and generate client config
echo "Connecting to VPN server to generate client certificate..."
gcloud auth activate-service-account --key-file=${SERVICE_ACCOUNT_KEY_PATH}
gcloud config set project ${PROJECT_ID}

gcloud compute ssh admin@${VPN_INSTANCE} --zone=${ZONE} --project=${PROJECT_ID} --command="sudo /opt/scripts/manage-vpn-users.sh add ${USERNAME}" 2>/dev/null || {
    echo "Waiting for VPN server to be ready..."
    sleep 30
    gcloud compute ssh admin@${VPN_INSTANCE} --zone=${ZONE} --project=${PROJECT_ID} --command="sudo /opt/scripts/manage-vpn-users.sh add ${USERNAME}"
}

# Download the configuration
echo ""
echo "Downloading VPN configuration..."
gcloud compute scp admin@${VPN_INSTANCE}:/opt/vpn-configs/${USERNAME}.ovpn ./${USERNAME}-staging.ovpn --zone=${ZONE} --project=${PROJECT_ID} 2>/dev/null || {
    echo "Config might not exist yet. Trying to retrieve from GCS bucket..."
    gsutil -o "GoogleAccessId=$(jq -r .client_email ${SERVICE_ACCOUNT_KEY_PATH})" -o "GoogleAccessSecret=$(jq -r .private_key ${SERVICE_ACCOUNT_KEY_PATH})" cp gs://${PROJECT_ID}-staging-vpn-configs/${USERNAME}.ovpn ./${USERNAME}-staging.ovpn 2>/dev/null || {
        echo "Unable to download config. Manual retrieval required."
        echo "Try: gcloud compute scp admin@${VPN_INSTANCE}:/opt/vpn-configs/${USERNAME}.ovpn . --zone=${ZONE}"
    }
}

# Get server IPs
VPN_IP=$(gcloud compute instances describe ${VPN_INSTANCE} --zone=${ZONE} --project=${PROJECT_ID} --format='value(networkInterfaces[0].accessConfigs[0].natIP)')
APP_IP=$(gcloud compute instances describe app-staging --zone=${ZONE} --project=${PROJECT_ID} --format='value(networkInterfaces[0].networkIP)')

echo ""
echo "========================================="
echo "VPN Configuration Complete!"
echo "========================================="
echo ""
echo "VPN Server IP: ${VPN_IP}"
echo "Staging App Server Internal IP: ${APP_IP}"
echo ""
echo "Configuration file: ${USERNAME}-staging.ovpn"
echo ""
echo "To connect to VPN:"
echo "1. Install OpenVPN client on your machine"
echo "2. Import the ${USERNAME}-staging.ovpn file"
echo "3. Connect to the VPN"
echo ""
echo "After connecting to VPN, you can access:"
echo "  - SSH to staging: ssh user@${APP_IP}"
echo "  - Web services: http://${APP_IP}"
echo "  - PostgreSQL: psql -h ${APP_IP} -U postgres"
echo "  - Development tools:"
echo "    - Mailhog: http://${APP_IP}:8025"
echo "    - pgAdmin: http://${APP_IP}:5050"
echo ""
echo "Test connectivity:"
echo "  ping ${APP_IP}"