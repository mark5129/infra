# `terraform/droplet` — shared DigitalOcean droplet module

Provisions one Ubuntu 22.04 droplet + reserved IP + firewall + DNS records + DO project,
with cloud-init hardening (deploy user, ufw, fail2ban, unattended upgrades, Docker Engine).
Originally lived duplicated inside `TravelPlanner/infra/` and
`SuperMarketReceiptFinder/infra/` — identical logic, differing only by variable values.

## Usage from a project repo

```hcl
module "server" {
  source = "git::https://github.com/mark5129/infra.git//terraform/droplet?ref=v1.0.0"

  do_token        = var.do_token
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

See `variables.tf` — `do_token`, `domain_name`, `ssh_key_names`, `trusted_ssh_ips`, and
`project_name`/`droplet_name` are required (no defaults, deliberately — a shared module
should never silently default to another project's name). Everything else (`region`,
`droplet_size`, `deploy_user`, `enable_dev_ports`, `create_www_record`,
`create_api_record`, `environment`) has the same sane default it always had.

## Migrating an existing project onto this module

Moving existing resources under a `module "server" { ... }` block changes their state
address. Applying that naively destroys and recreates the live droplet. Instead, for each
resource:

```bash
terraform state mv digitalocean_droplet.app                    'module.server.digitalocean_droplet.app'
terraform state mv digitalocean_reserved_ip.app                'module.server.digitalocean_reserved_ip.app'
terraform state mv digitalocean_reserved_ip_assignment.app     'module.server.digitalocean_reserved_ip_assignment.app'
terraform state mv digitalocean_project.main                   'module.server.digitalocean_project.main'
terraform state mv digitalocean_domain.root                    'module.server.digitalocean_domain.root'
terraform state mv digitalocean_record.root_a                  'module.server.digitalocean_record.root_a'
terraform state mv 'digitalocean_record.www[0]'                'module.server.digitalocean_record.www[0]'
terraform state mv digitalocean_firewall.app                   'module.server.digitalocean_firewall.app'
```

(Skip `www[0]`/`api[0]` moves for records you didn't create.) Then run `terraform plan` —
it must report **zero changes**. Only apply from a clean, zero-diff plan.
