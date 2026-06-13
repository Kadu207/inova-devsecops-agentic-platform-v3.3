import argparse
import asyncio
import json
from pathlib import Path
from uuid import uuid4

from runtime.contract_validation import validate_envelope
from runtime.events import EventEnvelope
from runtime.nats_bus import NatsEventBus
from runtime.settings import settings

META_KEYS = frozenset(
    {
        "tenant_id",
        "project",
        "correlation_id",
        "branch",
        "commit",
        "payload",
        "id",
        "type",
    }
)


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--subject", required=True)
    parser.add_argument("--payload", required=True)
    parser.add_argument("--skip-validate", action="store_true")
    args = parser.parse_args()
    data = json.loads(Path(args.payload).read_text(encoding="utf-8-sig"))
    payload = data.get("payload")
    if payload is None:
        payload = {k: v for k, v in data.items() if k not in META_KEYS}
    event = EventEnvelope(
        type=args.subject,
        tenant_id=data.get("tenant_id", settings.tenant_id),
        project=data.get("project", settings.project_name),
        correlation_id=data.get("correlation_id") or str(uuid4()),
        payload=payload,
    )
    if not args.skip_validate:
        validate_envelope(event, args.subject)
    bus = await NatsEventBus("publisher").connect()
    await bus.publish(args.subject, event)
    print(f"Published {args.subject} correlation_id={event.correlation_id}")


if __name__ == "__main__":
    asyncio.run(main())
