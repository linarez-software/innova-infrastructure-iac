terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "deep-wares-246918-terraform-state"
    prefix = "terraform/staging"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

locals {
  environment = "staging"
}

module "staging_infrastructure" {
  source = "../../"

  project_id                   = var.project_id
  region                       = var.region
  zone                         = var.zone
  environment                  = local.environment
  staging_instance_type        = var.staging_instance_type
  production_app_instance_type = "e2-standard-2"
  production_db_instance_type  = "e2-standard-2"
  allowed_ssh_ips              = var.allowed_ssh_ips
  domain_name                  = var.domain_name
  ssl_email                    = var.ssl_email
  db_password                  = var.db_password
  enable_monitoring            = var.enable_monitoring
  enable_backups               = var.enable_backups
  backup_retention_days        = 7
  postgresql_version           = var.postgresql_version

  labels = merge(
    var.labels,
    {
      environment = local.environment
      cost_center = "development"
    }
  )
}