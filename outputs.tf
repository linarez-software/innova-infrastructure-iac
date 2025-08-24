output "odoo_instance_ip" {
  description = "External IP address of the Odoo instance"
  value       = module.compute.odoo_external_ip
}

output "odoo_instance_internal_ip" {
  description = "Internal IP address of the Odoo instance"
  value       = module.compute.odoo_internal_ip
}

output "db_instance_ip" {
  description = "Internal IP address of the database instance (production only)"
  value       = var.environment == "production" ? module.compute.db_internal_ip : "N/A"
}

output "odoo_url" {
  description = "URL to access Odoo application"
  value       = var.domain_name != "" ? "https://${var.domain_name}" : "http://${module.compute.odoo_external_ip}"
}

output "ssh_command_odoo" {
  description = "SSH command to connect to Odoo instance"
  value       = "gcloud compute ssh ${module.compute.odoo_instance_name} --zone=${var.zone} --project=${var.project_id}"
}

output "ssh_command_db" {
  description = "SSH command to connect to database instance (production only)"
  value       = var.environment == "production" ? "gcloud compute ssh ${module.compute.db_instance_name} --zone=${var.zone} --project=${var.project_id}" : "N/A"
}

output "network_name" {
  description = "Name of the VPC network"
  value       = module.networking.network_name
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = module.networking.subnet_name
}

output "vpn_server_ip" {
  description = "External IP address of the VPN server"
  value       = module.vpn.vpn_external_ip
}

output "vpn_connection_info" {
  description = "VPN connection information"
  value       = module.vpn.vpn_connection_info
}

output "ssh_command_vpn" {
  description = "SSH command to connect to VPN server"
  value       = "gcloud compute ssh ${module.vpn.vpn_instance_name} --zone=${var.zone} --project=${var.project_id}"
}

output "service_accounts" {
  description = "Service account emails created"
  value = {
    odoo       = module.security.odoo_service_account_email
    database   = module.security.db_service_account_email
    monitoring = module.security.monitoring_service_account_email
    vpn        = module.security.vpn_service_account_email
  }
}

output "firewall_rules" {
  description = "Firewall rules created"
  value       = module.networking.firewall_rules
}

output "backup_bucket" {
  description = "GCS bucket for backups"
  value       = module.database.backup_bucket_name
}