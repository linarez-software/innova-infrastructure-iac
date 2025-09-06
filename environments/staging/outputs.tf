output "vpn_server_external_ip" {
  description = "External IP address of VPN server"
  value       = module.networking.vpn_static_ip
}

output "vpn_server_internal_ip" {
  description = "Internal IP address of VPN server"
  value       = module.vpn.vpn_internal_ip
}

output "app_server_external_ip" {
  description = "External IP address of application server"
  value       = module.networking.app_static_ip
}

output "app_server_internal_ip" {
  description = "Internal IP address of application server"
  value       = module.compute.app_internal_ip
}

output "jenkins_server_external_ip" {
  description = "External IP address of Jenkins server"
  value       = module.networking.jenkins_static_ip
}

output "jenkins_server_internal_ip" {
  description = "Internal IP address of Jenkins server"
  value       = module.compute.jenkins_internal_ip
}

output "vpn_connection_info" {
  description = "VPN connection information"
  value = {
    server_ip     = module.networking.vpn_static_ip
    server_port   = 1194
    protocol      = "udp"
    client_subnet = "10.8.0.0/24"
    max_clients   = 5
  }
}

output "firewall_rules" {
  description = "List of firewall rules created"
  value       = module.networking.firewall_rules
}

output "vpn_configs_bucket" {
  description = "GCS bucket for VPN client configurations"
  value       = module.vpn.vpn_configs_bucket
}