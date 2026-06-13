import asyncio

from runtime.events import EventEnvelope
from runtime.logging import configure_logging
from runtime.nats_bus import NatsEventBus

log = configure_logging("workers.orchestrator")

WORKER_NAME = "orchestrator"
SUBJECT = "task.orchestrate.requested"
DURABLE = "inova-orchestrator"
COMPLETED_SUBJECT = "task.orchestrated"
DESCRIPTION = "Orquestra eventos e publica proximas tarefas."

DEFAULT_NEXT_TASKS = [
    "task.audit.requested",
    "task.test.requested",
    "task.review.requested",
]


async def handle(event: EventEnvelope, bus: NatsEventBus) -> EventEnvelope:
    log.info(
        "processing",
        extra={
            "worker": WORKER_NAME,
            "event_type": event.type,
            "correlation_id": event.correlation_id,
        },
    )
    next_tasks = event.payload.get("next_tasks") or DEFAULT_NEXT_TASKS
    published: list[str] = []

    for task_subject in next_tasks:
        child = EventEnvelope(
            type=task_subject,
            tenant_id=event.tenant_id,
            project=event.project,
            correlation_id=event.correlation_id,
            causation_id=event.id,
            payload={
                "orchestrated_by": WORKER_NAME,
                "parent_type": event.type,
                **event.payload,
            },
        )
        await bus.publish(task_subject, child)
        published.append(task_subject)

    payload = {
        "worker": WORKER_NAME,
        "description": DESCRIPTION,
        "status": "completed",
        "next_tasks": published,
        "input": event.payload,
        "evidence": {"runtime": "nats-jetstream", "durable": DURABLE},
    }
    return event.completed(COMPLETED_SUBJECT, payload)


async def main():
    bus = await NatsEventBus(WORKER_NAME).connect()

    async def wrapped_handler(event: EventEnvelope) -> EventEnvelope:
        return await handle(event, bus)

    await bus.subscribe(
        SUBJECT, DURABLE, wrapped_handler, COMPLETED_SUBJECT, max_attempts=3
    )


if __name__ == "__main__":
    asyncio.run(main())
