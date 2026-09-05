# ---------------------------------------------------------------------------
# DNS
#
# Manages DNS records inside DigitalOcean for the configured domain.
# The domain must either already exist in your DO account or will be
# created here (the resource is idempotent – it will adopt an existing domain).
# ---------------------------------------------------------------------------

resource "digitalocean_domain" "root" {
  name = var.domain_name
}

# Root A record  (@)  →  reserved IP
resource "digitalocean_record" "root_a" {
  domain = digitalocean_domain.root.name
  type   = "A"
  name   = "@"
  value  = digitalocean_reserved_ip.app.ip_address
  ttl    = 300
}

# www CNAME  →  root domain
resource "digitalocean_record" "www" {
  count  = var.create_www_record ? 1 : 0
  domain = digitalocean_domain.root.name
  type   = "CNAME"
  name   = "www"
  value  = "@"
  ttl    = 300
}

# api A record  →  same reserved IP
resource "digitalocean_record" "api" {
  count  = var.create_api_record ? 1 : 0
  domain = digitalocean_domain.root.name
  type   = "A"
  name   = "api"
  value  = digitalocean_reserved_ip.app.ip_address
  ttl    = 300
}
