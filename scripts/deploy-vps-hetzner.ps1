param(
  [Parameter(Mandatory = $true)]
  [string]$Domain,
  [Parameter(Mandatory = $true)]
  [string]$VpsHost,
  [string]$VpsUser = "root",
  [int]$SshPort = 22,
  [string]$RemotePath = "",
  [string]$IdentityFile = "$env:USERPROFILE\.ssh\agenda-deploy",
  [ValidateSet("cloudflare", "caddy")]
  [string]$TlsMode = "cloudflare",
  [switch]$SkipDnsCheck
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Test-Path ".env.staging")) {
  Write-Host "Copie .env.staging.example para .env.staging e configure tokens."
  exit 1
}

Write-Host "==> Deploy Hetzner VPS"
Write-Host "    Domain: $Domain"
Write-Host "    Host:   ${VpsUser}@${VpsHost}:${SshPort}"
Write-Host ""

if (-not $SkipDnsCheck) {
  Write-Host "==> DNS (Cloudflare): confira registro A"
  Write-Host "    Nome: $Domain  ->  IP: $VpsHost  (proxy OFF/grey cloud para Let's Encrypt direto no Caddy)"
  Write-Host "    Ou proxy ON + SSL mode Full se Caddy emite cert na origem."
  try {
    $resolved = [System.Net.Dns]::GetHostAddresses($Domain)
    $ips = ($resolved | ForEach-Object { $_.ToString() }) -join ", "
    Write-Host "    Resolucao atual: $ips"
    if ($ips -notmatch [regex]::Escape($VpsHost)) {
      Write-Host "    AVISO: DNS ainda nao aponta para $VpsHost"
    }
  } catch {
    Write-Host "    AVISO: nao foi possivel resolver $Domain"
  }
  Write-Host ""
}

$sshTarget = "${VpsUser}@${VpsHost}"
if (-not $RemotePath) {
  $RemotePath = if ($VpsUser -eq "root") { "/opt/inova-devsecops" } else { "/home/$VpsUser/inova-devsecops" }
}
$sshArgs = @("-p", $SshPort, "-o", "StrictHostKeyChecking=accept-new")
if ($IdentityFile -and (Test-Path $IdentityFile)) {
  $sshArgs = @("-i", $IdentityFile) + $sshArgs
}

Write-Host "==> Preparando diretorio remoto ($RemotePath)..."
$prepareCmd = "if [ -d $RemotePath ]; then cd $RemotePath && docker compose --env-file .env.staging down 2>/dev/null || true; chmod -R u+rwX $RemotePath 2>/dev/null || true; fi; rm -rf $RemotePath; mkdir -p $RemotePath"
ssh @sshArgs $sshTarget $prepareCmd

$scpArgs = @("-P", "$SshPort", "-o", "StrictHostKeyChecking=accept-new")
if ($IdentityFile -and (Test-Path $IdentityFile)) {
  $scpArgs = @("-i", $IdentityFile) + $scpArgs
}

Write-Host "==> Enviando codigo (scp)..."
$remote = "${sshTarget}:${RemotePath}/"
$items = @(
  "workers", "runtime", "contracts", "deploy", "scripts", "database",
  "docker-compose.yml", "Dockerfile.worker", "requirements.txt",
  ".dockerignore", ".env", "tests", "examples"
)
foreach ($item in $items) {
  $localPath = Join-Path $root $item
  if (Test-Path $localPath) {
    & scp @scpArgs -r $localPath $remote
  }
}
ssh @sshArgs $sshTarget "chmod -R a+rX $RemotePath/workers $RemotePath/runtime $RemotePath/contracts $RemotePath/scripts 2>/dev/null || true"

Write-Host "==> Enviando .env.staging..."
& scp @scpArgs ".env.staging" "${sshTarget}:${RemotePath}/.env.staging"
if ($TlsMode -eq "cloudflare") {
  Write-Host "Modo Cloudflare: webhook na porta 8787 (sem Caddy 80/443)."
  Write-Host "Configure rota no Cloudflare para $Domain -> http://${VpsHost}:8787"
  $composeFiles = "-f docker-compose.yml -f deploy/vps/docker-compose.cloudflare.yml"
} else {
  $composeFiles = "-f docker-compose.yml -f deploy/vps/docker-compose.vps.yml --profile vps"
}

Write-Host "==> Subindo stack..."
$remoteCmd = "cd $RemotePath && export INOVA_DOMAIN='$Domain' && docker compose --env-file .env.staging $composeFiles --profile staging up -d --build && sleep 15 && curl -sf http://127.0.0.1:8787/health"
ssh @sshArgs $sshTarget $remoteCmd
if ($LASTEXITCODE -ne 0) {
  Write-Host "ERRO: deploy remoto falhou (exit $LASTEXITCODE)" -ForegroundColor Red
  exit $LASTEXITCODE
}

Write-Host "==> Aplicando schema Postgres (audit)..."
$initSql = @(
  (Join-Path $root "database\postgres\001_init_multitenant.sql"),
  (Join-Path $root "database\postgres\002_audit_runtime.sql")
) | ForEach-Object { if (Test-Path $_) { Get-Content $_ -Raw } }
if ($initSql.Count -gt 0) {
  ($initSql -join "`n") | ssh @sshArgs $sshTarget "cd $RemotePath && docker compose --env-file .env.staging exec -T postgres psql -U inova -d inova_platform"
}

Write-Host ""
Write-Host "Deploy remoto concluido."
Write-Host "Teste origem: curl -sf http://${VpsHost}:8787/health"
Write-Host "Teste publico (apos rota CF): curl -sf https://$Domain/health"
Write-Host "Webhook: POST https://$Domain/webhook/publish (HMAC WEBHOOK_SECRET)"
