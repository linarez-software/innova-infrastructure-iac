output "notification_channel_id" {
  description = "ID of the notification channel"
  value       = google_monitoring_notification_channel.email.id
}

output "dashboard_id" {
  description = "ID of the monitoring dashboard"
  value       = google_monitoring_dashboard.odoo_dashboard.id
}

output "alert_policies" {
  description = "List of alert policy IDs"
  value = [
    google_monitoring_alert_policy.cpu_utilization.id,
    google_monitoring_alert_policy.memory_utilization.id,
    google_monitoring_alert_policy.disk_utilization.id,
    google_monitoring_alert_policy.instance_uptime.id
  ]
}

output "logging_metric_id" {
  description = "ID of the logging metric for Odoo errors"
  value       = google_logging_metric.odoo_errors.id
}