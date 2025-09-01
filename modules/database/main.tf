locals {
  backup_bucket_name = "${var.project_id}-${var.environment}-backups"
}

resource "google_storage_bucket" "backup_bucket" {
  count = var.backup_enabled ? 1 : 0

  name          = local.backup_bucket_name
  location      = "US"
  force_destroy = false

  lifecycle_rule {
    condition {
      age = var.retention_days
    }
    action {
      type = "Delete"
    }
  }

  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type          = "SetStorageClass"
      storage_class = "NEARLINE"
    }
  }

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type          = "SetStorageClass"
      storage_class = "COLDLINE"
    }
  }

  versioning {
    enabled = true
  }

  labels = var.labels

  project = var.project_id
}

resource "google_storage_bucket_iam_member" "backup_bucket_iam" {
  count = var.backup_enabled ? 1 : 0

  bucket = google_storage_bucket.backup_bucket[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:db-${var.environment}-sa@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_compute_resource_policy" "daily_backup" {
  count = var.backup_enabled ? 1 : 0

  name   = "${var.environment}-daily-backup-policy"
  region = substr(var.zone, 0, length(var.zone) - 2)

  snapshot_schedule_policy {
    schedule {
      daily_schedule {
        days_in_cycle = 1
        start_time    = "02:00"
      }
    }

    retention_policy {
      max_retention_days    = var.retention_days
      on_source_disk_delete = "KEEP_AUTO_SNAPSHOTS"
    }

    snapshot_properties {
      labels            = var.labels
      storage_locations = ["us"]
      guest_flush       = false
    }
  }

  project = var.project_id
}

resource "null_resource" "backup_scripts" {
  count = var.backup_enabled ? 1 : 0

  provisioner "local-exec" {
    command = <<-EOT
      echo "Backup configuration for ${var.instance_name} created."
      echo "Backup bucket: ${local.backup_bucket_name}"
      echo "Retention days: ${var.retention_days}"
    EOT
  }

  triggers = {
    instance_id = var.instance_id
    bucket_name = var.backup_enabled ? google_storage_bucket.backup_bucket[0].name : ""
  }
}