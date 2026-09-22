#!/usr/bin/env python3
"""Upload selected keys from an env file into Vault KV v2."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from runtime.secret_loader import parse_env_file, put_vault_kv, render_env_contents  # noqa: E402

UPLOAD_KEYS = {
    "APP_ENV",
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
    "WORKER_ADAPTER_MODE",
    "OBSERVABILITY_DATADOG_ENABLED",
    "GRAFANA_ADMIN_PASSWORD",
    "GRAFANA_URL",
    "GRAFANA_API_KEY",
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--env-file", required=True)
    parser.add_argument(
        "--addr", default=os.environ.get("VAULT_ADDR", "http://127.0.0.1:8200")
    )
    parser.add_argument("--token", default=os.environ.get("VAULT_TOKEN", ""))
    parser.add_argument(
        "--render", default="", help="Optional path to write /run/inova/env"
    )
    args = parser.parse_args()
    if not args.token:
        raise SystemExit("VAULT_TOKEN ausente")
    parsed = parse_env_file(args.env_file)
    secrets = {key: parsed[key] for key in UPLOAD_KEYS if parsed.get(key)}
    put_vault_kv(args.addr, args.token, secrets)
    if args.render:
        Path(args.render).parent.mkdir(parents=True, exist_ok=True)
        Path(args.render).write_text(render_env_contents(parsed), encoding="utf-8")
        os.chmod(args.render, 0o600)
    print(f"Vault KV updated ({len(secrets)} keys).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
