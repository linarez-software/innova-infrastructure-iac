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

# Networking Module
module "networking" {
  source = "../../modules/networking"

  project_id  = var.project_id
  region      = var.region
  environment = local.environment

  # VPC Configuration from documentation
  vpc_name    = "staging-vpc"
  subnet_name = "staging-subnet"
  subnet_cidr = "10.0.0.0/24"

  # Static IP addresses as documented
  static_ips = {
    vpn_ip     = "staging-vpn-ip"
    app_ip     = "staging-app-ip"
    jenkins_ip = "staging-jenkins-ip" # Optional
  }
}

# VPN Module
module "vpn" {
  source = "../../modules/vpn"

  project_id  = var.project_id
  region      = var.region
  zone        = var.zone
  environment = local.environment

  # VPN Configuration from documentation
  instance_name         = "vpn-staging"
  machine_type          = "e2-micro"
  network_name          = module.networking.vpc_name
  subnet_name           = module.networking.subnet_name
  static_ip             = module.networking.vpn_static_ip
  service_account_email = module.security.vpn_service_account_email

  # VPN Network configuration
  vpn_subnet_cidr = "10.8.0.0/24"
  max_clients     = 5

  depends_on = [module.networking, module.security]
}

# Compute Module
module "compute" {
  source = "../../modules/compute"

  project_id  = var.project_id
  region      = var.region
  zone        = var.zone
  environment = local.environment

  # Network configuration
  network_name = module.networking.vpc_name
  subnet_name  = module.networking.subnet_name

  # Application Server Configuration from documentation
  app_instance_name = "app-staging"
  app_machine_type  = "e2-standard-2"
  app_disk_size     = 80 # Updated to 80GB as requested
  app_static_ip     = module.networking.app_static_ip

  # Jenkins Server Configuration (Optional)
  enable_jenkins        = var.enable_jenkins
  jenkins_instance_name = "jenkins-staging"
  jenkins_machine_type  = "e2-small"
  jenkins_disk_size     = 30
  jenkins_static_ip     = module.networking.jenkins_static_ip

  # Service Account
  service_account_email = module.security.app_service_account_email

  # Database configuration (on app server for staging)
  db_password = var.db_password

  depends_on = [module.networking, module.vpn, module.security]
}

# Security Module
module "security" {
  source = "../../modules/security"

  project_id  = var.project_id
  environment = local.environment
}