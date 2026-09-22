# Constitution - Inova DevSecOps v3.3

- Eventos devem respeitar contratos JSON Schema em `contracts/events/`.
- Workers operam em modo stub ate credenciais externas estarem configuradas.
- Toda mudanca critica exige teste automatizado e registro de audit log.
- Orquestrador publica proximas tarefas via NATS; nunca usar wildcard `task.*` no consumer.
- Staging/producao: secrets fora do checkout (Vault ou tmpfs `/run/inova`), TLS em Postgres/NATS, backup PITR e firewall minimo (22/80/443).
- Merge na `main` exige checks `gates`, `e2e-orchestrate-audit`, `ci`, `security`, `gitleaks` e `trivy`.
