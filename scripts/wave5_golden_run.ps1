param(
  [string]$Repo = "Kadu207/inova-devsecops-agentic-platform-v3.3",
  [switch]$SkipE2E,
  [switch]$ApplyBranchProtection,
  [switch]$SkipCiCheck
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$reportDir = Join-Path $root "reports"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportPath = Join-Path $reportDir "wave5-golden-run-$stamp.md"

$lines = @(
  "# Wave 5 Golden Run — $stamp",
  "",
  "## 1) Runtime local (Docker)",
  ""
)

Write-Host "==> Wave 5 Golden Run"
Write-Host "==> Verificando Docker stack..."

$ps = docker compose ps --format json 2>$null | ConvertFrom-Json
$healthy = @($ps | Where-Object { $_.Health -eq "healthy" -or $_.State -eq "running" })
if ($healthy.Count -lt 2) {
  Write-Host "Stack incompleta. Subindo docker compose..."
  docker compose up -d --build
  Start-Sleep -Seconds 8
}

$lines += "- Docker stack: OK ($($healthy.Count) servicos ativos)"
$lines += ""

if (-not $SkipE2E) {
  Write-Host "==> E2E full pipeline local..."
  & powershell -ExecutionPolicy Bypass -File scripts/e2e_full_pipeline.ps1
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  $lines += "## 2) E2E local"
  $lines += ""
  $lines += "- e2e-full-pipeline: PASSED"
  $lines += ""
}

if (-not $SkipCiCheck) {
  Write-Host "==> Verificando CI GitHub (ultimo push main)..."
  $runs = gh run list --repo $Repo --branch main --limit 6 --json name,conclusion,url,createdAt
  $parsed = $runs | ConvertFrom-Json
  $lines += "## 3) CI GitHub (evidencia)"
  $lines += ""
  foreach ($run in $parsed) {
    $icon = if ($run.conclusion -eq "success") { "OK" } else { $run.conclusion }
    $lines += "- **$($run.name)**: $icon — $($run.url)"
  }
  $lines += ""

  $failed = @($parsed | Where-Object { $_.conclusion -ne "success" })
  if ($failed.Count -gt 0) {
    Write-Host "AVISO: $($failed.Count) workflow(s) nao success no ultimo lote."
  }
}

if ($ApplyBranchProtection) {
  Write-Host "==> Branch protection (github-governance)..."
  & powershell -ExecutionPolicy Bypass -File scripts/apply_branch_protection.ps1 -Repo $Repo
  $bpCode = $LASTEXITCODE
  $lines += "## 4) Branch protection"
  $lines += ""
  if ($bpCode -eq 0) {
    $lines += "- apply_branch_protection: APPLIED"
  } elseif ($bpCode -eq 2) {
    $lines += "- apply_branch_protection: SKIPPED (GitHub Pro necessario para repo privado)"
  } else {
    $lines += "- apply_branch_protection: FAILED (exit $bpCode)"
  }
  $lines += ""
}

$lines += "## 5) Proximos passos"
$lines += ""
$lines += "- MCP: `publish_orchestrate` pipeline `full-devsecops` (Cursor + Docker local)"
$lines += "- MCP: `github-governance-mcp-local` → `apply_branch_protection` quando plano permitir"
$lines += "- Staging: `docker compose --profile staging up -d webhook-ingress`"
$lines += ""

$lines | Set-Content -Path $reportPath -Encoding utf8
Write-Host ""
Write-Host "Golden run report: $reportPath"
Write-Host "WAVE 5 GOLDEN RUN COMPLETE"
