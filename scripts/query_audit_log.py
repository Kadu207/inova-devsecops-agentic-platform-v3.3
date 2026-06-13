#!/usr/bin/env python3
"""Consulta worker_audit_log no Postgres (host ou via docker compose)."""

from __future__ import annotations

import argparse
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from runtime.settings import settings  # noqa: E402


def _host_db_url() -> str:
    db_url = os.environ.get("DATABASE_URL", settings.database_url)
    if "postgres:5432" in db_url and "localhost" not in db_url and "127.0.0.1" not in db_url:
        db_url = db_url.replace("@postgres:5432", "@127.0.0.1:55432")
    return db_url.replace("@localhost:5432", "@127.0.0.1:55432")


def _build_sql(args: argparse.Namespace) -> str:
    clauses: list[str] = []
    if args.correlation_id:
        safe = args.correlation_id.replace("'", "''")
        clauses.append(f"correlation_id = '{safe}'")
    if args.worker:
        safe = args.worker.replace("'", "''")
        clauses.append(f"worker = '{safe}'")
    where = f"WHERE {' AND '.join(clauses)}" if clauses else ""
    return f"""
        SELECT id, worker, event_type, status, correlation_id, created_at
        FROM public.worker_audit_log
        {where}
        ORDER BY id DESC
        LIMIT {int(args.last)};
    """


def _print_rows(rows: list[tuple]) -> None:
    if not rows:
        print("(sem registros)")
        return
    print(f"{'id':>6}  {'worker':<18} {'status':<10} {'correlation_id':<32} {'event_type'}")
    print("-" * 100)
    for row in rows:
        rid, worker, event_type, status, correlation_id, created_at = row
        print(
            f"{rid:>6}  {worker:<18} {status:<10} {correlation_id:<32} {event_type}  ({created_at})"
        )


def _query_via_psycopg(args: argparse.Namespace) -> list[tuple]:
    import psycopg

    conditions: list[str] = []
    params: list[object] = []
    if args.correlation_id:
        conditions.append("correlation_id = %s")
        params.append(args.correlation_id)
    if args.worker:
        conditions.append("worker = %s")
        params.append(args.worker)
    where = f"WHERE {' AND '.join(conditions)}" if conditions else ""
    sql = f"""
        SELECT id, worker, event_type, status, correlation_id, created_at
        FROM public.worker_audit_log
        {where}
        ORDER BY id DESC
        LIMIT %s
    """
    params.append(args.last)
    with psycopg.connect(_host_db_url()) as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()


def _query_via_docker(args: argparse.Namespace) -> list[tuple]:
    sql = _build_sql(args).strip()
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    proc = subprocess.run(
        [
            "docker",
            "compose",
            "exec",
            "-T",
            "postgres",
            "psql",
            "-U",
            "inova",
            "-d",
            "inova_platform",
            "-t",
            "-A",
            "-F",
            "|",
            "-c",
            sql,
        ],
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or proc.stdout.strip() or "docker psql failed")

    rows: list[tuple] = []
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split("|")
        if len(parts) != 6:
            continue
        rid, worker, event_type, status, correlation_id, created_at = parts
        rows.append((int(rid), worker, event_type, status, correlation_id, created_at))
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description="Consultar worker_audit_log")
    parser.add_argument("--correlation-id", help="Filtrar por correlation_id")
    parser.add_argument("--worker", help="Filtrar por worker")
    parser.add_argument("--last", type=int, default=20, help="Ultimas N linhas (default 20)")
    parser.add_argument("--docker", action="store_true", help="Forcar consulta via docker compose")
    args = parser.parse_args()

    rows: list[tuple] = []
    if args.docker:
        rows = _query_via_docker(args)
    else:
        try:
            rows = _query_via_psycopg(args)
        except Exception:
            rows = _query_via_docker(args)

    _print_rows(rows)


if __name__ == "__main__":
    main()
