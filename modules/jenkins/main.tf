terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

locals {
  jenkins_instance_name = "${var.project_name}-${var.environment}-jenkins"
  jenkins_disk_name     = "${var.project_name}-${var.environment}-jenkins-disk"
}

# Jenkins VM instance
resource "google_compute_instance" "jenkins" {
  name         = local.jenkins_instance_name
  machine_type = var.jenkins_instance_type
  zone         = var.zone

  allow_stopping_for_update = true

  labels = merge(
    var.labels,
    {
      role = "jenkins"
      type = "ci-cd"
    }
  )

  tags = [
    "jenkins-server",
    "allow-vpn-ssh",
    "allow-jenkins-web"
  ]

  boot_disk {
    initialize_params {
      image = var.jenkins_image
      size  = 50
      type  = "pd-standard"
    }
  }

  # Additional persistent disk for Jenkins data
  attached_disk {
    source      = google_compute_disk.jenkins_data.self_link
    device_name = "jenkins-data"
  }

  network_interface {
    network    = var.network_id
    subnetwork = var.subnet_id

    # Internal IP only - access via VPN
    access_config {}
  }

  service_account {
    email = var.jenkins_service_account_email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/compute",
      "https://www.googleapis.com/auth/devstorage.read_write",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write"
    ]
  }

  metadata = {
    ssh-keys = "jenkins:${var.jenkins_ssh_public_key}"
  }

  metadata_startup_script = templatefile("${path.module}/templates/jenkins-startup.sh", {
    project_id                = var.project_id
    environment               = var.environment
    jenkins_admin_user        = var.jenkins_admin_user
    jenkins_admin_password    = var.jenkins_admin_password
    jenkins_domain            = var.jenkins_domain
    ssl_email                 = var.ssl_email
    github_token_secret       = var.github_token_secret
    docker_registry_secret    = var.docker_registry_secret
    staging_deploy_key_secret = var.staging_deploy_key_secret
    prod_deploy_key_secret    = var.prod_deploy_key_secret
  })
}

# Persistent disk for Jenkins data
resource "google_compute_disk" "jenkins_data" {
  name = local.jenkins_disk_name
  type = "pd-ssd"
  zone = var.zone
  size = var.jenkins_data_disk_size

  labels = merge(
    var.labels,
    {
      role = "jenkins-data"
      type = "persistent-storage"
    }
  )
}

# Static internal IP reservation for Jenkins
resource "google_compute_address" "jenkins_internal" {
  name         = "${local.jenkins_instance_name}-internal-ip"
  subnetwork   = var.subnet_id
  address_type = "INTERNAL"
  region       = var.region

  labels = var.labels
}

# Health check for Jenkins
resource "google_compute_health_check" "jenkins" {
  name = "${local.jenkins_instance_name}-health-check"

  timeout_sec        = 10
  check_interval_sec = 30

  http_health_check {
    port         = "8080"
    request_path = "/login"
  }
}

# Firewall rule for Jenkins web interface (VPN access only)
resource "google_compute_firewall" "jenkins_web" {
  name    = "${var.project_name}-${var.environment}-allow-jenkins-web"
  network = var.network_id

  allow {
    protocol = "tcp"
    ports    = ["8080", "443", "80"]
  }

  source_ranges = [var.vpn_subnet_cidr]
  target_tags   = ["allow-jenkins-web"]

  description = "Allow Jenkins web interface access from VPN subnet only"
}

# Firewall rule for Jenkins agent connections
resource "google_compute_firewall" "jenkins_agent" {
  name    = "${var.project_name}-${var.environment}-allow-jenkins-agent"
  network = var.network_id

  allow {
    protocol = "tcp"
    ports    = ["50000"]
  }

  source_ranges = [var.subnet_cidr, var.vpn_subnet_cidr]
  target_tags   = ["jenkins-server"]

  description = "Allow Jenkins agent connections from internal subnet and VPN"
}