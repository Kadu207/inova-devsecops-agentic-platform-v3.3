#!/usr/bin/env bash
set -euo pipefail
mkdir -p .cursor/memory .cursor/tmp logs
[ -f .env ] || cp .env.example .env
python3 -m venv .venv || true
. .venv/bin/activate
pip install -U pip
pip install -r requirements-dev.txt
printf "\nInova v3.3 preparada para Cursor. Próximo passo: make dev\n"
