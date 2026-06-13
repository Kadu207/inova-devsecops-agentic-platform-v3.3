# AGENTS.md - Inova DevSecOps Agentic Platform v3.3

## Objetivo
Guia operacional para agentes Cursor neste repositorio event-driven.

## Bootstrap
- Windows: `powershell -ExecutionPolicy Bypass -File scripts/cursor-bootstrap.ps1`
- Linux/macOS: `make bootstrap`
- Subir stack: `docker compose up -d --build`

## Comandos uteis
- Validar contratos: `python scripts/validate_contracts.py`
- Publicar auditoria: `make publish-audit`
- Publicar orquestracao: `make publish-orchestrate`
- Pipeline completo: `make publish-full-pipeline`
- Consultar audit log: `make audit-log` ou `python scripts/query_audit_log.py --correlation-id <id>`
- E2E parcial: `make e2e-orchestrate-audit`
- E2E completo: `make e2e-full-pipeline`
- Release gate local: `make release-check`

## Arquitetura
- Mensageria: NATS JetStream (`runtime/nats_bus.py`)
- Envelope: `runtime/events.py`
- Workers: `workers/*/main.py`
- Orquestrador: subject `task.orchestrate.requested` (nao usar `task.*`)
- Contratos: `contracts/events/*.schema.json`

## Modos de execucao
- **stub**: sem credenciais externas (padrao local)
- **integrated**: Sonar/Snyk/Datadog/OpenRouter quando tokens existirem no `.env`

## Skills Cursor
- `.cursor/skills/event-audit/SKILL.md`
- `.cursor/skills/opencode-audit/SKILL.md`
- `.cursor/skills/release-validation/SKILL.md`
- `.cursor/skills/full-pipeline-e2e/SKILL.md`

## MCP (Onda 4)
- Server: `mcp/inova-runtime-mcp/` — tools `publish_orchestrate`, `publish_event`, `query_audit_log`, `runtime_health`
- Config: `.cursor/mcp.json` → `inova-runtime-mcp-local`
- Docs: `docs/WAVE4-MCP-AND-CI.md`

## Windows
Use `scripts/make.ps1 <target>` em vez de `make` (ex.: `make.ps1 audit-log`).

## Regras
Todas em `.cursor/rules/*.mdc` com frontmatter aplicavel.

## Evidencias
- Audit log: tabela `worker_audit_log`
- DLQ: subject `dlq.task.failed` + tabela `dead_letter_events`
