output "app_instance_id" {
  description = "Instance ID of application server"
  value       = google_compute_instance.app_instance.instance_id
}

output "app_instance_name" {
  description = "Name of application instance"
  value       = google_compute_instance.app_instance.name
}

output "app_external_ip" {
  description = "External IP of application instance"
  value       = google_compute_instance.app_instance.network_interface[0].access_config[0].nat_ip
}

output "app_internal_ip" {
  description = "Internal IP of application instance"
  value       = google_compute_instance.app_instance.network_interface[0].network_ip
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

output "db_external_ip" {
  description = "External IP of database instance"
  value       = var.environment == "production" ? google_compute_instance.db_instance[0].network_interface[0].access_config[0].nat_ip : ""
}

output "app_self_link" {
  description = "Self link of application instance"
  value       = google_compute_instance.app_instance.self_link
}

output "db_self_link" {
  description = "Self link of database instance"
  value       = var.environment == "production" ? google_compute_instance.db_instance[0].self_link : ""
}