#!/usr/bin/env bash
set -euo pipefail

# Sidecar PITR: archive WAL ja e feito pelo Postgres; este loop tira basebackup periodico.
INTERVAL_SECONDS="${BACKUP_INTERVAL_SECONDS:-21600}"
DEST="${BACKUP_DIR:-/backups}"
mkdir -p "$DEST"

cleanup_wal() {
  local oldest backup_tar first_wal
  oldest=$(find "$DEST" -mindepth 1 -maxdepth 1 -type d -name 'basebackup-*' \
    -printf '%T@ %p\n' | sort -n | head -n1 | cut -d' ' -f2-)
  [[ -n "$oldest" ]] || return 0
  backup_tar="$oldest/base.tar.gz"
  [[ -f "$backup_tar" ]] || return 0
  first_wal=$(tar -xOzf "$backup_tar" backup_label 2>/dev/null \
    | sed -nE 's/^START WAL LOCATION: .+ \(file ([0-9A-F]+)\)$/\1/p' \
    | head -n1)
  if [[ -n "$first_wal" ]]; then
    pg_archivecleanup /wal_archive "$first_wal"
    echo "WAL archive retained from ${first_wal}"
  fi
}

echo "postgres-backup sidecar started interval=${INTERVAL_SECONDS}s dest=${DEST}"
while true; do
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  target="${DEST}/basebackup-${stamp}"
  echo "starting pg_basebackup ${target}"
  if pg_basebackup -D "$target" -Ft -z -P; then
    echo "basebackup ok ${target}"
    find "$DEST" -maxdepth 1 -type d -name 'basebackup-*' -mtime +7 -exec rm -rf {} \; || true
    cleanup_wal
  else
    echo "basebackup failed" >&2
  fi
  sleep "$INTERVAL_SECONDS"
done
