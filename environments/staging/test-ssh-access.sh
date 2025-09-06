#!/bin/bash
# Test SSH access to internal servers

echo "Testing SSH access to internal servers..."
echo "========================================"

# Test app server (10.0.0.3)
echo "1. Testing SSH to app server (10.0.0.3):"
echo "   Command: ssh -v elinarezv@10.0.0.3 'hostname && whoami' 2>&1 | head -20"
echo ""

# Test jenkins server (10.0.0.4)
echo "2. Testing SSH to jenkins server (10.0.0.4):"
echo "   Command: ssh -v elinarezv@10.0.0.4 'hostname && whoami' 2>&1 | head -20"
echo ""

echo "3. SSH Key Information:"
echo "   Your public key fingerprint should be:"
echo "   4096 SHA256:pIVY8YJ/mBjmD1TftqP5IWceEIkooreYh+43dvCDMJ8"
echo ""

echo "4. Troubleshooting steps if connection fails:"
echo "   a) Make sure you're connected to the VPN"
echo "   b) Check if your SSH agent has the right key loaded:"
echo "      ssh-add -l"
echo "   c) Try with explicit key file:"
echo "      ssh -i /path/to/your/private/key elinarezv@10.0.0.4"
echo "   d) Check SSH client verbose output:"
echo "      ssh -vv elinarezv@10.0.0.4"
echo ""

echo "5. Alternative access methods:"
echo "   gcloud compute ssh app-staging --zone=us-central1-a --internal-ip"
echo "   gcloud compute ssh jenkins-staging --zone=us-central1-a --internal-ip"
echo ""

# Check what keys are deployed on servers
echo "6. Verifying deployed keys on servers:"
echo ""
echo "App server key fingerprint:"
gcloud compute ssh app-staging --zone=us-central1-a --internal-ip --command="sudo ssh-keygen -l -f /home/elinarezv/.ssh/authorized_keys 2>/dev/null || echo 'Key not found'"

echo ""
echo "Jenkins server key fingerprint:"
gcloud compute ssh jenkins-staging --zone=us-central1-a --internal-ip --command="sudo ssh-keygen -l -f /home/elinarezv/.ssh/authorized_keys 2>/dev/null || echo 'Key not found'"

echo ""
echo "7. Testing gcloud SSH access:"
echo ""
echo "Testing gcloud SSH to app server:"
gcloud compute ssh app-staging --zone=us-central1-a --internal-ip --command="echo 'App server access: SUCCESS' && whoami" 2>/dev/null || echo "App server access: FAILED"

echo ""
echo "Testing gcloud SSH to jenkins server:"
gcloud compute ssh jenkins-staging --zone=us-central1-a --internal-ip --command="echo 'Jenkins server access: SUCCESS' && whoami" 2>/dev/null || echo "Jenkins server access: FAILED"