param(
  [string]$EnvFile = "",
  [switch]$StrictIntegrated,
  [switch]$SkipDatadog,
  [switch]$SkipSonar,
  [switch]$SkipSnyk
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not $EnvFile) {
  $EnvFile = Join-Path $root ".env.staging"
}

function Import-DotEnv {
  param([string]$Path)
  if (-not (Test-Path $Path)) {
    throw "Arquivo nao encontrado: $Path`nCopie .env.staging.example para .env.staging no repo Inova."
  }
  $vars = @{}
  Get-Content $Path -Encoding UTF8 | ForEach-Object {
    $line = $_.Trim()
    if (-not $line -or $line.StartsWith("#")) { return }
    $idx = $line.IndexOf("=")
    if ($idx -lt 1) { return }
    $key = $line.Substring(0, $idx).Trim()
    $val = $line.Substring($idx + 1).Trim()
    if ($val.StartsWith('"') -and $val.EndsWith('"')) {
      $val = $val.Substring(1, $val.Length - 2)
    }
    $vars[$key] = $val
    Set-Item -Path "env:$key" -Value $val
  }
  return $vars
}

function Get-DatadogApiBase {
  param([string]$Site)
  $s = $Site.Trim().TrimEnd("/")
  if ($s -match "^https?://") {
    $s = ([uri]$s).Host
  }
  if ($s -like "api.*") {
    return "https://$s"
  }
  switch ($s) {
    "datadoghq.com" { return "https://api.datadoghq.com" }
    "datadoghq.eu" { return "https://api.datadoghq.eu" }
    "us3.datadoghq.com" { return "https://api.us3.datadoghq.com" }
    "us5.datadoghq.com" { return "https://api.us5.datadoghq.com" }
    "ap1.datadoghq.com" { return "https://api.ap1.datadoghq.com" }
    default {
      if ($s -like "*.datadoghq.*") {
        return "https://api.$s"
      }
      return "https://api.$s"
    }
  }
}

function Test-DatadogToken {
  param([string]$ApiKey, [string]$Site)
  if (-not $ApiKey) {
    return @{ ok = $false; detail = "DATADOG_API_KEY vazio" }
  }
  $base = Get-DatadogApiBase -Site $Site
  $headers = @{
    "DD-API-KEY"     = $ApiKey
    "Content-Type"   = "application/json"
  }
  try {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $resp = Invoke-RestMethod -Uri "$base/api/v1/validate" -Headers $headers -Method Get
    $ErrorActionPreference = $prev
    if ($resp.valid -eq $true) {
      return @{ ok = $true; detail = "valid em $base" }
    }
    return @{ ok = $false; detail = "resposta inesperada de $base" }
  } catch {
    $hint = ""
    if ($Site -eq "datadoghq.com" -or -not $Site) {
      $hint = " Sua org pode ser US5: defina DATADOG_SITE=us5.datadoghq.com"
    }
    return @{ ok = $false; detail = "falha em ${base}: $($_.Exception.Message).$hint" }
  }
}

function Test-SonarToken {
  param([string]$HostUrl, [string]$Token)
  if (-not $Token) {
    return @{ ok = $false; detail = "SONAR_TOKEN vazio" }
  }
  if (-not $HostUrl) {
    return @{ ok = $false; detail = "SONAR_HOST_URL vazio" }
  }
  $base = $HostUrl.Trim().TrimEnd("/")
  $pair = "${Token}:"
  $b64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($pair))
  $headers = @{ Authorization = "Basic $b64" }
  try {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $resp = Invoke-RestMethod -Uri "$base/api/authentication/validate" -Headers $headers -Method Get
    $ErrorActionPreference = $prev
    if ($resp.valid -eq $true) {
      return @{ ok = $true; detail = "valid em $base" }
    }
    return @{ ok = $false; detail = "token rejeitado por $base (valid=false)" }
  } catch {
    return @{
      ok     = $false
      detail = "falha em ${base}: token invalido ou URL errada. Gere em SonarCloud > My Account > Security."
    }
  }
}

function Test-SnykToken {
  param([string]$Token)
  if (-not $Token) {
    return @{ ok = $false; detail = "SNYK_TOKEN vazio" }
  }
  $headers = @{ Authorization = "token $Token" }
  try {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $resp = Invoke-RestMethod -Uri "https://api.snyk.io/v1/user/me" -Headers $headers -Method Get
    $ErrorActionPreference = $prev
    $user = $resp.username
    if ($user) {
      return @{ ok = $true; detail = "valid (usuario $user)" }
    }
    return @{ ok = $true; detail = "valid" }
  } catch {
    return @{ ok = $false; detail = "falha Snyk API: token invalido ou expirado" }
  }
}

Write-Host "==> validate_tokens.ps1"
Write-Host "    Env file: $EnvFile"
Write-Host ""

$vars = Import-DotEnv -Path $EnvFile
$mode = $vars["WORKER_ADAPTER_MODE"]
if (-not $mode) { $mode = "auto" }
Write-Host "    WORKER_ADAPTER_MODE=$mode"
Write-Host ""

$results = @()
$failures = 0

if (-not $SkipDatadog) {
  $obs = $vars["OBSERVABILITY_DATADOG_ENABLED"]
  $needDatadog = ($mode -eq "integrated") -or ($obs -eq "true")
  if ($needDatadog) {
    $site = $vars["DATADOG_SITE"]
    if (-not $site) { $site = "datadoghq.com" }
    $r = Test-DatadogToken -ApiKey $vars["DATADOG_API_KEY"] -Site $site
    $icon = if ($r.ok) { "OK" } else { "FAIL" }
    Write-Host "[$icon] Datadog ($site) - $($r.detail)"
    if (-not $r.ok) { $failures++ }
    $results += [pscustomobject]@{ Service = "Datadog"; Ok = $r.ok; Detail = $r.detail }
  } else {
    Write-Host "[SKIP] Datadog (nao exigido para mode=$mode observability=$obs)"
  }
}

if (-not $SkipSonar) {
  if ($mode -eq "integrated") {
    $r = Test-SonarToken -HostUrl $vars["SONAR_HOST_URL"] -Token $vars["SONAR_TOKEN"]
    $icon = if ($r.ok) { "OK" } else { "FAIL" }
    Write-Host "[$icon] Sonar ($($vars['SONAR_HOST_URL'])) - $($r.detail)"
    if (-not $r.ok) { $failures++ }
    $results += [pscustomobject]@{ Service = "Sonar"; Ok = $r.ok; Detail = $r.detail }
  } else {
    Write-Host "[SKIP] Sonar (WORKER_ADAPTER_MODE=$mode)"
  }
}

if (-not $SkipSnyk) {
  if ($mode -eq "integrated") {
    $r = Test-SnykToken -Token $vars["SNYK_TOKEN"]
    $icon = if ($r.ok) { "OK" } else { "FAIL" }
    Write-Host "[$icon] Snyk - $($r.detail)"
    if (-not $r.ok) { $failures++ }
    $results += [pscustomobject]@{ Service = "Snyk"; Ok = $r.ok; Detail = $r.detail }
  } else {
    Write-Host "[SKIP] Snyk (WORKER_ADAPTER_MODE=$mode)"
  }
}

Write-Host ""
if ($failures -gt 0) {
  Write-Host "VALIDACAO FALHOU: $failures servico(s). Corrija .env.staging antes do docker compose up."
  if ($StrictIntegrated) { exit 1 }
  exit 1
}

Write-Host "VALIDACAO OK: tokens prontos para staging."
exit 0
