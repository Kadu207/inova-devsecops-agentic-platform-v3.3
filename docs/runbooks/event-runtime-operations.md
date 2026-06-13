# Operação Event Runtime

## Health checks

| Serviço | URL / comando |
|---------|----------------|
| NATS | http://127.0.0.1:8222/healthz |
| Postgres | `docker compose exec postgres pg_isready -U inova -d inova_platform` |
| Workers | `docker compose ps` — todos `Up` |

## Consultar audit log

```bash
python scripts/query_audit_log.py --last 30
python scripts/query_audit_log.py --correlation-id e2e-full-...
python scripts/query_audit_log.py --worker audit_pipeline
```

Via SQL:

```sql
SELECT worker, event_type, status, correlation_id, created_at
FROM public.worker_audit_log
ORDER BY id DESC LIMIT 30;
```

## DLQ

```sql
SELECT * FROM public.dead_letter_events ORDER BY id DESC LIMIT 20;
```

Logs: `docker compose logs orchestrator audit-worker --tail=100`

## E2E operacional

```powershell
powershell -ExecutionPolicy Bypass -File scripts/e2e_orchestrate_audit.ps1
powershell -ExecutionPolicy Bypass -File scripts/e2e_full_pipeline.ps1
```

## Incidentes comuns

| Sintoma | Causa provável | Ação |
|---------|----------------|------|
| Postgres não sobe | Porta 5432/5433 ocupada | Usar host `55432` (docker-compose) |
| NATS unhealthy | Imagem scratch sem wget | Usar `nats:2.10-alpine` |
| Publisher ModuleNotFoundError | PYTHONPATH | Rebuild workers (`docker compose build`) |
| 0 rows no audit log | Workers não subiram | `docker compose up -d --build` e aguardar healthy |

Ver também: `docs/WAVE3-OPERATIONS.md`
