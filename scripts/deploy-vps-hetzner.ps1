param(
  [Parameter(Mandatory = $true)]
  [string]$Domain,
  [Parameter(Mandatory = $true)]
  [string]$VpsHost,
  [string]$VpsUser = "root",
  [int]$SshPort = 22,
  [string]$RemotePath = "/opt/inova-devsecops",
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
$sshArgs = @("-p", $SshPort, "-o", "StrictHostKeyChecking=accept-new")

Write-Host "==> Preparando diretorio remoto..."
ssh @sshArgs $sshTarget "mkdir -p $RemotePath"

Write-Host "==> Enviando arquivos (exclui .venv, .git)..."
if (-not (Get-Command rsync -ErrorAction SilentlyContinue)) {
  Write-Host "rsync nao encontrado. Use WSL/Git-Bash ou instale rsync."
  Write-Host "Alternativa: git clone no VPS e copie apenas .env.staging via scp."
  exit 1
}

$exclude = @(
  "--exclude=.git",
  "--exclude=.venv",
  "--exclude=.env",
  "--exclude=reports",
  "--exclude=.scannerwork"
)
$rsyncCmd = @(
  "-az", "--delete",
  "-e", "ssh -p $SshPort -o StrictHostKeyChecking=accept-new",
  @exclude,
  "$root/",
  "${sshTarget}:${RemotePath}/"
)
& rsync @rsyncCmd

Write-Host "==> Enviando .env.staging..."
scp -P $SshPort -o StrictHostKeyChecking=accept-new ".env.staging" "${sshTarget}:${RemotePath}/.env.staging"

Write-Host "==> Subindo stack (Caddy + webhook + workers)..."
$remoteCmd = "cd $RemotePath && export INOVA_DOMAIN='$Domain' && docker compose --env-file .env.staging -f docker-compose.yml -f deploy/vps/docker-compose.vps.yml --profile staging --profile vps up -d --build && sleep 5 && curl -sf http://127.0.0.1:8787/health || true"
ssh @sshArgs $sshTarget $remoteCmd

Write-Host ""
Write-Host "Deploy remoto concluido."
Write-Host "Teste: curl -sf https://$Domain/health"
Write-Host "Webhook: POST https://$Domain/webhook/publish (HMAC com WEBHOOK_SECRET)"
