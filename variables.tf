variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "${PROJECT_ID}"
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "${GCP_REGION}"
}

variable "zone" {
  description = "The GCP zone for resources"
  type        = string
  default     = "${GCP_ZONE}"
}

variable "environment" {
  description = "Environment name (staging or production)"
  type        = string
  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be either 'staging' or 'production'."
  }
}

variable "staging_instance_type" {
  description = "Instance type for staging environment"
  type        = string
  default     = "e2-standard-2"
}

variable "production_odoo_instance_type" {
  description = "Instance type for production Odoo server"
  type        = string
  default     = "c4-standard-4-lssd"
}

variable "production_db_instance_type" {
  description = "Instance type for production database server"
  type        = string
  default     = "n2-highmem-4"
}

variable "allowed_ssh_ips" {
  description = "List of IP ranges allowed to SSH into instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "domain_name" {
  description = "Domain name for the Odoo application"
  type        = string
  default     = ""
}

variable "ssl_email" {
  description = "Email address for Let's Encrypt SSL certificates"
  type        = string
  default     = ""
}

variable "odoo_admin_passwd" {
  description = "Odoo master admin password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_password" {
  description = "PostgreSQL database password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_monitoring" {
  description = "Enable GCP monitoring and logging"
  type        = bool
  default     = true
}

variable "enable_backups" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30
}

variable "odoo_version" {
  description = "Odoo version to install"
  type        = string
  default     = "18.0"
}

variable "postgresql_version" {
  description = "PostgreSQL version to install"
  type        = string
  default     = "15"
}

variable "odoo_workers" {
  description = "Number of Odoo worker processes"
  type        = number
  default     = 7
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    managed_by = "terraform"
    platform   = "odoo"
    version    = "v18"
  }
}