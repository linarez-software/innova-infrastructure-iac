output "backup_bucket_name" {
  description = "Name of the backup bucket"
  value       = var.backup_enabled ? google_storage_bucket.backup_bucket[0].name : ""
}

output "backup_bucket_url" {
  description = "URL of the backup bucket"
  value       = var.backup_enabled ? google_storage_bucket.backup_bucket[0].url : ""
}

output "backup_policy_id" {
  description = "ID of the backup policy"
  value       = var.backup_enabled ? google_compute_resource_policy.daily_backup[0].id : ""
}

output "backup_policy_name" {
  description = "Name of the backup policy"
  value       = var.backup_enabled ? google_compute_resource_policy.daily_backup[0].name : ""
}