from __future__ import annotations

import os
from pathlib import Path
from typing import Any
from urllib.parse import urljoin

import httpx

_SECRET_KEYS = (
    "POSTGRES_PASSWORD",
    "DATABASE_URL",
    "OPENROUTER_API_KEY",
    "SONAR_TOKEN",
    "SONAR_HOST_URL",
    "SONAR_ORGANIZATION",
    "SNYK_TOKEN",
    "DATADOG_API_KEY",
    "DATADOG_SITE",
    "WEBHOOK_SECRET",
    "NATS_URL",
    "NATS_TLS_CA",
    "VAULT_ADDR",
    "VAULT_CACERT",
    "VAULT_TOKEN",
    "WORKER_ADAPTER_MODE",
    "OBSERVABILITY_DATADOG_ENABLED",
    "GRAFANA_ADMIN_PASSWORD",
    "GRAFANA_URL",
    "GRAFANA_API_KEY",
    "APP_ENV",
)


def parse_env_file(path: str | Path) -> dict[str, str]:
    values: dict[str, str] = {}
    env_path = Path(path)
    if not env_path.is_file():
        return values
    try:
        lines = env_path.read_text(encoding="utf-8").splitlines()
    except OSError:
        return values
    for raw in lines:
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip("'").strip('"')
        if key:
            values[key] = value
    return values


def load_env_file(path: str | Path, override: bool = False) -> dict[str, str]:
    loaded = parse_env_file(path)
    for key, value in loaded.items():
        if override or key not in os.environ:
            os.environ[key] = value
    return loaded


def _vault_token() -> str:
    token = os.environ.get("VAULT_TOKEN", "").strip()
    if token:
        return token
    token_file = os.environ.get("VAULT_TOKEN_FILE", "").strip()
    if token_file and Path(token_file).is_file():
        return Path(token_file).read_text(encoding="utf-8").strip()
    return ""


def fetch_vault_kv(
    addr: str,
    token: str,
    mount: str = "secret",
    path: str = "inova/runtime",
    timeout: float = 10.0,
) -> dict[str, Any]:
    url = urljoin(addr.rstrip("/") + "/", f"v1/{mount}/data/{path.lstrip('/')}")
    ca_cert = os.environ.get("VAULT_CACERT", "").strip()
    response = httpx.get(
        url,
        headers={"X-Vault-Token": token},
        timeout=timeout,
        verify=ca_cert or True,
    )
    response.raise_for_status()
    payload = response.json()
    data = payload.get("data", {}).get("data", {})
    return data if isinstance(data, dict) else {}


def put_vault_kv(
    addr: str,
    token: str,
    secrets: dict[str, str],
    mount: str = "secret",
    path: str = "inova/runtime",
    timeout: float = 10.0,
) -> None:
    url = urljoin(addr.rstrip("/") + "/", f"v1/{mount}/data/{path.lstrip('/')}")
    ca_cert = os.environ.get("VAULT_CACERT", "").strip()
    response = httpx.post(
        url,
        headers={"X-Vault-Token": token},
        json={"data": secrets},
        timeout=timeout,
        verify=ca_cert or True,
    )
    response.raise_for_status()


def apply_runtime_secrets() -> dict[str, str]:
    applied: dict[str, str] = {}
    secrets_file = os.environ.get("INOVA_SECRETS_FILE", "/run/inova/env")
    if Path(secrets_file).is_file():
        applied.update(load_env_file(secrets_file, override=False))

    addr = os.environ.get("VAULT_ADDR", "").strip()
    token = _vault_token()
    if addr and token:
        vault_data = fetch_vault_kv(
            addr,
            token,
            mount=os.environ.get("VAULT_KV_MOUNT", "secret"),
            path=os.environ.get("VAULT_SECRET_PATH", "inova/runtime"),
        )
        for key, value in vault_data.items():
            if value is None:
                continue
            text = str(value)
            os.environ[key] = text
            applied[key] = text
    return applied


def render_env_contents(values: dict[str, str]) -> str:
    lines = [f"{key}={values[key]}" for key in sorted(values) if values[key] != ""]
    return "\n".join(lines) + ("\n" if lines else "")
