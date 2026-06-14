from __future__ import annotations

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from runtime.events import EventEnvelope
from workers.common.adapters import run_adapter


def _mock_http_client(get_response=None, post_response=None):
    client = AsyncMock()
    client.get = AsyncMock(return_value=get_response)
    client.post = AsyncMock(return_value=post_response)
    client.__aenter__ = AsyncMock(return_value=client)
    client.__aexit__ = AsyncMock(return_value=None)
    return client


def _json_response(payload: dict):
    response = MagicMock()
    response.raise_for_status = MagicMock()
    response.json.return_value = payload
    return response


@pytest.mark.asyncio
async def test_sonar_integrated_with_mock():
    event = EventEnvelope(
        type="task.sonar.requested",
        tenant_id="inova-ti",
        project="demo-app",
        payload={"project_key": "demo-key"},
    )
    with patch("workers.common.adapters.settings") as mock_settings:
        mock_settings.sonar_token = "secret"
        mock_settings.sonar_host_url = "https://sonar.example.com"
        with patch("workers.common.adapters.httpx.AsyncClient") as client_cls:
            client_cls.return_value = _mock_http_client(
                get_response=_json_response({"projectStatus": {"status": "OK"}})
            )
            result = await run_adapter("sonar_worker", event)

    assert result["mode"] == "integrated"
    assert result["passed"] is True
    assert result["quality_gate"] == "OK"


@pytest.mark.asyncio
async def test_snyk_integrated_with_mock():
    event = EventEnvelope(
        type="task.snyk.requested", tenant_id="inova-ti", project="demo"
    )
    with patch("workers.common.adapters.settings") as mock_settings:
        mock_settings.snyk_token = "secret"
        with patch("workers.common.adapters.httpx.AsyncClient") as client_cls:
            client_cls.return_value = _mock_http_client(
                get_response=_json_response(
                    {
                        "username": "inovatidev",
                        "orgs": [{"id": "org-1"}, {"id": "org-2"}],
                    }
                )
            )
            result = await run_adapter("snyk_worker", event)

    assert result["mode"] == "integrated"
    assert result["orgs_available"] == 2
    assert result["org_id"] == "org-1"


@pytest.mark.asyncio
async def test_datadog_integrated_with_mock():
    event = EventEnvelope(
        type="task.datadog.requested",
        tenant_id="inova-ti",
        project="demo",
        correlation_id="corr-1",
        payload={"title": "Test", "text": "body"},
    )
    with patch("workers.common.adapters.settings") as mock_settings:
        mock_settings.datadog_api_key = "dd-key"
        with patch("workers.common.adapters.httpx.AsyncClient") as client_cls:
            client_cls.return_value = _mock_http_client(
                post_response=_json_response({"event": {"id": 12345}})
            )
            result = await run_adapter("datadog_worker", event)

    assert result["mode"] == "integrated"
    assert result["event_id"] == 12345


@pytest.mark.asyncio
async def test_opencode_integrated_with_mock():
    event = EventEnvelope(
        type="task.opencode.requested",
        tenant_id="inova-ti",
        project="demo",
        payload={"prompt": "Audit dependencies"},
    )
    with patch("workers.common.adapters.settings") as mock_settings:
        mock_settings.openrouter_api_key = "or-key"
        mock_settings.openrouter_model = "test/model"
        with patch("workers.common.adapters.httpx.AsyncClient") as client_cls:
            client_cls.return_value = _mock_http_client(
                post_response=_json_response(
                    {"choices": [{"message": {"content": "All good."}}]}
                )
            )
            result = await run_adapter("opencode_executor", event)

    assert result["mode"] == "integrated"
    assert result["summary"] == "All good."
