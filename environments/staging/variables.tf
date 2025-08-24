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

variable "staging_instance_type" {
  description = "Instance type for staging environment"
  type        = string
  default     = "e2-standard-2"
}

variable "allowed_ssh_ips" {
  description = "List of IP ranges allowed to SSH into instances"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "domain_name" {
  description = "Domain name for the Odoo application (staging subdomain)"
  type        = string
  default     = ""
}

variable "ssl_email" {
  description = "Email address for Let's Encrypt SSL certificates"
  type        = string
  default     = ""
}

variable "odoo_admin_passwd" {
  description = "Odoo master admin password for staging"
  type        = string
  sensitive   = true
  default     = "staging-admin-2024"
}

variable "db_password" {
  description = "PostgreSQL database password for staging"
  type        = string
  sensitive   = true
  default     = "staging-db-2024"
}

variable "enable_monitoring" {
  description = "Enable GCP monitoring and logging"
  type        = bool
  default     = true
}

variable "enable_backups" {
  description = "Enable automated backups"
  type        = bool
  default     = false
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

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    managed_by  = "terraform"
    platform    = "odoo"
    version     = "v18"
    environment = "staging"
  }
}