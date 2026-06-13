#!/usr/bin/env python3
"""Exporta batch do worker_audit_log para Datadog Logs."""

from __future__ import annotations

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from runtime.observability.datadog import export_audit_entry, is_enabled  # noqa: E402
from runtime.settings import settings  # noqa: E402


def _fetch_rows(last: int, correlation_id: str | None) -> list[tuple]:
    import psycopg

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
    db_url = os.environ.get("DATABASE_URL", settings.database_url)
    with psycopg.connect(db_url) as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()


def main() -> None:
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
