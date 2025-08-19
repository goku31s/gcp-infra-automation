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

metadata_startup_script = <<'SCRIPT'
#!/bin/bash
set -euxo pipefail

# Install deps
apt-get update -y
apt-get install -y python3 curl

# Write the web app
cat > /usr/local/bin/webserver.py <<'PY'
import http.server, socketserver, os
from urllib.request import Request, urlopen

PORT = 80

def gcp_meta(path):
    req = Request(f"http://metadata.google.internal/computeMetadata/v1/{path}",
                  headers={"Metadata-Flavor":"Google"})
    with urlopen(req, timeout=2) as r:
        return r.read().decode()

def instance_name():
    try:
        return gcp_meta("instance/name")              # e.g., "mig-xyz-abc"
    except Exception:
        return os.uname().nodename

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        # Health endpoint for LB (also keep "/" healthy)
        if self.path == "/healthz":
            self.send_response(200)
            self.send_header("Content-Type","text/plain")
            self.end_headers()
            self.wfile.write(b"ok")
            return

        name = instance_name()
        html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<title>GCP Infra Automation Project</title>
<meta name="viewport" content="width=device-width, initial-scale=1"/>
<style>
  body {{ font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial;
         background: linear-gradient(135deg,#0f2027,#203a43,#2c5364);
         color:#fff; margin:0; padding:32px; }}
  .wrap {{ max-width: 1000px; margin:0 auto; }}
  .hero {{ text-align:center; margin:10px 0 24px; }}
  .badge {{ display:inline-block; background:#18c6e5; color:#001018;
           padding:6px 12px; border-radius:999px; font-weight:700; }}
  h1 {{ font-size: 2.4rem; margin: 12px 0 8px; }}
  .served {{ font-size:1.1rem; opacity:.9; }}
  .vm {{ display:inline-block; margin-top:8px; background:#111827; padding:6px 10px;
         border-radius:8px; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }}
  .grid {{ display:grid; gap:16px; grid-template-columns:1fr; }}
  @media (min-width:900px) {{ .grid {{ grid-template-columns:1fr 1fr; }} }}
  .card {{ background: rgba(0,0,0,.55); border:1px solid rgba(255,255,255,.1);
           border-radius:14px; padding:18px 20px; box-shadow:0 8px 24px rgba(0,0,0,.25); }}
  h2 {{ color:#ffdd57; margin:4px 0 8px; }}
  p {{ line-height:1.6; }}
  ul {{ padding-left: 18px; }}
  li {{ margin:6px 0; }}
  footer {{ text-align:center; opacity:.75; margin-top:24px; font-size:.9rem; }}
</style>
</head>
<body>
  <div class="wrap">
    <div class="hero">
      <span class="badge">Academic Project · Terraform × Cloud Build × GCP</span>
      <h1>Scalable Python Web App on GCP</h1>
      <div class="served">Served by VM:</div>
      <div class="vm">{name}</div>
      <div style="margin-top:8px; opacity:.9;">Refresh to see load-balancer rotation across instances.</div>
    </div>

    <div class="grid">
      <div class="card">
        <h2>Broad Area of Work</h2>
        <p>This project is part of the academic areas of <b>Cloud Computing</b>, <b>Infrastructure Automation</b>, and <b>DevOps</b>, with a focus on <b>Google Cloud Platform (GCP)</b>.</p>
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
        <p>This is a self-initiated academic project to gain hands-on experience in deploying scalable infrastructure on a major cloud platform (GCP) and automating with modern DevOps tools.</p>
        <p>Traditionally, deployment required manual steps and physical servers. With GCP + Terraform + Cloud Build, deployment is quick, scalable, and programmable. The Python web server is deliberately simple and prints the VM hostname, clearly demonstrating load balancing and autoscaling.</p>
      </div>

      <div class="card">
        <h2>Objectives</h2>
        <ul>
          <li>Provision VPC, subnet, firewall rules (port 80)</li>
          <li>Create instance template for a Python web server</li>
          <li>Configure a Managed Instance Group with autoscaling</li>
          <li>Deploy an HTTP Load Balancer with health checks</li>
          <li>Show the VM hostname to visualize rotation</li>
          <li>Automate applies via Cloud Build (CI/CD)</li>
          <li>Simulate traffic to observe scaling behavior</li>
        </ul>
      </div>

      <div class="card">
        <h2>Scope of Work</h2>
        <p><b>In Scope:</b> Terraform modules for GCP infra · Python HTTP server · VPC/Firewall/MIG/LB · Cloud Build pipeline · Load simulation & monitoring.</p>
        <p><b>Out of Scope:</b> Complex apps or DBs · External web servers (Nginx/Apache) · Security hardening beyond defaults.</p>
      </div>
    </div>

    <footer>&copy; 2025 Sukrit Singh · GCP Infrastructure Automation</footer>
  </div>
</body>
</html>"""

        self.send_response(200)
        self.send_header("Content-Type","text/html; charset=utf-8")
        self.send_header("Cache-Control","no-store")
        self.end_headers()
        self.wfile.write(html.encode())

    # Quiet logs
    def log_message(self, fmt, *args):
        return

with socketserver.TCPServer(("", PORT), Handler) as httpd:
    httpd.serve_forever()
PY
chmod +x /usr/local/bin/webserver.py

# Run as a systemd service (restarts if it ever crashes)
cat > /etc/systemd/system/python-web.service <<'UNIT'
[Unit]
Description=Simple Python Web Server for MIG Demo
After=network-online.target
Wants=network-online.target

[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/webserver.py
Restart=always
RestartSec=2
User=root

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now python-web.service
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
