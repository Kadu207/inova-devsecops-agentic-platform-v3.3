#!/usr/bin/env bash
set -euo pipefail

# Gera CA interna + certs Postgres/NATS. Nao versionar a pasta generated/.
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$ROOT/deploy/tls/generated}"
mkdir -p "$OUT"

openssl version >/dev/null

openssl genrsa -out "$OUT/ca.key" 4096
openssl req -x509 -new -nodes -key "$OUT/ca.key" -sha256 -days 825 \
  -subj "/CN=Inova Internal CA" -out "$OUT/ca.crt"

make_cert() {
  local name="$1"
  openssl genrsa -out "$OUT/${name}.key" 2048
  openssl req -new -key "$OUT/${name}.key" -subj "/CN=${name}" -out "$OUT/${name}.csr"
  cat > "$OUT/${name}.ext" <<EOF
subjectAltName = DNS:${name},DNS:localhost,IP:127.0.0.1
extendedKeyUsage = serverAuth,clientAuth
EOF
  openssl x509 -req -in "$OUT/${name}.csr" -CA "$OUT/ca.crt" -CAkey "$OUT/ca.key" \
    -CAcreateserial -out "$OUT/${name}.crt" -days 825 -sha256 -extfile "$OUT/${name}.ext"
  rm -f "$OUT/${name}.csr" "$OUT/${name}.ext"
  chmod 600 "$OUT/${name}.key"
}

make_cert postgres
make_cert nats
chmod 644 "$OUT/ca.crt" "$OUT/postgres.crt" "$OUT/nats.crt"
chmod 600 "$OUT/ca.key"
echo "TLS material written to $OUT"
