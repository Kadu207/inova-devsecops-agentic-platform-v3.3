#!/usr/bin/env bash
set -euo pipefail

# Inicializa Vault (1 share), unseal, KV v2 e token de workers.
# Chaves ficam em /run/inova (tmpfs). Nao gravar no checkout da aplicacao.
VAULT_ADDR="${VAULT_ADDR:-https://127.0.0.1:8200}"
RUN_DIR="${INOVA_RUN_DIR:-/run/inova}"
POLICY_FILE="${1:-deploy/vault/policies/workers.hcl}"
export VAULT_ADDR

mkdir -p "$RUN_DIR"
chmod 700 "$RUN_DIR"

if command -v vault >/dev/null 2>&1; then
  vault_cmd() { command vault "$@"; }
else
  vault_cmd() {
    local token_args=()
    if [[ -n "${VAULT_TOKEN:-}" ]]; then
      token_args=(-e VAULT_TOKEN)
    fi
    docker compose exec -T "${token_args[@]}" \
      -e VAULT_ADDR=https://127.0.0.1:8200 \
      -e VAULT_CACERT=/vault/tls/ca.crt \
      vault vault "$@"
  }
fi

echo "==> Aguardando Vault em ${VAULT_ADDR}"
for _ in $(seq 1 30); do
  if vault_cmd status >/dev/null 2>&1 || vault_cmd status 2>&1 | grep -Eq "Initialized|sealed|Sealed"; then
    break
  fi
  sleep 2
done

INIT_PATH="${RUN_DIR}/vault-init.json"
status_output=$(vault_cmd status 2>&1 || true)
if ! grep -q "Initialized.*true" <<<"$status_output"; then
  echo "==> vault operator init"
  vault_cmd operator init -key-shares=1 -key-threshold=1 -format=json > "$INIT_PATH"
  chmod 600 "$INIT_PATH"
fi

if [[ ! -f "$INIT_PATH" ]]; then
  echo "Arquivo ${INIT_PATH} ausente. Reinjete o init JSON no tmpfs." >&2
  exit 1
fi

UNSEAL=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["unseal_keys_b64"][0])' "$INIT_PATH")
ROOT=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["root_token"])' "$INIT_PATH")

vault_cmd operator unseal "$UNSEAL" >/dev/null || true
export VAULT_TOKEN="$ROOT"
printf '%s\n' "$ROOT" > "${RUN_DIR}/vault_root_token"
chmod 600 "${RUN_DIR}/vault_root_token"

vault_cmd secrets enable -path=secret kv-v2 >/dev/null 2>&1 || true
vault_cmd policy write inova-workers - < "$POLICY_FILE"
WORKER_TOKEN=$(vault_cmd token create -policy=inova-workers -ttl=768h -format=json | python3 -c 'import json,sys; print(json.load(sys.stdin)["auth"]["client_token"])')
printf '%s\n' "$WORKER_TOKEN" > "${RUN_DIR}/vault_token"
chmod 600 "${RUN_DIR}/vault_token"
echo "Vault bootstrap ok. Worker token em ${RUN_DIR}/vault_token"
