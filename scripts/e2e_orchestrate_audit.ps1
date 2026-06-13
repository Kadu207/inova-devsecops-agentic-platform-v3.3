param(
  [string]$CorrelationId = "e2e-orchestrate-$(Get-Date -Format 'yyyyMMddHHmmss')"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$python = Join-Path $root ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) {
  throw "Venv nao encontrado. Rode scripts/cursor-bootstrap.ps1 primeiro."
}

Write-Host "==> Subindo stack Docker..."
docker compose up -d --build

Write-Host "==> Aguardando Postgres e NATS..."
for ($i = 0; $i -lt 60; $i++) {
  $pg = docker compose exec -T postgres pg_isready -U inova -d inova_platform 2>$null
  $nats = docker compose ps nats --format "{{.Health}}" 2>$null
  if ($LASTEXITCODE -eq 0 -and $nats -match "healthy") { break }
  Start-Sleep -Seconds 2
}

Write-Host "==> Aguardando workers (orchestrator, audit-worker)..."
for ($i = 0; $i -lt 30; $i++) {
  $orch = docker compose ps orchestrator --format "{{.Status}}" 2>$null
  $audit = docker compose ps audit-worker --format "{{.Status}}" 2>$null
  if ($orch -match "Up" -and $audit -match "Up") { break }
  Start-Sleep -Seconds 2
}

Write-Host "==> Publicando task.orchestrate.requested (correlation_id=$CorrelationId)..."
$payloadPath = Join-Path $root "examples\events\.e2e_orchestrate_payload.json"
$data = Get-Content (Join-Path $root "examples\events\orchestrate_requested.json") -Raw | ConvertFrom-Json
$data.correlation_id = $CorrelationId
$data | ConvertTo-Json -Depth 10 | ForEach-Object {
  [System.IO.File]::WriteAllText($payloadPath, $_)
}

docker compose run --rm publisher python scripts/publish_event.py `
  --subject task.orchestrate.requested `
  --payload examples/events/.e2e_orchestrate_payload.json

Write-Host "==> Aguardando processamento (15s)..."
Start-Sleep -Seconds 15

Write-Host "==> worker_audit_log:"
docker compose exec -T postgres psql -U inova -d inova_platform -c @"
SELECT worker, event_type, status, correlation_id, created_at
FROM public.worker_audit_log
WHERE correlation_id = '$CorrelationId'
ORDER BY id ASC;
"@

$count = docker compose exec -T postgres psql -U inova -d inova_platform -t -A -c @"
SELECT COUNT(*) FROM public.worker_audit_log
WHERE correlation_id = '$CorrelationId' AND status = 'completed';
"@

$count = ($count -replace '\s', '')
if ([int]$count -lt 2) {
  Write-Host "E2E FAILED: esperado >=2 completed, encontrado $count"
  docker compose logs orchestrator audit-worker --tail=80
  exit 1
}

Write-Host "E2E PASSED: orchestrator + audit pipeline registrados."
