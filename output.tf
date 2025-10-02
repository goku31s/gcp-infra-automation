output "load_balancer_ip" {
  description = "Global external IP of the HTTP LB"
  value       = google_compute_global_forwarding_rule.forwarding_rule.ip_address
}

output "http_url" {
  description = "Convenience URL for testing"
  value       = "http://${google_compute_global_forwarding_rule.forwarding_rule.ip_address}"
}

