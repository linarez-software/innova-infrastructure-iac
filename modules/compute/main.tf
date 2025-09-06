# Application Server - Consolidated for staging (Odoo + PostgreSQL + Redis + NGINX)
resource "google_compute_instance" "app_instance" {
  name         = var.app_instance_name
  machine_type = var.app_machine_type
  zone         = var.zone

  # Network tags as documented
  tags = [
    "web-server",
    "ssh-server", 
    "database-server",
    "cache-server",
    "app-server"
  ]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.app_disk_size
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = var.network_name
    subnetwork = var.subnet_name

    access_config {
      nat_ip       = var.app_static_ip
      network_tier = "STANDARD"
    }
  }

  metadata = {
    startup-script = local.app_startup_script
    enable-oslogin = "TRUE"
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  labels = var.labels

  project = var.project_id
}

# Jenkins Server - Optional CI/CD and Development Tools
resource "google_compute_instance" "jenkins_instance" {
  count = var.enable_jenkins ? 1 : 0

  name         = var.jenkins_instance_name
  machine_type = var.jenkins_machine_type
  zone         = var.zone

  # Network tags as documented
  tags = [
    "jenkins-server",
    "ssh-server",
    "dev-tools"
  ]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.jenkins_disk_size
      type  = "pd-standard"
    }
  }

  network_interface {
    network    = var.network_name
    subnetwork = var.subnet_name

    access_config {
      nat_ip       = var.jenkins_static_ip
      network_tier = "STANDARD"
    }
  }

  metadata = {
    startup-script = local.jenkins_startup_script
    enable-oslogin = "TRUE"
  }

  service_account {
    email  = var.service_account_email
    scopes = ["cloud-platform"]
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  labels = var.labels

  project = var.project_id
}

# Local values for startup scripts
locals {
  app_startup_script = templatefile("${path.module}/templates/staging-startup.sh", {
    postgresql_version = "15"
    db_password        = var.db_password
    domain_name        = ""
    ssl_email          = ""
    pgadmin_email      = "admin@staging.local"
    pgadmin_password   = var.db_password
    staging_ssh_users  = []
  })

  jenkins_startup_script = ""  # We'll implement this later
}