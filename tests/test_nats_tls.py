from __future__ import annotations

from unittest.mock import AsyncMock, patch

import pytest

from runtime.nats_bus import NatsEventBus


@pytest.mark.asyncio
async def test_nats_connect_passes_tls_context_for_tls_url():
    bus = NatsEventBus("audit_pipeline")
    with (
        patch("runtime.nats_bus.settings") as mock_settings,
        patch("runtime.nats_bus.nats.connect", new_callable=AsyncMock) as connect,
        patch.object(bus, "ensure_stream", new_callable=AsyncMock),
    ):
        mock_settings.nats_url = "tls://nats:4222"
        mock_settings.nats_tls_ca = ""
        mock_settings.nats_stream = "INOVA_TASKS"
        fake_nc = AsyncMock()
        fake_nc.jetstream.return_value = AsyncMock()
        connect.return_value = fake_nc
        await bus.connect()
    assert connect.call_args.kwargs.get("tls") is not None


@pytest.mark.asyncio
async def test_nats_connect_plain_url_has_no_tls_kwarg():
    bus = NatsEventBus("audit_pipeline")
    with (
        patch("runtime.nats_bus.settings") as mock_settings,
        patch("runtime.nats_bus.nats.connect", new_callable=AsyncMock) as connect,
        patch.object(bus, "ensure_stream", new_callable=AsyncMock),
    ):
        mock_settings.nats_url = "nats://nats:4222"
        mock_settings.nats_tls_ca = ""
        fake_nc = AsyncMock()
        fake_nc.jetstream.return_value = AsyncMock()
        connect.return_value = fake_nc
        await bus.connect()
    assert "tls" not in connect.call_args.kwargs
