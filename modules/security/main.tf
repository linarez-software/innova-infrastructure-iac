resource "google_service_account" "app_service_account" {
  account_id   = "app-${var.environment}-sa"
  display_name = "Application ${var.environment} Service Account"
  description  = "Service account for application server in ${var.environment}"

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

resource "google_service_account" "jenkins_service_account" {
  account_id   = "jenkins-${var.environment}-sa"
  display_name = "Jenkins ${var.environment} Service Account"
  description  = "Service account for Jenkins CI/CD server in ${var.environment}"

  project = var.project_id
}

resource "google_project_iam_member" "app_compute_instance_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin"
  member  = "serviceAccount:${google_service_account.app_service_account.email}"
}

resource "google_project_iam_member" "app_service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.app_service_account.email}"
}

resource "google_project_iam_member" "app_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.app_service_account.email}"
}

resource "google_project_iam_member" "app_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.app_service_account.email}"
}

resource "google_project_iam_member" "app_storage_object_viewer" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.app_service_account.email}"
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

resource "google_kms_key_ring" "app_keyring" {
  count = var.environment == "production" ? 1 : 0

  name     = "app-${var.environment}-keyring"
  location = "global"

  project = var.project_id
}

resource "google_kms_crypto_key" "app_key" {
  count = var.environment == "production" ? 1 : 0

  name            = "odoo-${var.environment}-key"
  key_ring        = google_kms_key_ring.app_keyring[0].id
  rotation_period = "2592000s"

  lifecycle {
    prevent_destroy = false
  }
}

resource "google_kms_crypto_key_iam_member" "app_key_encrypter" {
  count = var.environment == "production" ? 1 : 0

  crypto_key_id = google_kms_crypto_key.app_key[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.app_service_account.email}"
}

resource "google_kms_crypto_key_iam_member" "db_key_encrypter" {
  count = var.environment == "production" ? 1 : 0

  crypto_key_id = google_kms_crypto_key.app_key[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.db_service_account.email}"
}

# Jenkins service account IAM permissions
resource "google_project_iam_member" "jenkins_compute_instance_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin"
  member  = "serviceAccount:${google_service_account.jenkins_service_account.email}"
}

resource "google_project_iam_member" "jenkins_service_account_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.jenkins_service_account.email}"
}

resource "google_project_iam_member" "jenkins_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.jenkins_service_account.email}"
}

resource "google_project_iam_member" "jenkins_metric_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.jenkins_service_account.email}"
}

resource "google_project_iam_member" "jenkins_storage_admin" {
  project = var.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.jenkins_service_account.email}"
}

resource "google_project_iam_member" "jenkins_source_repo_admin" {
  project = var.project_id
  role    = "roles/source.admin"
  member  = "serviceAccount:${google_service_account.jenkins_service_account.email}"
}

resource "google_project_iam_member" "jenkins_container_admin" {
  project = var.project_id
  role    = "roles/container.admin"
  member  = "serviceAccount:${google_service_account.jenkins_service_account.email}"
}

resource "google_project_iam_member" "jenkins_secret_manager_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.jenkins_service_account.email}"
}

# Allow Jenkins to deploy to other compute instances
resource "google_project_iam_member" "jenkins_compute_admin" {
  project = var.project_id
  role    = "roles/compute.admin"
  member  = "serviceAccount:${google_service_account.jenkins_service_account.email}"
}

# OS Login permissions for user access
resource "google_project_iam_member" "user_os_login" {
  project = var.project_id
  role    = "roles/compute.osLogin"
  member  = "user:elinarezv@gmail.com"
}

# Note: osLoginExternalUser role is not supported at project level
# It's typically granted at the organization level for external users

# Enable IAP API
resource "google_project_service" "iap_api" {
  project = var.project_id
  service = "iap.googleapis.com"

  disable_dependent_services = false
}

resource "google_project_iam_member" "user_iap_tunnel" {
  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = "user:elinarezv@gmail.com"
}

resource "google_project_iam_member" "user_compute_instance_admin" {
  project = var.project_id
  role    = "roles/compute.instanceAdmin.v1"
  member  = "user:elinarezv@gmail.com"
}

resource "google_project_iam_member" "user_compute_admin" {
  project = var.project_id
  role    = "roles/compute.admin"
  member  = "user:elinarezv@gmail.com"
}

resource "google_project_iam_member" "user_editor" {
  project = var.project_id
  role    = "roles/editor"  
  member  = "user:elinarezv@gmail.com"
}