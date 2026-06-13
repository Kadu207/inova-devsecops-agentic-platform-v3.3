from runtime.events import EventEnvelope
from runtime.contract_validation import validate_envelope


def test_audit_example_contract():
    event = EventEnvelope(
        type="task.audit.requested",
        tenant_id="inova-ti",
        project="inova-ti-os",
        correlation_id="audit-local-001",
        payload={"requested_by": "cursor", "scope": ["pipeline"]},
    )
    validate_envelope(event, "task.audit.requested")


def test_orchestrate_example_contract():
    event = EventEnvelope(
        type="task.orchestrate.requested",
        tenant_id="inova-ti",
        project="inova-ti-os",
        correlation_id="orchestrate-local-001",
        payload={"pipeline": "default-devsecops"},
    )
    validate_envelope(event, "task.orchestrate.requested")
