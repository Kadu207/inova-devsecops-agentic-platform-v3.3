import pytest

from runtime.events import EventEnvelope
from workers.common.adapters import run_adapter


@pytest.mark.asyncio
async def test_sonar_adapter_stub_without_credentials():
    event = EventEnvelope(
        type="task.sonar.requested", tenant_id="inova-ti", project="demo"
    )
    result = await run_adapter("sonar_worker", event)
    assert result["mode"] == "stub"
    assert result["provider"] == "sonarqube"


@pytest.mark.asyncio
async def test_opencode_adapter_stub_without_credentials():
    event = EventEnvelope(
        type="task.opencode.requested", tenant_id="inova-ti", project="demo"
    )
    result = await run_adapter("opencode_executor", event)
    assert result["mode"] == "stub"
    assert "OPENROUTER_API_KEY" in result["note"]


@pytest.mark.asyncio
async def test_opencode_adapter_integrated_requires_key():
    from unittest.mock import patch

    event = EventEnvelope(
        type="task.opencode.requested", tenant_id="inova-ti", project="demo"
    )
    with patch("workers.common.adapters.settings") as mock_settings:
        mock_settings.openrouter_api_key = ""
        mock_settings.worker_adapter_mode = "integrated"
        with pytest.raises(RuntimeError, match="OPENROUTER_API_KEY"):
            await run_adapter("opencode_executor", event)
