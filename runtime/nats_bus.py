from __future__ import annotations

import asyncio
import json
from typing import Awaitable, Callable

import nats
from nats.js.api import AckPolicy, ConsumerConfig, DeliverPolicy, StreamConfig

from runtime.audit import write_audit, write_dlq
from runtime.contract_validation import validate_envelope
from runtime.events import EventEnvelope
from runtime.logging import configure_logging
from runtime.settings import settings

Handler = Callable[[EventEnvelope], Awaitable[EventEnvelope | None]]
log = configure_logging("runtime.nats_bus")


class NatsEventBus:
    def __init__(self, worker_name: str):
        self.worker_name = worker_name
        self.nc = None
        self.js = None

    async def connect(self):
        self.nc = await nats.connect(settings.nats_url)
        self.js = self.nc.jetstream()
        await self.ensure_stream()
        return self

    async def ensure_stream(self):
        try:
            await self.js.stream_info(settings.nats_stream)
        except Exception:
            await self.js.add_stream(
                StreamConfig(
                    name=settings.nats_stream,
                    subjects=["task.>", "pipeline.>", "review.>", "release.>", "dlq.>"],
                    retention="limits",
                    max_msgs=100000,
                    storage="file",
                )
            )

    async def publish(self, subject: str, event: EventEnvelope):
        validate_envelope(event, subject)
        payload = event.model_dump_json().encode("utf-8")
        await self.js.publish(subject, payload)
        log.info(
            "published",
            extra={
                "subject": subject,
                "correlation_id": event.correlation_id,
                "event_type": event.type,
            },
        )

    async def _ensure_consumer(
        self, durable: str, subject: str, max_attempts: int
    ) -> None:
        config = ConsumerConfig(
            durable_name=durable,
            deliver_policy=DeliverPolicy.ALL,
            ack_policy=AckPolicy.EXPLICIT,
            filter_subject=subject,
            max_deliver=max_attempts,
        )
        try:
            await self.js.add_consumer(settings.nats_stream, config)
        except Exception as exc:
            if "already in use" not in str(exc).lower():
                raise

    async def subscribe(
        self,
        subject: str,
        durable: str,
        handler: Handler,
        completed_subject: str | None = None,
        max_attempts: int = 3,
    ):
        await self._ensure_consumer(durable, subject, max_attempts)
        sub = await self.js.pull_subscribe(
            subject, durable=durable, stream=settings.nats_stream
        )
        log.info(
            "subscribed",
            extra={"worker": self.worker_name, "subject": subject, "durable": durable},
        )
        while True:
            try:
                msgs = await sub.fetch(batch=5, timeout=1)
            except asyncio.TimeoutError:
                continue
            for msg in msgs:
                event: EventEnvelope | None = None
                try:
                    event = EventEnvelope(**json.loads(msg.data.decode("utf-8")))
                    validate_envelope(event, subject)
                    write_audit(
                        self.worker_name,
                        event.type,
                        event.tenant_id,
                        event.project,
                        event.correlation_id,
                        "started",
                        event.payload,
                    )
                    result = await handler(event)
                    if result and completed_subject:
                        await self.publish(completed_subject, result)
                    write_audit(
                        self.worker_name,
                        event.type,
                        event.tenant_id,
                        event.project,
                        event.correlation_id,
                        "completed",
                        result.payload if result else {},
                    )
                    await msg.ack()
                except Exception as exc:
                    try:
                        if event is None:
                            event = EventEnvelope(
                                **json.loads(msg.data.decode("utf-8"))
                            )
                        write_audit(
                            self.worker_name,
                            event.type,
                            event.tenant_id,
                            event.project,
                            event.correlation_id,
                            "failed",
                            event.payload,
                            str(exc),
                        )
                        if event.attempt + 1 >= max_attempts:
                            dlq_event = event.completed(
                                "task.failed",
                                {
                                    "worker": self.worker_name,
                                    "error": str(exc),
                                    "original_type": event.type,
                                },
                            )
                            await self.publish("dlq.task.failed", dlq_event)
                            write_dlq(
                                event.tenant_id,
                                event.project,
                                event.type,
                                event.correlation_id,
                                event.payload,
                                str(exc),
                                self.worker_name,
                            )
                            await msg.ack()
                        else:
                            await msg.nak()
                    except Exception:
                        await msg.nak()
