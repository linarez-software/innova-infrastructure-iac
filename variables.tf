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

variable "production_app_instance_type" {
  description = "Instance type for production application server"
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
  description = "Domain name for the application"
  type        = string
  default     = ""
}

variable "ssl_email" {
  description = "Email address for Let's Encrypt SSL certificates"
  type        = string
  default     = ""
}

variable "db_password" {
  description = "PostgreSQL database password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "pgadmin_email" {
  description = "Default email for pgAdmin admin user (staging only)"
  type        = string
  default     = "admin@staging.local"
}

variable "pgadmin_password" {
  description = "Default password for pgAdmin admin user (uses db_password if empty, staging only)"
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

variable "postgresql_version" {
  description = "PostgreSQL version to install"
  type        = string
  default     = "15"
}

# Jenkins Configuration Variables
variable "enable_jenkins" {
  description = "Enable Jenkins CI/CD server deployment"
  type        = bool
  default     = true
}

variable "jenkins_instance_type" {
  description = "Instance type for Jenkins server"
  type        = string
  default     = "e2-standard-4"
}

variable "jenkins_data_disk_size" {
  description = "Size of the persistent disk for Jenkins data (GB)"
  type        = number
  default     = 100
}

variable "jenkins_admin_user" {
  description = "Jenkins admin username"
  type        = string
  default     = "admin"
}

variable "jenkins_admin_password" {
  description = "Jenkins admin password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "jenkins_domain" {
  description = "Domain name for Jenkins (optional, for SSL setup)"
  type        = string
  default     = ""
}

variable "jenkins_ssh_public_key" {
  description = "SSH public key for Jenkins user access"
  type        = string
  default     = ""
}

variable "github_token_secret" {
  description = "GitHub personal access token for repository access"
  type        = string
  sensitive   = true
  default     = ""
}

variable "docker_registry_secret" {
  description = "Docker registry credentials"
  type        = string
  sensitive   = true
  default     = ""
}

variable "staging_deploy_key_secret" {
  description = "SSH deploy key for staging environment"
  type        = string
  sensitive   = true
  default     = ""
}

variable "prod_deploy_key_secret" {
  description = "SSH deploy key for production environment"
  type        = string
  sensitive   = true
  default     = ""
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    managed_by = "terraform"
    platform   = "infrastructure"
    version    = "v1.0"
  }
}