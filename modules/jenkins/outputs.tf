output "jenkins_instance_id" {
  description = "The ID of the Jenkins instance"
  value       = google_compute_instance.jenkins.id
}

output "jenkins_instance_name" {
  description = "The name of the Jenkins instance"
  value       = google_compute_instance.jenkins.name
}

output "jenkins_internal_ip" {
  description = "The internal IP address of the Jenkins instance"
  value       = google_compute_instance.jenkins.network_interface[0].network_ip
}

output "jenkins_external_ip" {
  description = "The external IP address of the Jenkins instance"
  value       = try(google_compute_instance.jenkins.network_interface[0].access_config[0].nat_ip, "")
}

output "jenkins_web_url" {
  description = "The Jenkins web interface URL"
  value       = var.jenkins_domain != "" ? "https://${var.jenkins_domain}" : "http://${google_compute_instance.jenkins.network_interface[0].network_ip}:8080"
}

output "jenkins_ssh_command" {
  description = "SSH command to connect to Jenkins server"
  value       = "gcloud compute ssh ${google_compute_instance.jenkins.name} --zone=${var.zone}"
}

output "jenkins_data_disk_id" {
  description = "The ID of the Jenkins persistent data disk"
  value       = google_compute_disk.jenkins_data.id
}

output "jenkins_health_check_id" {
  description = "The ID of the Jenkins health check"
  value       = google_compute_health_check.jenkins.id
}