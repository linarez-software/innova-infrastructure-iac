variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
}

variable "zone" {
  description = "The GCP zone for resources"
  type        = string
}

variable "production_app_instance_type" {
  description = "Instance type for production application server (optimized for performance)"
  type        = string
  default     = "c4-standard-4-lssd"

  validation {
    condition = contains([
      "c4-standard-4-lssd",
      "c3-standard-4",
      "e2-standard-4",
      "n2-standard-4"
    ], var.production_app_instance_type)
    error_message = "Production application instance type must be a valid high-performance instance type."
  }
}

variable "production_db_instance_type" {
  description = "Instance type for production database server (optimized for memory)"
  type        = string
  default     = "n2-highmem-4"

  validation {
    condition = contains([
      "n2-highmem-4",
      "n2-highmem-8",
      "n1-highmem-4",
      "n1-highmem-8"
    ], var.production_db_instance_type)
    error_message = "Production database instance type must be a valid high-memory instance type."
  }
}

variable "allowed_ssh_ips" {
  description = "List of IP ranges allowed to SSH into instances"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.allowed_ssh_ips) > 0
    error_message = "SSH access must be restricted to specific IP ranges in production."
  }
}

variable "domain_name" {
  description = "Domain name for the application (optional for production)"
  type        = string
  default     = ""
}

variable "ssl_email" {
  description = "Email address for monitoring alerts"
  type        = string

  validation {
    condition     = can(regex("^[\\w\\.-]+@[\\w\\.-]+\\.[a-zA-Z]{2,}$", var.ssl_email))
    error_message = "Valid email address is required for monitoring alerts."
  }
}

variable "db_password" {
  description = "PostgreSQL database password for production"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 12
    error_message = "Production database password must be at least 12 characters long."
  }
}

variable "enable_monitoring" {
  description = "Enable GCP monitoring and logging (recommended for production)"
  type        = bool
  default     = true
}

variable "enable_backups" {
  description = "Enable automated backups (required for production)"
  type        = bool
  default     = true
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 30

  validation {
    condition     = var.backup_retention_days >= 7
    error_message = "Backup retention must be at least 7 days for production."
  }
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
    platform    = "infrastructure"
    version     = "v1-0"
    environment = "production"
  }
}