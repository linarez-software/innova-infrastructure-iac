output "app_service_account_email" {
  description = "Email of the application service account"
  value       = google_service_account.app_service_account.email
}

output "app_service_account_id" {
  description = "ID of the application service account"
  value       = google_service_account.app_service_account.id
}

output "db_service_account_email" {
  description = "Email of the database service account"
  value       = google_service_account.db_service_account.email
}

output "db_service_account_id" {
  description = "ID of the database service account"
  value       = google_service_account.db_service_account.id
}

output "monitoring_service_account_email" {
  description = "Email of the monitoring service account"
  value       = google_service_account.monitoring_service_account.email
}

output "monitoring_service_account_id" {
  description = "ID of the monitoring service account"
  value       = google_service_account.monitoring_service_account.id
}

output "vpn_service_account_email" {
  description = "Email of the VPN service account"
  value       = google_service_account.vpn_service_account.email
}

output "vpn_service_account_id" {
  description = "ID of the VPN service account"
  value       = google_service_account.vpn_service_account.id
}

output "jenkins_service_account_email" {
  description = "Email of the Jenkins service account"
  value       = google_service_account.jenkins_service_account.email
}

output "jenkins_service_account_id" {
  description = "ID of the Jenkins service account"
  value       = google_service_account.jenkins_service_account.id
}

output "kms_keyring_id" {
  description = "ID of the KMS keyring (production only)"
  value       = var.environment == "production" ? google_kms_key_ring.app_keyring[0].id : ""
}

output "kms_crypto_key_id" {
  description = "ID of the KMS crypto key (production only)"
  value       = var.environment == "production" ? google_kms_crypto_key.app_key[0].id : ""
}