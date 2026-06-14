param(
  [string]$EnvFile = ".env.staging"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$envPath = Join-Path $root $EnvFile
if (-not (Test-Path $envPath)) {
  Write-Host "Arquivo de env nao encontrado: $envPath"
  exit 1
}

$vars = @{}
Get-Content $envPath | ForEach-Object {
  $line = $_.Trim()
  if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
    $parts = $line.Split("=", 2)
    $vars[$parts[0].Trim()] = $parts[1].Trim()
  }
}

$token = $vars["SONAR_TOKEN"]
if (-not $token) {
  Write-Host "SONAR_TOKEN ausente em $EnvFile"
  exit 1
}

Write-Host "==> SonarCloud scan (project=inova-ti-os, org=kadu207)"
docker run --rm `
  -v "${root}:/usr/src" `
  -w /usr/src `
  -e SONAR_TOKEN=$token `
  sonarsource/sonar-scanner-cli:latest

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "==> Quality gate:"
$hostUrl = if ($vars["SONAR_HOST_URL"]) { $vars["SONAR_HOST_URL"].TrimEnd("/") } else { "https://sonarcloud.io" }
$qg = curl.exe -s -u "${token}:" "$hostUrl/api/qualitygates/project_status?projectKey=inova-ti-os"
Write-Host $qg
