---
name: release-validation
description: Executa gate de release local (lint, contratos, testes, release_check). Use antes de tag/release ou quando o usuario pedir validacao de release.
---

# Release Validation

## Passos
1. `make release-check`
2. Confirmar workflows CI verdes (ci, security, compliance, workers-runtime)
3. Confirmar presenca de docs legais e schemas

## Falhas comuns
- Contrato invalido: corrigir `examples/events` ou schema em `contracts/events`
- Lint: `python -m ruff check --fix runtime workers scripts tests`
