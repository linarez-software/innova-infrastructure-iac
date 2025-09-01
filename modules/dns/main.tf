terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# Create or reference the DNS managed zone
data "google_dns_managed_zone" "main" {
  count = var.create_zone ? 0 : 1
  name  = var.zone_name
}

resource "google_dns_managed_zone" "main" {
  count       = var.create_zone ? 1 : 0
  name        = var.zone_name
  dns_name    = "${var.domain_name}."
  description = "DNS zone for ${var.domain_name}"
  
  labels = var.labels
  
  project = var.project_id
}

locals {
  managed_zone_name = var.create_zone ? google_dns_managed_zone.main[0].name : data.google_dns_managed_zone.main[0].name
}

# Production Records

# Root domain A record pointing to app-production
resource "google_dns_record_set" "root" {
  name         = "${var.domain_name}."
  type         = "A"
  ttl          = var.ttl
  managed_zone = local.managed_zone_name
  rrdatas      = [var.app_production_ip]
  
  project = var.project_id
}

# www CNAME pointing to root domain
resource "google_dns_record_set" "www" {
  name         = "www.${var.domain_name}."
  type         = "CNAME"
  ttl          = var.ttl
  managed_zone = local.managed_zone_name
  rrdatas      = ["${var.domain_name}."]
  
  project = var.project_id
}

# Database subdomain pointing to db-production
resource "google_dns_record_set" "db_production" {
  count        = var.db_production_ip != "" ? 1 : 0
  name         = "db.${var.domain_name}."
  type         = "A"
  ttl          = var.ttl
  managed_zone = local.managed_zone_name
  rrdatas      = [var.db_production_ip]
  
  project = var.project_id
}

# VPN production subdomain
resource "google_dns_record_set" "vpn_production" {
  name         = "vpn.${var.domain_name}."
  type         = "A"
  ttl          = var.ttl
  managed_zone = local.managed_zone_name
  rrdatas      = [var.vpn_production_ip]
  
  project = var.project_id
}

# Jenkins production subdomain
resource "google_dns_record_set" "jenkins_production" {
  count        = var.jenkins_production_ip != "" ? 1 : 0
  name         = "jenkins.${var.domain_name}."
  type         = "A"
  ttl          = var.ttl
  managed_zone = local.managed_zone_name
  rrdatas      = [var.jenkins_production_ip]
  
  project = var.project_id
}

# Staging Records

# Odoo staging subdomain pointing to app-staging
resource "google_dns_record_set" "odoo_staging" {
  name         = "odoo.staging.${var.domain_name}."
  type         = "A"
  ttl          = var.ttl
  managed_zone = local.managed_zone_name
  rrdatas      = [var.app_staging_ip]
  
  project = var.project_id
}

# VPN staging subdomain
resource "google_dns_record_set" "vpn_staging" {
  name         = "vpn.staging.${var.domain_name}."
  type         = "A"
  ttl          = var.ttl
  managed_zone = local.managed_zone_name
  rrdatas      = [var.vpn_staging_ip]
  
  project = var.project_id
}

# Jenkins staging subdomain
resource "google_dns_record_set" "jenkins_staging" {
  count        = var.jenkins_staging_ip != "" ? 1 : 0
  name         = "jenkins.staging.${var.domain_name}."
  type         = "A"
  ttl          = var.ttl
  managed_zone = local.managed_zone_name
  rrdatas      = [var.jenkins_staging_ip]
  
  project = var.project_id
}

# Additional staging subdomains for development tools
resource "google_dns_record_set" "mailhog_staging" {
  count        = var.enable_dev_tools_dns ? 1 : 0
  name         = "mailhog.staging.${var.domain_name}."
  type         = "A"
  ttl          = var.ttl
  managed_zone = local.managed_zone_name
  rrdatas      = [var.app_staging_ip]
  
  project = var.project_id
}

resource "google_dns_record_set" "pgadmin_staging" {
  count        = var.enable_dev_tools_dns ? 1 : 0
  name         = "pgadmin.staging.${var.domain_name}."
  type         = "A"
  ttl          = var.ttl
  managed_zone = local.managed_zone_name
  rrdatas      = [var.app_staging_ip]
  
  project = var.project_id
}

# MX Records (if needed for email)
resource "google_dns_record_set" "mx" {
  count        = length(var.mx_records) > 0 ? 1 : 0
  name         = "${var.domain_name}."
  type         = "MX"
  ttl          = var.ttl
  managed_zone = local.managed_zone_name
  rrdatas      = var.mx_records
  
  project = var.project_id
}

# TXT Records (for domain verification, SPF, etc.)
resource "google_dns_record_set" "txt" {
  count        = length(var.txt_records) > 0 ? 1 : 0
  name         = "${var.domain_name}."
  type         = "TXT"
  ttl          = var.ttl
  managed_zone = local.managed_zone_name
  rrdatas      = var.txt_records
  
  project = var.project_id
}