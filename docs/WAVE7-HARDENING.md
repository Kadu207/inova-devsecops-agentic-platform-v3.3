# Onda 7 — Hardening de produção e gates de merge

Ondas 1–6 entregaram runtime, E2E, MCP, CI, golden run, staging integrated e webhook na VPS. A Onda 7 fecha o ciclo de **produção**: secrets fora do checkout, TLS interno, backup PITR, firewall mínimo, scans de container/segredo e merge gate real na `main`.

## Decisão de governança (branch protection)

Branch protection e rulesets exigem GitHub Pro/Team em repositório **privado**. No GitHub Free a API retorna 403.

**Solução adotada:** tornar o repositório **público**. No GitHub Free, repositórios públicos suportam protected branches e required status checks. Secrets do Actions (`SONAR_TOKEN`, `WEBHOOK_SECRET`, `WEBHOOK_URL`) permanecem criptografados. Arquivos `.env` / `.env.staging` continuam no `.gitignore`.

Não há outro caminho gratuito que bloqueie merge na `main`.

## Escopo

| Item | Entrega |
|------|---------|
| Spec | este documento + constituição |
| Gitleaks | job `gitleaks` em PRs e push (`security.yml`) |
| Trivy | job `trivy` no `Dockerfile.worker` (gate CRITICAL) |
| OpenCode integrated | `OPENROUTER_API_KEY` no runtime staging; falha em modo `integrated` se ausente |
| Grafana | serviço `observability` + provisionamento de `inova-audit-overview` |
| Vault | KV v2; workers leem secrets; `.env` não permanece no diretório da aplicação na VPS |
| TLS | Postgres `ssl=on` e NATS `tls://` no overlay de hardening |
| PITR | `wal_level=replica` + archive + sidecar de basebackup |
| Firewall | UFW: 22/tcp (SSH), 80, 443; webhook só em `127.0.0.1` |
| Merge gate | `gates`, `e2e-orchestrate-audit`, `ci`, `security`, `gitleaks`, `trivy` |

## Arquitetura de secrets (VPS)

```
Operador (local .env.staging)
        |  SSH / tmpfs /run/inova/env
        v
   Vault KV secret/inova/runtime
        |
        +--> render /run/inova/env (tmpfs, compose interpolation)
        +--> workers: VAULT_ADDR + token de política restrita
```

- Checkout em `/opt/inova-devsecops` **não** contém `.env` nem `.env.staging`.
- Unseal key e root token ficam em `/run/inova/` (tmpfs) no deploy; após reboot, re-injetar ou unseal manual.
- Política `inova-workers` só lê `secret/data/inova/runtime`.

## TLS interno

Certificados gerados em `deploy/tls/generated/` (gitignored) com CA interna:

- Postgres: `postgres.crt` / `postgres.key`, `sslmode=require`
- NATS: `nats.crt` / `nats.key`, `NATS_URL=tls://nats:4222`, `NATS_TLS_CA=.../ca.crt`

Dev local (sem profile `hardening`) permanece `nats://` e Postgres sem SSL para não quebrar E2E.

## Critérios de aceite

- [x] `docs/WAVE7-HARDENING.md` versionado
- [x] Job `gitleaks` no workflow `security` (PRs + push)
- [x] Job `trivy` faz build da imagem worker e falha em CRITICAL
- [x] Grafana sobe com profile `observability` e dashboard `inova-audit-overview` provisionado
- [x] Overlay `deploy/vps/docker-compose.hardening.yml` com Vault, TLS, PITR, Grafana
- [x] Deploy Hetzner injeta secrets em `/run/inova` e não copia `.env` para o checkout
- [x] Firewall script libera só 22/80/443 (e porta SSH custom)
- [x] Repositório público + branch protection na `main` com required checks
- [x] Testes unitários do loader de secrets, TLS NATS e presença dos jobs CI

## Comandos

```powershell
powershell -ExecutionPolicy Bypass -File scripts/make.ps1 test
powershell -ExecutionPolicy Bypass -File scripts/make.ps1 observability-up
powershell -ExecutionPolicy Bypass -File scripts/import_grafana_dashboard.ps1
powershell -ExecutionPolicy Bypass -File scripts/apply_branch_protection.ps1 -MakePublicIfRequired
```

## Fora de escopo

- GitHub Pro / org Team
- Auto-unseal com KMS cloud
- mTLS obrigatório cliente-NATS (TLS server-side nesta onda)
