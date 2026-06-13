# Onda 4 — MCP + GitHub Actions

## MCP server vs GitHub Actions — qual a diferença?

| | **MCP server (local)** | **GitHub Actions (CI)** |
|---|------------------------|-------------------------|
| **Onde roda** | Sua máquina (Cursor) | Runners do GitHub (cloud) |
| **Quem dispara** | Você ou o agente Cursor no chat | Push, PR, `workflow_dispatch` |
| **Para quê** | Operar e debugar o runtime ao vivo: publicar evento, ver audit log, checar saúde | Automatizar gates e E2E em todo PR/merge — evidência reproduzível no repositório |
| **Depende de Docker local?** | Sim (stack `docker compose`) | Não — o workflow sobe Postgres/NATS/workers no runner |
| **Ideal quando** | Desenvolvimento, demos, troubleshooting com agente | Equipe, compliance, “só merge se pipeline passou” |

**Ordem recomendada:** MCP primeiro para validar localmente; GitHub Actions em seguida para fixar o mesmo fluxo no CI.

Não são excludentes — **use os dois**: MCP no dia a dia, Actions no repositório.

---

## 1) MCP server — `inova-runtime-mcp-local`

### Instalar

```powershell
cd mcp/inova-runtime-mcp
npm install
```

### Cursor

O arquivo `.cursor/mcp.json` já registra o server. Recarregue o Cursor (Reload Window) após `npm install`.

### Tools disponíveis

- `publish_orchestrate` — pipeline `default` ou `full-devsecops`
- `publish_event` — subject + payload JSON
- `query_audit_log` — consulta Postgres (host `127.0.0.1:55432`)
- `runtime_health` — `docker compose ps` + NATS healthz

### Pré-requisito

```powershell
docker compose up -d --build
```

---

## 2) GitHub Actions — `orchestrate-devsecops.yml`

### Triggers

| Evento | Jobs |
|--------|------|
| **PR → main** | `gates` + `e2e-orchestrate-audit` |
| **Push main/develop** | `gates` + `e2e-orchestrate-audit` |
| **Push main** | + `e2e-full-devsecops` |
| **workflow_dispatch** | Escolha `orchestrate-audit` ou `full-devsecops` |

### Disparar manualmente

GitHub → Actions → **orchestrate-devsecops** → Run workflow.

---

## Windows — substituto do `make`

O PowerShell não inclui `make`. Use:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/make.ps1 publish-full-pipeline
powershell -ExecutionPolicy Bypass -File scripts/make.ps1 e2e-full-pipeline
powershell -ExecutionPolicy Bypass -File scripts/make.ps1 audit-log
```

---

## Próximo passo (Onda 5 — entregue)

Ver `docs/WAVE5-GOVERNANCE-AND-STAGING.md`:

- Golden run: `scripts/wave5_golden_run.ps1`
- Branch protection + `github-governance-mcp`
- Webhook ingress NATS (profile `staging`)
