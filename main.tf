# -------------------------------
# Networking (VPC and Subnet)
# -------------------------------
resource "google_compute_network" "vpc" {
  name                    = local.names.network
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "subnet" {
  name                     = local.names.subnet
  ip_cidr_range            = var.subnet_cidr
  network                  = google_compute_network.vpc.id
  region                   = var.region
  private_ip_google_access = true
}

# -------------------------------
# Firewall Rules
# -------------------------------
resource "google_compute_firewall" "allow_http_https" {
  name    = local.names.fw_http_https
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["80"]  
  }

  # Use both custom tag and GCP predefined tags
  target_tags   = [local.web_tag, "http-server", "https-server"]
  source_ranges = ["0.0.0.0/0"]
  description   = "Allow HTTP and HTTPS traffic from anywhere"
}

resource "google_compute_firewall" "allow_ssh_anywhere" {
  name    = "${var.name_prefix}-allow-ssh"
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags   = [local.web_tag, "http-server", "https-server"]
  source_ranges = ["0.0.0.0/0"]
  description   = "Allow SSH access from anywhere"
}

resource "google_compute_firewall" "allow_lb_health_checks" {
  name    = local.names.fw_hc
  network = google_compute_network.vpc.id

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  target_tags = [local.web_tag, "http-server", "https-server"]
  source_ranges = [
    "130.211.0.0/22",  # Google Cloud Load Balancer health check ranges
    "35.191.0.0/16",   # Google Cloud Load Balancer health check ranges
  ]
  description = "Allow health checks from Google Cloud Load Balancers"
}

# -------------------------------
# Instance Template
# -------------------------------
resource "google_compute_instance_template" "instance_template" {
  name         = local.names.instance_template
  machine_type = var.instance_type
  
  tags = [local.web_tag, "http-server"]

  disk {
    auto_delete  = true
    boot         = true
    source_image = "ubuntu-minimal-2404-noble-amd64-v20250818"
  }

  network_interface {
    network    = google_compute_network.vpc.id
    subnetwork = google_compute_subnetwork.subnet.id
    
    access_config {
     
    }
  }


  metadata_startup_script = <<-EOT
#!/bin/bash
# =======================================================
# GCP Academic Project - Python Web Server Deployment
# Enhanced with Beautiful Modern UI
# =======================================================

set -e  # Exit immediately if a command exits with a non-zero status

# -------------------------------
# Update & Install Dependencies
# -------------------------------
echo "[INFO] Updating system & installing Python..."
sudo apt-get update -y
sudo apt-get install -y python3 python3-pip curl

# -------------------------------
# Fetch Instance Metadata
# -------------------------------
echo "[INFO] Fetching GCP instance metadata..."
HOSTNAME=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/hostname)
PROJECT_ID=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/project/project-id)
ZONE=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/zone | awk -F/ '{print $NF}')
INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)

# -------------------------------
# Setup Application Directory
# -------------------------------
echo "[INFO] Setting up application directory..."
sudo mkdir -p /app
sudo chown $USER:$USER /app

# -------------------------------
# Create Python Web Server
# -------------------------------
echo "[INFO] Creating Python web server script..."
sudo tee /app/web_server.py > /dev/null << 'EOF'
from http.server import BaseHTTPRequestHandler, HTTPServer
import socket, os

class WebServerHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()

            hostname = socket.gethostname()
            project_id = os.environ.get('PROJECT_ID', 'Not available')
            zone = os.environ.get('ZONE', 'Not available')
            internal_ip = os.environ.get('INTERNAL_IP', 'Not available')

            html_content = f"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>GCP Academic Project - Cloud Infrastructure Demo</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
<style>
* {{{{
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}}}}

body {{{{
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 50%, #f093fb 100%);
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 20px;
  position: relative;
  overflow-x: hidden;
}}}}

body::before {{{{
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: url("data:image/svg+xml,%3Csvg width='60' height='60' viewBox='0 0 60 60' xmlns='http://www.w3.org/2000/svg'%3E%3Cg fill='none' fill-rule='evenodd'%3E%3Cg fill='%23ffffff' fill-opacity='0.03'%3E%3Ccircle cx='30' cy='30' r='2'/%3E%3C/g%3E%3C/g%3E%3C/svg%3E") repeat;
  pointer-events: none;
}}}}

.container {{{{
  max-width: 1000px;
  width: 100%;
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(20px);
  border-radius: 24px;
  box-shadow: 0 32px 64px -8px rgba(0, 0, 0, 0.25);
  border: 1px solid rgba(255, 255, 255, 0.2);
  position: relative;
  overflow: hidden;
  animation: slideUp 0.8s ease-out;
}}}}

