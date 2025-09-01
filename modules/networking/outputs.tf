output "network_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.vpc_network.id
}

output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc_network.name
}

output "network_self_link" {
  description = "The self link of the VPC network"
  value       = google_compute_network.vpc_network.self_link
}

output "subnet_id" {
  description = "The ID of the subnet"
  value       = google_compute_subnetwork.subnet.id
}

output "subnet_name" {
  description = "The name of the subnet"
  value       = google_compute_subnetwork.subnet.name
}

output "subnet_self_link" {
  description = "The self link of the subnet"
  value       = google_compute_subnetwork.subnet.self_link
}

output "subnet_cidr" {
  description = "The CIDR block of the subnet"
  value       = google_compute_subnetwork.subnet.ip_cidr_range
}

output "static_ip_address" {
  description = "Static external IP address for production"
  value       = var.environment == "production" ? google_compute_address.app_static_ip[0].address : null
}

output "firewall_rules" {
  description = "List of firewall rules created"
  value = [
    google_compute_firewall.allow_ssh_vpn_only.name,
    google_compute_firewall.allow_vpn_server.name,
    google_compute_firewall.allow_http_https.name,
    google_compute_firewall.deny_direct_app_ports.name,
    google_compute_firewall.allow_internal_postgres.name,
    google_compute_firewall.allow_internal_redis.name,
    google_compute_firewall.allow_internal.name,
    google_compute_firewall.deny_all.name
  ]
}