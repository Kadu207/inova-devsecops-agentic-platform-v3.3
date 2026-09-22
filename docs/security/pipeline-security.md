# Pipeline Security (v3.3)

## Gates implementados
- CI: ruff + pytest + validate_contracts
- Security workflow: pip-audit + bandit
- Secret scan: gitleaks em PRs e push (`job: gitleaks`)
- Container scan: Trivy na imagem `Dockerfile.worker` (`job: trivy`, gate CRITICAL)
- Compliance workflow: contratos + docs legais/seguranca + spec Onda 7
- Release workflow: make release-check

## Hardening VPS (Onda 7)
- TLS em Postgres (`sslmode=require`) e NATS (`tls://`)
- Secrets em Vault KV + tmpfs `/run/inova` (sem `.env` no checkout)
- Backup PITR: WAL archive + sidecar `pg_basebackup`
- Firewall UFW: 22, 80, 443; webhook em `127.0.0.1:8787`

Documentacao: `docs/WAVE7-HARDENING.md`
