locals {
  vpn_instance_name = "vpn-${var.environment}"
  
  vpn_startup_script = templatefile("${path.module}/templates/openvpn-startup.sh", {
    vpn_subnet_ip     = "10.8.0.0"
    vpn_subnet_mask   = "255.255.255.0"
    max_vpn_clients   = var.max_vpn_clients
    vpn_admin_email   = var.vpn_admin_email
    environment       = var.environment
    internal_subnet   = "10.0.0.0/24"
    project_id        = var.project_id
    zone              = var.zone
  })
}

resource "google_compute_address" "vpn_static_ip" {
  name         = "${local.vpn_instance_name}-ip"
  address_type = "EXTERNAL"
  region       = var.region
  network_tier = "STANDARD"
  
  project = var.project_id
}

resource "google_compute_instance" "vpn_instance" {
  name         = local.vpn_instance_name
  machine_type = var.vpn_instance_type
  zone         = var.zone
  
  tags = [
    "vpn-server",
    "ssh-allowed"
  ]
  
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 10
      type  = "pd-standard"
    }
  }
  
  network_interface {
    subnetwork = var.subnet_id
    
    access_config {
      nat_ip       = google_compute_address.vpn_static_ip.address
      network_tier = "STANDARD"
    }
  }
  
  can_ip_forward = true
  
  metadata = {
    startup-script = local.vpn_startup_script
    enable-oslogin = "TRUE"
  }
  
  service_account {
    email  = var.vpn_service_account_email
    scopes = ["cloud-platform"]
  }
  
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                  = true
    enable_integrity_monitoring = true
  }
  
  labels = var.labels
  
  project = var.project_id
}

resource "google_storage_bucket" "vpn_configs" {
  name          = "${var.project_id}-${var.environment}-vpn-configs"
  location      = "US"
  force_destroy = true
  
  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }
  
  versioning {
    enabled = true
  }
  
  labels = var.labels
  
  project = var.project_id
}

resource "google_storage_bucket_iam_member" "vpn_bucket_access" {
  bucket = google_storage_bucket.vpn_configs.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.vpn_service_account_email}"
}

resource "null_resource" "vpn_client_configs" {
  depends_on = [google_compute_instance.vpn_instance]
  
  provisioner "local-exec" {
    command = <<-EOT
      echo "VPN Server configured at: ${google_compute_address.vpn_static_ip.address}"
      echo "VPN Client subnet: ${var.vpn_subnet_cidr}"
      echo "Max clients: ${var.max_vpn_clients}"
      echo ""
      echo "To generate client certificates:"
      echo "1. SSH to VPN server: gcloud compute ssh ${local.vpn_instance_name} --zone=${var.zone}"
      echo "2. Run: sudo /etc/openvpn/easy-rsa/easyrsa build-client-full client1 nopass"
      echo "3. Download config: sudo /opt/scripts/generate-client-config.sh client1"
    EOT
  }
  
  triggers = {
    instance_id = google_compute_instance.vpn_instance.instance_id
  }
}