variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "project_name" {
  description = "The project name for resource naming"
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
  description = "The environment (staging or production)"
  type        = string
}

variable "network_id" {
  description = "The VPC network ID"
  type        = string
}

variable "subnet_id" {
  description = "The subnet ID where Jenkins will be deployed"
  type        = string
}

variable "subnet_cidr" {
  description = "The subnet CIDR block"
  type        = string
}

variable "vpn_subnet_cidr" {
  description = "The VPN subnet CIDR block for access control"
  type        = string
  default     = "10.8.0.0/24"
}

variable "jenkins_instance_type" {
  description = "The machine type for Jenkins server"
  type        = string
  default     = "e2-standard-4"
}

variable "jenkins_image" {
  description = "The OS image for Jenkins server"
  type        = string
  default     = "ubuntu-os-cloud/ubuntu-2204-lts"
}

variable "jenkins_data_disk_size" {
  description = "Size of the persistent disk for Jenkins data (GB)"
  type        = number
  default     = 100
}

variable "jenkins_service_account_email" {
  description = "Service account email for Jenkins instance"
  type        = string
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
}

variable "jenkins_domain" {
  description = "Domain name for Jenkins (optional, for SSL setup)"
  type        = string
  default     = ""
}

variable "ssl_email" {
  description = "Email for SSL certificate registration"
  type        = string
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
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}