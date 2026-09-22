# Constitution - Inova DevSecOps v3.3

- Eventos devem respeitar contratos JSON Schema.
- Workers operam em modo stub ate credenciais externas estarem configuradas.
- Toda mudanca critica exige teste e evidencia de audit log.
- Staging/producao usa Vault ou tmpfs `/run/inova`; TLS em Postgres/NATS; merge gate com gitleaks e Trivy.
