locals {
  is_production = var.environment == "production"

  app_instance_name = "app-${var.environment}"
  db_instance_name  = "db-${var.environment}"

  app_instance_type = local.is_production ? var.production_app_instance_type : var.staging_instance_type

  staging_startup_script = templatefile("${path.module}/templates/staging-startup.sh", {
    postgresql_version = var.postgresql_version
    db_password        = var.db_password
    domain_name        = var.domain_name
    ssl_email          = var.ssl_email
    pgadmin_email      = var.pgadmin_email
    pgadmin_password   = var.pgadmin_password
    staging_ssh_users  = var.staging_ssh_users
  })

  production_app_startup_script = local.is_production ? templatefile("${path.module}/templates/production-app-startup.sh", {
    db_password = var.db_password
    db_host     = "DB_INSTANCE_IP_PLACEHOLDER"
    domain_name = var.domain_name
    ssl_email   = var.ssl_email
  }) : ""

  production_db_startup_script = local.is_production ? templatefile("${path.module}/templates/production-db-startup.sh", {
    postgresql_version = var.postgresql_version
    db_password        = var.db_password
    app_host           = "APP_INSTANCE_IP_PLACEHOLDER"
    project_id         = var.project_id
    zone               = var.zone
  }) : ""
}

resource "google_compute_instance" "app_instance" {
  name         = local.app_instance_name
  machine_type = local.app_instance_type
  zone         = var.zone

  tags = [
    "ssh-allowed",
    "http-server",
    "https-server",
    "app-server",
    local.is_production ? "redis-server" : "postgresql-server"
  ]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = local.is_production ? 30 : 20
      type  = "pd-standard"
    }
  }

  dynamic "scratch_disk" {
    for_each = local.is_production && strcontains(local.app_instance_type, "lssd") ? [1] : []
    content {
      interface = "NVME"
    }
  }

  network_interface {
    subnetwork = var.subnet_id

    access_config {
      network_tier = local.is_production ? "PREMIUM" : "STANDARD"
    }
  }

  metadata = {
    startup-script = local.staging_startup_script
    enable-oslogin = local.is_production ? "TRUE" : "FALSE"  # Disable OS Login for staging to use traditional SSH
  }

  service_account {
    email  = var.app_service_account_email
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

resource "google_compute_instance" "db_instance" {
  count = local.is_production ? 1 : 0

  name         = local.db_instance_name
  machine_type = var.production_db_instance_type
  zone         = var.zone

  tags = [
    "ssh-allowed",
    "postgresql-server"
  ]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 100
      type  = "pd-standard"
    }
  }

  network_interface {
    subnetwork = var.subnet_id

    access_config {
      network_tier = "PREMIUM"
    }
  }

  metadata = {
    startup-script = templatefile("${path.module}/templates/production-db-startup.sh", {
      postgresql_version = var.postgresql_version
      db_password        = var.db_password
      project_id         = var.project_id
    })
    enable-oslogin = "TRUE"
  }

  service_account {
    email  = var.db_service_account_email
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