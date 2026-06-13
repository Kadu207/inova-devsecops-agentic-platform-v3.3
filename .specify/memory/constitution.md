# Constitution - Inova DevSecOps v3.3

- Eventos devem respeitar contratos JSON Schema em `contracts/events/`.
- Workers operam em modo stub ate credenciais externas estarem configuradas.
- Toda mudanca critica exige teste automatizado e registro de audit log.
- Orquestrador publica proximas tarefas via NATS; nunca usar wildcard `task.*` no consumer.
