# inova-runtime-mcp

MCP server para operar o runtime event-driven da plataforma Inova v3.3 a partir do Cursor.

## Tools

| Tool | Descrição |
|------|-----------|
| `publish_orchestrate` | Publica `task.orchestrate.requested` (default ou full-devsecops) |
| `publish_event` | Publica evento arbitrário com payload JSON |
| `query_audit_log` | Consulta `worker_audit_log` via Postgres |
| `runtime_health` | Status Docker + NATS health |

## Requisitos

- Node.js 18+
- Docker Desktop com stack `docker compose up -d`
- `npm install` nesta pasta

## Cursor

Adicione em `.cursor/mcp.json` (já incluído no repo):

```json
"inova-runtime-mcp-local": {
  "command": "node",
  "args": ["mcp/inova-runtime-mcp/src/server.mjs"],
  "env": { "INOVA_PROJECT_ROOT": "." }
}
```

## Teste manual

```bash
cd mcp/inova-runtime-mcp && npm install && npm start
```
