terraform {
  required_version = ">= 1.5.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.36"
    }
  }
}

# ---------------------------------------------------------------------------
# Provider
# ---------------------------------------------------------------------------

provider "digitalocean" {
  token = var.do_token
}

# ---------------------------------------------------------------------------
# Data – look up SSH keys by fingerprint
# ---------------------------------------------------------------------------

data "digitalocean_ssh_key" "keys" {
  for_each = toset(var.ssh_key_names)
  name     = each.value
}

# ---------------------------------------------------------------------------
# Droplet  (Ubuntu LTS, 2 vCPU / 4 GB RAM)
# ---------------------------------------------------------------------------

resource "digitalocean_droplet" "app" {
  name       = var.droplet_name
  region     = var.region
  size       = var.droplet_size # s-2vcpu-4gb
  image      = "ubuntu-22-04-x64"
  backups    = true             # provider-managed weekly backups (daily via pg_dump in docker-compose)
  monitoring = true

  ssh_keys = [for k in data.digitalocean_ssh_key.keys : k.id]

  user_data = templatefile("${path.module}/cloud-init.yaml.tpl", {
    deploy_user = var.deploy_user
  })

  tags = [
    var.project_name,
    var.environment,
  ]
}

# ---------------------------------------------------------------------------
# Reserved (static) public IP  →  assign to Droplet
# ---------------------------------------------------------------------------

resource "digitalocean_reserved_ip" "app" {
  region = var.region
}

resource "digitalocean_reserved_ip_assignment" "app" {
  ip_address = digitalocean_reserved_ip.app.ip_address
  droplet_id = digitalocean_droplet.app.id
}

# ---------------------------------------------------------------------------
# DigitalOcean project  (groups all resources)
# ---------------------------------------------------------------------------

locals {
  normalized_environment = lower(trimspace(var.environment))
  digitalocean_project_environment_map = {
    production  = "Production"
    prod        = "Production"
    staging     = "Staging"
    stage       = "Staging"
    development = "Development"
    dev         = "Development"
  }
  digitalocean_project_environment = lookup(
    local.digitalocean_project_environment_map,
    local.normalized_environment,
    null
  )
}

resource "digitalocean_project" "main" {
  name        = var.project_name
  description = "${var.project_name} ${var.environment} infrastructure"
  purpose     = "Web Application"
  environment = local.digitalocean_project_environment

  lifecycle {
    precondition {
      condition     = local.digitalocean_project_environment != null
      error_message = "var.environment must be one of: production, prod, staging, stage, development, or dev."
    }
  }
  resources = [
    digitalocean_droplet.app.urn,
    digitalocean_reserved_ip.app.urn,
  ]
}
