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

variable "vpn_service_account_email" {
  description = "Service account email for VPN"
  type        = string
}

variable "vpn_instance_type" {
  description = "Instance type for VPN server"
  type        = string
  default     = "e2-micro"
}

variable "vpn_admin_email" {
  description = "Admin email for VPN certificates"
  type        = string
}

variable "vpn_subnet_cidr" {
  description = "CIDR block for VPN clients"
  type        = string
  default     = "10.8.0.0/24"
}

variable "max_vpn_clients" {
  description = "Maximum number of VPN clients"
  type        = number
  default     = 5
}

variable "labels" {
  description = "Labels to apply"
  type        = map(string)
  default     = {}
}