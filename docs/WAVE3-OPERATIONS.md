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

- [ ] Trocar senhas default (`change_me`) em Postgres, MinIO, Redis
- [ ] `APP_ENV=production` no `.env`
- [ ] Firewall: expor só portas necessárias (443/80, não 55432 publicamente)
- [ ] TLS no Postgres e NATS (ou rede privada)
- [ ] Backup PITR PostgreSQL + volume NATS JetStream
- [ ] Monitoramento: health NATS `:8222`, logs workers, alertas Datadog
- [ ] Secrets em vault (não `.env` em disco no servidor)

## Próxima etapa sugerida (Onda 4)

- MCP server local expondo `publish_event` e `query_audit_log` ao Cursor
- Integração GitHub Actions → publish orchestrate em PR/push
- Golden run com github-governance-mcp (branch protection + checks)
