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
    ports    = ["80", "443"]
  }

  target_tags   = [local.web_tag]
  source_ranges = ["0.0.0.0/0"]
}

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

# -------------------------------
# Instance Template
# -------------------------------
resource "google_compute_instance_template" "instance_template" {
  name         = local.names.instance_template
  machine_type = var.instance_type
  tags         = [local.web_tag]

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

  metadata_startup_script = <<-EOT
#!/bin/bash
apt-get update -y
apt-get install -y python3 python3-pip

# Fetch dynamic metadata
HOSTNAME=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/hostname)
PROJECT_ID=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/project/project-id)
ZONE=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/zone | awk -F/ '{print $NF}')
INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)

# Create Python web server script
cat > /app/web_server.py << 'PYTHON_SCRIPT'
from http.server import BaseHTTPRequestHandler, HTTPServer
import socket
import datetime
import os

class WebServerHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            
            hostname = socket.gethostname()
            current_time = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            
            # Read environment variables or use defaults
            project_id = os.environ.get('PROJECT_ID', 'Not available')
            zone = os.environ.get('ZONE', 'Not available')
            internal_ip = os.environ.get('INTERNAL_IP', 'Not available')
            
            html_content = f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>GCP Academic Project Demo</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            line-height: 1.6;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
            min-height: 100vh;
            padding: 20px;
        }}
        
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background: rgba(255, 255, 255, 0.95);
            border-radius: 15px;
            padding: 30px;
            box-shadow: 0 10px 30px rgba(0, 0, 0, 0.2);
        }}
        
        header {{
            text-align: center;
            margin-bottom: 30px;
            padding-bottom: 20px;
            border-bottom: 3px solid #667eea;
        }}
        
        h1 {{
            color: #2c3e50;
            font-size: 2.5em;
            margin-bottom: 10px;
            background: linear-gradient(45deg, #667eea, #764ba2);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }}
        
        .subtitle {{
            color: #7f8c8d;
            font-size: 1.2em;
        }}
        
        .section {{
            margin-bottom: 30px;
            padding: 20px;
            background: #f8f9fa;
            border-radius: 10px;
            border-left: 5px solid #667eea;
        }}
        
        .section h2 {{
            color: #2c3e50;
            margin-bottom: 15px;
            display: flex;
            align-items: center;
        }}
        
        .section h2::before {{
            content: "📌";
            margin-right: 10px;
            font-size: 1.2em;
        }}
        
        .info-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }}
        
        .info-card {{
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
            border: 1px solid #e9ecef;
        }}
        
        .info-card h3 {{
            color: #2c3e50;
            margin-bottom: 10px;
            display: flex;
            align-items: center;
        }}
        
        .info-card h3::before {{
            content: "🔹";
            margin-right: 8px;
        }}
        
        .highlight {{
            background: linear-gradient(45deg, #667eea, #764ba2);
            color: white;
            padding: 20px;
            border-radius: 10px;
            margin: 20px 0;
        }}
        
        .tech-stack {{
            display: flex;
            flex-wrap: wrap;
            gap: 10px;
            margin-top: 10px;
        }}
        
        .tech-tag {{
            background: linear-gradient(45deg, #667eea, #764ba2);
            color: white;
            padding: 5px 15px;
            border-radius: 20px;
            font-size: 0.9em;
            font-weight: 500;
        }}
        
        .objective-list {{
            list-style: none;
            padding: 0;
        }}
        
        .objective-list li {{
            padding: 10px 0;
            border-bottom: 1px solid #e9ecef;
            display: flex;
            align-items: center;
        }}
        
        .objective-list li::before {{
            content: "✅";
            margin-right: 10px;
            color: #27ae60;
        }}
        
        .scope-grid {{
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
        }}
        
        .in-scope, .out-scope {{
            background: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
        }}
        
        .in-scope h3 {{ color: #27ae60; }}
        .out-scope h3 {{ color: #e74c3c; }}
        
        footer {{
            text-align: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 2px solid #e9ecef;
            color: #7f8c8d;
        }}
        
        @media (max-width: 768px) {{
            .scope-grid {{
                grid-template-columns: 1fr;
            }}
            
            .container {{
                padding: 15px;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🚀 GCP Academic Project Live Demo</h1>
            <p class="subtitle">Cloud Computing & DevOps Infrastructure Automation</p>
        </header>

        <div class="info-grid">
            <div class="info-card">
                <h3>Instance Information</h3>
                <p><strong>Hostname:</strong> {hostname}</p>
                <p><strong>Project ID:</strong> {project_id}</p>
                <p><strong>Zone:</strong> {zone}</p>
                <p><strong>Internal IP:</strong> {internal_ip}</p>
                <p><strong>Server Time:</strong> {current_time}</p>
            </div>
            
            <div class="info-card">
                <h3>Load Balancer Info</h3>
                <p>This instance is part of a Managed Instance Group</p>
                <p>Traffic is distributed via GCP HTTP Load Balancer</p>
                <p>Refresh to see different instances serving requests</p>
            </div>
        </div>

        <div class="section">
            <h2>📚 Broad Area of Work</h2>
            <p>This project is part of the academic areas of <strong>Cloud Computing, Infrastructure Automation, and DevOps</strong>, with a strong focus on the Google Cloud Platform (GCP).</p>
            
            <div class="highlight">
                <h3>Key Technologies & Concepts:</h3>
                <div class="tech-stack">
                    <span class="tech-tag">Infrastructure as Code (IaC) using Terraform</span>
                    <span class="tech-tag">Cloud-native resource provisioning on GCP</span>
                    <span class="tech-tag">CI/CD Automation using Google Cloud Build</span>
                    <span class="tech-tag">Compute Engine, VPC networking</span>
                    <span class="tech-tag">Load Balancing and Autoscaling</span>
                    <span class="tech-tag">Managed Instance Groups</span>
                </div>
            </div>
            
            <p>Using GCP provides high scalability, reliability, and simplified DevOps workflows compared to traditional hosting methods.</p>
        </div>

        <div class="section">
            <h2>🎯 Project Objectives</h2>
            <ul class="objective-list">
                <li>Provision GCP infrastructure using Terraform (VPC, subnet, firewall rules)</li>
                <li>Create instance template for Python web server</li>
                <li>Set up Managed Instance Group (MIG) with autoscaling</li>
                <li>Configure HTTP Load Balancer with health checks</li>
                <li>Use Python's built-in HTTP server to host lightweight web pages</li>
                <li>Set up Cloud Build CI/CD for automatic infrastructure deployment</li>
                <li>Simulate high traffic to trigger autoscaling behavior</li>
                <li>Ensure even traffic distribution across healthy instances</li>
            </ul>
        </div>

        <div class="section">
            <h2>📋 Scope of Work</h2>
            <div class="scope-grid">
                <div class="in-scope">
                    <h3>✅ In Scope</h3>
                    <ul>
                        <li>Writing and testing Terraform modules for GCP</li>
                        <li>Hosting Python HTTP server</li>
                        <li>GCP resource creation (VPC, firewall, MIG, LB)</li>
                        <li>CI/CD pipeline using Cloud Build</li>
                        <li>Load simulation and monitoring</li>
                    </ul>
                </div>
                
                <div class="out-scope">
                    <h3>❌ Out of Scope</h3>
                    <ul>
                        <li>Complex web applications</li>
                        <li>Database integration</li>
                        <li>External web servers (Nginx/Apache)</li>
                        <li>Advanced security hardening</li>
                    </ul>
                </div>
            </div>
        </div>

        <div class="section">
            <h2>🔍 Background</h2>
            <p>This is a <strong>self-initiated academic project</strong> with no direct relation to job responsibilities. The motivation is to gain hands-on experience in deploying scalable infrastructure using GCP and automating the process with modern DevOps tools.</p>
            <p>Traditionally, deploying web applications required manual steps and physical servers. In contrast, GCP's managed services offer quick, scalable, and programmable deployment using tools like Terraform.</p>
        </div>

        <footer>
            <p>🔄 Refresh this page to see load balancing in action across multiple instances</p>
            <p>⚡ Powered by Google Cloud Platform & Terraform</p>
        </footer>
    </div>
</body>
</html>
"""
            self.wfile.write(html_content.encode('utf-8'))
        elif self.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'Healthy')
        else:
            self.send_response(404)
            self.end_headers()
            self.wfile.write(b'Not Found')

def run_server():
    server_address = ('', 80)
    httpd = HTTPServer(server_address, WebServerHandler)
    print('Web server started on port 80...')
    httpd.serve_forever()

if __name__ == '__main__':
    run_server()
PYTHON_SCRIPT

# Set environment variables for the Python script
export PROJECT_ID="$PROJECT_ID"
export ZONE="$ZONE"
export INTERNAL_IP="$INTERNAL_IP"

# Create directory and start Python server
mkdir -p /app
cd /app

# Start Python web server on port 80 with environment variables
nohup env PROJECT_ID="$PROJECT_ID" ZONE="$ZONE" INTERNAL_IP="$INTERNAL_IP" python3 /app/web_server.py > /var/log/web_server.log 2>&1 &

# Add cron job to keep server running
(crontab -l 2>/dev/null; echo "@reboot cd /app && nohup env PROJECT_ID=\"$PROJECT_ID\" ZONE=\"$ZONE\" INTERNAL_IP=\"$INTERNAL_IP\" python3 /app/web_server.py > /var/log/web_server.log 2>&1 &") | crontab -

echo "Web server started successfully with project info: $PROJECT_ID"
EOT
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
      target = 0.01
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
  timeout_sec           = 30
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
