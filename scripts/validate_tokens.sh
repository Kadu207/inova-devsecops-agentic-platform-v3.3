#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="${1:-$ROOT/.env.staging}"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Arquivo nao encontrado: $ENV_FILE"
  exit 1
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

MODE="${WORKER_ADAPTER_MODE:-auto}"
SITE="${DATADOG_SITE:-datadoghq.com}"
FAIL=0

datadog_api_base() {
  case "$SITE" in
    datadoghq.com) echo "https://api.datadoghq.com" ;;
    datadoghq.eu) echo "https://api.datadoghq.eu" ;;
    us3.datadoghq.com) echo "https://api.us3.datadoghq.com" ;;
    us5.datadoghq.com) echo "https://api.us5.datadoghq.com" ;;
    ap1.datadoghq.com) echo "https://api.ap1.datadoghq.com" ;;
    api.*) echo "https://${SITE#api.}" ;;
    *.datadoghq.*) echo "https://api.$SITE" ;;
    *) echo "https://api.$SITE" ;;
  esac
}

echo "==> validate_tokens.sh"
echo "    Env file: $ENV_FILE"
echo "    WORKER_ADAPTER_MODE=$MODE"
echo ""

if [[ "$MODE" == "integrated" || "${OBSERVABILITY_DATADOG_ENABLED:-false}" == "true" ]]; then
  BASE="$(datadog_api_base)"
  if curl -sf -H "DD-API-KEY: ${DATADOG_API_KEY:-}" -H "Content-Type: application/json" \
    "$BASE/api/v1/validate" | grep -q '"valid":true'; then
    echo "[OK] Datadog ($SITE) - valid em $BASE"
  else
    echo "[FAIL] Datadog ($SITE) - verifique DATADOG_API_KEY e DATADOG_SITE (ex.: us5.datadoghq.com)"
    FAIL=$((FAIL + 1))
  fi
else
  echo "[SKIP] Datadog"
fi

if [[ "$MODE" == "integrated" ]]; then
  if curl -sf -u "${SONAR_TOKEN:-}:" "${SONAR_HOST_URL%/}/api/authentication/validate" | grep -q '"valid":true'; then
    echo "[OK] Sonar ($SONAR_HOST_URL)"
  else
    echo "[FAIL] Sonar - token ou URL invalidos"
    FAIL=$((FAIL + 1))
  fi

  if curl -sf -H "Authorization: token ${SNYK_TOKEN:-}" \
    "https://api.snyk.io/v1/user/me" >/dev/null; then
    echo "[OK] Snyk"
  else
    echo "[FAIL] Snyk - token invalido"
    FAIL=$((FAIL + 1))
  fi
else
  echo "[SKIP] Sonar/Snyk (mode=$MODE)"
fi

echo ""
if [[ "$FAIL" -gt 0 ]]; then
  echo "VALIDACAO FALHOU: $FAIL servico(s)"
  exit 1
fi
echo "VALIDACAO OK"
exit 0
