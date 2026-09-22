param(
  [string]$CorrelationId = "e2e-vps-$(Get-Date -Format 'yyyyMMddHHmmss')",
  [string]$WebhookUrl = "https://skillsmcp.inovatitech.com.br/webhook/publish",
  [string]$VpsHost = "128.140.77.31",
  [string]$VpsUser = "gestaoti",
  [string]$RemotePath = "/home/gestaoti/inova-devsecops",
  [string]$IdentityFile = "$env:USERPROFILE\.ssh\agenda-deploy",
  [int]$MinCompletedWorkers = 11,
  [int]$WaitSeconds = 45
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "==> E2E full pipeline REMOTO (VPS via webhook)"
Write-Host "    correlation_id: $CorrelationId"
Write-Host "    webhook:        $WebhookUrl"
Write-Host ""

Write-Host "==> Health check publico..."
curl.exe -sf "$($WebhookUrl -replace '/webhook/publish$','')/health" | Out-Null
if ($LASTEXITCODE -ne 0) {
  Write-Error "Health check falhou em $WebhookUrl"
}

$data = Get-Content (Join-Path $root "examples\events\orchestrate_full_devsecops.json") -Raw | ConvertFrom-Json
$data.correlation_id = $CorrelationId
$payload = @{
  subject        = "task.orchestrate.requested"
  tenant_id      = $data.tenant_id
  project        = $data.project
  correlation_id = $data.correlation_id
  payload        = $data.payload
} | ConvertTo-Json -Depth 20 -Compress

Write-Host "==> Publicando task.orchestrate.requested..."
$envStaging = Join-Path $root ".env.staging"
if (-not (Test-Path $envStaging)) {
  $envStaging = "C:\Users\Carlos\OneDrive\Área de Trabalho\Projetos DEV\Evolução de Skills e MCP\.env.staging"
}
$result = & (Join-Path $PSScriptRoot "publish_webhook.ps1") `
  -PayloadJson $payload `
  -WebhookUrl $WebhookUrl `
  -EnvFile $envStaging
Write-Host "    accepted correlation_id=$($result.correlation_id)"

Write-Host "==> Aguardando workers na VPS (${WaitSeconds}s)..."
Start-Sleep -Seconds $WaitSeconds

$sshArgs = @("-o", "StrictHostKeyChecking=accept-new")
if ($IdentityFile -and (Test-Path $IdentityFile)) {
  $sshArgs = @("-i", $IdentityFile) + $sshArgs
}
$sshTarget = "${VpsUser}@${VpsHost}"
$compose = "docker compose --env-file /run/inova/env -f docker-compose.yml -f deploy/vps/docker-compose.hardening.yml -f deploy/vps/docker-compose.cloudflare.yml"

$auditSql = "SELECT worker, event_type, status, correlation_id, created_at FROM public.worker_audit_log WHERE correlation_id = '$CorrelationId' ORDER BY id ASC;"
$countSql = "SELECT COUNT(DISTINCT worker) FROM public.worker_audit_log WHERE correlation_id = '$CorrelationId' AND status = 'completed';"

Write-Host "==> worker_audit_log (VPS):"
$auditSql | ssh @sshArgs $sshTarget "cd $RemotePath && $compose exec -T postgres psql -U inova -d inova_platform"

$completedRaw = ($countSql | ssh @sshArgs $sshTarget "cd $RemotePath && $compose exec -T postgres psql -U inova -d inova_platform -t -A")
$completedWorkers = if ($completedRaw -is [array]) { ($completedRaw -join '') } else { [string]$completedRaw }
$completedWorkers = ($completedWorkers -replace '\s', '').Trim()
Write-Host "Workers completed distintos: $completedWorkers (minimo $MinCompletedWorkers)"

if ([int]$completedWorkers -lt $MinCompletedWorkers) {
  Write-Host "E2E FULL PIPELINE REMOTO FAILED"
  ssh @sshArgs $sshTarget "cd $RemotePath && $compose logs orchestrator sonar-worker snyk-worker datadog-worker --tail=40"
  exit 1
}

Write-Host "E2E FULL PIPELINE REMOTO PASSED: $completedWorkers workers (correlation_id=$CorrelationId)"
