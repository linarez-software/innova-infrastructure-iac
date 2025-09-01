variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone for resources"
  type        = string
  default     = "us-central1-a"
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
  description = "Domain name for the application (staging subdomain)"
  type        = string
  default     = ""
}

variable "ssl_email" {
  description = "Email address for Let's Encrypt SSL certificates"
  type        = string
  default     = ""
}


variable "db_password" {
  description = "PostgreSQL database password for staging"
  type        = string
  sensitive   = true
  default     = "staging-db-2024"
}

variable "pgadmin_email" {
  description = "Default email for pgAdmin admin user"
  type        = string
  default     = "admin@staging.local"
}

variable "pgadmin_password" {
  description = "Default password for pgAdmin admin user (uses db_password if not set)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "staging_ssh_users" {
  description = "List of SSH users for staging environment (developers without GCP access)"
  type = list(object({
    username = string
    ssh_key  = string
  }))
  default = []
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
    version     = "v1.0"
    environment = "staging"
  }
}