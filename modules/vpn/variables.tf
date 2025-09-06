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

variable "instance_name" {
  description = "Name of the VPN instance"
  type        = string
}

variable "machine_type" {
  description = "Machine type for VPN server"
  type        = string
  default     = "e2-micro"
}

variable "network_name" {
  description = "Network name"
  type        = string
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
}

variable "static_ip" {
  description = "Static IP address for VPN server"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for VPN server"
  type        = string
  default     = null
}

variable "vpn_subnet_cidr" {
  description = "CIDR block for VPN clients"
  type        = string
  default     = "10.8.0.0/24"
}

variable "max_clients" {
  description = "Maximum number of VPN clients"
  type        = number
  default     = 5
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}