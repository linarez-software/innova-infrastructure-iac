variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "zone" {
  description = "The GCP zone"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "network_id" {
  description = "Network ID"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
}

variable "staging_instance_type" {
  description = "Instance type for staging"
  type        = string
  default     = "e2-standard-2"
}

variable "production_app_instance_type" {
  description = "Instance type for production application server"
  type        = string
  default     = "c4-standard-4-lssd"
}

variable "production_db_instance_type" {
  description = "Instance type for production database"
  type        = string
  default     = "n2-highmem-4"
}

variable "app_service_account_email" {
  description = "Service account email for application server"
  type        = string
}

variable "db_service_account_email" {
  description = "Service account email for database"
  type        = string
}

variable "domain_name" {
  description = "Domain name for application"
  type        = string
  default     = ""
}

variable "ssl_email" {
  description = "Email for SSL certificates"
  type        = string
  default     = ""
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "postgresql_version" {
  description = "PostgreSQL version"
  type        = string
  default     = "15"
}

variable "pgadmin_email" {
  description = "pgAdmin default admin email"
  type        = string
  default     = "admin@staging.local"
}

variable "pgadmin_password" {
  description = "pgAdmin default admin password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "labels" {
  description = "Labels to apply"
  type        = map(string)
  default     = {}
}