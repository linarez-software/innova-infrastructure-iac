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

variable "production_odoo_instance_type" {
  description = "Instance type for production Odoo server (optimized for performance)"
  type        = string
  default     = "c4-standard-4-lssd"
  
  validation {
    condition = contains([
      "c4-standard-4-lssd",
      "c3-standard-4",
      "e2-standard-4",
      "n2-standard-4"
    ], var.production_odoo_instance_type)
    error_message = "Production Odoo instance type must be a valid high-performance instance type."
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
  description = "Domain name for the Odoo application (required for production)"
  type        = string
  
  validation {
    condition     = var.domain_name != ""
    error_message = "Domain name is required for production environment."
  }
}

variable "ssl_email" {
  description = "Email address for Let's Encrypt SSL certificates (required for production)"
  type        = string
  
  validation {
    condition     = can(regex("^[\\w\\.-]+@[\\w\\.-]+\\.[a-zA-Z]{2,}$", var.ssl_email))
    error_message = "Valid email address is required for SSL certificates in production."
  }
}

variable "odoo_admin_passwd" {
  description = "Odoo master admin password for production"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.odoo_admin_passwd) >= 12
    error_message = "Production admin password must be at least 12 characters long."
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
  description = "Number of Odoo worker processes (optimized for 4 vCPUs)"
  type        = number
  default     = 7
  
  validation {
    condition     = var.odoo_workers >= 1 && var.odoo_workers <= 12
    error_message = "Odoo workers must be between 1 and 12."
  }
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    managed_by  = "terraform"
    platform    = "odoo"
    version     = "v18"
    environment = "production"
  }
}