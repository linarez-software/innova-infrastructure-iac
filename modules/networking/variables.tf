variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC network"
  type        = string
}

variable "subnet_name" {
  description = "Name of the subnet"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR block for the subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "static_ips" {
  description = "Static IP address names"
  type = object({
    vpn_ip     = string
    app_ip     = string
    jenkins_ip = string
  })
}

variable "labels" {
  description = "Labels to apply to resources"
  type        = map(string)
  default     = {}
}