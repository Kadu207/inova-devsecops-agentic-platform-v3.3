SHELL := /bin/bash

.PHONY: bootstrap bootstrap-ps dev down logs test lint validate-contracts publish-audit publish-opencode publish-orchestrate publish-full-pipeline migrate release-check e2e-orchestrate-audit e2e-full-pipeline audit-log wave5-golden-run apply-branch-protection staging-up observability-up

bootstrap:
	python3 -m venv .venv || true
	. .venv/bin/activate && pip install -U pip && pip install -r requirements-dev.txt

bootstrap-ps:
	powershell -ExecutionPolicy Bypass -File scripts/cursor-bootstrap.ps1

migrate:
	docker compose exec -T postgres psql -U inova -d inova_platform < database/postgres/001_init_multitenant.sql
	docker compose exec -T postgres psql -U inova -d inova_platform < database/postgres/002_audit_runtime.sql

dev:
	docker compose up -d --build

workers:
	docker compose up -d --build orchestrator audit-worker opencode-worker sonar-worker snyk-worker datadog-worker test-worker build-worker review-worker release-worker notification-worker

down:
	docker compose down

logs:
	docker compose logs -f --tail=200

test:
	python -m pytest -q

lint:
	python -m ruff check runtime workers scripts tests
	python -m ruff format --check runtime workers scripts tests

validate-contracts:
	python scripts/validate_contracts.py

publish-audit:
	docker compose run --rm publisher python scripts/publish_event.py --subject task.audit.requested --payload examples/events/audit_requested.json

publish-opencode:
	docker compose run --rm publisher python scripts/publish_event.py --subject task.opencode.requested --payload examples/events/opencode_requested.json

publish-orchestrate:
	docker compose run --rm publisher python scripts/publish_event.py --subject task.orchestrate.requested --payload examples/events/orchestrate_requested.json

publish-full-pipeline:
	docker compose run --rm publisher python scripts/publish_event.py --subject task.orchestrate.requested --payload examples/events/orchestrate_full_devsecops.json

audit-log:
	python scripts/query_audit_log.py --last 20

release-check: lint validate-contracts test
	python scripts/release_check.py

e2e-orchestrate-audit:
	bash scripts/e2e_orchestrate_audit.sh

e2e-full-pipeline:
	bash scripts/e2e_full_pipeline.sh

wave5-golden-run:
	bash scripts/wave5_golden_run.sh

apply-branch-protection:
	MAKE_PUBLIC_IF_REQUIRED=1 bash scripts/apply_branch_protection.sh

staging-up:
	docker compose --env-file .env.staging -f docker-compose.yml -f deploy/staging/docker-compose.staging.yml --profile staging up -d --build

observability-up:
	docker compose --profile observability up -d grafana
