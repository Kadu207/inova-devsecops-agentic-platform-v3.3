# Runbook VPS (Hetzner + Cloudflare)

## Por que dominio + VPS?

| Camada | Funcao |
|--------|--------|
| **Local (Docker)** | Desenvolvimento e E2E; webhook em `127.0.0.1:8787` — inacessivel da internet |
| **Dominio (Cloudflare)** | Nome estavel (`staging.seudominio.com`), DNS, opcional WAF/DDoS |
| **VPS (Hetzner)** | Stack 24/7; recebe webhooks de GitHub/Sonar/ferramentas externas |
| **Caddy (no VPS)** | TLS automatico (Let's Encrypt) e reverse proxy para `webhook-ingress` |

Sem VPS/dominio publico, integracoes externas nao conseguem chamar `POST /webhook/publish`.

## Cloudflare DNS

1. Registro **A**: `staging.seudominio.com` → IP publico da VPS Hetzner
2. Para Caddy + Let's Encrypt na origem: **proxy desligado** (nuvem cinza) ou SSL **Full**
3. Firewall Hetzner: liberar **22** (SSH), **80** e **443** (Caddy)

## Deploy remoto (Hetzner)

```powershell
# Na maquina local (com SSH configurado para a VPS)
powershell -ExecutionPolicy Bypass -File scripts/deploy-vps-hetzner.ps1 `
  -Domain staging.seudominio.com `
  -VpsHost 203.0.113.10 `
  -VpsUser root
```

## Deploy local (teste Caddy — mesma maquina)

```powershell
powershell -ExecutionPolicy Bypass -File scripts/deploy-vps.ps1 -Domain staging.seudominio.com
```

## Modo Cloudflare (porta 80 ocupada — Excellence Dental)

Quando a VPS ja usa **80/443** (nginx, cloudflared, etc.), use o override `deploy/vps/docker-compose.cloudflare.yml`:

- Webhook exposto em **`127.0.0.1:8787`** (Onda 7 — nao publicar 8787)
- MinIO remapeado para **`127.0.0.1:19000`** (evita conflito com MinIO do Swarm na 9000)
- **Sem Caddy** na origem; use Cloudflare Tunnel para 80/443 -> `http://127.0.0.1:8787`

```powershell
powershell -ExecutionPolicy Bypass -File scripts/deploy-vps-hetzner.ps1 `
  -Domain skillsmcp.inovatitech.com.br `
  -VpsHost 128.140.77.31 `
  -VpsUser gestaoti `
  -TlsMode cloudflare `
  -SkipDnsCheck `
  -IdentityFile "$env:USERPROFILE\.ssh\agenda-deploy"
```

### Roteamento Cloudflare (obrigatorio)

O dominio com **proxy laranja** hoje pode apontar para outro servico (ex.: Excellence Dental). Configure uma das opcoes:

**Opcao A — Cloudflare Tunnel / Zero Trust (recomendado se ja usa cloudflared):**

1. Dashboard Cloudflare → **Zero Trust** → **Networks** → **Tunnels**
2. Edite o tunnel da VPS → **Public Hostname**
3. Hostname: `skillsmcp.inovatitech.com.br`
4. Service: `http://127.0.0.1:8787` (ou `http://host.docker.internal:8787` conforme rede do tunnel)

**Opcao B — Origin Rules / Workers (proxy → IP:8787):**

1. Crie regra para `skillsmcp.inovatitech.com.br/*` → origin `http://128.140.77.31:8787`
2. Firewall Hetzner: liberar **TCP 8787** (somente se Cloudflare conectar direto ao IP, nao via tunnel interno)

**Opcao C — DNS grey cloud (sem proxy):**

1. Registro A: `skillsmcp` → `128.140.77.31`, proxy **desligado**
2. Clientes acessam `http://skillsmcp.inovatitech.com.br:8787/health` (sem TLS nativo na 8787)

### Validacao pos-deploy

```bash
# Origem (deve retornar JSON ok)
curl -sf http://128.140.77.31:8787/health

# Publico (apos rota CF)
curl -sf https://skillsmcp.inovatitech.com.br/health
```
