---
name: full-pipeline-e2e
description: Executa teste E2E do pipeline DevSecOps completo (orchestrator + 10 workers) e valida worker_audit_log. Use quando validar Onda 3, release ou regressão do runtime event-driven.
---

# Full Pipeline E2E

## Pré-requisitos

- Docker Desktop rodando
- Stack: `docker compose up -d --build`

## Executar

**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -File scripts/e2e_full_pipeline.ps1
```

**Linux:**
```bash
bash scripts/e2e_full_pipeline.sh
```

## Critério de sucesso

- >= 11 workers distintos com `status = completed` no `worker_audit_log`
- Inclui: orchestrator, audit_pipeline, opencode_executor, sonar_worker, snyk_worker, datadog_worker, test_worker, build_worker, review_worker, release_worker, notification_worker

## Verificar manualmente

```bash
python scripts/query_audit_log.py --correlation-id <id-do-teste>
```

## Referências

- Payload: `examples/events/orchestrate_full_devsecops.json`
- Docs: `docs/WAVE3-OPERATIONS.md`, `docs/integrations/README.md`
