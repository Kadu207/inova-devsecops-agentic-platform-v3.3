# Onda 5 — Governança GitHub + webhook staging

Ondas 1–4 entregaram runtime, E2E, MCP local e CI (`orchestrate-devsecops`). A Onda 5 fecha o ciclo **golden run**: evidência local + CI + governança + ingress externo para NATS.

## Análise do seu `docker compose up -d --build`

Saída validada — stack **saudável**:

| Item | Status |
|------|--------|
| Build 12 workers + orchestrator | ✅ ~20s, cache eficiente |
| Postgres | ✅ Healthy |
| NATS (alpine + healthz) | ✅ Healthy |
| Redis, Qdrant | ✅ Running |
| 29 containers | ✅ Up |

**Próximo passo operacional imediato:** golden run ou teste MCP (`publish_orchestrate pipeline full-devsecops`).

---

## 1) Golden run (local + CI)

```powershell
# E2E local + evidência CI + relatório em reports/
powershell -ExecutionPolicy Bypass -File scripts/wave5_golden_run.ps1

# Com tentativa de branch protection (requer GitHub Pro em repo privado)
powershell -ExecutionPolicy Bypass -File scripts/wave5_golden_run.ps1 -ApplyBranchProtection
```

```bash
make wave5-golden-run
```

Gera `reports/wave5-golden-run-<timestamp>.md` com:
- Docker OK
- E2E full pipeline PASSED
- URLs dos workflows GitHub na `main`
- Status de branch protection (se solicitado)

---

## 2) Branch protection + required checks

Checks disponíveis no repositório (último push `main`):

- `gates`, `e2e-orchestrate-audit`, `e2e-full-devsecops` (workflow `orchestrate-devsecops`)
- `ci`, `security`, `compliance`, `workers-runtime`

### Script CLI

```powershell
powershell -ExecutionPolicy Bypass -File scripts/apply_branch_protection.ps1
powershell -ExecutionPolicy Bypass -File scripts/apply_branch_protection.ps1 -DryRun
```

### MCP Cursor (`github-governance-mcp-local`)

No workspace **Evolução de Skills e MCP**, após Reload Window:

```json
{
  "repo": "Kadu207/inova-devsecops-agentic-platform-v3.3",
  "branches": ["main"],
  "required_approving_review_count": 1,
  "enforce_admins": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true,
  "strict": true,
  "contexts": ["gates", "e2e-orchestrate-audit", "ci", "security", "gitleaks", "trivy"]
}
```

Tool: `apply_branch_protection`

### Limitação GitHub Free (repo privado)

A API retorna **403** — branch protection em repositório privado exige **GitHub Pro/Team/Enterprise** ou repo público.

**Enquanto isso:** workflows continuam rodando em PR/push; merge manual com revisão de checks na aba Actions.

---

## 3) Webhook ingress (staging / VPS)

Publica eventos HTTP → NATS com HMAC.

### Subir (profile staging)

```powershell
# Defina WEBHOOK_SECRET no .env antes de staging/producao
docker compose --profile staging up -d webhook-ingress
```

Porta local: `127.0.0.1:8787`

### Endpoints

| Método | Path | Descrição |
|--------|------|-----------|
| GET | `/health` | Health check |
| POST | `/webhook/publish` | Publica evento no NATS |

### Payload (exemplo)

```json
{
  "subject": "task.orchestrate.requested",
  "correlation_id": "webhook-staging-001",
  "payload": {
    "pipeline": "full-devsecops"
  }
}
```

Header: `X-Inova-Signature: sha256=<hmac-sha256-do-body>`

Subjects permitidos (allowlist):
- `task.orchestrate.requested`
- `task.audit.requested`
- `task.opencode.requested`

### VPS (resumo)

1. Copiar pacote + `.env` com secrets de produção
2. `docker compose --profile staging up -d --build`
3. Reverse proxy (TLS) na frente da porta 8787
4. Rotacionar `WEBHOOK_SECRET`; nunca commitar

Runbook: `docs/runbooks/vps-deploy.md`

---

## Critérios de aceite Onda 5

- [x] Golden run script com relatório auditável
- [x] Script/MCP path para branch protection documentado
- [x] Webhook ingress com HMAC + validação de contrato
- [x] Branch protection aplicada (repo público no GitHub Free — Onda 7)
- [x] Webhook testado em VPS staging (Onda 6)

---

## Onda 6 / 7

Onda 6: staging integrated, Datadog, VPS. Onda 7: `docs/WAVE7-HARDENING.md` (Trivy, gitleaks, Vault, TLS, PITR, Grafana, merge gate).
