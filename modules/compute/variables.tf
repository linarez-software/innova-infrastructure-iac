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

variable "network_name" {
  description = "Network name"
  type        = string
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
}

# Application Server Configuration
variable "app_instance_name" {
  description = "Name of the application instance"
  type        = string
}

variable "app_machine_type" {
  description = "Machine type for application server"
  type        = string
  default     = "e2-standard-2"
}

variable "app_disk_size" {
  description = "Disk size for application server in GB"
  type        = number
  default     = 80
}

variable "app_static_ip" {
  description = "Static IP address for application server"
  type        = string
}

# Jenkins Server Configuration (Optional)
variable "enable_jenkins" {
  description = "Enable Jenkins server"
  type        = bool
  default     = false
}

variable "jenkins_instance_name" {
  description = "Name of the Jenkins instance"
  type        = string
  default     = ""
}

variable "jenkins_machine_type" {
  description = "Machine type for Jenkins server"
  type        = string
  default     = "e2-small"
}

variable "jenkins_disk_size" {
  description = "Disk size for Jenkins server in GB"
  type        = number
  default     = 30
}

variable "jenkins_static_ip" {
  description = "Static IP address for Jenkins server"
  type        = string
  default     = ""
}

# Common Configuration
variable "service_account_email" {
  description = "Service account email for instances"
  type        = string
  default     = null
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}