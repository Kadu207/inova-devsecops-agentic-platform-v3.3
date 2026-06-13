from __future__ import annotations

import json
from functools import lru_cache
from pathlib import Path

from jsonschema import Draft202012Validator, ValidationError

from runtime.events import EventEnvelope

CONTRACTS_DIR = Path(__file__).resolve().parent.parent / "contracts" / "events"
META_KEYS = frozenset(
    {"tenant_id", "project", "correlation_id", "branch", "commit", "payload"}
)


@lru_cache(maxsize=128)
def _load_schema(schema_name: str) -> dict:
    path = CONTRACTS_DIR / schema_name
    if not path.exists():
        raise FileNotFoundError(f"Schema not found: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def schema_name_for_subject(subject: str) -> str:
    return f"{subject}.schema.json"


def validate_envelope(event: EventEnvelope, subject: str | None = None) -> None:
    envelope_schema = _load_schema("event-envelope.schema.json")
    Draft202012Validator(envelope_schema).validate(event.model_dump())

    event_type = subject or event.type
    schema_file = schema_name_for_subject(event_type)
    schema_path = CONTRACTS_DIR / schema_file
    if not schema_path.exists():
        return

    payload_schema = _load_schema(schema_file)
    business_payload = {
        "tenant_id": event.tenant_id,
        "project": event.project,
        "correlation_id": event.correlation_id,
        **event.payload,
    }
    try:
        Draft202012Validator(payload_schema).validate(business_payload)
    except ValidationError as exc:
        raise ValueError(
            f"Contract validation failed for {event_type}: {exc.message}"
        ) from exc
