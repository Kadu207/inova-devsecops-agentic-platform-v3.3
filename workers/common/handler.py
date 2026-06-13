from __future__ import annotations

from typing import Any, Dict

from runtime.events import EventEnvelope
from runtime.logging import configure_logging
from workers.common.adapters import run_adapter

log = configure_logging("workers.common.handler")


def build_base_payload(
    worker_name: str, description: str, durable: str, event: EventEnvelope
) -> Dict[str, Any]:
    return {
        "worker": worker_name,
        "description": description,
        "status": "completed",
        "input": event.payload,
        "recommendations": [],
        "evidence": {"runtime": "nats-jetstream", "durable": durable, "mode": "stub"},
    }


async def handle_task(
    worker_name: str,
    description: str,
    durable: str,
    completed_subject: str,
    event: EventEnvelope,
) -> EventEnvelope:
    log.info(
        "processing",
        extra={
            "worker": worker_name,
            "event_type": event.type,
            "correlation_id": event.correlation_id,
        },
    )
    payload = build_base_payload(worker_name, description, durable, event)
    adapter_result = await run_adapter(worker_name, event)
    payload.update(adapter_result)
    if adapter_result.get("mode") == "integrated":
        payload["evidence"]["mode"] = "integrated"
    return event.completed(completed_subject, payload)
