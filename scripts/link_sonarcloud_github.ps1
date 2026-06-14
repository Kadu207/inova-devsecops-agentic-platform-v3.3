param(
  [string]$Organization = "kadu207",
  [string]$ProjectKey = "inova-ti-os",
  [string]$Repository = "Kadu207/inova-devsecops-agentic-platform-v3.3"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$envPath = Join-Path $root ".env.staging"
if (-not (Test-Path $envPath)) {
  Write-Host "Copie .env.staging.example para .env.staging"
  exit 1
}

$token = $null
Get-Content $envPath | ForEach-Object {
  if ($_ -match '^SONAR_TOKEN=(.+)$') { $token = $matches[1].Trim() }
}
if (-not $token) {
  Write-Host "SONAR_TOKEN ausente em .env.staging"
  exit 1
}

function Get-ProjectLinks {
  curl.exe -s -u "${token}:" `
    "https://sonarcloud.io/api/project_links/search?projectKey=$ProjectKey"
}

Write-Host "==> SonarCloud ALM binding (GitHub)"
Write-Host ""
Write-Host "Passos manuais (SonarCloud nao expoe bind via API publica):"
Write-Host "  1. Instale o GitHub App SonarCloud se ainda nao:"
Write-Host "     https://github.com/apps/sonarcloud/installations/new"
Write-Host "  2. Org SonarCloud - GitHub integration:"
Write-Host "     https://sonarcloud.io/organizations/$Organization/overview"
Write-Host "  3. Projeto - Administration - Pull Request Decoration:"
Write-Host "     https://sonarcloud.io/project/overview?id=$ProjectKey"
Write-Host "     Vincule o repositorio: $Repository"
Write-Host ""

$links = Get-ProjectLinks | ConvertFrom-Json
if ($links.links -and $links.links.Count -gt 0) {
  Write-Host "[OK] Project links encontrados:"
  $links.links | ForEach-Object { Write-Host "  - $($_.name): $($_.url)" }
  exit 0
}

Write-Host "[PENDENTE] Nenhum link GitHub no projeto ainda."
Write-Host "Conclua os passos acima e rode este script novamente para validar."
exit 2
