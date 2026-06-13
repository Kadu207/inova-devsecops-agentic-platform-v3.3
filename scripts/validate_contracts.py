from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from jsonschema import Draft202012Validator

from runtime.contract_validation import CONTRACTS_DIR, validate_envelope
from runtime.events import EventEnvelope

META_KEYS = frozenset(
    {"tenant_id", "project", "correlation_id", "branch", "commit", "payload"}
)


def validate_schema_files() -> list[str]:
    errors: list[str] = []
    for schema_path in sorted(CONTRACTS_DIR.glob("*.schema.json")):
        try:
            schema = json.loads(schema_path.read_text(encoding="utf-8"))
            Draft202012Validator.check_schema(schema)
        except Exception as exc:
            errors.append(f"{schema_path.name}: invalid schema: {exc}")
    return errors


def validate_examples() -> list[str]:
    errors: list[str] = []
    examples_dir = Path("examples/events")
    subject_map = {
        "audit_requested.json": "task.audit.requested",
        "opencode_requested.json": "task.opencode.requested",
        "orchestrate_requested.json": "task.orchestrate.requested",
        "test_requested.json": "task.test.requested",
        "build_requested.json": "task.build.requested",
        "review_requested.json": "task.review.requested",
        "release_requested.json": "task.release.requested",
        "notification_requested.json": "task.notification.requested",
        "sonar_requested.json": "task.sonar.requested",
        "snyk_requested.json": "task.snyk.requested",
        "datadog_requested.json": "task.datadog.requested",
    }
    for filename, subject in subject_map.items():
        path = examples_dir / filename
        if not path.exists():
            errors.append(f"Missing example: {path}")
            continue
        data = json.loads(path.read_text(encoding="utf-8"))
        payload = data.get("payload") or {
            k: v for k, v in data.items() if k not in META_KEYS
        }
        event = EventEnvelope(
            type=subject,
            tenant_id=data.get("tenant_id", "inova-ti"),
            project=data.get("project", "unknown"),
            correlation_id=data.get("correlation_id", "example"),
            payload=payload,
        )
        try:
            validate_envelope(event, subject)
        except Exception as exc:
            errors.append(f"{filename}: {exc}")
    return errors


def main() -> int:
    errors = validate_schema_files() + validate_examples()
    if errors:
        print("Contract validation failed:")
        for err in errors:
            print(f"  - {err}")
        return 1
    print("Contract validation passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
