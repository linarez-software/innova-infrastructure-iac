# DNS Setup Guide for innovaeyewear.com

This guide explains how to configure DNS records for the innovaeyewear.com domain using Google Cloud DNS.

## DNS Architecture

All DNS records are managed through Terraform using Google Cloud DNS. The configuration creates the following DNS structure:

### Production DNS Records

| Record | Type | Points To | URL |
|--------|------|-----------|-----|
| innovaeyewear.com | A | app-production | https://innovaeyewear.com |
| www.innovaeyewear.com | CNAME | innovaeyewear.com | https://www.innovaeyewear.com |
| db.innovaeyewear.com | A | db-production | https://db.innovaeyewear.com |
| vpn.innovaeyewear.com | A | vpn-production | https://vpn.innovaeyewear.com |
| jenkins.innovaeyewear.com | A | jenkins-production | https://jenkins.innovaeyewear.com |

### Staging DNS Records

| Record | Type | Points To | URL |
|--------|------|-----------|-----|
| odoo.staging.innovaeyewear.com | A | app-staging | https://odoo.staging.innovaeyewear.com |
| vpn.staging.innovaeyewear.com | A | vpn-staging | https://vpn.staging.innovaeyewear.com |
| jenkins.staging.innovaeyewear.com | A | jenkins-staging | https://jenkins.staging.innovaeyewear.com |
| mailhog.staging.innovaeyewear.com | A | app-staging | http://mailhog.staging.innovaeyewear.com:8025 |
| pgadmin.staging.innovaeyewear.com | A | app-staging | http://pgadmin.staging.innovaeyewear.com:5050 |

## Setup Instructions

### Prerequisites

1. Domain must be registered (innovaeyewear.com)
2. Google Cloud DNS API must be enabled
3. DNS zone must exist or be created

### Step 1: Check if DNS Zone Exists

```bash
# Check if the zone already exists
gcloud dns managed-zones list --filter="dnsName:innovaeyewear.com"

# If it doesn't exist, you'll need to create it (see Step 2)
```

### Step 2: Create DNS Zone (if needed)

If the zone doesn't exist, either:

**Option A: Create via Terraform**
```hcl
# In terraform.tfvars
create_dns_zone = true
```

**Option B: Create manually**
```bash
gcloud dns managed-zones create innovaeyewear-zone \
  --dns-name="innovaeyewear.com." \
  --description="DNS zone for innovaeyewear.com"
```

### Step 3: Configure Terraform Variables

Edit `environments/production/terraform.tfvars`:

```hcl
# Enable DNS management
enable_dns      = true
dns_domain_name = "innovaeyewear.com"
dns_zone_name   = "innovaeyewear-zone"
create_dns_zone = false  # Set to true if zone doesn't exist
dns_ttl         = 300    # 5 minutes

# If managing all DNS from production, provide staging IPs
staging_app_ip     = "35.208.34.83"      # From staging outputs
staging_vpn_ip     = "35.208.230.78"     # From staging outputs
staging_jenkins_ip = "35.222.154.199"    # From staging outputs

# Optional: Add email records
mx_records = [
  "10 mail.innovaeyewear.com.",
  "20 mail2.innovaeyewear.com."
]

# Optional: Add TXT records for verification
txt_records = [
  "v=spf1 include:_spf.google.com ~all",
  "google-site-verification=YOUR_VERIFICATION_CODE"
]
```

### Step 4: Deploy DNS Configuration

```bash
# Deploy from production environment (recommended)
cd environments/production
terraform plan
terraform apply

# DNS records will be created automatically based on instance IPs
```

### Step 5: Update Domain Registrar

After creating the zone, update your domain registrar to use Google Cloud DNS name servers:

```bash
# Get the name servers
gcloud dns managed-zones describe innovaeyewear-zone \
  --format="value(nameServers)"

# Example output:
# ns-cloud-a1.googledomains.com.
# ns-cloud-a2.googledomains.com.
# ns-cloud-a3.googledomains.com.
# ns-cloud-a4.googledomains.com.
```

Update your domain registrar with these name servers.

### Step 6: Verify DNS Resolution

```bash
# Test DNS resolution (may take up to 48 hours to propagate)
nslookup innovaeyewear.com
nslookup www.innovaeyewear.com
nslookup odoo.staging.innovaeyewear.com
nslookup jenkins.innovaeyewear.com

# Or use dig for more details
dig innovaeyewear.com
dig odoo.staging.innovaeyewear.com
```

## SSL/TLS Configuration

After DNS is configured, update your instances to use SSL certificates:

