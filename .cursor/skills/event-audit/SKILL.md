---
name: event-audit
description: Executa auditoria event-driven local publicando task.audit.requested e validando contratos/audit log. Use quando o usuario pedir auditoria de pipeline, event audit ou publish-audit.
---

# Event Audit

## Quando usar
- Auditoria de pipeline via workers NATS
- Validacao de contratos antes de publicar evento

## Passos
1. Rodar `python scripts/validate_contracts.py`
2. Garantir stack ativa: `docker compose up -d`
3. Publicar evento:
   - `make publish-audit`
   - ou `python scripts/publish_event.py --subject task.audit.requested --payload examples/events/audit_requested.json`
4. Verificar logs: `docker compose logs audit-worker --tail=100`
5. Consultar audit log SQL:
   - `select worker,status,created_at from worker_audit_log order by id desc limit 20;`

## Criterio de sucesso
- Worker retorna `task.audit.completed`
- Registro `completed` em `worker_audit_log`
