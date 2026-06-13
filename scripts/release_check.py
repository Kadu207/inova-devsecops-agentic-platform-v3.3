from __future__ import annotations

import os
import subprocess  # nosec B404
import sys
from pathlib import Path

REQUIRED = [
    ".cursor/rules/00-governance.mdc",
    ".cursor/rules/10-event-driven-workers.mdc",
    "AGENTS.md",
    "docker-compose.yml",
    "runtime/nats_bus.py",
    "runtime/contract_validation.py",
    "workers/orchestrator/main.py",
    "workers/common/adapters.py",
    "database/postgres/001_init_multitenant.sql",
    "database/postgres/002_audit_runtime.sql",
    "docs/v3.3-event-driven-workers-runtime.md",
    "contracts/events/event-envelope.schema.json",
    "scripts/validate_contracts.py",
]

WORKERS = [
    "orchestrator",
    "audit_pipeline",
    "opencode_executor",
    "sonar_worker",
    "snyk_worker",
    "datadog_worker",
    "test_worker",
    "build_worker",
    "review_worker",
    "release_worker",
    "notification_worker",
]


def run(cmd: list[str]) -> None:
    print(f"+ {' '.join(cmd)}")
    env = os.environ.copy()
    root = str(Path(__file__).resolve().parent.parent)
    env["PYTHONPATH"] = root + os.pathsep + env.get("PYTHONPATH", "")
    subprocess.run(cmd, check=True, env=env)  # nosec B603


def main() -> int:
    missing = [p for p in REQUIRED if not Path(p).exists()]
    if missing:
        print(f"Release check failed. Missing: {missing}")
        return 1

    for worker in WORKERS:
        path = Path(f"workers/{worker}/main.py")
        if not path.exists():
            print(f"Release check failed. Missing worker: {path}")
            return 1

    schemas = list(Path("contracts/events").glob("*.schema.json"))
    if len(schemas) < 20:
        print(f"Release check failed. Expected >=20 schemas, found {len(schemas)}")
        return 1

    run(
        [
            sys.executable,
            "-m",
            "ruff",
            "check",
            "runtime",
            "workers",
            "scripts",
            "tests",
        ]
    )
    run([sys.executable, "scripts/validate_contracts.py"])
    run([sys.executable, "-m", "pytest", "-q"])
    print("Release check approved for v3.3")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
