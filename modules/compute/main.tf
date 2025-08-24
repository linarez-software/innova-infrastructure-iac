locals {
  is_production = var.environment == "production"
  
  odoo_instance_name = "odoo-${var.environment}"
  db_instance_name   = "db-${var.environment}"
  
  odoo_instance_type = local.is_production ? var.production_odoo_instance_type : var.staging_instance_type
  
  staging_startup_script = templatefile("${path.module}/templates/staging-startup.sh", {
    odoo_version       = var.odoo_version
    postgresql_version = var.postgresql_version
    odoo_admin_passwd  = var.odoo_admin_passwd
    db_password        = var.db_password
    domain_name        = var.domain_name
    ssl_email          = var.ssl_email
    odoo_workers       = var.odoo_workers
  })
  
  production_odoo_startup_script = templatefile("${path.module}/templates/production-odoo-startup.sh", {
    odoo_version       = var.odoo_version
    odoo_admin_passwd  = var.odoo_admin_passwd
    db_password        = var.db_password
    db_host            = google_compute_instance.db_instance[0].network_interface[0].network_ip
    domain_name        = var.domain_name
    ssl_email          = var.ssl_email
    odoo_workers       = var.odoo_workers
  })
  
  production_db_startup_script = templatefile("${path.module}/templates/production-db-startup.sh", {
    postgresql_version = var.postgresql_version
    db_password        = var.db_password
    odoo_host          = google_compute_instance.odoo_instance.network_interface[0].network_ip
  })
}

resource "google_compute_instance" "odoo_instance" {
  name         = local.odoo_instance_name
  machine_type = local.odoo_instance_type
  zone         = var.zone
  
  tags = [
    "ssh-allowed",
    "http-server",
    "https-server",
    "odoo-server",
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
    for_each = local.is_production && strcontains(local.odoo_instance_type, "lssd") ? [1] : []
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
    startup-script = local.is_production ? local.production_odoo_startup_script : local.staging_startup_script
    enable-oslogin = "TRUE"
  }
  
  service_account {
    email  = var.odoo_service_account_email
    scopes = ["cloud-platform"]
  }
  
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                  = true
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
      type  = "pd-ssd"
    }
  }
  
  network_interface {
    subnetwork = var.subnet_id
  }
  
  metadata = {
    startup-script = local.production_db_startup_script
    enable-oslogin = "TRUE"
  }
  
  service_account {
    email  = var.db_service_account_email
    scopes = ["cloud-platform"]
  }
  
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                  = true
    enable_integrity_monitoring = true
  }
  
  labels = var.labels
  
  project = var.project_id
}

resource "google_compute_disk" "additional_data_disk" {
  count = local.is_production ? 1 : 0
  
  name = "${local.db_instance_name}-data"
  type = "pd-ssd"
  zone = var.zone
  size = 200
  
  labels = var.labels
  
  project = var.project_id
}

resource "google_compute_attached_disk" "db_data_disk" {
  count = local.is_production ? 1 : 0
  
  disk     = google_compute_disk.additional_data_disk[0].id
  instance = google_compute_instance.db_instance[0].id
  
  project = var.project_id
}