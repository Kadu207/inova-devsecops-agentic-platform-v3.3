from __future__ import annotations
from datetime import datetime, timezone
from typing import Any, Dict, Optional
from uuid import uuid4
from pydantic import BaseModel, Field


class EventEnvelope(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid4()))
    type: str
    tenant_id: str
    project: str = "unknown"
    correlation_id: str = Field(default_factory=lambda: str(uuid4()))
    causation_id: Optional[str] = None
    created_at: str = Field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    attempt: int = 0
    payload: Dict[str, Any] = Field(default_factory=dict)

    def next_attempt(self) -> "EventEnvelope":
        data = self.model_dump()
        data["attempt"] = int(data.get("attempt", 0)) + 1
        data["causation_id"] = self.id
        data["id"] = str(uuid4())
        data["created_at"] = datetime.now(timezone.utc).isoformat()
        return EventEnvelope(**data)

    def completed(self, event_type: str, payload: Dict[str, Any]) -> "EventEnvelope":
        return EventEnvelope(
            type=event_type,
            tenant_id=self.tenant_id,
            project=self.project,
            correlation_id=self.correlation_id,
            causation_id=self.id,
            payload=payload,
        )
