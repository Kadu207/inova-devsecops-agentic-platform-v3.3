#!/usr/bin/env bash
set -euo pipefail

# Firewall minimo Onda 7: SSH + HTTP/HTTPS. Webhook fica em 127.0.0.1.
SSH_PORT="${1:-22}"

if ! command -v ufw >/dev/null 2>&1; then
  echo "ufw nao instalado — instalando..."
  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -y
    sudo apt-get install -y ufw
  else
    echo "Instale ufw manualmente." >&2
    exit 1
  fi
fi

sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow "${SSH_PORT}/tcp" comment "ssh"
sudo ufw allow 80/tcp comment "http"
sudo ufw allow 443/tcp comment "https"
sudo ufw --force enable
sudo ufw status verbose
echo "Firewall Onda 7 aplicado (22/80/443; SSH_PORT=${SSH_PORT})."
