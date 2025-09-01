locals {
  is_production = var.environment == "production"
}

resource "google_monitoring_notification_channel" "email" {
  display_name = "${var.environment}-email-notification"
  type         = "email"

  labels = {
    email_address = var.alert_notification_email
  }

  force_delete = false

  project = var.project_id
}

resource "google_monitoring_alert_policy" "cpu_utilization" {
  display_name = "${var.environment}-high-cpu-usage"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "VM CPU usage"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.8

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]


  documentation {
    content   = "CPU usage has exceeded 80% for 5 minutes."
    mime_type = "text/markdown"
  }

  project = var.project_id
}

resource "google_monitoring_alert_policy" "memory_utilization" {
  display_name = "${var.environment}-high-memory-usage"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "VM Memory usage"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"agent.googleapis.com/memory/percent_used\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 90

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]


  documentation {
    content   = "Memory usage has exceeded 90% for 5 minutes."
    mime_type = "text/markdown"
  }

  project = var.project_id
}

resource "google_monitoring_alert_policy" "disk_utilization" {
  display_name = "${var.environment}-high-disk-usage"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Disk usage"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"agent.googleapis.com/disk/percent_used\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 85

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]


  documentation {
    content   = "Disk usage has exceeded 85%."
    mime_type = "text/markdown"
  }

  project = var.project_id
}

resource "google_monitoring_alert_policy" "instance_uptime" {
  display_name = "${var.environment}-instance-down"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Instance is down"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/uptime\""
      duration        = "60s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]


  documentation {
    content   = "Instance appears to be down."
    mime_type = "text/markdown"
  }

  project = var.project_id
}

resource "google_monitoring_dashboard" "odoo_dashboard" {
  dashboard_json = jsonencode({
    displayName = "${var.environment}-odoo-dashboard"
    gridLayout = {
      widgets = [
        {
          title = "CPU Utilization"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/cpu/utilization\""
                }
              }
            }]
          }
        },
        {
          title = "Memory Usage"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"gce_instance\" AND metric.type=\"agent.googleapis.com/memory/percent_used\""
                }
              }
            }]
          }
        },
        {
          title = "Disk Usage"
          xyChart = {
            dataSets = [{
              timeSeriesQuery = {
                timeSeriesFilter = {
                  filter = "resource.type=\"gce_instance\" AND metric.type=\"agent.googleapis.com/disk/percent_used\""
                }
              }
            }]
          }
        },
        {
          title = "Network Traffic"
          xyChart = {
            dataSets = [
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/network/received_bytes_count\""
                  }
                }
              },
              {
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"gce_instance\" AND metric.type=\"compute.googleapis.com/instance/network/sent_bytes_count\""
                  }
                }
              }
            ]
          }
        }
      ]
    }
  })

  project = var.project_id
}

resource "google_logging_metric" "odoo_errors" {
  name   = "${var.environment}-odoo-errors"
  filter = "resource.type=\"gce_instance\" AND logName=~\".*odoo.*\" AND severity>=ERROR"

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
    labels {
      key         = "instance_name"
      value_type  = "STRING"
      description = "The name of the instance"
    }
  }

  label_extractors = {
    "instance_name" = "EXTRACT(resource.labels.instance_id)"
  }

  project = var.project_id
}

resource "google_monitoring_alert_policy" "database_connection_failures" {
  count = local.is_production ? 1 : 0

  display_name = "${var.environment}-database-connection-failures"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Database connection failures"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"logging.googleapis.com/user/${google_logging_metric.odoo_errors.name}\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]


  documentation {
    content   = "Database connection failures detected."
    mime_type = "text/markdown"
  }

  project = var.project_id
}

resource "google_monitoring_alert_policy" "local_ssd_performance" {
  count = local.is_production ? 1 : 0

  display_name = "${var.environment}-local-ssd-performance"
  combiner     = "OR"
  enabled      = true

  conditions {
    display_name = "Local SSD IOPS"

    condition_threshold {
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/disk/read_ops_count\""
      duration        = "300s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1000

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_RATE"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]


  documentation {
    content   = "Local SSD performance degradation detected."
    mime_type = "text/markdown"
  }

  project = var.project_id
}