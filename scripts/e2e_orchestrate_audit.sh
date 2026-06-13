#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CORRELATION_ID="${CORRELATION_ID:-e2e-orchestrate-$(date +%s)}"
export CORRELATION_ID

echo "==> Subindo stack Docker..."
docker compose up -d --build

echo "==> Aguardando Postgres e NATS..."
for i in $(seq 1 30); do
  if docker compose exec -T postgres pg_isready -U inova -d inova_platform >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

echo "==> Publicando task.orchestrate.requested (correlation_id=$CORRELATION_ID)..."
TMP_PAYLOAD="$ROOT/examples/events/.e2e_orchestrate_payload.json"
python3 - <<PY > "$TMP_PAYLOAD"
import json
from pathlib import Path
data = json.loads(Path("examples/events/orchestrate_requested.json").read_text())
data["correlation_id"] = "$CORRELATION_ID"
print(json.dumps(data))
PY

docker compose run --rm publisher python scripts/publish_event.py \
  --subject task.orchestrate.requested \
  --payload examples/events/.e2e_orchestrate_payload.json

echo "==> Aguardando processamento dos workers (15s)..."
sleep 15

echo "==> Verificando worker_audit_log..."
docker compose exec -T postgres psql -U inova -d inova_platform -c \
  "SELECT worker, event_type, status, correlation_id, created_at
   FROM public.worker_audit_log
   WHERE correlation_id = '$CORRELATION_ID'
   ORDER BY id ASC;"

COUNT=$(docker compose exec -T postgres psql -U inova -d inova_platform -t -A -c \
  "SELECT COUNT(*) FROM public.worker_audit_log WHERE correlation_id = '$CORRELATION_ID' AND status = 'completed';")

if [ "${COUNT:-0}" -lt 2 ]; then
  echo "E2E FAILED: esperado >=2 registros completed, encontrado ${COUNT:-0}"
  docker compose logs orchestrator audit-worker --tail=80
  exit 1
fi

echo "E2E PASSED: orchestrator + audit pipeline registrados em worker_audit_log."
