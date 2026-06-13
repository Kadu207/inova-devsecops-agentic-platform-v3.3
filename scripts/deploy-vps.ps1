param(
  [string]$Domain = "staging.example.com"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path ".env.staging")) {
  Write-Host "Copie .env.staging.example para .env.staging e configure tokens."
  exit 1
}

$env:INOVA_DOMAIN = $Domain

Write-Host "==> Deploy VPS staging (domain=$Domain)"
docker compose `
  --env-file .env.staging `
  -f docker-compose.yml `
  -f deploy/vps/docker-compose.vps.yml `
  --profile staging `
  --profile vps `
  up -d --build

Start-Sleep -Seconds 3
try {
  Invoke-RestMethod -Uri "http://127.0.0.1:8787/health" -Method Get
} catch {
  Write-Host "Health check local falhou - verifique logs webhook-ingress"
}

Write-Host "Deploy concluido. TLS: https://$Domain/health"
