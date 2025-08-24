resource "google_compute_network" "vpc_network" {
  name                            = var.network_name
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = false
  
  project = var.project_id
}

resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc_network.id
  
  private_ip_google_access = true
  
  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
  
  project = var.project_id
}

resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.network_name}-allow-ssh"
  network = google_compute_network.vpc_network.name
  
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  
  source_ranges = var.allowed_ssh_ips
  target_tags   = ["ssh-allowed"]
  
  project = var.project_id
}

resource "google_compute_firewall" "allow_http_https" {
  name    = "${var.network_name}-allow-http-https"
  network = google_compute_network.vpc_network.name
  
  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
  
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
  
  project = var.project_id
}

resource "google_compute_firewall" "allow_odoo" {
  name    = "${var.network_name}-allow-odoo"
  network = google_compute_network.vpc_network.name
  
  allow {
    protocol = "tcp"
    ports    = ["8069", "8072"]
  }
  
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["odoo-server"]
  
  project = var.project_id
}

resource "google_compute_firewall" "allow_internal_postgres" {
  name    = "${var.network_name}-allow-internal-postgres"
  network = google_compute_network.vpc_network.name
  
  allow {
    protocol = "tcp"
    ports    = ["5432", "6432"]
  }
  
  source_ranges = [var.subnet_cidr]
  target_tags   = ["postgresql-server"]
  
  project = var.project_id
}

resource "google_compute_firewall" "allow_internal_redis" {
  name    = "${var.network_name}-allow-internal-redis"
  network = google_compute_network.vpc_network.name
  
  allow {
    protocol = "tcp"
    ports    = ["6379"]
  }
  
  source_ranges = [var.subnet_cidr]
  target_tags   = ["redis-server"]
  
  project = var.project_id
}

resource "google_compute_firewall" "allow_internal" {
  name    = "${var.network_name}-allow-internal"
  network = google_compute_network.vpc_network.name
  
  allow {
    protocol = "icmp"
  }
  
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  
  source_ranges = [var.subnet_cidr]
  
  project = var.project_id
}

resource "google_compute_firewall" "deny_all" {
  name     = "${var.network_name}-deny-all"
  network  = google_compute_network.vpc_network.name
  priority = 65534
  
  deny {
    protocol = "all"
  }
  
  source_ranges = ["0.0.0.0/0"]
  
  project = var.project_id
}

resource "google_compute_address" "odoo_static_ip" {
  count = var.environment == "production" ? 1 : 0
  
  name         = "${var.network_name}-odoo-ip"
  address_type = "EXTERNAL"
  region       = var.region
  
  project = var.project_id
}

resource "google_compute_router" "router" {
  name    = "${var.network_name}-router"
  network = google_compute_network.vpc_network.id
  region  = var.region
  
  project = var.project_id
}