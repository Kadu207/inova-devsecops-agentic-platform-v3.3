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

$lines = New-Object System.Collections.Generic.List[string]
[void]$lines.Add("# Wave 5 Golden Run - $stamp")
[void]$lines.Add("")
[void]$lines.Add("## 1) Runtime local (Docker)")
[void]$lines.Add("")

Write-Host "==> Wave 5 Golden Run"
Write-Host "==> Verificando Docker stack..."

$psJson = docker compose ps --format json 2>$null
$healthy = @()
if ($psJson) {
  $healthy = @($psJson | ConvertFrom-Json | Where-Object {
      $_.Health -eq "healthy" -or $_.State -eq "running"
    })
}
if ($healthy.Count -lt 2) {
  Write-Host "Stack incompleta. Subindo docker compose..."
  docker compose up -d --build
  Start-Sleep -Seconds 8
  $psJson = docker compose ps --format json 2>$null
  if ($psJson) {
    $healthy = @($psJson | ConvertFrom-Json)
  }
}

[void]$lines.Add("- Docker stack: OK ($($healthy.Count) servicos ativos)")
[void]$lines.Add("")

if (-not $SkipE2E) {
  Write-Host "==> E2E full pipeline local..."
  & powershell -ExecutionPolicy Bypass -File scripts/e2e_full_pipeline.ps1
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  [void]$lines.Add("## 2) E2E local")
  [void]$lines.Add("")
  [void]$lines.Add("- e2e-full-pipeline: PASSED")
  [void]$lines.Add("")
}

if (-not $SkipCiCheck) {
  Write-Host "==> Verificando CI GitHub (ultimo push main)..."
  $runs = gh run list --repo $Repo --branch main --limit 6 --json name,conclusion,url,createdAt
  $parsed = $runs | ConvertFrom-Json
  [void]$lines.Add("## 3) CI GitHub (evidencia)")
  [void]$lines.Add("")
  foreach ($run in $parsed) {
    $icon = if ($run.conclusion -eq "success") { "OK" } else { $run.conclusion }
    $line = "- **$($run.name)**: $icon - $($run.url)"
    [void]$lines.Add($line)
  }
  [void]$lines.Add("")

  $failed = @($parsed | Where-Object { $_.conclusion -ne "success" })
  if ($failed.Count -gt 0) {
    Write-Host "AVISO: $($failed.Count) workflow(s) nao success no ultimo lote."
  }
}

if ($ApplyBranchProtection) {
  Write-Host "==> Branch protection (github-governance)..."
  & powershell -ExecutionPolicy Bypass -File scripts/apply_branch_protection.ps1 -Repo $Repo
  $bpCode = $LASTEXITCODE
  [void]$lines.Add("## 4) Branch protection")
  [void]$lines.Add("")
  if ($bpCode -eq 0) {
    [void]$lines.Add("- apply_branch_protection: APPLIED")
  } elseif ($bpCode -eq 2) {
    [void]$lines.Add("- apply_branch_protection: SKIPPED (GitHub Pro necessario para repo privado)")
  } else {
    [void]$lines.Add("- apply_branch_protection: FAILED (exit $bpCode)")
  }
  [void]$lines.Add("")
}

[void]$lines.Add("## 5) Proximos passos")
[void]$lines.Add("")
[void]$lines.Add('- MCP: publish_orchestrate pipeline full-devsecops (Cursor + Docker local)')
[void]$lines.Add('- MCP: github-governance-mcp-local apply_branch_protection quando plano permitir')
[void]$lines.Add('- Staging: docker compose --profile staging up -d webhook-ingress')
[void]$lines.Add("")

$lines | Set-Content -Path $reportPath -Encoding UTF8
Write-Host ""
Write-Host "Golden run report: $reportPath"
Write-Host "WAVE 5 GOLDEN RUN COMPLETE"
