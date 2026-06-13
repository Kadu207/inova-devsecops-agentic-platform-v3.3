param(
  [switch]$SkipNpmInstall
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$mcpDir = Join-Path $root "mcp\inova-runtime-mcp"
if (-not $SkipNpmInstall) {
  Write-Host "==> npm install em mcp/inova-runtime-mcp..."
  Push-Location $mcpDir
  npm install
  Pop-Location
}

Write-Host ""
Write-Host "MCP inova-runtime-mcp-local - proximos passos:"
Write-Host "  1. Docker: docker compose up -d --build"
Write-Host "  2. Cursor: Developer -> Reload Window"
Write-Host "  3. Settings -> MCP -> confirmar inova-runtime-mcp-local verde"
Write-Host "  4. No chat: use publish_orchestrate pipeline full-devsecops"
Write-Host ""
Write-Host "Config projeto: .cursor/mcp.json"
Write-Host "Config workspace Evolucao Skills: Evolucao de Skills e MCP/.cursor/mcp.json"
