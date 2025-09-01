output "zone_name" {
  description = "The name of the DNS managed zone"
  value       = local.managed_zone_name
}

output "name_servers" {
  description = "The name servers for the DNS zone"
  value       = var.create_zone ? google_dns_managed_zone.main[0].name_servers : data.google_dns_managed_zone.main[0].name_servers
}

output "dns_records" {
  description = "Map of all DNS records created"
  value = {
    # Production
    root                = google_dns_record_set.root.name
    www                 = google_dns_record_set.www.name
    db_production       = var.db_production_ip != "" ? google_dns_record_set.db_production[0].name : null
    vpn_production      = google_dns_record_set.vpn_production.name
    jenkins_production  = var.jenkins_production_ip != "" ? google_dns_record_set.jenkins_production[0].name : null
    
    # Staging
    odoo_staging        = google_dns_record_set.odoo_staging.name
    vpn_staging         = google_dns_record_set.vpn_staging.name
    jenkins_staging     = var.jenkins_staging_ip != "" ? google_dns_record_set.jenkins_staging[0].name : null
    mailhog_staging     = var.enable_dev_tools_dns ? google_dns_record_set.mailhog_staging[0].name : null
    pgadmin_staging     = var.enable_dev_tools_dns ? google_dns_record_set.pgadmin_staging[0].name : null
  }
}

output "domain_urls" {
  description = "Full URLs for all configured services"
  value = {
    # Production URLs
    main_site           = "https://${var.domain_name}"
    www_site            = "https://www.${var.domain_name}"
    database            = var.db_production_ip != "" ? "https://db.${var.domain_name}" : null
    vpn_production      = "https://vpn.${var.domain_name}"
    jenkins_production  = var.jenkins_production_ip != "" ? "https://jenkins.${var.domain_name}" : null
    
    # Staging URLs
    odoo_staging        = "https://odoo.staging.${var.domain_name}"
    vpn_staging         = "https://vpn.staging.${var.domain_name}"
    jenkins_staging     = var.jenkins_staging_ip != "" ? "https://jenkins.staging.${var.domain_name}" : null
    mailhog_staging     = var.enable_dev_tools_dns ? "http://mailhog.staging.${var.domain_name}:8025" : null
    pgadmin_staging     = var.enable_dev_tools_dns ? "http://pgadmin.staging.${var.domain_name}:5050" : null
  }
}