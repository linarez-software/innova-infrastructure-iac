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
  value       = var.app_static_ip
}

output "app_internal_ip" {
  description = "Internal IP of application instance"
  value       = google_compute_instance.app_instance.network_interface[0].network_ip
}

output "jenkins_instance_id" {
  description = "Instance ID of Jenkins server"
  value       = var.enable_jenkins ? google_compute_instance.jenkins_instance[0].instance_id : null
}

output "jenkins_instance_name" {
  description = "Name of Jenkins instance"
  value       = var.enable_jenkins ? google_compute_instance.jenkins_instance[0].name : null
}

output "jenkins_external_ip" {
  description = "External IP of Jenkins instance"
  value       = var.enable_jenkins ? var.jenkins_static_ip : null
}

output "jenkins_internal_ip" {
  description = "Internal IP of Jenkins instance"
  value       = var.enable_jenkins ? google_compute_instance.jenkins_instance[0].network_interface[0].network_ip : null
}

output "app_self_link" {
  description = "Self link of application instance"
  value       = google_compute_instance.app_instance.self_link
}

output "jenkins_self_link" {
  description = "Self link of Jenkins instance"
  value       = var.enable_jenkins ? google_compute_instance.jenkins_instance[0].self_link : null
}