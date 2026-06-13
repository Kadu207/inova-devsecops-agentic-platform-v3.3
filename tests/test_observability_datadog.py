from unittest.mock import MagicMock, patch

from runtime.observability.datadog import export_audit_entry, is_enabled


def test_is_enabled_requires_flag_and_key(monkeypatch):
    monkeypatch.setattr(
        "runtime.observability.datadog.settings.observability_datadog_enabled", False
    )
    monkeypatch.setattr("runtime.observability.datadog.settings.datadog_api_key", "k")
    assert not is_enabled()

    monkeypatch.setattr(
        "runtime.observability.datadog.settings.observability_datadog_enabled", True
    )
    monkeypatch.setattr("runtime.observability.datadog.settings.datadog_api_key", "")
    assert not is_enabled()

    monkeypatch.setattr("runtime.observability.datadog.settings.datadog_api_key", "k")
    assert is_enabled()


def test_export_audit_entry_posts_to_datadog(monkeypatch):
    monkeypatch.setattr(
        "runtime.observability.datadog.settings.observability_datadog_enabled", True
    )
    monkeypatch.setattr(
        "runtime.observability.datadog.settings.datadog_api_key", "test-key"
    )
    monkeypatch.setattr(
        "runtime.observability.datadog.settings.datadog_site", "datadoghq.com"
    )
    monkeypatch.setattr("runtime.observability.datadog.settings.app_env", "staging")
    monkeypatch.setattr(
        "runtime.observability.datadog.settings.project_name", "inova-test"
    )

    mock_client = MagicMock()
    mock_cm = MagicMock()
    mock_cm.__enter__.return_value = mock_client
    mock_cm.__exit__.return_value = False

    with patch("runtime.observability.datadog.httpx.Client", return_value=mock_cm):
        export_audit_entry(
            worker="sonar_worker",
            event_type="task.sonar.requested",
            tenant_id="t1",
            project="p1",
            correlation_id="c1",
            status="completed",
            payload={"mode": "integrated"},
        )

    assert mock_client.post.call_count == 2
