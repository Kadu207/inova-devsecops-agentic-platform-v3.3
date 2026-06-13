# Onboarding Linux — Cursor + Inova v3.3

## 1) Pré-requisitos no Linux

```bash
sudo apt update
sudo apt install -y git curl make python3 python3-venv python3-pip docker.io docker-compose-plugin
sudo usermod -aG docker "$USER"
newgrp docker
```

Instale o **Cursor** pelo site oficial e abra a pasta do projeto:
`inova-devsecops-agentic-platform-v3.3`

## 2) Sincronizar o projeto

Opções recomendadas:
- **Git** (preferencial): clone/push do repositório entre Windows e Linux
- **OneDrive/sync**: copie a pasta inteira, mas **não** copie `.venv/` (recrie no Linux)

## 3) Bootstrap no Linux

```bash
cp .env.example .env
bash scripts/cursor-bootstrap.sh
make dev
make validate-contracts
```

## 4) Cursor no Linux

Após abrir o projeto no Cursor:
- Regras: `.cursor/rules/*.mdc` (aplicadas automaticamente)
- Skills: `.cursor/skills/*/SKILL.md`
- Comandos: `.cursor/commands/`
- Guia do agente: `AGENTS.md`

**Não é necessário procedimento extra** além de abrir a pasta do projeto no Cursor Linux — rules/skills vêm no repositório.

### MCP e plugins (atenção)

Plugins MCP (Notion, GitLab, Prisma, etc.) são configurados **por instalação do Cursor**, não no repo. No Linux você precisa:
1. Instalar o Cursor e fazer login na mesma conta
2. Reativar os mesmos plugins em **Settings → MCP**
3. Reautenticar serviços que exigem OAuth (Notion, GitLab, Figma, etc.)

Skills globais em `~/.cursor/skills` ou `~/.agents/skills` **não** são copiadas automaticamente — use Git/dotfiles ou copie manualmente se quiser as mesmas skills fora do projeto.

### Sincronizar configuração pessoal (opcional)

```bash
# Exemplo: dotfiles com settings do Cursor
rsync -av ~/.cursor/ novo-linux:~/.cursor/   # ou via git private repo
```

## 5) Variáveis opcionais (.env)

Para modo integrado (não stub):
- `OPENROUTER_API_KEY`
- `SONAR_HOST_URL` + `SONAR_TOKEN`
- `SNYK_TOKEN`
- `DATADOG_API_KEY`

## 6) Teste ponta a ponta

```bash
bash scripts/e2e_orchestrate_audit.sh
```

Ou manualmente:
```bash
make publish-orchestrate
docker compose exec -T postgres psql -U inova -d inova_platform -c \
  "SELECT worker, event_type, status, correlation_id FROM worker_audit_log ORDER BY id DESC LIMIT 20;"
```

## 7) Diferenças Windows vs Linux

| Item | Windows | Linux |
|------|---------|-------|
| Bootstrap | `scripts/cursor-bootstrap.ps1` | `scripts/cursor-bootstrap.sh` |
| Python venv | `py -3.13 -m venv .venv` | `python3 -m venv .venv` |
| Compose | Docker Desktop | `docker compose` nativo |
| Validar contratos | `.venv\Scripts\python.exe scripts/validate_contracts.py` | `.venv/bin/python scripts/validate_contracts.py` |

**Importante:** sempre use o Python do `.venv` do projeto, não o Python global do sistema.
