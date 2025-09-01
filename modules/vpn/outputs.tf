output "vpn_instance_id" {
  description = "Instance ID of VPN server"
  value       = google_compute_instance.vpn_instance.instance_id
}

output "vpn_instance_name" {
  description = "Name of VPN instance"
  value       = google_compute_instance.vpn_instance.name
}

output "vpn_external_ip" {
  description = "External IP of VPN server"
  value       = google_compute_address.vpn_static_ip.address
}

output "vpn_internal_ip" {
  description = "Internal IP of VPN server"
  value       = google_compute_instance.vpn_instance.network_interface[0].network_ip
}

output "vpn_subnet_cidr" {
  description = "VPN client subnet CIDR"
  value       = var.vpn_subnet_cidr
}

output "vpn_configs_bucket" {
  description = "GCS bucket for VPN client configurations"
  value       = google_storage_bucket.vpn_configs.name
}

output "vpn_connection_info" {
  description = "VPN connection information"
  value = {
    server_ip     = google_compute_address.vpn_static_ip.address
    server_port   = 1194
    protocol      = "udp"
    client_subnet = var.vpn_subnet_cidr
    max_clients   = var.max_vpn_clients
  }
}