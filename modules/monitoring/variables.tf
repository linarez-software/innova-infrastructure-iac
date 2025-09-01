variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "app_instance_id" {
  description = "Instance ID of application server"
  type        = string
}

variable "db_instance_id" {
  description = "Instance ID of database server"
  type        = string
  default     = ""
}

variable "monitoring_service_account" {
  description = "Monitoring service account email"
  type        = string
}

variable "alert_notification_email" {
  description = "Email for alert notifications"
  type        = string
}

variable "labels" {
  description = "Labels to apply"
  type        = map(string)
  default     = {}
}