"""Exporta entradas do worker_audit_log para Datadog (logs + events)."""

from __future__ import annotations

import json
import logging
from typing import Any

import httpx

from runtime.settings import settings

log = logging.getLogger("runtime.observability.datadog")

DATADOG_LOGS_URL = "https://http-intake.logs.{site}/api/v2/logs"
DATADOG_EVENTS_URL = "https://api.{site}/api/v1/events"


def _site_host() -> str:
    site = settings.datadog_site.strip() or "datadoghq.com"
    return site.replace("https://", "").replace("http://", "").strip("/")


def is_enabled() -> bool:
    return settings.observability_datadog_enabled and bool(
        settings.datadog_api_key.strip()
    )


def export_audit_entry(
    worker: str,
    event_type: str,
    tenant_id: str,
    project: str,
    correlation_id: str,
    status: str,
    payload: dict[str, Any],
    error: str | None = None,
) -> None:
    if not is_enabled():
        return

    tags = [
        f"tenant:{tenant_id}",
        f"project:{project}",
        f"worker:{worker}",
        f"status:{status}",
        f"correlation_id:{correlation_id}",
        f"env:{settings.app_env}",
    ]
    body = {
        "worker": worker,
        "event_type": event_type,
        "correlation_id": correlation_id,
        "status": status,
        "payload": payload,
        "error": error,
    }

    try:
        site = _site_host()
        headers = {
            "DD-API-KEY": settings.datadog_api_key,
            "Content-Type": "application/json",
        }
        log_entry = {
            "ddsource": "inova-runtime",
            "service": settings.project_name,
            "status": status,
            "message": f"{worker} {event_type} {status} correlation_id={correlation_id}",
            "tags": tags,
            "attributes": body,
        }
        with httpx.Client(timeout=10.0) as client:
            client.post(
                DATADOG_LOGS_URL.format(site=site),
                headers=headers,
                json=[log_entry],
            )
            if status in {"completed", "failed"}:
                client.post(
                    DATADOG_EVENTS_URL.format(site=site),
                    headers=headers,
                    json={
                        "title": f"inova.{worker}.{status}",
                        "text": json.dumps(body)[:4000],
                        "alert_type": "success" if status == "completed" else "error",
                        "tags": tags,
                    },
                )
    except Exception as exc:
        log.warning(
            "datadog_export_failed",
            extra={
                "worker": worker,
                "correlation_id": correlation_id,
                "error": str(exc),
            },
        )
