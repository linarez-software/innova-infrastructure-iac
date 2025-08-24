resource "google_service_account" "odoo_service_account" {
  account_id   = "odoo-${var.environment}-sa"
  display_name = "Odoo ${var.environment} Service Account"
  description  = "Service account for Odoo application in ${var.environment}"
  
  project = var.project_id
}

resource "google_service_account" "db_service_account" {
  account_id   = "db-${var.environment}-sa"
  display_name = "Database ${var.environment} Service Account"
  description  = "Service account for database in ${var.environment}"
  
  project = var.project_id
}

resource "google_service_account" "monitoring_service_account" {
  account_id   = "monitoring-${var.environment}-sa"
  display_name = "Monitoring ${var.environment} Service Account"
  description  = "Service account for monitoring in ${var.environment}"
  
  project = var.project_id
}

resource "google_service_account" "vpn_service_account" {
  account_id   = "vpn-${var.environment}-sa"
  display_name = "VPN ${var.environment} Service Account"
  description  = "Service account for VPN server in ${var.environment}"
  
  project = var.project_id
}

resource "google_project_iam_member" "odoo_compute_instance_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin"
  member  = "serviceAccount:${google_service_account.odoo_service_account.email}"
}

resource "google_project_iam_member" "odoo_service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.odoo_service_account.email}"
}

resource "google_project_iam_member" "odoo_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.odoo_service_account.email}"
}

resource "google_project_iam_member" "odoo_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.odoo_service_account.email}"
}

resource "google_project_iam_member" "odoo_storage_object_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.odoo_service_account.email}"
}

resource "google_project_iam_member" "db_compute_instance_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin"
  member  = "serviceAccount:${google_service_account.db_service_account.email}"
}

resource "google_project_iam_member" "db_service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.db_service_account.email}"
}

resource "google_project_iam_member" "db_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.db_service_account.email}"
}

resource "google_project_iam_member" "db_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.db_service_account.email}"
}

resource "google_project_iam_member" "db_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.db_service_account.email}"
}

resource "google_project_iam_member" "monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.monitoring_service_account.email}"
}

resource "google_project_iam_member" "monitoring_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.monitoring_service_account.email}"
}

resource "google_project_iam_member" "monitoring_notification_channel_editor" {
  project = var.project_id
  role    = "roles/monitoring.notificationChannelEditor"
  member  = "serviceAccount:${google_service_account.monitoring_service_account.email}"
}

resource "google_project_iam_member" "monitoring_alert_policy_editor" {
  project = var.project_id
  role    = "roles/monitoring.alertPolicyEditor"
  member  = "serviceAccount:${google_service_account.monitoring_service_account.email}"
}

resource "google_project_iam_member" "monitoring_dashboard_editor" {
  project = var.project_id
  role    = "roles/monitoring.dashboardEditor"
  member  = "serviceAccount:${google_service_account.monitoring_service_account.email}"
}

resource "google_project_iam_member" "monitoring_log_viewer" {
  project = var.project_id
  role    = "roles/logging.viewer"
  member  = "serviceAccount:${google_service_account.monitoring_service_account.email}"
}

resource "google_project_iam_member" "vpn_compute_instance_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin"
  member  = "serviceAccount:${google_service_account.vpn_service_account.email}"
}

resource "google_project_iam_member" "vpn_service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.vpn_service_account.email}"
}

resource "google_project_iam_member" "vpn_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vpn_service_account.email}"
}

resource "google_project_iam_member" "vpn_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vpn_service_account.email}"
}

resource "google_project_iam_member" "vpn_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.vpn_service_account.email}"
}

resource "google_kms_key_ring" "odoo_keyring" {
  count = var.environment == "production" ? 1 : 0
  
  name     = "odoo-${var.environment}-keyring"
  location = "global"
  
  project = var.project_id
}

resource "google_kms_crypto_key" "odoo_key" {
  count = var.environment == "production" ? 1 : 0
  
  name            = "odoo-${var.environment}-key"
  key_ring        = google_kms_key_ring.odoo_keyring[0].id
  rotation_period = "2592000s"
  
  lifecycle {
    prevent_destroy = true
  }
}

resource "google_kms_crypto_key_iam_member" "odoo_key_encrypter" {
  count = var.environment == "production" ? 1 : 0
  
  crypto_key_id = google_kms_crypto_key.odoo_key[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.odoo_service_account.email}"
}

resource "google_kms_crypto_key_iam_member" "db_key_encrypter" {
  count = var.environment == "production" ? 1 : 0
  
  crypto_key_id = google_kms_crypto_key.odoo_key[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.db_service_account.email}"
}