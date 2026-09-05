# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------

output "droplet_id" {
  description = "Numeric ID of the Droplet."
  value       = digitalocean_droplet.app.id
}

output "droplet_name" {
  description = "Name of the Droplet."
  value       = digitalocean_droplet.app.name
}

output "reserved_ip" {
  description = "Static public IP address assigned to the Droplet."
  value       = digitalocean_reserved_ip.app.ip_address
}

output "domain" {
  description = "Root domain managed in DigitalOcean."
  value       = digitalocean_domain.root.name
}

output "ssh_command" {
  description = "Example SSH command to connect as the deploy user (root login is disabled by cloud-init)."
  value       = "ssh ${var.deploy_user}@${digitalocean_reserved_ip.app.ip_address}"
}

output "firewall_id" {
  description = "ID of the cloud firewall."
  value       = digitalocean_firewall.app.id
}
