---
name: golden-run-governance
description: Executar Wave 5 golden run — E2E local, evidência CI GitHub, branch protection e webhook staging. Use quando o usuário pedir golden run, Onda 5, governança GitHub ou webhook NATS staging.
---

# Golden Run — Onda 5

## Pré-requisitos

- Docker stack up: `docker compose up -d --build`
- `gh` autenticado (`gh auth status`)
- Repo: `Kadu207/inova-devsecops-agentic-platform-v3.3`

## Fluxo

1. **Golden run completo**
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts/wave5_golden_run.ps1
   ```

2. **Com branch protection** (requer GitHub Pro em repo privado)
   ```powershell
   powershell -ExecutionPolicy Bypass -File scripts/wave5_golden_run.ps1 -ApplyBranchProtection
   ```

3. **MCP governança** (workspace Evolução de Skills e MCP)
   - Tool `apply_branch_protection` em `github-governance-mcp-local`
   - Contexts: `gates`, `e2e-orchestrate-audit`, `ci`, `security`

4. **Webhook staging**
   ```powershell
   docker compose --profile staging up -d webhook-ingress
   curl http://127.0.0.1:8787/health
   ```

## Documentação

`docs/WAVE5-GOVERNANCE-AND-STAGING.md`

## Limitação conhecida

Branch protection API retorna 403 em repositório **privado** no plano GitHub Free. Documentar SKIPPED no relatório; workflows CI continuam como evidência.
