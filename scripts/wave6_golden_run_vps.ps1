param(
  [string]$Repo = "Kadu207/inova-devsecops-agentic-platform-v3.3",
  [string]$WebhookUrl = "https://skillsmcp.inovatitech.com.br/webhook/publish",
  [switch]$SkipE2E,
  [switch]$SkipCiCheck
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$reportDir = Join-Path $root "reports"
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$reportPath = Join-Path $reportDir "wave6-golden-run-vps-$stamp.md"

$lines = New-Object System.Collections.Generic.List[string]
[void]$lines.Add("# Wave 6 Golden Run VPS - $stamp")
[void]$lines.Add("")
[void]$lines.Add("## 1) Webhook publico")
[void]$lines.Add("")

Write-Host "==> Wave 6 Golden Run VPS"
$healthUrl = $WebhookUrl -replace '/webhook/publish$', '/health'
$health = curl.exe -sf $healthUrl 2>$null
if ($LASTEXITCODE -ne 0) {
  Write-Error "Health check falhou: $healthUrl"
}
[void]$lines.Add("- GET $healthUrl : OK")
[void]$lines.Add("- POST $WebhookUrl : HMAC WEBHOOK_SECRET")
[void]$lines.Add("")

if (-not $SkipE2E) {
  Write-Host "==> E2E full pipeline remoto..."
  & powershell -ExecutionPolicy Bypass -File scripts/e2e_full_pipeline_remote.ps1 -WebhookUrl $WebhookUrl
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  [void]$lines.Add("## 2) E2E remoto (VPS)")
  [void]$lines.Add("")
  [void]$lines.Add("- e2e-full-pipeline-remote: PASSED")
  [void]$lines.Add("")
}

if (-not $SkipCiCheck) {
  Write-Host "==> CI GitHub (ultimo push main)..."
  $runs = gh run list --repo $Repo --branch main --limit 6 --json name,conclusion,url,createdAt 2>$null
  if ($LASTEXITCODE -eq 0 -and $runs) {
    [void]$lines.Add("## 3) CI GitHub")
    [void]$lines.Add("")
    foreach ($run in ($runs | ConvertFrom-Json)) {
      $icon = if ($run.conclusion -eq "success") { "OK" } else { $run.conclusion }
      [void]$lines.Add("- **$($run.name)**: $icon - $($run.url)")
    }
    [void]$lines.Add("")
  }
}

[void]$lines.Add("## 4) Integracoes externas")
[void]$lines.Add("")
[void]$lines.Add("- GitHub: workflow `trigger-vps-orchestrate` + secrets WEBHOOK_URL / WEBHOOK_SECRET")
[void]$lines.Add("- SonarCloud: nao apontar webhook nativo; usar step pos-scan no CI ou GitHub Actions")
[void]$lines.Add("")

$lines | Set-Content -Path $reportPath -Encoding UTF8
Write-Host ""
Write-Host "Golden run VPS report: $reportPath"
Write-Host "WAVE 6 GOLDEN RUN VPS COMPLETE"