.container::before {{{{
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 4px;
  background: linear-gradient(90deg, #ff6b6b, #4ecdc4, #45b7d1, #96ceb4, #ffeaa7);
  background-size: 300% 100%;
  animation: gradientShift 3s ease infinite;
}}}}

@keyframes slideUp {{{{
  from {{{{
    opacity: 0;
    transform: translateY(30px);
  }}}}
  to {{{{
    opacity: 1;
    transform: translateY(0);
  }}}}
}}}}

@keyframes gradientShift {{{{
  0%, 100% {{{{ background-position: 0% 50%; }}}}
  50% {{{{ background-position: 100% 50%; }}}}
}}}}

.content {{{{
  padding: 60px 50px;
}}}}

.header {{{{
  text-align: center;
  margin-bottom: 50px;
}}}}

.student-info {{{{
  margin: 30px 0;
  display: flex;
  flex-direction: column;
  gap: 20px;
  align-items: center;
}}}}

.student-card {{{{
  background: rgba(255, 255, 255, 0.9);
  border-radius: 16px;
  padding: 24px 32px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.3);
  backdrop-filter: blur(10px);
}}}}

.student-name {{{{
  font-size: 1.5rem;
  font-weight: 600;
  color: #2d3748;
  margin-bottom: 8px;
  background: linear-gradient(135deg, #667eea, #764ba2);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}}}}

.student-id {{{{
  font-size: 1rem;
  color: #4a5568;
  font-weight: 500;
  font-family: 'Courier New', monospace;
}}}}

.project-title {{{{
  text-align: center;
  max-width: 600px;
}}}}

.project-title h4 {{{{
  font-size: 1.1rem;
  color: #4a5568;
  margin-bottom: 12px;
  font-weight: 500;
}}}}

.project-name {{{{
  font-size: 1.25rem;
  font-weight: 600;
  color: #2d3748;
  line-height: 1.5;
  background: linear-gradient(135deg, #4ecdc4, #44a08d);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}}}}

.title {{{{
  font-size: 3rem;
  font-weight: 700;
  color: #2d3748;
  margin-bottom: 16px;
  background: linear-gradient(135deg, #667eea, #764ba2);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}}}}

.subtitle {{{{
  font-size: 1.25rem;
  color: #718096;
  font-weight: 400;
  margin-bottom: 30px;
}}}}

.badges {{{{
  display: flex;
  gap: 12px;
  justify-content: center;
  flex-wrap: wrap;
}}}}

.badge {{{{
  padding: 8px 20px;
  background: linear-gradient(135deg, #667eea, #764ba2);
  color: white;
  border-radius: 50px;
  font-size: 0.875rem;
  font-weight: 500;
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);
}}}}

.cards-grid {{{{
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
  gap: 30px;
  margin: 50px 0;
}}}}

.card {{{{
  background: rgba(255, 255, 255, 0.8);
  border-radius: 16px;
  padding: 30px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.3);
  transition: all 0.3s ease;
  position: relative;
  overflow: hidden;
}}}}

.card::before {{{{
  content: '';
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  height: 3px;
  background: linear-gradient(90deg, #ff6b6b, #4ecdc4);
  transform: scaleX(0);
  transition: transform 0.3s ease;
}}}}

.card:hover {{{{
  transform: translateY(-5px);
  box-shadow: 0 16px 48px rgba(0, 0, 0, 0.15);
}}}}

.card:hover::before {{{{
  transform: scaleX(1);
}}}}

.card-title {{{{
  font-size: 1.5rem;
  font-weight: 600;
  color: #2d3748;
  margin-bottom: 20px;
  display: flex;
  align-items: center;
  gap: 12px;
}}}}

.icon {{{{
  width: 32px;
  height: 32px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 1.25rem;
}}}}

.icon-info {{{{ background: linear-gradient(135deg, #667eea, #764ba2); }}}}
.icon-objectives {{{{ background: linear-gradient(135deg, #4ecdc4, #44a08d); }}}}

.info-item {{{{
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 0;
  border-bottom: 1px solid rgba(0, 0, 0, 0.05);
}}}}

.info-item:last-child {{{{
  border-bottom: none;
}}}}

.info-label {{{{
  font-weight: 500;
  color: #4a5568;
}}}}

.info-value {{{{
  font-weight: 600;
  color: #2d3748;
  background: linear-gradient(135deg, #ffeaa7, #fdcb6e);
  padding: 4px 12px;
  border-radius: 6px;
  font-family: 'Courier New', monospace;
  font-size: 0.875rem;
}}}}

.objectives-list {{{{
  list-style: none;
  padding: 0;
}}}}

.objectives-list li {{{{
  padding: 16px 0;
  border-bottom: 1px solid rgba(0, 0, 0, 0.05);
  position: relative;
  padding-left: 40px;
  color: #4a5568;
  line-height: 1.6;
}}}}

.objectives-list li:last-child {{{{
  border-bottom: none;
}}}}

.objectives-list li::before {{{{
  content: '✨';
  position: absolute;
  left: 0;
  top: 16px;
  width: 24px;
  height: 24px;
  background: linear-gradient(135deg, #4ecdc4, #44a08d);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
}}}}

.tech-section {{{{
  margin: 40px 0;
  text-align: center;
}}}}

.tech-title {{{{
  font-size: 1.75rem;
  font-weight: 600;
  color: #2d3748;
  margin-bottom: 30px;
}}}}

.tech-tags {{{{
  display: flex;
  gap: 16px;
  justify-content: center;
  flex-wrap: wrap;
}}}}

.tech-tag {{{{
  padding: 12px 24px;
  background: linear-gradient(135deg, #a8edea, #fed6e3);
  color: #2d3748;
  border-radius: 50px;
  font-weight: 500;
  font-size: 0.875rem;
  box-shadow: 0 4px 12px rgba(168, 237, 234, 0.3);
  transition: all 0.3s ease;
}}}}

.tech-tag:hover {{{{
  transform: translateY(-2px);
  box-shadow: 0 8px 20px rgba(168, 237, 234, 0.4);
}}}}

.footer {{{{
  margin-top: 60px;
  padding-top: 30px;
  border-top: 1px solid rgba(0, 0, 0, 0.1);
  text-align: center;
}}}}

.footer-content {{{{
  color: #718096;
  font-size: 0.875rem;
  margin-bottom: 16px;
}}}}

.status-indicator {{{{
  display: inline-flex;
  align-items: center;
  gap: 8px;
  background: rgba(72, 187, 120, 0.1);
  color: #38a169;
  padding: 8px 16px;
  border-radius: 50px;
  font-size: 0.875rem;
  font-weight: 500;
}}}}

.status-dot {{{{
  width: 8px;
  height: 8px;
  background: #38a169;
  border-radius: 50%;
  animation: pulse 2s infinite;
}}}}

@keyframes pulse {{{{
  0%, 100% {{{{ opacity: 1; }}}}
  50% {{{{ opacity: 0.5; }}}}
}}}}

@media (max-width: 768px) {{{{
  .content {{{{ padding: 40px 30px; }}}}
  .title {{{{ font-size: 2.5rem; }}}}
  .cards-grid {{{{ grid-template-columns: 1fr; gap: 20px; }}}}
  .tech-tags {{{{ gap: 12px; }}}}
  .badges {{{{ gap: 8px; }}}}
  .student-info {{{{ gap: 16px; }}}}
  .student-card {{{{ padding: 20px 24px; }}}}
  .student-name {{{{ font-size: 1.25rem; }}}}
  .project-name {{{{ font-size: 1.1rem; }}}}
}}}}
</style>
</head>
<body>
<div class="container">
  <div class="content">
    <div class="header">
      <h1 class="title">🚀 GCP Academic Project</h1>
      <p class="subtitle">Cloud Infrastructure & DevOps Excellence</p>
      
      <div class="student-info">
        <div class="student-card">
          <div class="student-details">
            <h3 class="student-name">Sukrit Singh</h3>
            <p class="student-id">BITS ID: 202117BH134</p>
          </div>
        </div>
        <div class="project-title">
          <h4>Capstone Project Work Title:</h4>
          <p class="project-name">Scalable Web Hosting on Google Cloud using GCP resources Built by Terraform</p>
        </div>
      </div>
      
      <div class="badges">
        <span class="badge">Google Cloud Platform</span>
        <span class="badge">Infrastructure as Code</span>
        <span class="badge">DevOps</span>
      </div>
    </div>

    <div class="cards-grid">
      <div class="card">
        <h2 class="card-title">
          <span class="icon icon-info">☁️</span>
          Instance Information
        </h2>
        <div class="info-item">
          <span class="info-label">Hostname</span>
          <span class="info-value">{hostname}</span>
        </div>
        <div class="info-item">
          <span class="info-label">Project ID</span>
          <span class="info-value">{project_id}</span>
        </div>
        <div class="info-item">
          <span class="info-label">Zone</span>
          <span class="info-value">{zone}</span>
        </div>
        <div class="info-item">
          <span class="info-label">Internal IP</span>
          <span class="info-value">{internal_ip}</span>
        </div>
      </div>

      <div class="card">
        <h2 class="card-title">
          <span class="icon icon-objectives">🎯</span>
          Project Objectives
        </h2>
        <ul class="objectives-list">
          <li>Provision infrastructure with Terraform (VPC, Firewall, subnet, Managed Instance Group, instance template, Load Balancer)</li>
          <li>Deploy scalable Python HTTP server with instance metadata</li>
          <li>Implement CI/CD pipeline via Google Cloud Build</li>
          <li>Configure autoscaling with comprehensive load testing</li>
        </ul>
      </div>
    </div>

    <div class="tech-section">
      <h2 class="tech-title">Technologies & Concepts</h2>
      <div class="tech-tags">
        <span class="tech-tag">Cloud Computing</span>
        <span class="tech-tag">Infrastructure Automation</span>
        <span class="tech-tag">Terraform</span>
        <span class="tech-tag">Python</span>
        <span class="tech-tag">Load Balancing</span>
        <span class="tech-tag">Autoscaling</span>
      </div>
    </div>

    <div class="footer">
      <div class="footer-content">
        <div class="status-indicator">
          <span class="status-dot"></span>
          Service Running Successfully
        </div>
      </div>
      <div class="footer-content">
        © 2025 GCP Academic Project | Sukrit Singh (202117BH134) | Modern Cloud Infrastructure Demo
      </div>
    </div>
  </div>
</div>
</body>
</html>
"""
            self.wfile.write(html_content.encode("utf-8"))
        elif self.path == '/health':
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b'Healthy')
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not Found')

def run_server():
    httpd = HTTPServer(("", 80), WebServerHandler)
    print("Web server started on port 80...")
    httpd.serve_forever()

if __name__ == '__main__':
    run_server()
EOF

# -------------------------------
# Export Environment Variables
# -------------------------------
echo "[INFO] Exporting environment variables..."
export PROJECT_ID="$PROJECT_ID"
export ZONE="$ZONE"
export INTERNAL_IP="$INTERNAL_IP"

# -------------------------------
# Prepare Logging
# -------------------------------
sudo touch /var/log/web_server.log
sudo chown $USER:$USER /var/log/web_server.log

# -------------------------------
# Systemd Service Setup
# -------------------------------
echo "[INFO] Creating systemd service..."
sudo tee /etc/systemd/system/web_server.service > /dev/null << EOF
[Unit]
Description=Python Web Server
After=network.target

[Service]
Type=simple
WorkingDirectory=/app
Environment="PROJECT_ID=$PROJECT_ID"
Environment="ZONE=$ZONE"
Environment="INTERNAL_IP=$INTERNAL_IP"
ExecStart=/usr/bin/python3 /app/web_server.py
Restart=always
RestartSec=5
StandardOutput=file:/var/log/web_server.log
StandardError=file:/var/log/web_server.log

[Install]
WantedBy=multi-user.target
EOF

# -------------------------------
# Enable & Start Service
# -------------------------------
echo "[INFO] Starting web server service..."
sudo systemctl daemon-reload
sudo systemctl enable web_server.service
sudo systemctl start web_server.service

# -------------------------------
#  Success Message
# -------------------------------
echo "======================================================="
echo "  Beautiful Python web server deployed successfully!"
echo "  Modern UI with stunning visual effects"
echo "  Accessible on port 80"
echo "  Auto-starts on reboot"
echo "  Logs at /var/log/web_server.log"
echo "======================================================="

# -------------------------------
#  Make this script self-executable (first run only)
# -------------------------------
SCRIPT_PATH="$HOME/startup_script.sh"
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "[INFO] Saving this script as $SCRIPT_PATH for reuse..."
    cp "$0" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    echo "[INFO] Script saved for future runs!"
fi
EOT

  # Ensure the instance template can be recreated
  lifecycle {
    create_before_destroy = true
  }
}

# -------------------------------
# Managed Instance Group
# -------------------------------
resource "google_compute_instance_group_manager" "mig" {
  name               = local.names.mig
  base_instance_name = "web"
  zone               = var.zone
  target_size        = 2

  version {
    instance_template = google_compute_instance_template.instance_template.self_link
  }

  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_http_health_check.hc.id
    initial_delay_sec = 300
  }

  update_policy {
    type                           = "PROACTIVE"
    minimal_action                 = "RESTART"
    max_surge_fixed                = 1
    max_unavailable_fixed          = 1
    most_disruptive_allowed_action = "REPLACE"
  }

  depends_on = [google_compute_instance_template.instance_template]
}

resource "google_compute_autoscaler" "asg" {
  name   = local.names.asg
  zone   = var.zone
  target = google_compute_instance_group_manager.mig.id

  autoscaling_policy {
    min_replicas    = var.autoscaler_min_replicas
    max_replicas    = var.autoscaler_max_replicas
    cooldown_period = 60

    cpu_utilization {
      target = 0.5
    }
  }
}

# -------------------------------
# HTTP Load Balancer
# -------------------------------
resource "google_compute_http_health_check" "hc" {
  name               = local.names.hc
  request_path       = "/"
  check_interval_sec = 10
  timeout_sec        = 5
}

resource "google_compute_backend_service" "backend" {
  name                  = local.names.backend
  protocol              = "HTTP"
  timeout_sec           = 60
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
