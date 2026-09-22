#!/usr/bin/env bash
set -euo pipefail

# Sidecar PITR: archive WAL ja e feito pelo Postgres; este loop tira basebackup periodico.
INTERVAL_SECONDS="${BACKUP_INTERVAL_SECONDS:-21600}"
DEST="${BACKUP_DIR:-/backups}"
mkdir -p "$DEST"

echo "postgres-backup sidecar started interval=${INTERVAL_SECONDS}s dest=${DEST}"
while true; do
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  target="${DEST}/basebackup-${stamp}"
  echo "starting pg_basebackup ${target}"
  if pg_basebackup -D "$target" -Ft -z -P -W 2>/dev/null || pg_basebackup -D "$target" -Ft -z -P; then
    echo "basebackup ok ${target}"
    find "$DEST" -maxdepth 1 -type d -name 'basebackup-*' -mtime +7 -exec rm -rf {} \; || true
  else
    echo "basebackup failed" >&2
  fi
  sleep "$INTERVAL_SECONDS"
done
