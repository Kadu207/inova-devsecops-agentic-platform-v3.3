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
  [switch]$SkipDnsCheck,
  [switch]$Hardening,
  [switch]$SkipFirewall
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
  ".dockerignore", "tests", "examples"
)
foreach ($item in $items) {
  $localPath = Join-Path $root $item
  if (Test-Path $localPath) {
    & scp @scpArgs -r $localPath $remote
  }
}
ssh @sshArgs $sshTarget "chmod -R a+rX $RemotePath/workers $RemotePath/runtime $RemotePath/contracts $RemotePath/scripts 2>/dev/null || true"

Write-Host "==> Injetando secrets em tmpfs /run/inova (nao permanece no checkout)"
$remoteEnv = "${sshTarget}:/tmp/inova.env"
& scp @scpArgs ".env.staging" $remoteEnv
$injectCmd = @"
sudo mkdir -p /run/inova && sudo cp /tmp/inova.env /run/inova/env && sudo chown $VpsUser`:$VpsUser /run/inova /run/inova/env && sudo chmod 700 /run/inova && sudo chmod 600 /run/inova/env && rm -f /tmp/inova.env
if ! grep -q 'sslmode=require' /run/inova/env; then
  sed -i 's|DATABASE_URL=\(.*\)$|DATABASE_URL=\1?sslmode=require|' /run/inova/env
fi
grep -q '^NATS_URL=tls://' /run/inova/env || echo 'NATS_URL=tls://nats:4222' >> /run/inova/env
grep -q '^NATS_TLS_CA=' /run/inova/env || echo 'NATS_TLS_CA=/app/deploy/tls/generated/ca.crt' >> /run/inova/env
grep -q '^VAULT_ADDR=' /run/inova/env || echo 'VAULT_ADDR=http://vault:8200' >> /run/inova/env
grep -q '^INOVA_SECRETS_FILE=' /run/inova/env || echo 'INOVA_SECRETS_FILE=/run/inova/env' >> /run/inova/env
grep -q '^APP_ENV=' /run/inova/env || echo 'APP_ENV=staging' >> /run/inova/env
"@
ssh @sshArgs $sshTarget $injectCmd

if ($TlsMode -eq "cloudflare") {
  Write-Host "Modo Cloudflare: webhook em 127.0.0.1:8787 (firewall so 80/443)."
  Write-Host "Configure Cloudflare Tunnel: $Domain -> http://127.0.0.1:8787"
  $composeFiles = "-f docker-compose.yml -f deploy/vps/docker-compose.hardening.yml -f deploy/vps/docker-compose.cloudflare.yml"
} else {
  $composeFiles = "-f docker-compose.yml -f deploy/vps/docker-compose.hardening.yml -f deploy/vps/docker-compose.vps.yml --profile vps"
}

Write-Host "==> Gerando TLS interno..."
ssh @sshArgs $sshTarget "cd $RemotePath && bash deploy/tls/generate-certs.sh && (chown 999:999 deploy/tls/generated/postgres.key deploy/tls/generated/postgres.crt 2>/dev/null || sudo chown 999:999 deploy/tls/generated/postgres.key deploy/tls/generated/postgres.crt)"

Write-Host "==> Subindo stack (hardening)..."
$profiles = "--profile staging --profile observability"
$remoteCmd = "cd $RemotePath && export INOVA_DOMAIN='$Domain' && docker compose --env-file /run/inova/env $composeFiles $profiles up -d --build && sleep 15 && curl -sf http://127.0.0.1:8787/health"
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
  ($initSql -join "`n") | ssh @sshArgs $sshTarget "cd $RemotePath && docker compose --env-file /run/inova/env exec -T postgres psql -U inova -d inova_platform"
}

Write-Host "==> Vault bootstrap + upload de secrets..."
$vaultCmd = "cd $RemotePath && docker compose --env-file /run/inova/env $composeFiles $profiles up -d vault && sleep 8 && docker compose --env-file /run/inova/env $composeFiles exec -T -e VAULT_ADDR=http://127.0.0.1:8200 vault vault status || true"
ssh @sshArgs $sshTarget $vaultCmd
ssh @sshArgs $sshTarget "cd $RemotePath && INOVA_RUN_DIR=/run/inova VAULT_ADDR=http://127.0.0.1:8200 bash scripts/vault_bootstrap.sh deploy/vault/policies/workers.hcl"
ssh @sshArgs $sshTarget "cd $RemotePath && VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=`$(sudo cat /run/inova/vault_root_token) docker compose --env-file /run/inova/env $composeFiles run --rm --no-deps --entrypoint python orchestrator scripts/vault_put_secrets.py --env-file /run/inova/env --addr http://vault:8200 --render /run/inova/env"

if (-not $SkipFirewall) {
  Write-Host "==> Firewall UFW (22/80/443)..."
  ssh @sshArgs $sshTarget "bash $RemotePath/deploy/vps/ufw-firewall.sh $SshPort"
}

Write-Host ""
Write-Host "Deploy remoto concluido (Onda 7 hardening)."
Write-Host "Health loopback: curl -sf http://127.0.0.1:8787/health  (na VPS)"
Write-Host "Publico (apos tunnel/Caddy): curl -sf https://$Domain/health"
Write-Host "Grafana: http://127.0.0.1:3000  (uid=inova-audit-overview)"
Write-Host "Webhook: POST https://$Domain/webhook/publish (HMAC WEBHOOK_SECRET)"