### For Production
```bash
# SSH to production app server
gcloud compute ssh app-production --zone=us-central1-a

# Set up SSL with Let's Encrypt
sudo ./scripts/setup-ssl.sh -d innovaeyewear.com -e admin@innovaeyewear.com
sudo ./scripts/setup-ssl.sh -d www.innovaeyewear.com -e admin@innovaeyewear.com
```

### For Staging
```bash
# SSH to staging server
gcloud compute ssh app-staging --zone=us-central1-a

# Set up SSL for staging subdomain
sudo ./scripts/setup-ssl.sh -d odoo.staging.innovaeyewear.com -e admin@innovaeyewear.com
```

### For Jenkins
```bash
# Jenkins SSL is configured automatically if jenkins_domain is set
# In terraform.tfvars:
jenkins_domain = "jenkins.innovaeyewear.com"  # For production
# or
jenkins_domain = "jenkins.staging.innovaeyewear.com"  # For staging
```

## Managing DNS Records

### Add Custom DNS Records

To add additional DNS records, modify the DNS module or add them manually:

```bash
# Add a custom A record
gcloud dns record-sets create custom.innovaeyewear.com \
  --zone=innovaeyewear-zone \
  --type=A \
  --ttl=300 \
  --rrdatas=1.2.3.4

# Add a CNAME record
gcloud dns record-sets create alias.innovaeyewear.com \
  --zone=innovaeyewear-zone \
  --type=CNAME \
  --ttl=300 \
  --rrdatas=target.innovaeyewear.com.
```

### Update Existing Records

DNS records are automatically updated when instance IPs change:

```bash
# After infrastructure changes
terraform apply

# DNS records will be updated with new IPs automatically
```

### Remove DNS Records

To remove DNS management:

```bash
# Disable DNS in terraform.tfvars
enable_dns = false

# Apply changes
terraform apply
```

## DNS Management Strategy

### Recommended Approach

1. **Manage all DNS from production environment**
   - Set `enable_dns = true` in production
   - Set `enable_dns = false` in staging
   - Provide staging IPs as variables in production

2. **Benefits**:
   - Single source of truth for DNS
   - Avoid conflicts between environments
   - Easier management and updates

### Alternative: Separate DNS Management

If you prefer to manage DNS separately:

1. Create a dedicated DNS management directory
2. Use data sources to fetch instance IPs
3. Manage all DNS records independently

## Troubleshooting

### DNS Not Resolving

```bash
# Check zone status
gcloud dns managed-zones describe innovaeyewear-zone

# List all records
gcloud dns record-sets list --zone=innovaeyewear-zone

# Check specific record
gcloud dns record-sets describe innovaeyewear.com \
  --zone=innovaeyewear-zone \
  --type=A
```

### Wrong IP Address

```bash
# Check current IPs
gcloud compute instances list --format="table(name,EXTERNAL_IP)"

# Update terraform.tfvars with correct IPs
# Then apply
terraform apply
```

### SSL Certificate Issues

```bash
# Check certificate status
sudo certbot certificates

# Renew certificates
sudo certbot renew

# Force renewal
sudo certbot renew --force-renewal
```

## DNS Records Reference

### Required Records

- **A Records**: Direct domain to IP mappings
- **CNAME Records**: Aliases (www → root domain)

### Optional Records

- **MX Records**: Email routing
- **TXT Records**: Domain verification, SPF, DKIM
- **CAA Records**: Certificate authority authorization

## Monitoring DNS

### Check DNS Propagation

Use online tools to verify DNS propagation:
- https://www.whatsmydns.net/
- https://dnschecker.org/

### Monitor DNS Health

```bash
# Set up monitoring alert for DNS
gcloud alpha monitoring policies create \
  --notification-channels=YOUR_CHANNEL_ID \
  --display-name="DNS Health Check" \
  --condition="dns.query.response_time > 1000"
```

## Security Considerations

1. **DNSSEC**: Consider enabling DNSSEC for additional security
2. **CAA Records**: Add CAA records to restrict certificate issuance
3. **Rate Limiting**: Monitor and limit DNS queries if needed
4. **Access Control**: Restrict who can modify DNS records

## Cost Optimization

- Google Cloud DNS charges per zone and per million queries
- Current configuration: 1 zone + minimal queries
- Estimated cost: ~$0.20/month for zone + usage

## Important Notes

1. **DNS Propagation**: Changes can take up to 48 hours to propagate globally
2. **TTL**: Lower TTL (300s) allows faster updates but increases queries
3. **Name Servers**: Must be updated at domain registrar
4. **Backup**: Keep a record of DNS configuration outside of Terraform
5. **Testing**: Always test DNS changes in staging first if possible