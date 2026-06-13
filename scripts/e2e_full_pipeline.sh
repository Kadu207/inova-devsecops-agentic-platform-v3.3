#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CORRELATION_ID="${CORRELATION_ID:-e2e-full-$(date +%s)}"
MIN_COMPLETED="${MIN_COMPLETED_WORKERS:-11}"
WAIT_SECONDS="${WAIT_SECONDS:-30}"

echo "==> Subindo stack Docker..."
docker compose up -d --build

echo "==> Aguardando Postgres e NATS..."
for i in $(seq 1 60); do
  if docker compose exec -T postgres pg_isready -U inova -d inova_platform >/dev/null 2>&1; then
    health=$(docker compose ps nats --format '{{.Health}}' 2>/dev/null || true)
    if echo "$health" | grep -q healthy; then break; fi
  fi
  sleep 2
done

echo "==> Publicando pipeline full-devsecops (correlation_id=$CORRELATION_ID)..."
TMP_PAYLOAD="$ROOT/examples/events/.e2e_full_pipeline_payload.json"
python3 - <<PY > "$TMP_PAYLOAD"
import json
from pathlib import Path
data = json.loads(Path("examples/events/orchestrate_full_devsecops.json").read_text())
data["correlation_id"] = "$CORRELATION_ID"
print(json.dumps(data))
PY

docker compose run --rm publisher python scripts/publish_event.py \
  --subject task.orchestrate.requested \
  --payload examples/events/.e2e_full_pipeline_payload.json

echo "==> Aguardando processamento (${WAIT_SECONDS}s)..."
sleep "$WAIT_SECONDS"

echo "==> worker_audit_log:"
docker compose exec -T postgres psql -U inova -d inova_platform -c \
  "SELECT worker, event_type, status, correlation_id, created_at
   FROM public.worker_audit_log
   WHERE correlation_id = '$CORRELATION_ID'
   ORDER BY id ASC;"

COUNT=$(docker compose exec -T postgres psql -U inova -d inova_platform -t -A -c \
  "SELECT COUNT(DISTINCT worker) FROM public.worker_audit_log
   WHERE correlation_id = '$CORRELATION_ID' AND status = 'completed';")

if [ "${COUNT:-0}" -lt "$MIN_COMPLETED" ]; then
  echo "E2E FULL PIPELINE FAILED: esperado >=$MIN_COMPLETED workers completed, encontrado ${COUNT:-0}"
  exit 1
fi

echo "E2E FULL PIPELINE PASSED: ${COUNT} workers registrados."
