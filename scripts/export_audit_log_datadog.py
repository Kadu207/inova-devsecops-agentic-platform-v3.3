#!/usr/bin/env python3
"""Exporta batch do worker_audit_log para Datadog Logs."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


def _load_staging_env() -> None:
    staging = ROOT / ".env.staging"
    if not staging.is_file():
        return
    for raw in staging.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ[key.strip()] = value.strip()


def _in_docker() -> bool:
    return Path("/.dockerenv").exists()


def _resolve_db_url(url: str, host_port: int = 15432) -> str:
    """Resolve o Postgres Docker para a porta alternativa do host local."""
    if _in_docker():
        return url
    if "@postgres:5432" in url:
        return url.replace("@postgres:5432", f"@127.0.0.1:{host_port}")
    return url


def _fetch_rows(last: int, correlation_id: str | None) -> list[tuple]:
    import psycopg

    from runtime.settings import settings

    params: list[object] = []
    sql = """
        SELECT id, worker, event_type, status, correlation_id, created_at
        FROM public.worker_audit_log
    """
    if correlation_id:
        sql += " WHERE correlation_id = %s"
        params.append(correlation_id)
    sql += " ORDER BY id DESC LIMIT %s"
    params.append(last)
    db_url = _resolve_db_url(
        os.environ.get("DATABASE_URL", settings.database_url),
        settings.postgres_host_port,
    )
    try:
        with psycopg.connect(db_url) as conn:
            with conn.cursor() as cur:
                cur.execute(sql, params)
                return cur.fetchall()
    except Exception as exc:
        if os.environ.get("DATABASE_URL") or not (ROOT / ".env.staging").is_file():
            raise
        print(
            "Aviso: conexao local falhou; use dentro do Docker:\n"
            "  docker compose --env-file .env.staging run --rm publisher "
            "python scripts/export_audit_log_datadog.py ...",
            file=sys.stderr,
        )
        raise exc


def main() -> None:
    _load_staging_env()

    from runtime.observability.datadog import export_audit_entry, is_enabled
    from runtime.settings import settings

    parser = argparse.ArgumentParser(description="Export audit log rows to Datadog")
    parser.add_argument("--last", type=int, default=50)
    parser.add_argument("--correlation-id")
    args = parser.parse_args()

    if not is_enabled():
        print("OBSERVABILITY_DATADOG_ENABLED=true e DATADOG_API_KEY necessarios.")
        raise SystemExit(1)

    rows = _fetch_rows(args.last, args.correlation_id)
    for row in rows:
        rid, worker, event_type, status, correlation_id, created_at = row
        export_audit_entry(
            worker=worker,
            event_type=event_type,
            tenant_id=settings.tenant_id,
            project=settings.project_name,
            correlation_id=correlation_id,
            status=status,
            payload={"created_at": str(created_at), "audit_id": rid},
        )
    print(f"Exported {len(rows)} audit rows to Datadog.")


if __name__ == "__main__":
    main()
