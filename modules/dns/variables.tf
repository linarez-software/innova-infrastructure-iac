variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "domain_name" {
  description = "The domain name (e.g., innovaeyewear.com)"
  type        = string
}

variable "zone_name" {
  description = "The name of the DNS managed zone"
  type        = string
  default     = "innovaeyewear-zone"
}

variable "create_zone" {
  description = "Whether to create a new DNS zone or use an existing one"
  type        = bool
  default     = false
}

variable "ttl" {
  description = "TTL for DNS records in seconds"
  type        = number
  default     = 300
}

# Production IPs
variable "app_production_ip" {
  description = "External IP of the production application server"
  type        = string
}

variable "db_production_ip" {
  description = "External IP of the production database server"
  type        = string
  default     = ""
}

variable "vpn_production_ip" {
  description = "External IP of the production VPN server"
  type        = string
}

variable "jenkins_production_ip" {
  description = "External IP of the production Jenkins server"
  type        = string
  default     = ""
}

# Staging IPs
variable "app_staging_ip" {
  description = "External IP of the staging application server"
  type        = string
}

variable "vpn_staging_ip" {
  description = "External IP of the staging VPN server"
  type        = string
}

variable "jenkins_staging_ip" {
  description = "External IP of the staging Jenkins server"
  type        = string
  default     = ""
}

# Additional DNS options
variable "enable_dev_tools_dns" {
  description = "Create DNS records for staging development tools (mailhog, pgadmin)"
  type        = bool
  default     = true
}

variable "mx_records" {
  description = "MX records for email (format: 'priority mail-server.')"
  type        = list(string)
  default     = []
}

variable "txt_records" {
  description = "TXT records for domain verification, SPF, etc."
  type        = list(string)
  default     = []
}

variable "labels" {
  description = "Labels to apply to DNS resources"
  type        = map(string)
  default     = {}
}