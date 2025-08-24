variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "zone" {
  description = "The GCP zone"
  type        = string
}

variable "instance_id" {
  description = "Instance ID for database"
  type        = string
}

variable "instance_name" {
  description = "Instance name for database"
  type        = string
}

variable "backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "retention_days" {
  description = "Backup retention days"
  type        = number
  default     = 30
}

variable "labels" {
  description = "Labels to apply"
  type        = map(string)
  default     = {}
}