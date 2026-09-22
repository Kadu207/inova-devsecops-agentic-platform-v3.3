# Inova DevSecOps Agentic Platform v3.3

Versão **3.3 — Event-Driven Workers Runtime** com hardening de contratos, CI real e integração Cursor.

## Uso rápido

### Windows
```powershell
copy .env.example .env
powershell -ExecutionPolicy Bypass -File scripts/cursor-bootstrap.ps1
docker compose up -d --build
python scripts/validate_contracts.py
make publish-orchestrate
```

### Linux/macOS
```bash
cp .env.example .env
make bootstrap
make dev
make validate-contracts
make publish-orchestrate
```

## Serviços principais

- NATS JetStream: mensageria e streams duráveis
- PostgreSQL: multi-tenant, audit log (`worker_audit_log`) e DLQ (`dead_letter_events`)
- Workers: orquestração (`task.orchestrate.requested`), auditoria, OpenCode, Sonar, Snyk, Datadog, testes, build, revisão, release e notificações

## Modos de worker

- **stub** (padrão local): resposta simulada sem credenciais
- **integrated**: Sonar/Snyk/Datadog/OpenRouter quando tokens existirem no `.env`

## Cursor

- Regras: `.cursor/rules/*.mdc` (com frontmatter)
- Skills: `.cursor/skills/*/SKILL.md`
- Comandos: `.cursor/commands/`
- Guia agente: `AGENTS.md`

## Gates locais

```bash
make lint
make validate-contracts
make test
make release-check
```

## E2E (Onda 3)

```powershell
# Windows — pipeline parcial (orchestrator + audit)
powershell -ExecutionPolicy Bypass -File scripts/e2e_orchestrate_audit.ps1

# Windows — pipeline DevSecOps completo (11 workers)
powershell -ExecutionPolicy Bypass -File scripts/e2e_full_pipeline.ps1
```

```bash
make e2e-orchestrate-audit
make e2e-full-pipeline
python scripts/query_audit_log.py --correlation-id <id>
```

Documentação: `docs/WAVE3-OPERATIONS.md`, `docs/integrations/README.md`, `docs/WAVE4-MCP-AND-CI.md`, `docs/WAVE7-HARDENING.md`

### Windows (sem `make`)

```powershell
powershell -ExecutionPolicy Bypass -File scripts/make.ps1 publish-full-pipeline
powershell -ExecutionPolicy Bypass -File scripts/make.ps1 e2e-full-pipeline
powershell -ExecutionPolicy Bypass -File scripts/make.ps1 audit-log
```

### MCP Cursor (Onda 4)

```powershell
cd mcp/inova-runtime-mcp && npm install
```

Recarregue o Cursor — server `inova-runtime-mcp-local` em `.cursor/mcp.json`.

## Onda 5 — Golden run e staging

```powershell
powershell -ExecutionPolicy Bypass -File scripts/wave5_golden_run.ps1
docker compose --profile staging up -d webhook-ingress
```

Documentação: `docs/WAVE5-GOVERNANCE-AND-STAGING.md`

## Onda 6 — Staging integrated, observabilidade e VPS

```powershell
copy .env.staging.example .env.staging
docker compose --env-file .env.staging --profile staging up -d --build
powershell -ExecutionPolicy Bypass -File scripts/deploy-vps.ps1 -Domain staging.seudominio.com
```

Documentação: `docs/WAVE6-STAGING-OBSERVABILITY-VPS.md`

## Onda 7 — Hardening e merge gate

```powershell
powershell -ExecutionPolicy Bypass -File scripts/make.ps1 test
powershell -ExecutionPolicy Bypass -File scripts/import_grafana_dashboard.ps1
powershell -ExecutionPolicy Bypass -File scripts/apply_branch_protection.ps1 -MakePublicIfRequired
```

- CI: jobs `gitleaks` e `trivy` no workflow `security`
- VPS: Vault + TLS Postgres/NATS + PITR + UFW 22/80/443
- Grafana: profile `observability`, dashboard `inova-audit-overview`
- Branch protection na `main` (repositório público no GitHub Free)

Documentação: `docs/WAVE7-HARDENING.md`

## Observação de segurança

Portas de infraestrutura local bindam em `127.0.0.1`. Troque credenciais default antes de expor em VPS/produção.
