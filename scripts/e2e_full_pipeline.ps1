param(
  [string]$CorrelationId = "e2e-full-$(Get-Date -Format 'yyyyMMddHHmmss')",
  [int]$MinCompletedWorkers = 11,
  [int]$WaitSeconds = 30
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "==> Subindo stack Docker (todos os workers)..."
docker compose up -d --build

Write-Host "==> Aguardando Postgres e NATS..."
for ($i = 0; $i -lt 60; $i++) {
  docker compose exec -T postgres pg_isready -U inova -d inova_platform 2>$null | Out-Null
  $nats = docker compose ps nats --format "{{.Health}}" 2>$null
  if ($LASTEXITCODE -eq 0 -and $nats -match "healthy") { break }
  Start-Sleep -Seconds 2
}

Write-Host "==> Aguardando workers principais..."
$required = @("orchestrator", "audit-worker", "sonar-worker", "snyk-worker", "datadog-worker")
for ($i = 0; $i -lt 45; $i++) {
  $allUp = $true
  foreach ($svc in $required) {
    $st = docker compose ps $svc --format "{{.Status}}" 2>$null
    if ($st -notmatch "Up") { $allUp = $false; break }
  }
  if ($allUp) { break }
  Start-Sleep -Seconds 2
}

Write-Host "==> Publicando pipeline full-devsecops (correlation_id=$CorrelationId)..."
$payloadPath = Join-Path $root "examples\events\.e2e_full_pipeline_payload.json"
$data = Get-Content (Join-Path $root "examples\events\orchestrate_full_devsecops.json") -Raw | ConvertFrom-Json
$data.correlation_id = $CorrelationId
$data | ConvertTo-Json -Depth 10 | ForEach-Object {
  [System.IO.File]::WriteAllText($payloadPath, $_)
}

docker compose run --rm publisher python scripts/publish_event.py `
  --subject task.orchestrate.requested `
  --payload examples/events/.e2e_full_pipeline_payload.json

Write-Host "==> Aguardando processamento (${WaitSeconds}s)..."
Start-Sleep -Seconds $WaitSeconds

Write-Host "==> worker_audit_log:"
docker compose exec -T postgres psql -U inova -d inova_platform -c @"
SELECT worker, event_type, status, correlation_id, created_at
FROM public.worker_audit_log
WHERE correlation_id = '$CorrelationId'
ORDER BY id ASC;
"@

$completedWorkers = docker compose exec -T postgres psql -U inova -d inova_platform -t -A -c @"
SELECT COUNT(DISTINCT worker) FROM public.worker_audit_log
WHERE correlation_id = '$CorrelationId' AND status = 'completed';
"@

$completedWorkers = ($completedWorkers -replace '\s', '')
Write-Host "Workers completed distintos: $completedWorkers (minimo $MinCompletedWorkers)"

if ([int]$completedWorkers -lt $MinCompletedWorkers) {
  Write-Host "E2E FULL PIPELINE FAILED"
  docker compose logs orchestrator sonar-worker snyk-worker datadog-worker --tail=50
  exit 1
}

Write-Host "E2E FULL PIPELINE PASSED: $completedWorkers workers registrados em worker_audit_log."
