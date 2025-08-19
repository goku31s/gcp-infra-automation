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
    source_image = "ubuntu-os-cloud/ubuntu-2204-lts"
  }

  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.subnet.id
    access_config {} 
  }

metadata_startup_script = <<-SCRIPT
  #!/bin/bash
  apt-get update -y
  apt-get install -y python3

  cat > /var/www/project.html <<'EOF'
  <!DOCTYPE html>
  <html lang="en">
  <head>
    <meta charset="UTF-8">
    <title>GCP Infra Automation Project</title>
    <style>
      body {
        font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
        background: linear-gradient(to right, #0f2027, #203a43, #2c5364);
        color: #fff;
        margin: 0;
        padding: 40px;
        text-align: center;
      }
      h1 {
        font-size: 3em;
        color: #ffdd57;
      }
      h2 {
        margin-top: 40px;
        color: #4ee1ec;
      }
      p, li {
        font-size: 1.1em;
        line-height: 1.6;
        max-width: 900px;
        margin: 10px auto;
        text-align: justify;
      }
      ul {
        list-style-type: "✔ ";
        padding-left: 0;
      }
      .card {
        background: rgba(0,0,0,0.6);
        padding: 20px;
        margin: 25px auto;
        border-radius: 12px;
        box-shadow: 0 4px 12px rgba(0,0,0,0.4);
        max-width: 1000px;
      }
      footer {
        margin-top: 40px;
        font-size: 0.85em;
        opacity: 0.7;
      }
    </style>
  </head>
  <body>
    <h1>🚀 GCP Infrastructure Automation Project</h1>

    <div class="card">
      <h2>Broad Area of Work</h2>
      <p>
        This project is part of the academic areas of <strong>Cloud Computing</strong>, 
        <strong>Infrastructure Automation</strong>, and <strong>DevOps</strong>, with a strong 
        focus on the <strong>Google Cloud Platform (GCP)</strong>.
      </p>
      <ul>
        <li>Infrastructure as Code (IaC) using Terraform</li>
        <li>Cloud-native resource provisioning on GCP</li>
        <li>CI/CD Automation using Google Cloud Build</li>
        <li>Compute Engine, VPC networking, Load Balancing, and Autoscaling</li>
        <li>Hosting a basic Python web application served from Managed Instance Groups</li>
      </ul>
    </div>

    <div class="card">
      <h2>Background</h2>
      <p>
        This is a self-initiated academic project motivated by the goal of gaining hands-on 
        experience in deploying scalable infrastructure using GCP and automating the process 
        with modern DevOps tools.
      </p>
      <p>
        Traditionally, deploying a web application required manual steps and physical servers. 
        GCP’s managed services, combined with Terraform and Cloud Build, allow quick, scalable, 
        and programmable deployment. The Python web server demonstrates load balancing and 
        auto-scaling behavior clearly.
      </p>
    </div>

    <div class="card">
      <h2>Objectives</h2>
      <ul>
        <li>Provision VPC, subnet, firewall rules (port 80), and compute infrastructure</li>
        <li>Create instance template for Python web server</li>
        <li>Configure Managed Instance Group with autoscaling</li>
        <li>Deploy HTTP Load Balancer with health checks</li>
        <li>Host a Python web page displaying VM hostname</li>
        <li>Automate infra changes via Cloud Build CI/CD</li>
        <li>Simulate traffic to test autoscaling and balancing</li>
      </ul>
    </div>

    <div class="card">
      <h2>Scope of Work</h2>
      <p><strong>In Scope:</strong></p>
      <ul>
        <li>Terraform modules for GCP infra</li>
        <li>Python HTTP server serving VM hostname</li>
        <li>VPC, firewall, MIG, Load Balancer creation</li>
        <li>CI/CD pipeline with Cloud Build</li>
        <li>Load testing and monitoring autoscaling</li>
      </ul>
      <p><strong>Out of Scope:</strong></p>
      <ul>
        <li>Complex web applications / database integration</li>
        <li>External web servers like Nginx/Apache</li>
        <li>Advanced security hardening</li>
      </ul>
    </div>

    <footer>
      &copy; 2025 Sukrit Singh | Academic Project – GCP Infrastructure Automation
    </footer>
  </body>
  </html>
  EOF

  # Start Python HTTP server on port 80
  cd /var/www
  nohup python3 -m http.server 80 --directory /var/www > server.log 2>&1 &
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
