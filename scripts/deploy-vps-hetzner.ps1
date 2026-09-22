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
if ($TlsMode -eq "cloudflare") {
  $composeFiles = "-f docker-compose.yml -f deploy/vps/docker-compose.hardening.yml -f deploy/vps/docker-compose.cloudflare.yml"
  $composeEnv = "docker-compose.yml:deploy/vps/docker-compose.hardening.yml:deploy/vps/docker-compose.cloudflare.yml"
} else {
  $composeFiles = "-f docker-compose.yml -f deploy/vps/docker-compose.hardening.yml -f deploy/vps/docker-compose.vps.yml --profile vps"
  $composeEnv = "docker-compose.yml:deploy/vps/docker-compose.hardening.yml:deploy/vps/docker-compose.vps.yml"
}
$sshArgs = @("-p", $SshPort, "-o", "StrictHostKeyChecking=accept-new")
if ($IdentityFile -and (Test-Path $IdentityFile)) {
  $sshArgs = @("-i", $IdentityFile) + $sshArgs
}

Write-Host "==> Preparando diretorio remoto ($RemotePath)..."
$prepareCmd = "if [ -d $RemotePath ]; then cd $RemotePath && if [ -r /run/inova/env ]; then docker compose --env-file /run/inova/env $composeFiles --profile staging --profile observability down 2>/dev/null || true; fi; chmod -R u+rwX $RemotePath 2>/dev/null || true; fi; rm -rf $RemotePath; mkdir -p $RemotePath"
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
$injectCmd = @'
sudo mkdir -p /run/inova && sudo cp /tmp/inova.env /run/inova/env && sudo chown __VPS_USER__:999 /run/inova /run/inova/env && sudo chmod 750 /run/inova && sudo chmod 640 /run/inova/env && rm -f /tmp/inova.env
db_url="$(grep '^DATABASE_URL=' /run/inova/env | cut -d= -f2-)"
if [ -z "$db_url" ]; then echo 'DATABASE_URL ausente' >&2; exit 1; fi
case "$db_url" in
  *sslmode=*) db_url="$(printf '%s' "$db_url" | sed -E 's/([?&])sslmode=[^&]*/\1sslmode=require/')" ;;
  *\?*) db_url="${db_url}&sslmode=require" ;;
  *) db_url="${db_url}?sslmode=require" ;;
esac
awk -v value="$db_url" 'BEGIN { updated=0 } /^DATABASE_URL=/ { print "DATABASE_URL=" value; updated=1; next } { print } END { if (!updated) print "DATABASE_URL=" value }' /run/inova/env > /run/inova/env.tmp
mv /run/inova/env.tmp /run/inova/env
set_env() {
  key="$1"; value="$2"
  awk -v key="$key" -v value="$value" 'BEGIN { updated=0 } index($0, key "=") == 1 { if (!updated) print key "=" value; updated=1; next } { print } END { if (!updated) print key "=" value }' /run/inova/env > /run/inova/env.tmp
  mv /run/inova/env.tmp /run/inova/env
}
set_env NATS_URL tls://nats:4222
set_env NATS_TLS_CA /app/deploy/tls/generated/ca.crt
set_env VAULT_ADDR https://vault:8200
set_env VAULT_CACERT /app/deploy/tls/generated/ca.crt
set_env VAULT_TOKEN_FILE /run/inova/vault_token
set_env INOVA_SECRETS_FILE /run/inova/env
set_env APP_ENV staging
'@
$injectCmd = $injectCmd.Replace("__VPS_USER__", $VpsUser)
ssh @sshArgs $sshTarget $injectCmd

if ($TlsMode -eq "cloudflare") {
  Write-Host "Modo Cloudflare: webhook em 127.0.0.1:8787 (firewall so 80/443)."
  Write-Host "Configure Cloudflare Tunnel: $Domain -> http://127.0.0.1:8787"
}

Write-Host "==> Gerando TLS interno..."
ssh @sshArgs $sshTarget "cd $RemotePath && bash deploy/tls/generate-certs.sh && sudo chown 999:999 deploy/tls/generated/postgres.key deploy/tls/generated/postgres.crt && sudo chown 100:100 deploy/tls/generated/vault.key deploy/tls/generated/vault.crt"

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
$vaultCmd = "cd $RemotePath && docker compose --env-file /run/inova/env $composeFiles $profiles up -d vault && sleep 8 && docker compose --env-file /run/inova/env $composeFiles exec -T -e VAULT_ADDR=https://127.0.0.1:8200 -e VAULT_CACERT=/vault/tls/ca.crt vault vault status || true"
ssh @sshArgs $sshTarget $vaultCmd
ssh @sshArgs $sshTarget "cd $RemotePath && COMPOSE_FILE='$composeEnv' INOVA_RUN_DIR=/run/inova VAULT_ADDR=https://127.0.0.1:8200 VAULT_CACERT=$RemotePath/deploy/tls/generated/ca.crt bash scripts/vault_bootstrap.sh deploy/vault/policies/workers.hcl"
ssh @sshArgs $sshTarget "cd $RemotePath && VAULT_TOKEN=`$(sudo cat /run/inova/vault_root_token) docker compose --env-file /run/inova/env $composeFiles run --rm --no-deps --user 0 --volume /run/inova:/run/inova:rw -e VAULT_TOKEN -e VAULT_CACERT=/app/deploy/tls/generated/ca.crt --entrypoint python orchestrator scripts/vault_put_secrets.py --env-file /run/inova/env --addr https://vault:8200"
ssh @sshArgs $sshTarget "cd $RemotePath && docker compose --env-file /run/inova/env $composeFiles $profiles restart orchestrator audit-worker opencode-worker sonar-worker snyk-worker datadog-worker test-worker build-worker review-worker release-worker notification-worker webhook-ingress"
ssh @sshArgs $sshTarget "sudo chown $VpsUser`:999 /run/inova /run/inova/env && sudo chmod 750 /run/inova && sudo chmod 640 /run/inova/env && sudo chown 999:999 /run/inova/vault_token && sudo chmod 400 /run/inova/vault_token"

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
