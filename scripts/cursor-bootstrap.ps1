param(
  [switch]$SkipDockerCheck
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path ".venv")) {
  py -3.13 -m venv .venv
}

& .\.venv\Scripts\python.exe -m pip install -U pip
& .\.venv\Scripts\pip.exe install -r requirements-dev.txt

New-Item -ItemType Directory -Force -Path ".cursor/memory", ".cursor/tmp" | Out-Null
if (-not (Test-Path ".cursor/memory/constitution.md")) {
  @"
# Constitution - Inova DevSecOps v3.3

- Eventos devem respeitar contratos JSON Schema.
- Workers operam em modo stub ate credenciais externas estarem configuradas.
- Toda mudanca critica exige teste e evidencia de audit log.
"@ | Set-Content -Path ".cursor/memory/constitution.md" -Encoding utf8
}

if (-not $SkipDockerCheck) {
  docker compose config | Out-Null
}

Write-Host "Bootstrap concluido. Proximo passo:"
Write-Host "  docker compose up -d --build"
Write-Host "  powershell -ExecutionPolicy Bypass -File scripts/make.ps1 dev"
