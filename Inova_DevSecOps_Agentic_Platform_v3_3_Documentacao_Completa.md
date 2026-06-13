
# Inova DevSecOps Agentic Platform v3.3 — Event-Driven Workers Runtime

## 1. Objetivo
A v3.3 transforma o template em uma plataforma executável de orquestração por eventos, preparada para uso no Cursor. Ela usa NATS JetStream para mensageria, workers separados para tarefas distintas, audit log em PostgreSQL e contratos JSON versionados.

## 2. Fluxo operacional
Cursor ou GitHub Actions publica um evento, o Orchestrator roteia, workers especializados processam, resultados são publicados em eventos `.completed` e evidências são registradas no PostgreSQL.

## 3. Workers implementados
- orchestrator
- audit-pipeline
- opencode-executor
- sonar-worker
- snyk-worker
- datadog-worker
- test-worker
- build-worker
- review-worker
- release-worker
- notification-worker

## 4. Mensageria
NATS JetStream com stream `INOVA_TASKS`, subjects `task.*`, `pipeline.*`, `review.*`, `release.*` e `dlq.*`. Cada worker usa durable consumer próprio, confirmação explícita, retry e DLQ.

## 5. Retry e DLQ
Cada worker tenta processar até 3 vezes. Após falha, publica `task.failed` em `dlq.task.failed`.

## 6. Audit log
Toda execução registra início, conclusão e falhas em `public.worker_audit_log`.

## 7. PostgreSQL multi-tenant
Inclui tenants, users, tenant_secrets, project_memory, RLS e tabelas de auditoria.

## 8. OpenCode/OpenRouter/DeepSeek
O OpenCode funciona como executor opcional. Configure `OPENROUTER_API_KEY` e `OPENROUTER_MODEL`. O worker `opencode_executor` está pronto para receber `task.opencode.requested`.

## 9. Como usar no Cursor
Abra a pasta no Cursor. As regras `.cursor/rules` orientarão arquitetura, TDD, SDD, segurança, banco multi-tenant e workers event-driven.

## 10. Comandos
```bash
cp .env.example .env
bash scripts/cursor-bootstrap.sh
make dev
make publish-audit
make publish-opencode
make logs
```

## 11. Produção/VPS
Para produção, trocar senhas, usar Vault/secrets, habilitar TLS do PostgreSQL, configurar backup PITR, restringir portas no firewall e ativar observabilidade.

## 12. Limites conscientes
O pacote é executável em desenvolvimento local. Integrações externas exigem tokens reais. O worker OpenCode está preparado como executor e pode ser expandido para chamar comandos reais do OpenCode conforme ambiente.


# Política de Privacidade

Documento base LGPD para sistemas Inova TI. Ajustar com jurídico antes de publicação.


# Termos de Uso

Documento base de termos de uso para plataformas Inova TI. Ajustar com jurídico antes de publicação.


# Operação Event Runtime

Monitorar NATS em :8222, logs dos workers, tabela worker_audit_log e DLQ.


# Runbook VPS

1. Instalar Docker. 2. Copiar pacote. 3. Configurar .env. 4. Executar docker compose up -d --build. 5. Validar logs e audit log.


# Segurança de Banco

PostgreSQL com RLS, TLS, pgAudit, secrets fora do código, usuários por função e backup PITR.


# Segurança de Pipeline

SAST, DAST, secret scan, container scan, dependency scan, branch protection, least privilege e bloqueio por quality gate.


# Anexo — Workers

- orchestrator
- audit_pipeline
- opencode_executor
- sonar_worker
- snyk_worker
- datadog_worker
- test_worker
- build_worker
- review_worker
- release_worker
- notification_worker

# Anexo — Agentes

- 1. Product Owner
- 2. Business Analyst
- 3. Spec Writer
- 4. Architect
- 5. Threat Modeler
- 6. Backend Engineer
- 7. Frontend Engineer
- 8. Database Engineer
- 9. DevOps Engineer
- 10. Integration Engineer
- 11. Unit Tester
- 12. Integration Tester
- 13. E2E Tester
- 14. Security Tester
- 15. Performance Tester
- 16. Code Reviewer
- 17. Architecture Reviewer
- 18. Security Reviewer
- 19. UX Reviewer
- 20. Documentation Reviewer
- 21. Quality Gate Validator
- 22. Compliance Validator
- 23. Release Validator
- 24. Production Validator
- 25. Final Approval Agent
- 26. Orchestrator
- 27. Auditor Agent
- 28. Memory Manager
- 29. Knowledge Curator
- 30. Incident Manager
- 31. OpenCode Executor
- 32. Event Runtime Supervisor

# Anexo — Contratos de Eventos

- task.audit.completed.schema.json
- task.audit.requested.schema.json
- task.build.completed.schema.json
- task.build.requested.schema.json
- task.datadog.completed.schema.json
- task.datadog.requested.schema.json
- task.failed.schema.json
- task.notification.completed.schema.json
- task.notification.requested.schema.json
- task.opencode.completed.schema.json
- task.opencode.requested.schema.json
- task.release.completed.schema.json
- task.release.requested.schema.json
- task.review.completed.schema.json
- task.review.requested.schema.json
- task.snyk.completed.schema.json
- task.snyk.requested.schema.json
- task.sonar.completed.schema.json
- task.sonar.requested.schema.json
- task.test.completed.schema.json
- task.test.requested.schema.json