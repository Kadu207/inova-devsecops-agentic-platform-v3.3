from runtime.events import EventEnvelope


def test_event_completion_keeps_correlation():
    e = EventEnvelope(
        type="task.audit.requested",
        tenant_id="inova-ti",
        project="x",
        correlation_id="c1",
        payload={"a": 1},
    )
    done = e.completed("task.audit.completed", {"ok": True})
    assert done.correlation_id == "c1"
    assert done.causation_id == e.id
    assert done.payload["ok"] is True


def test_retry_increments_attempt():
    e = EventEnvelope(type="task.audit.requested", tenant_id="inova-ti")
    r = e.next_attempt()
    assert r.attempt == 1
    assert r.causation_id == e.id
