from __future__ import annotations

from typing import Awaitable, Callable

from runtime.events import EventEnvelope
from runtime.nats_bus import NatsEventBus

Handler = Callable[[EventEnvelope], Awaitable[EventEnvelope | None]]


async def run_worker(
    worker_name: str,
    subject: str,
    durable: str,
    completed_subject: str,
    handler: Handler,
    max_attempts: int = 3,
) -> None:
    bus = await NatsEventBus(worker_name).connect()
    await bus.subscribe(
        subject, durable, handler, completed_subject, max_attempts=max_attempts
    )
