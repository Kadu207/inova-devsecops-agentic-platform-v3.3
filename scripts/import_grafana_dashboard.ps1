param(
  [string]$GrafanaUrl = $(if ($env:GRAFANA_URL) { $env:GRAFANA_URL } else { "http://127.0.0.1:3000" })
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$python = Join-Path $root ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) {
  $python = "python"
}

Write-Host "==> Subindo Grafana (profile observability)"
docker compose --profile observability up -d grafana
if ($LASTEXITCODE -ne 0) {
  Write-Host "AVISO: docker compose grafana falhou; tentando import via API mesmo assim."
}

& $python scripts/import_grafana_dashboard.py --url $GrafanaUrl
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Dashboard Inova Audit Overview disponivel em $GrafanaUrl (uid=inova-audit-overview)"
