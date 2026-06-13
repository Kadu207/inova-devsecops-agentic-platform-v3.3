import pytest

from runtime.events import EventEnvelope
from workers.orchestrator.main import DEFAULT_NEXT_TASKS, handle


class FakeBus:
    def __init__(self):
        self.published: list[tuple[str, EventEnvelope]] = []

    async def publish(self, subject: str, event: EventEnvelope):
        self.published.append((subject, event))


@pytest.mark.asyncio
async def test_orchestrator_publishes_next_tasks():
    bus = FakeBus()
    event = EventEnvelope(
        type="task.orchestrate.requested",
        tenant_id="inova-ti",
        project="demo",
        correlation_id="c-1",
        payload={},
    )
    result = await handle(event, bus)
    assert result.type == "task.orchestrated"
    assert len(bus.published) == len(DEFAULT_NEXT_TASKS)
    assert bus.published[0][0] == "task.audit.requested"
    assert result.payload["next_tasks"] == DEFAULT_NEXT_TASKS
