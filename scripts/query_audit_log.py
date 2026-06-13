#!/usr/bin/env python3
"""Consulta worker_audit_log no Postgres (host ou via docker compose)."""

from __future__ import annotations

import argparse
import os
import re
import subprocess  # nosec B404
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from runtime.settings import settings  # noqa: E402


def _host_db_url() -> str:
    db_url = os.environ.get("DATABASE_URL", settings.database_url)
    if (
        "postgres:5432" in db_url
        and "localhost" not in db_url
        and "127.0.0.1" not in db_url
    ):
        db_url = db_url.replace("@postgres:5432", "@127.0.0.1:55432")
    return db_url.replace("@localhost:5432", "@127.0.0.1:55432")


def _validate_filter(value: str, field: str) -> str:
    if not re.fullmatch(r"[\w.-]+", value):
        raise ValueError(f"{field} invalido: {value!r}")
    return value


def _print_rows(rows: list[tuple]) -> None:
    if not rows:
        print("(sem registros)")
        return
    print(
        f"{'id':>6}  {'worker':<18} {'status':<10} {'correlation_id':<32} {'event_type'}"
    )
    print("-" * 100)
    for row in rows:
        rid, worker, event_type, status, correlation_id, created_at = row
        print(
            f"{rid:>6}  {worker:<18} {status:<10} {correlation_id:<32} {event_type}  ({created_at})"
        )


def _query_via_psycopg(args: argparse.Namespace) -> list[tuple]:
    import psycopg

    base = """
        SELECT id, worker, event_type, status, correlation_id, created_at
        FROM public.worker_audit_log
    """
    params: list[object] = []
    if args.correlation_id and args.worker:
        _validate_filter(args.correlation_id, "correlation_id")
        _validate_filter(args.worker, "worker")
        sql = (
            base
            + " WHERE correlation_id = %s AND worker = %s"
            + " ORDER BY id DESC LIMIT %s"
        )
        params = [args.correlation_id, args.worker, args.last]
    elif args.correlation_id:
        _validate_filter(args.correlation_id, "correlation_id")
        sql = base + " WHERE correlation_id = %s ORDER BY id DESC LIMIT %s"
        params = [args.correlation_id, args.last]
    elif args.worker:
        _validate_filter(args.worker, "worker")
        sql = base + " WHERE worker = %s ORDER BY id DESC LIMIT %s"
        params = [args.worker, args.last]
    else:
        sql = base + " ORDER BY id DESC LIMIT %s"
        params = [args.last]

    with psycopg.connect(_host_db_url()) as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()


def _query_via_docker(args: argparse.Namespace) -> list[tuple]:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    cmd = [
        "docker",
        "compose",
        "exec",
        "-T",
        "orchestrator",
        "python",
        "scripts/query_audit_log.py",
        "--last",
        str(int(args.last)),
    ]
    if args.correlation_id:
        _validate_filter(args.correlation_id, "correlation_id")
        cmd.extend(["--correlation-id", args.correlation_id])
    if args.worker:
        _validate_filter(args.worker, "worker")
        cmd.extend(["--worker", args.worker])

    proc = subprocess.run(  # nosec B603
        cmd,
        cwd=root,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(
            proc.stderr.strip() or proc.stdout.strip() or "docker query failed"
        )

    rows: list[tuple] = []
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line or line.startswith("id") or line.startswith("-"):
            continue
        parts = line.split()
        if len(parts) < 5:
            continue
        rid = int(parts[0])
        worker = parts[1]
        status = parts[2]
        correlation_id = parts[3]
        event_type = parts[4]
        created_at = " ".join(parts[5:]).strip("()") if len(parts) > 5 else ""
        rows.append((rid, worker, event_type, status, correlation_id, created_at))
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description="Consultar worker_audit_log")
    parser.add_argument("--correlation-id", help="Filtrar por correlation_id")
    parser.add_argument("--worker", help="Filtrar por worker")
    parser.add_argument(
        "--last", type=int, default=20, help="Ultimas N linhas (default 20)"
    )
    parser.add_argument(
        "--docker", action="store_true", help="Forcar consulta via docker compose"
    )
    args = parser.parse_args()

    rows: list[tuple] = []
    if args.docker:
        rows = _query_via_docker(args)
    else:
        try:
            rows = _query_via_psycopg(args)
        except Exception:
            if os.path.exists("/.dockerenv"):
                raise
            rows = _query_via_docker(args)

    _print_rows(rows)


if __name__ == "__main__":
    main()
