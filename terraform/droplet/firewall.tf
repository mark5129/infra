# ---------------------------------------------------------------------------
# Cloud Firewall
#
# Inbound:  SSH (22) from trusted IPs only
#           HTTP (80) and HTTPS (443) from any source
#           Dev (3001) + Test (3002) from trusted IPs – only when
#             enable_dev_ports = true (default: false)
# Outbound: all traffic permitted
# ---------------------------------------------------------------------------

resource "digitalocean_firewall" "app" {
  name = "${var.droplet_name}-fw"

  droplet_ids = [digitalocean_droplet.app.id]

  # -- Inbound rules --------------------------------------------------------

  # SSH – restricted to operator-supplied trusted CIDRs
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.trusted_ssh_ips
  }

  # HTTP
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # HTTPS
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Dev (3001) + Test (3002) – exposed only to trusted IPs when opted in.
  # Keep disabled in production-only deployments to reduce attack surface.
  dynamic "inbound_rule" {
    for_each = var.enable_dev_ports ? [1] : []
    content {
      protocol         = "tcp"
      port_range       = "3001-3002"
      source_addresses = var.trusted_ssh_ips
    }
  }

  # -- Outbound rules -------------------------------------------------------

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
