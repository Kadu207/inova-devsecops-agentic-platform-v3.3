# Event Audit

1. Rodar `python scripts/validate_contracts.py`
2. Publicar: `make publish-audit`
3. Verificar logs: `docker compose logs audit-worker --tail=100`
4. Consultar audit log no PostgreSQL (`worker_audit_log`)
