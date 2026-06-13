#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

if [[ ! -f .env.staging ]]; then
  echo "Copie .env.staging.example para .env.staging e configure tokens."
  exit 1
fi

export INOVA_DOMAIN="${INOVA_DOMAIN:-staging.example.com}"

echo "==> Deploy VPS staging (domain=${INOVA_DOMAIN})"
docker compose \
  --env-file .env.staging \
  -f docker-compose.yml \
  -f deploy/vps/docker-compose.vps.yml \
  --profile staging \
  --profile vps \
  up -d --build

echo "==> Health local"
curl -sf "http://127.0.0.1:8787/health" || true
echo ""
echo "Deploy concluido. TLS: https://${INOVA_DOMAIN}/health"
