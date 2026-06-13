# Onda 6 — Staging integrated, observabilidade e VPS

## 1) Staging integrated (Sonar / Snyk / Datadog)

```powershell
copy .env.staging.example .env.staging
# Preencha SONAR_TOKEN, SNYK_TOKEN, DATADOG_API_KEY
docker compose --env-file .env.staging --profile staging up -d --build
```

| Variavel | Valor staging | Efeito |
|----------|---------------|--------|
| `WORKER_ADAPTER_MODE` | `integrated` | Falha se token ausente (nao cai em stub) |
| `WORKER_ADAPTER_MODE` | `auto` | Usa token se existir (default dev) |
| `OBSERVABILITY_DATADOG_ENABLED` | `true` | Cada `write_audit` exporta para Datadog |

Tokens reais nunca vao para o git — apenas `.env.staging` local/VPS.

---

## 2) Observabilidade — audit log para Datadog

### Automatico (runtime)

Com `OBSERVABILITY_DATADOG_ENABLED=true`, cada linha em `worker_audit_log` gera:
- **Log** em Datadog Logs (`ddsource=inova-runtime`)
- **Event** em Datadog Events (status completed/failed)

Tags: `tenant`, `project`, `worker`, `correlation_id`, `env`.

### Batch (backfill)

```powershell
.venv\Scripts\python.exe scripts/export_audit_log_datadog.py --last 100
.venv\Scripts\python.exe scripts/export_audit_log_datadog.py --correlation-id e2e-full-20260613190236
```

### Grafana (opcional)

Datadog e a fonte primaria nesta onda. Para Grafana self-hosted:
1. Configure Loki/Prometheus ou plugin Datadog no Grafana
2. Use `GRAFANA_URL` + `GRAFANA_API_KEY` em `.env.staging` para automacao futura
3. Dashboard de referencia: `deploy/grafana/inova-audit-overview.json`

Consultas uteis no Datadog Logs:
```
service:inova-devsecops-agentic-platform @attributes.worker:sonar_worker
@attributes.correlation_id:e2e-full-*
```

---

## 3) Deploy VPS — webhook + TLS

### Pre-requisitos VPS

- Docker + Compose
- Dominio apontando para o IP (`A` record)
- Portas 80/443 abertas

### Deploy

```powershell
$env:INOVA_DOMAIN = "staging.seudominio.com"
powershell -ExecutionPolicy Bypass -File scripts/deploy-vps.ps1 -Domain staging.seudominio.com
```

```bash
INOVA_DOMAIN=staging.seudominio.com bash scripts/deploy-vps.sh
```

Stack: workers + `webhook-ingress` + **Caddy** (TLS automatico Let's Encrypt).

### Endpoints publicos

| URL | Descricao |
|-----|-----------|
| `GET https://<domain>/health` | Health webhook |
| `POST https://<domain>/webhook/publish` | Publica evento NATS (HMAC) |

### Seguranca VPS

- Rotacionar `WEBHOOK_SECRET` e credenciais Postgres
- `APP_ENV=staging` ou `production` (bloqueia defaults `change_me`)
- Firewall: apenas 80/443 publicos; Postgres/NATS nao expostos

---

## Validacao pos-deploy

```powershell
curl http://127.0.0.1:8787/health
powershell -ExecutionPolicy Bypass -File scripts/wave5_golden_run.ps1
powershell -ExecutionPolicy Bypass -File scripts/apply_branch_protection.ps1
```

---

## Correcoes Onda 5 (aplicadas)

| Erro | Causa | Correcao |
|------|-------|----------|
| `wave5_golden_run.ps1` parse error | Unicode em-dash e backticks PowerShell | ASCII + List[string] |
| `utf8NoBOM` invalido | PowerShell 5.x | `[System.IO.File]::WriteAllText` UTF8 sem BOM |
| `curl: (52) Empty reply` | `log.info(extra={"message":...})` conflita LogRecord | Campo `line` + Connection close |
