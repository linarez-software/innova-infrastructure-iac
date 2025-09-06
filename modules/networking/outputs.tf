output "vpc_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.vpc_network.id
}

output "vpc_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc_network.name
}

output "vpc_self_link" {
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

output "vpn_static_ip" {
  description = "VPN server static IP address"
  value       = google_compute_address.vpn_static_ip.address
}

output "app_static_ip" {
  description = "Application server static IP address"
  value       = google_compute_address.app_static_ip.address
}

output "jenkins_static_ip" {
  description = "Jenkins server static IP address"
  value       = length(google_compute_address.jenkins_static_ip) > 0 ? google_compute_address.jenkins_static_ip[0].address : null
}

output "firewall_rules" {
  description = "List of firewall rules created"
  value = [
    google_compute_firewall.staging_allow_iap.name,
    google_compute_firewall.staging_allow_http_https.name,
    google_compute_firewall.staging_allow_vpn_server.name,
    google_compute_firewall.staging_allow_ssh_vpn_only.name,
    google_compute_firewall.staging_allow_jenkins_web.name,
    google_compute_firewall.staging_allow_dev_tools.name,
    google_compute_firewall.staging_allow_internal_subnet.name,
    google_compute_firewall.staging_allow_vpn_clients.name,
    google_compute_firewall.staging_allow_postgresql.name,
    google_compute_firewall.staging_allow_redis.name,
    google_compute_firewall.staging_deny_direct_app_ports.name
  ]
}