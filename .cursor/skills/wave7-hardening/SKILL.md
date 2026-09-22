---
name: wave7-hardening
description: Onda 7 — Trivy, gitleaks, Vault, TLS Postgres/NATS, PITR, Grafana, firewall e branch protection. Use quando o usuário pedir hardening de produção, merge gate ou WAVE7.
---

# Onda 7 — Hardening

## Spec

`docs/WAVE7-HARDENING.md`

## CI

Jobs `gitleaks` e `trivy` em `.github/workflows/security.yml`.

## Grafana

```powershell
powershell -ExecutionPolicy Bypass -File scripts/import_grafana_dashboard.ps1
```

## Branch protection (GitHub Free)

Repositório público + required checks. Aplicar:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/apply_branch_protection.ps1 -MakePublicIfRequired
```

## VPS

`scripts/deploy-vps-hetzner.ps1` injeta secrets em `/run/inova`, gera TLS, sobe Vault e aplica UFW 22/80/443.
