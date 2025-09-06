variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "deep-wares-246918"
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

variable "db_password" {
  description = "PostgreSQL database password for staging"
  type        = string
  sensitive   = true
}

variable "enable_jenkins" {
  description = "Enable Jenkins server (optional for staging)"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default = {
    managed_by  = "terraform"
    environment = "staging"
    cost_center = "development"
  }
}