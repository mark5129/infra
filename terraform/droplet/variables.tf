# ---------------------------------------------------------------------------
# Input variables
# ---------------------------------------------------------------------------

variable "region" {
  description = "DigitalOcean region slug for the Droplet and related resources."
  type        = string
  default     = "nyc3"
}

variable "droplet_name" {
  description = "Name assigned to the Droplet."
  type        = string
}

variable "droplet_size" {
  description = "Droplet size slug (2 vCPU / 4 GB RAM)."
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "ssh_key_names" {
  description = "List of SSH key names (as they appear in the DigitalOcean control panel) to add to the Droplet."
  type        = list(string)
}

variable "trusted_ssh_ips" {
  description = "CIDR blocks that are allowed to connect on port 22. Use [\"0.0.0.0/0\",\"::/0\"] to allow all (not recommended)."
  type        = list(string)
}

# ---------------------------------------------------------------------------
# DNS variables
# ---------------------------------------------------------------------------

variable "domain_name" {
  description = "Root domain name managed in DigitalOcean (e.g. example.com)."
  type        = string
}

variable "create_www_record" {
  description = "When true a CNAME record for www.<domain> is created."
  type        = bool
  default     = true
}

variable "create_api_record" {
  description = "When true an A record for api.<domain> pointing to the Droplet IP is created."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Server
# ---------------------------------------------------------------------------

variable "deploy_user" {
  description = "Name of the non-root OS user created by cloud-init for deployments."
  type        = string
  default     = "deploy"
}

variable "enable_dev_ports" {
  description = "When true, opens ports 3001 (dev) and 3002 (test) to trusted_ssh_ips. Leave false on production-only servers."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Project / tagging
# ---------------------------------------------------------------------------

variable "project_name" {
  description = "Name of the DigitalOcean project used to group resources, and label used in resource tags/descriptions."
  type        = string
}

variable "environment" {
  description = "Deployment environment tag (e.g. production, staging)."
  type        = string
  default     = "production"
}
