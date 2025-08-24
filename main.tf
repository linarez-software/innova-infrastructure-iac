locals {
  project_name = "innova-odoo"
  common_labels = merge(
    var.labels,
    {
      environment = var.environment
      project     = local.project_name
    }
  )
  
  is_production = var.environment == "production"
  
  network_name = "${local.project_name}-${var.environment}-network"
  subnet_name  = "${local.project_name}-${var.environment}-subnet"
  
  odoo_instance_name = "${local.project_name}-${var.environment}-odoo"
  db_instance_name   = "${local.project_name}-${var.environment}-db"
}

resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "iam.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "iap.googleapis.com",
  ])
  
  service            = each.value
  disable_on_destroy = false
}

module "networking" {
  source = "./modules/networking"
  
  project_id      = var.project_id
  region          = var.region
  environment     = var.environment
  network_name    = local.network_name
  subnet_name     = local.subnet_name
  allowed_ssh_ips = var.allowed_ssh_ips
  labels          = local.common_labels
  
  depends_on = [google_project_service.required_apis]
}

module "security" {
  source = "./modules/security"
  
  project_id  = var.project_id
  environment = var.environment
  labels      = local.common_labels
  
  depends_on = [google_project_service.required_apis]
}

module "compute" {
  source = "./modules/compute"
  
  project_id                    = var.project_id
  region                        = var.region
  zone                          = var.zone
  environment                   = var.environment
  network_id                    = module.networking.network_id
  subnet_id                     = module.networking.subnet_id
  staging_instance_type         = var.staging_instance_type
  production_odoo_instance_type = var.production_odoo_instance_type
  production_db_instance_type   = var.production_db_instance_type
  odoo_service_account_email    = module.security.odoo_service_account_email
  db_service_account_email      = module.security.db_service_account_email
  domain_name                   = var.domain_name
  ssl_email                     = var.ssl_email
  odoo_admin_passwd             = var.odoo_admin_passwd
  db_password                   = var.db_password
  odoo_version                  = var.odoo_version
  postgresql_version            = var.postgresql_version
  odoo_workers                  = var.odoo_workers
  labels                        = local.common_labels
  
  depends_on = [
    module.networking,
    module.security
  ]
}

module "database" {
  source = "./modules/database"
  
  project_id         = var.project_id
  environment        = var.environment
  zone               = var.zone
  instance_id        = local.is_production ? module.compute.db_instance_id : module.compute.odoo_instance_id
  instance_name      = local.is_production ? module.compute.db_instance_name : module.compute.odoo_instance_name
  backup_enabled     = var.enable_backups
  retention_days     = var.backup_retention_days
  labels             = local.common_labels
  
  depends_on = [module.compute]
}

module "monitoring" {
  source = "./modules/monitoring"
  
  count = var.enable_monitoring ? 1 : 0
  
  project_id                   = var.project_id
  environment                  = var.environment
  odoo_instance_id             = module.compute.odoo_instance_id
  db_instance_id               = local.is_production ? module.compute.db_instance_id : ""
  monitoring_service_account   = module.security.monitoring_service_account_email
  alert_notification_email     = var.ssl_email
  labels                       = local.common_labels
  
  depends_on = [
    module.compute,
    module.security
  ]
}