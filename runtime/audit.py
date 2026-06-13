from __future__ import annotations

import json
import logging
from typing import Any, Dict

import psycopg

from runtime.settings import settings

log = logging.getLogger("runtime.audit")


def write_audit(
    worker: str,
    event_type: str,
    tenant_id: str,
    project: str,
    correlation_id: str,
    status: str,
    payload: Dict[str, Any],
    error: str | None = None,
) -> None:
    try:
        with psycopg.connect(settings.database_url) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """insert into public.worker_audit_log
                    (tenant_id, project, worker, event_type, correlation_id, status, payload, error)
                    values (%s,%s,%s,%s,%s,%s,%s::jsonb,%s)""",
                    (
                        tenant_id,
                        project,
                        worker,
                        event_type,
                        correlation_id,
                        status,
                        json.dumps(payload),
                        error,
                    ),
                )
    except Exception as exc:
        log.warning(
            "audit_write_failed",
            extra={
                "worker": worker,
                "event_type": event_type,
                "correlation_id": correlation_id,
                "status": status,
                "error": str(exc),
            },
        )


def write_dlq(
    tenant_id: str,
    project: str,
    event_type: str,
    correlation_id: str,
    payload: Dict[str, Any],
    error: str,
    worker: str | None = None,
) -> None:
    try:
        with psycopg.connect(settings.database_url) as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """insert into public.dead_letter_events
                    (tenant_id, project, event_type, correlation_id, payload, error)
                    values (%s,%s,%s,%s,%s::jsonb,%s)""",
                    (
                        tenant_id,
                        project,
                        event_type,
                        correlation_id,
                        json.dumps(
                            {**payload, "worker": worker} if worker else payload
                        ),
                        error,
                    ),
                )
    except Exception as exc:
        log.error(
            "dlq_write_failed",
            extra={
                "event_type": event_type,
                "correlation_id": correlation_id,
                "error": str(exc),
            },
        )
