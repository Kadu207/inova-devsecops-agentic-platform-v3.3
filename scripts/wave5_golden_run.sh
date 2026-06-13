#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-Kadu207/inova-devsecops-agentic-platform-v3.3}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

STAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="reports/wave5-golden-run-${STAMP}.md"
mkdir -p reports

{
  echo "# Wave 5 Golden Run — ${STAMP}"
  echo ""
  echo "## 1) Runtime local"
  echo ""
} >"${REPORT}"

echo "==> Wave 5 Golden Run"
docker compose ps

echo "==> E2E full pipeline"
bash scripts/e2e_full_pipeline.sh

{
  echo "- e2e-full-pipeline: PASSED"
  echo ""
  echo "## 2) CI GitHub"
  echo ""
  gh run list --repo "${REPO}" --branch main --limit 6
} >>"${REPORT}"

echo "Report: ${REPORT}"
echo "WAVE 5 GOLDEN RUN COMPLETE"
