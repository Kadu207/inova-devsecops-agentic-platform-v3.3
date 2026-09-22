from __future__ import annotations

import json
from pathlib import Path
from unittest.mock import MagicMock, patch

import pytest

from runtime.secret_loader import (
    apply_runtime_secrets,
    fetch_vault_kv,
    parse_env_file,
    put_vault_kv,
    render_env_contents,
)


def test_parse_env_file_ignores_comments_and_blanks(tmp_path: Path):
    env_file = tmp_path / "env"
    env_file.write_text(
        "# comment\n\nOPENROUTER_API_KEY=sk-test\nDATABASE_URL='postgres://x'\n",
        encoding="utf-8",
    )
    parsed = parse_env_file(env_file)
    assert parsed["OPENROUTER_API_KEY"] == "sk-test"
    assert parsed["DATABASE_URL"] == "postgres://x"


def test_apply_runtime_secrets_from_tmpfs_file(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
):
    env_file = tmp_path / "env"
    env_file.write_text("WEBHOOK_SECRET=from-file\nAPP_ENV=staging\n", encoding="utf-8")
    monkeypatch.setenv("INOVA_SECRETS_FILE", str(env_file))
    monkeypatch.delenv("VAULT_ADDR", raising=False)
    monkeypatch.delenv("WEBHOOK_SECRET", raising=False)
    applied = apply_runtime_secrets()
    assert applied["WEBHOOK_SECRET"] == "from-file"
    assert applied["APP_ENV"] == "staging"


def test_fetch_vault_kv_reads_v2_payload():
    response = MagicMock()
    response.raise_for_status = MagicMock()
    response.json.return_value = {
        "data": {"data": {"OPENROUTER_API_KEY": "or-from-vault"}}
    }
    with patch("runtime.secret_loader.httpx.get", return_value=response) as get:
        data = fetch_vault_kv("http://vault:8200", "token")
    assert data["OPENROUTER_API_KEY"] == "or-from-vault"
    get.assert_called_once()
    args, kwargs = get.call_args
    assert args[0].endswith("/v1/secret/data/inova/runtime")
    assert kwargs["headers"]["X-Vault-Token"] == "token"


def test_put_vault_kv_posts_data_wrapper():
    response = MagicMock()
    response.raise_for_status = MagicMock()
    with patch("runtime.secret_loader.httpx.post", return_value=response) as post:
        put_vault_kv("http://vault:8200", "token", {"SNYK_TOKEN": "snyk"})
    payload = post.call_args.kwargs["json"]
    assert payload == {"data": {"SNYK_TOKEN": "snyk"}}


def test_render_env_contents_skips_empty():
    rendered = render_env_contents({"A": "1", "B": ""})
    assert rendered == "A=1\n"


def test_wave7_security_workflow_defines_gitleaks_and_trivy():
    workflow = Path(".github/workflows/security.yml").read_text(encoding="utf-8")
    assert "gitleaks:" in workflow
    assert "trivy:" in workflow
    assert "gitleaks detect" in workflow
    assert "aquasecurity/trivy-action" in workflow


def test_local_compose_uses_collision_free_configurable_ports():
    compose = Path("docker-compose.yml").read_text(encoding="utf-8")
    expected = {
        "NATS_HOST_PORT": "14222",
        "NATS_MONITOR_HOST_PORT": "18222",
        "POSTGRES_HOST_PORT": "15432",
        "REDIS_HOST_PORT": "16379",
        "QDRANT_HOST_PORT": "16333",
        "MINIO_HOST_PORT": "19010",
        "MINIO_CONSOLE_HOST_PORT": "19011",
        "WEBHOOK_HOST_PORT": "18787",
        "GRAFANA_HOST_PORT": "13000",
    }
    for variable, default in expected.items():
        assert f"${{{variable}:-{default}}}" in compose


def test_wave7_docs_and_hardening_overlay_exist():
    assert Path("docs/WAVE7-HARDENING.md").is_file()
    assert Path("deploy/vps/docker-compose.hardening.yml").is_file()
    assert Path("deploy/vps/ufw-firewall.sh").is_file()
    assert Path("deploy/grafana/provisioning/dashboards/provider.yml").is_file()
    dashboard = json.loads(
        Path("deploy/grafana/inova-audit-overview.json").read_text(encoding="utf-8")
    )
    assert dashboard["uid"] == "inova-audit-overview"
    assert dashboard["title"] == "Inova Audit Overview"
