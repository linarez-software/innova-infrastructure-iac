output "odoo_instance_id" {
  description = "Instance ID of Odoo server"
  value       = google_compute_instance.odoo_instance.instance_id
}

output "odoo_instance_name" {
  description = "Name of Odoo instance"
  value       = google_compute_instance.odoo_instance.name
}

output "odoo_external_ip" {
  description = "External IP of Odoo instance"
  value       = google_compute_instance.odoo_instance.network_interface[0].access_config[0].nat_ip
}

output "odoo_internal_ip" {
  description = "Internal IP of Odoo instance"
  value       = google_compute_instance.odoo_instance.network_interface[0].network_ip
}

output "db_instance_id" {
  description = "Instance ID of database server (production only)"
  value       = var.environment == "production" ? google_compute_instance.db_instance[0].instance_id : ""
}

output "db_instance_name" {
  description = "Name of database instance"
  value       = var.environment == "production" ? google_compute_instance.db_instance[0].name : ""
}

output "db_internal_ip" {
  description = "Internal IP of database instance"
  value       = var.environment == "production" ? google_compute_instance.db_instance[0].network_interface[0].network_ip : ""
}

output "odoo_self_link" {
  description = "Self link of Odoo instance"
  value       = google_compute_instance.odoo_instance.self_link
}

output "db_self_link" {
  description = "Self link of database instance"
  value       = var.environment == "production" ? google_compute_instance.db_instance[0].self_link : ""
}