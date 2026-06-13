# Pipeline Security (v3.3)

## Gates implementados
- CI: ruff + pytest + validate_contracts
- Security workflow: pip-audit + bandit
- Compliance workflow: contratos + docs legais/seguranca
- Release workflow: make release-check

## Pendencias de hardening avancado
- Container scan (Trivy) em pipeline dedicado
- Secret scan (gitleaks) em PRs
- TLS/auth no NATS para producao
