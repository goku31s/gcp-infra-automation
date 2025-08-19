# -------------------------------
# Networking (VPC and Subnet)
# -------------------------------
resource "google_compute_network" "vpc" {
  name                    = local.names.network
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "subnet" {
  name          = local.names.subnet
  ip_cidr_range = var.subnet_cidr
  network       = google_compute_network.vpc.id
  region        = var.region
  private_ip_google_access = true
}

# -------------------------------------
# Firewall (targeted to "web" tag)
# -------------------------------------
# Allow HTTP/HTTPS from anywhere to instances tagged "web"

resource "google_compute_firewall" "allow_http_https" {
  name    = local.names.fw_http_https
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  target_tags   = [local.web_tag]
  source_ranges = ["0.0.0.0/0"]
}

# Allow SSH from anywhere (for academic/demo purposes)
resource "google_compute_firewall" "allow_ssh_anywhere" {
  name    = "${var.name_prefix}-allow-ssh"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = [local.web_tag]
  source_ranges = ["0.0.0.0/0"]
}

# Allow LB Health Checks
resource "google_compute_firewall" "allow_lb_health_checks" {
  name    = local.names.fw_hc
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  target_tags = [local.web_tag]
  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16",
  ]
}

# -------------------------------------
# Instance Template (global resource)
# -------------------------------------
# NOTE: google_compute_instance_template is global (no 'region' field).
resource "google_compute_instance_template" "instance_template" {
  name         = local.names.instance_template
  machine_type = var.instance_type

  tags = [local.web_tag]

  disk {
    auto_delete  = true
    boot         = true
    source_image = "ubuntu-os-cloud/ubuntu-2004-lts"
  }

  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {} 
  }

  metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    apt-get update
    apt-get install -y apache2
    echo "Hostname is $(hostname)" > /var/www/html/index.html
    systemctl restart apache2
    systemctl enable ssh
    systemctl restart ssh
  SCRIPT
}

# -------------------------------------
# Managed Instance Group (zonal)
# -------------------------------------
resource "google_compute_instance_group_manager" "mig" {
  name               = local.names.mig
  base_instance_name = "web"
  zone               = var.zone

  # Start with 2 instances as requested
  target_size = 2

  version {
    instance_template = google_compute_instance_template.instance_template.self_link
  }

  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check       = google_compute_http_health_check.hc.id
    initial_delay_sec  = 300
  }

  update_policy {
    type                    = "PROACTIVE"
    minimal_action          = "RESTART"
    max_surge_fixed         = 1
    max_unavailable_fixed   = 1
    most_disruptive_allowed_action = "REPLACE"
  }

  depends_on = [google_compute_instance_template.instance_template]
}

# Autoscaler for the MIG
resource "google_compute_autoscaler" "asg" {
  name   = local.names.asg
  zone   = var.zone
  target = google_compute_instance_group_manager.mig.id

  autoscaling_policy {
    min_replicas    = var.autoscaler_min_replicas
    max_replicas    = var.autoscaler_max_replicas
    cooldown_period = 60

    cpu_utilization {
      # Scale out when average CPU > 1%
      target = 0.01
    }
  }
}

# -------------------------------------
# HTTP Load Balancer (External, Classic)
# -------------------------------------
resource "google_compute_http_health_check" "hc" {
  name               = local.names.hc
  request_path       = "/"
  check_interval_sec = 5
  timeout_sec        = 5
}

resource "google_compute_backend_service" "backend" {
  name                  = local.names.backend
  protocol              = "HTTP"
  timeout_sec           = 10
  health_checks         = [google_compute_http_health_check.hc.id]
  load_balancing_scheme = "EXTERNAL"

  backend {
    group           = google_compute_instance_group_manager.mig.instance_group
    balancing_mode  = "UTILIZATION"
    max_utilization = 0.8
  }
}

resource "google_compute_url_map" "urlmap" {
  name            = local.names.urlmap
  default_service = google_compute_backend_service.backend.id
}

resource "google_compute_target_http_proxy" "proxy" {
  name    = local.names.proxy
  url_map = google_compute_url_map.urlmap.id
}

resource "google_compute_global_forwarding_rule" "forwarding_rule" {
  name                  = local.names.forwarding_rule
  target                = google_compute_target_http_proxy.proxy.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL"
  ip_protocol           = "TCP"
}
