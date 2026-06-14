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

## Validacao

```bash
curl -sf https://staging.seudominio.com/health
```

Webhook autenticado: `POST /webhook/publish` com header HMAC (`WEBHOOK_SECRET`).
