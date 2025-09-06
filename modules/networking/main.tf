# VPC Network
resource "google_compute_network" "vpc_network" {
  name                            = var.vpc_name
  auto_create_subnetworks         = false
  routing_mode                    = "REGIONAL"
  delete_default_routes_on_create = false

  project = var.project_id
}

# Subnet
resource "google_compute_subnetwork" "subnet" {
  name          = var.subnet_name
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc_network.id

  private_ip_google_access = true

  project = var.project_id
}

# Static IP Addresses as documented
resource "google_compute_address" "vpn_static_ip" {
  name         = var.static_ips.vpn_ip
  address_type = "EXTERNAL"
  region       = var.region
  network_tier = "STANDARD"

  project = var.project_id
}

resource "google_compute_address" "app_static_ip" {
  name         = var.static_ips.app_ip
  address_type = "EXTERNAL"
  region       = var.region
  network_tier = "STANDARD"

  project = var.project_id
}

resource "google_compute_address" "jenkins_static_ip" {
  count = var.static_ips.jenkins_ip != "" ? 1 : 0

  name         = var.static_ips.jenkins_ip
  address_type = "EXTERNAL"
  region       = var.region
  network_tier = "STANDARD"

  project = var.project_id
}

# Firewall Rules - Exact implementation from networking specifications

# 0. IAP SSH Access (Higher Priority)
resource "google_compute_firewall" "staging_allow_iap" {
  name     = "staging-allow-iap"
  network  = google_compute_network.vpc_network.name
  priority = 100

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["ssh-server"]

  description = "Allow IAP SSH access for administration"

  project = var.project_id
}

# 1. Web Application Access
resource "google_compute_firewall" "staging_allow_http_https" {
  name     = "staging-allow-http-https"
  network  = google_compute_network.vpc_network.name
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]

  description = "Allow HTTP and HTTPS access to web application"

  project = var.project_id
}

# 2. VPN Server Access
resource "google_compute_firewall" "staging_allow_vpn_server" {
  name     = "staging-allow-vpn-server"
  network  = google_compute_network.vpc_network.name
  priority = 1000

  allow {
    protocol = "udp"
    ports    = ["1194"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["vpn-server"]

  description = "Allow OpenVPN access to VPN server"

  project = var.project_id
}

# 3. SSH Access (VPN Only)
resource "google_compute_firewall" "staging_allow_ssh_vpn_only" {
  name     = "staging-allow-ssh-vpn-only"
  network  = google_compute_network.vpc_network.name
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["10.8.0.0/24"]
  target_tags   = ["ssh-server"]

  description = "Allow SSH access only from VPN clients"

  project = var.project_id
}

# 4. VPN Server Management SSH (External Access)
resource "google_compute_firewall" "staging_allow_vpn_management" {
  name     = "staging-allow-vpn-management"
  network  = google_compute_network.vpc_network.name
  priority = 500

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["vpn-server"]

  description = "Allow SSH access to VPN server for management"

  project = var.project_id
}

# 5. Jenkins Web Interface (VPN Only)
resource "google_compute_firewall" "staging_allow_jenkins_web" {
  name     = "staging-allow-jenkins-web"
  network  = google_compute_network.vpc_network.name
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }

  source_ranges = ["10.8.0.0/24"]
  target_tags   = ["jenkins-server"]

  description = "Allow Jenkins web interface access from VPN clients only"

  project = var.project_id
}

# 5. Development Tools (VPN Only)
resource "google_compute_firewall" "staging_allow_dev_tools" {
  name     = "staging-allow-dev-tools"
  network  = google_compute_network.vpc_network.name
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["8025", "5050"]
  }

  source_ranges = ["10.8.0.0/24"]
  target_tags   = ["dev-tools"]

  description = "Allow access to Mailhog and pgAdmin from VPN clients only"

  project = var.project_id
}

# 6. Internal Subnet Communication
resource "google_compute_firewall" "staging_allow_internal_subnet" {
  name     = "staging-allow-internal-subnet"
  network  = google_compute_network.vpc_network.name
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/24"]

  description = "Allow all communication within internal subnet"

  project = var.project_id
}

# 7. VPN Client Communication
resource "google_compute_firewall" "staging_allow_vpn_clients" {
  name     = "staging-allow-vpn-clients"
  network  = google_compute_network.vpc_network.name
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.8.0.0/24"]

  description = "Allow all communication from VPN clients to internal resources"

  project = var.project_id
}

# 8. Database Access (Internal + VPN)
resource "google_compute_firewall" "staging_allow_postgresql" {
  name     = "staging-allow-postgresql"
  network  = google_compute_network.vpc_network.name
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }

  source_ranges = ["10.0.0.0/24", "10.8.0.0/24"]
  target_tags   = ["database-server"]

  description = "Allow PostgreSQL access from internal subnet and VPN clients"

  project = var.project_id
}

# 9. Redis Access (Internal + VPN)
resource "google_compute_firewall" "staging_allow_redis" {
  name     = "staging-allow-redis"
  network  = google_compute_network.vpc_network.name
  priority = 1000

  allow {
    protocol = "tcp"
    ports    = ["6379"]
  }

  source_ranges = ["10.0.0.0/24", "10.8.0.0/24"]
  target_tags   = ["cache-server"]

  description = "Allow Redis access from internal subnet and VPN clients"

  project = var.project_id
}

# 10. Deny Direct Application Ports
resource "google_compute_firewall" "staging_deny_direct_app_ports" {
  name     = "staging-deny-direct-app-ports"
  network  = google_compute_network.vpc_network.name
  priority = 1000

  deny {
    protocol = "tcp"
    ports    = ["8000-8999"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["app-server"]

  description = "Deny direct access to application development ports"

  project = var.project_id
}