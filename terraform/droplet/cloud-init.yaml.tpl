#cloud-config
# Server bootstrap: hardening + Docker Engine
# Rendered by Terraform templatefile() – only ${deploy_user} is substituted.
# All other $${...} sequences become ${...} in the output (escaped for apt/shell).

# ---------------------------------------------------------------------------
# System update + base packages
# ---------------------------------------------------------------------------
package_update: true
package_upgrade: true
packages:
  - ufw
  - fail2ban
  - unattended-upgrades
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg

# ---------------------------------------------------------------------------
# Create non-root deploy user
# ---------------------------------------------------------------------------
users:
  - name: ${deploy_user}
    groups: [sudo]
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    lock_passwd: true

# ---------------------------------------------------------------------------
# Write config files (runs before runcmd)
# ---------------------------------------------------------------------------
write_files:
  # Security updates only, auto-reboot at 03:00 UTC
  - path: /etc/apt/apt.conf.d/50unattended-upgrades
    content: |
      Unattended-Upgrade::Allowed-Origins {
          "$${distro_id}:$${distro_codename}-security";
      };
      Unattended-Upgrade::Automatic-Reboot "true";
      Unattended-Upgrade::Automatic-Reboot-Time "03:00";

  - path: /etc/apt/apt.conf.d/20auto-upgrades
    content: |
      APT::Periodic::Update-Package-Lists "1";
      APT::Periodic::Unattended-Upgrade "1";

  # fail2ban – ban IPs after 5 failed SSH attempts for 1 hour
  - path: /etc/fail2ban/jail.local
    content: |
      [DEFAULT]
      bantime  = 3600
      findtime = 600
      maxretry = 5

      [sshd]
      enabled = true

  # Docker log rotation – prevent disk exhaustion
  - path: /etc/docker/daemon.json
    content: |
      {
        "log-driver": "json-file",
        "log-opts": {
          "max-size": "10m",
          "max-file": "3"
        }
      }

# ---------------------------------------------------------------------------
# Bootstrap commands
# ---------------------------------------------------------------------------
runcmd:
  # ── Deploy user: copy root SSH keys ──────────────────────────────────────
  - mkdir -p /home/${deploy_user}/.ssh
  - cp /root/.ssh/authorized_keys /home/${deploy_user}/.ssh/authorized_keys
  - chown -R ${deploy_user}:${deploy_user} /home/${deploy_user}/.ssh
  - chmod 700 /home/${deploy_user}/.ssh
  - chmod 600 /home/${deploy_user}/.ssh/authorized_keys

  # ── SSH hardening ─────────────────────────────────────────────────────────
  - sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  - sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  - sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
  - systemctl restart sshd

  # ── UFW firewall ──────────────────────────────────────────────────────────
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow 22/tcp
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw --force enable

  # ── fail2ban ──────────────────────────────────────────────────────────────
  - systemctl enable fail2ban
  - systemctl start fail2ban

  # ── Docker Engine (official convenience script) ───────────────────────────
  - curl -fsSL https://get.docker.com | sh
  - usermod -aG docker ${deploy_user}
  - systemctl enable docker
  - systemctl start docker

  # ── Timezone + NTP ────────────────────────────────────────────────────────
  - timedatectl set-timezone UTC
  - systemctl enable systemd-timesyncd
  - systemctl start systemd-timesyncd
