# Onda 3 — Operação, pipeline completo e produção

Ondas 1 e 2 entregaram runtime confiável, contratos, CI, Cursor DX e adapters externos (stub/integrated).

## Objetivos da Onda 3

1. **Pipeline DevSecOps E2E** — orquestrar todos os workers e validar `worker_audit_log`
2. **Contratos de integração** — documentar entrada/saída por provider (`docs/integrations/`)
3. **Testes integrated simulados** — mocks HTTP sem tokens reais
4. **Operação** — runbooks, consulta de audit log, checklist VPS/produção

## Comandos

```bash
# E2E parcial (orchestrator + audit) — Onda 2
make e2e-orchestrate-audit

# E2E pipeline completo (11 workers)
make e2e-full-pipeline

# Consultar audit log
python scripts/query_audit_log.py --correlation-id <id>
python scripts/query_audit_log.py --last 20
```

## Modo integrated (produção/staging)

Configure no `.env`:

| Variável | Worker |
|----------|--------|
| `OPENROUTER_API_KEY` | opencode_executor |
| `SONAR_HOST_URL`, `SONAR_TOKEN` | sonar_worker |
| `SNYK_TOKEN` | snyk_worker |
| `DATADOG_API_KEY` | datadog_worker |

Sem tokens, todos respondem em modo **stub** (seguro para local/CI).

## Checklist produção (VPS)

- [x] Trocar senhas default (`change_me`) em Postgres, MinIO, Redis
- [x] `APP_ENV=production` no `.env` (ou `staging` no overlay; defaults `change_me` bloqueados)
- [x] Firewall: expor só 80/443 (+ SSH); webhook em loopback
- [x] TLS no Postgres e NATS (overlay `docker-compose.hardening.yml`)
- [x] Backup PITR PostgreSQL + volume NATS JetStream
- [x] Monitoramento: Grafana `inova-audit-overview` + Datadog
- [x] Secrets em Vault / tmpfs `/run/inova` (não `.env` no checkout do servidor)

Ver Onda 7: `docs/WAVE7-HARDENING.md`

## Próxima etapa sugerida (Onda 4)

- MCP server local expondo `publish_event` e `query_audit_log` ao Cursor
- Integração GitHub Actions → publish orchestrate em PR/push
- Golden run com github-governance-mcp (branch protection + checks)
