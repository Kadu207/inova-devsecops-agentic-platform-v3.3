---
name: opencode-audit
description: Executa worker OpenCode/OpenRouter para auditoria assistida. Use quando o usuario pedir opencode audit, openrouter ou analise assistida de codigo.
---

# OpenCode Audit

## Passos
1. Configurar `.env` com `OPENROUTER_API_KEY` (opcional para modo integrado)
2. Validar contrato: `python scripts/validate_contracts.py`
3. Publicar:
   - `make publish-opencode`
4. Verificar worker: `docker compose logs opencode-worker --tail=100`

## Modos
- Sem chave: retorno stub documentado
- Com chave: chamada real OpenRouter via `workers/common/adapters.py`
