# `terraform/droplet` — shared DigitalOcean droplet module

Provisions one Ubuntu 22.04 droplet + reserved IP + firewall + DNS records + DO project,
with cloud-init hardening (deploy user, ufw, fail2ban, unattended upgrades, Docker Engine).
Originally lived duplicated inside `TravelPlanner/infra/` and
`SuperMarketReceiptFinder/infra/` — identical logic, differing only by variable values.

## Usage from a project repo

```hcl
# In the project's own infra/main.tf — the provider is configured once, here,
# and inherited automatically by the module (do NOT put a provider block
# inside the module itself; a reusable module should never configure its own
# provider).
terraform {
  required_version = ">= 1.5.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.36"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

module "server" {
  source = "git::https://github.com/mark5129/infra.git//terraform/droplet?ref=v1.0.0"

  project_name    = "travelplanner"       # "smart-cart" for SuperMarketReceiptFinder
  droplet_name    = "travelplanner-prod"
  domain_name     = "markusheuer.com"
  ssh_key_names   = var.ssh_key_names
  trusted_ssh_ips = var.trusted_ssh_ips
}

output "reserved_ip"  { value = module.server.reserved_ip }
output "ssh_command"  { value = module.server.ssh_command }
```

Pin `?ref=` to a tag (not a branch) so a change to this repo never silently changes what a
project's `terraform plan` produces.

## Variables

See `variables.tf` — `domain_name`, `ssh_key_names`, `trusted_ssh_ips`, and
`project_name`/`droplet_name` are required (no defaults, deliberately — a shared module
should never silently default to another project's name). Everything else (`region`,
`droplet_size`, `deploy_user`, `enable_dev_ports`, `create_www_record`,
`create_api_record`, `environment`) has the same sane default it always had. `do_token`
is a root-level variable only (used to configure the provider) — the module itself never
declares it, since it inherits the provider rather than configuring its own.

## Before your first `terraform apply` — check for an existing server first

As far as we could tell, this Terraform (in either project) has never actually been
applied — no state file, no configured backend, no trace of `terraform` having run on the
server it supposedly provisions. That almost certainly means the server was created another
way (by hand, through the DigitalOcean console) and this code documents the intended
infrastructure rather than the thing that built it.

**This matters because Terraform has no state to compare against.** A first `terraform
apply` here won't detect or adopt an existing droplet/DNS records/firewall — it will just
try to create new ones. If a matching droplet already exists, you'll end up with two.
Before running `apply` for the first time:

1. Check the DigitalOcean console (or `doctl compute droplet list` / `doctl projects list`)
   for a droplet/project already matching this config's names.
2. If one exists and you want Terraform to manage it going forward rather than create a
   duplicate, use `terraform import` to bring each existing resource into state first
   (`terraform import module.server.digitalocean_droplet.app <existing-id>`, etc.), then
   `terraform plan` and confirm it reports zero changes before ever applying.
3. If nothing exists yet, a plain `terraform init && terraform plan && terraform apply` is
   fine — you'd be provisioning for the first time, not migrating anything.
