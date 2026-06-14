param(
  [Parameter(Position = 0, Mandatory = $true)]
  [string]$Target
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$python = Join-Path $root ".venv\Scripts\python.exe"
if (-not (Test-Path $python)) {
  Write-Host "Venv ausente. Rode: powershell -ExecutionPolicy Bypass -File scripts/cursor-bootstrap.ps1"
  exit 1
}

function Invoke-DockerPublish {
  param([string]$Subject, [string]$Payload)
  docker compose run --rm publisher python scripts/publish_event.py `
    --subject $Subject `
    --payload $Payload
}

switch ($Target) {
  "bootstrap" { & powershell -ExecutionPolicy Bypass -File scripts/cursor-bootstrap.ps1 }
  "dev" { docker compose up -d --build }
  "down" { docker compose down }
  "logs" { docker compose logs -f --tail=200 }
  "test" { & $python -m pytest -q }
  "lint" {
    & $python -m ruff check runtime workers scripts tests
    & $python -m ruff format --check runtime workers scripts tests
  }
  "validate-contracts" { & $python scripts/validate_contracts.py }
  "publish-audit" { Invoke-DockerPublish "task.audit.requested" "examples/events/audit_requested.json" }
  "publish-opencode" { Invoke-DockerPublish "task.opencode.requested" "examples/events/opencode_requested.json" }
  "publish-orchestrate" { Invoke-DockerPublish "task.orchestrate.requested" "examples/events/orchestrate_requested.json" }
  "publish-full-pipeline" { Invoke-DockerPublish "task.orchestrate.requested" "examples/events/orchestrate_full_devsecops.json" }
  "audit-log" { & $python scripts/query_audit_log.py --last 20 }
  "release-check" {
    & $python -m ruff check runtime workers scripts tests
    & $python scripts/validate_contracts.py
    & $python -m pytest -q
    & $python scripts/release_check.py
  }
  "e2e-orchestrate-audit" { & powershell -ExecutionPolicy Bypass -File scripts/e2e_orchestrate_audit.ps1 }
  "e2e-full-pipeline" { & powershell -ExecutionPolicy Bypass -File scripts/e2e_full_pipeline.ps1 }
  "wave5-golden-run" { & powershell -ExecutionPolicy Bypass -File scripts/wave5_golden_run.ps1 @args }
  "apply-branch-protection" { & powershell -ExecutionPolicy Bypass -File scripts/apply_branch_protection.ps1 @args }
  "validate-tokens" { & powershell -ExecutionPolicy Bypass -File scripts/validate_tokens.ps1 @args }
  "staging-up" {
    & powershell -ExecutionPolicy Bypass -File scripts/validate_tokens.ps1 @args
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    docker compose --env-file .env.staging --profile staging up -d --build
  }
  "sonar-scan" { & powershell -ExecutionPolicy Bypass -File scripts/sonar_scan.ps1 @args }
  "link-sonar-github" { & powershell -ExecutionPolicy Bypass -File scripts/link_sonarcloud_github.ps1 @args }
  "deploy-vps-hetzner" { & powershell -ExecutionPolicy Bypass -File scripts/deploy-vps-hetzner.ps1 @args }
  default {
    Write-Host "Alvo desconhecido: $Target"
    Write-Host "Targets: bootstrap, dev, down, logs, test, lint, validate-contracts,"
    Write-Host "  publish-audit, publish-opencode, publish-orchestrate, publish-full-pipeline,"
    Write-Host "  audit-log, release-check, e2e-orchestrate-audit, e2e-full-pipeline,"
    Write-Host "  wave5-golden-run, apply-branch-protection, validate-tokens, staging-up, sonar-scan"
    exit 1
  }
}
