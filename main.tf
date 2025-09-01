locals {
  project_name = "innova-infrastructure"
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

  app_instance_name = "${local.project_name}-${var.environment}-app"
  db_instance_name  = "${local.project_name}-${var.environment}-db"
}

resource "google_project_service" "required_apis" {
  for_each = toset([
    "compute.googleapis.com",
    "iam.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
    "iap.googleapis.com",
    "cloudkms.googleapis.com",
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

  project_id                   = var.project_id
  region                       = var.region
  zone                         = var.zone
  environment                  = var.environment
  network_id                   = module.networking.network_id
  subnet_id                    = module.networking.subnet_id
  staging_instance_type        = var.staging_instance_type
  production_app_instance_type = var.production_app_instance_type
  production_db_instance_type  = var.production_db_instance_type
  app_service_account_email    = module.security.app_service_account_email
  db_service_account_email     = module.security.db_service_account_email
  domain_name                  = var.domain_name
  ssl_email                    = var.ssl_email
  db_password                  = var.db_password
  postgresql_version           = var.postgresql_version
  pgadmin_email                = var.pgadmin_email
  pgadmin_password             = var.pgadmin_password
  labels                       = local.common_labels

  depends_on = [
    module.networking,
    module.security
  ]
}

module "database" {
  source = "./modules/database"

  project_id     = var.project_id
  environment    = var.environment
  zone           = var.zone
  instance_id    = local.is_production ? module.compute.db_instance_id : module.compute.app_instance_id
  instance_name  = local.is_production ? module.compute.db_instance_name : module.compute.app_instance_name
  backup_enabled = var.enable_backups
  retention_days = var.backup_retention_days
  labels         = local.common_labels

  depends_on = [module.compute]
}

module "vpn" {
  source = "./modules/vpn"

  project_id                = var.project_id
  region                    = var.region
  zone                      = var.zone
  environment               = var.environment
  network_id                = module.networking.network_id
  subnet_id                 = module.networking.subnet_id
  vpn_service_account_email = module.security.vpn_service_account_email
  vpn_admin_email           = var.ssl_email
  vpn_instance_type         = "e2-micro"
  vpn_subnet_cidr           = "10.8.0.0/24"
  max_vpn_clients           = 5
  labels                    = local.common_labels

  depends_on = [
    module.networking,
    module.security
  ]
}

module "jenkins" {
  source = "./modules/jenkins"

  count = var.enable_jenkins ? 1 : 0

  project_id                    = var.project_id
  project_name                  = local.project_name
  region                        = var.region
  zone                          = var.zone
  environment                   = var.environment
  network_id                    = module.networking.network_id
  subnet_id                     = module.networking.subnet_id
  subnet_cidr                   = module.networking.subnet_cidr
  vpn_subnet_cidr               = "10.8.0.0/24"
  jenkins_instance_type         = var.jenkins_instance_type
  jenkins_data_disk_size        = var.jenkins_data_disk_size
  jenkins_service_account_email = module.security.jenkins_service_account_email
  jenkins_admin_user            = var.jenkins_admin_user
  jenkins_admin_password        = var.jenkins_admin_password
  jenkins_domain                = var.jenkins_domain
  ssl_email                     = var.ssl_email
  jenkins_ssh_public_key        = var.jenkins_ssh_public_key
  github_token_secret           = var.github_token_secret
  docker_registry_secret        = var.docker_registry_secret
  staging_deploy_key_secret     = var.staging_deploy_key_secret
  prod_deploy_key_secret        = var.prod_deploy_key_secret
  labels                        = local.common_labels

  depends_on = [
    module.networking,
    module.security
  ]
}

module "monitoring" {
  source = "./modules/monitoring"

  count = var.enable_monitoring ? 1 : 0

  project_id                 = var.project_id
  environment                = var.environment
  app_instance_id            = module.compute.app_instance_id
  db_instance_id             = local.is_production ? module.compute.db_instance_id : ""
  monitoring_service_account = module.security.monitoring_service_account_email
  alert_notification_email   = var.ssl_email
  labels                     = local.common_labels

  depends_on = [
    module.compute,
    module.security
  ]
}