#!/usr/bin/env python3
"""Import or verify the Inova Grafana audit dashboard."""

from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path

import httpx

ROOT = Path(__file__).resolve().parents[1]
DASHBOARD = ROOT / "deploy" / "grafana" / "inova-audit-overview.json"


def wait_health(base: str, timeout: float = 60.0) -> None:
    deadline = time.time() + timeout
    last_error = "timeout"
    while time.time() < deadline:
        try:
            response = httpx.get(f"{base}/api/health", timeout=5.0)
            if response.status_code == 200:
                return
            last_error = f"HTTP {response.status_code}"
        except httpx.HTTPError as exc:
            last_error = str(exc)
        time.sleep(2)
    raise SystemExit(f"Grafana health failed: {last_error}")


def import_dashboard(base: str, user: str, password: str, api_key: str) -> None:
    payload = {
        "dashboard": json.loads(DASHBOARD.read_text(encoding="utf-8")),
        "overwrite": True,
        "folderId": 0,
    }
    headers = {"Content-Type": "application/json"}
    auth = None
    if api_key:
        headers["Authorization"] = f"Bearer {api_key}"
    else:
        auth = (user, password)
    response = httpx.post(
        f"{base}/api/dashboards/db",
        headers=headers,
        auth=auth,
        json=payload,
        timeout=30.0,
    )
    response.raise_for_status()
    uid = response.json().get("uid") or payload["dashboard"].get("uid")
    print(f"Grafana dashboard imported uid={uid}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--url", default=os.environ.get("GRAFANA_URL", "http://127.0.0.1:3000")
    )
    parser.add_argument("--user", default=os.environ.get("GRAFANA_USER", "admin"))
    parser.add_argument(
        "--password",
        default=os.environ.get("GRAFANA_ADMIN_PASSWORD", "inova_grafana_change_me"),
    )
    parser.add_argument("--api-key", default=os.environ.get("GRAFANA_API_KEY", ""))
    parser.add_argument("--skip-wait", action="store_true")
    args = parser.parse_args()
    if not DASHBOARD.is_file():
        raise SystemExit(f"Dashboard ausente: {DASHBOARD}")
    base = args.url.rstrip("/")
    if not args.skip_wait:
        wait_health(base)
    import_dashboard(base, args.user, args.password, args.api_key)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
