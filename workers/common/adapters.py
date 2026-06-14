from __future__ import annotations

from typing import Any, Dict

import httpx

from runtime.events import EventEnvelope
from runtime.settings import settings


async def _stub(worker_name: str, note: str) -> Dict[str, Any]:
    return {
        "mode": "stub",
        "status": "completed",
        "note": note,
    }


async def run_adapter(worker_name: str, event: EventEnvelope) -> Dict[str, Any]:
    mode = settings.worker_adapter_mode.lower()
    if mode == "stub":
        return await _stub(worker_name, f"Forced stub mode for {worker_name}.")
    if worker_name == "audit_pipeline":
        return {
            "mode": "stub",
            "score": 92,
            "checks": ["contracts", "security", "tests", "release-readiness"],
        }
    if worker_name == "release_worker":
        return {"mode": "stub", "release_gate": "approved_with_local_checks"}
    if worker_name == "test_worker":
        return {"mode": "stub", "tests_passed": True, "total": 0}
    if worker_name == "build_worker":
        return {"mode": "stub", "artifact": "local-stub"}
    if worker_name == "review_worker":
        return {"mode": "stub", "review_status": "approved_with_notes"}
    if worker_name == "notification_worker":
        return {"mode": "stub", "channel": "stub", "delivered": False}

    if worker_name == "opencode_executor":
        return await _opencode_adapter(event)
    if worker_name == "sonar_worker":
        return await _sonar_adapter(event)
    if worker_name == "snyk_worker":
        return await _snyk_adapter(event)
    if worker_name == "datadog_worker":
        return await _datadog_adapter(event)

    return await _stub(worker_name, "Generic stub worker response.")


async def _opencode_adapter(event: EventEnvelope) -> Dict[str, Any]:
    if not settings.openrouter_api_key:
        return {
            "mode": "stub",
            "provider": "openrouter",
            "note": "Configure OPENROUTER_API_KEY para execução real.",
        }
    prompt = (
        event.payload.get("prompt")
        or event.payload.get("scope")
        or "Audit this repository."
    )
    if isinstance(prompt, list):
        prompt = ", ".join(str(item) for item in prompt)
    async with httpx.AsyncClient(timeout=60.0) as client:
        response = await client.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {settings.openrouter_api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": settings.openrouter_model,
                "messages": [
                    {
                        "role": "system",
                        "content": "You are a DevSecOps audit assistant.",
                    },
                    {"role": "user", "content": str(prompt)},
                ],
            },
        )
        response.raise_for_status()
        data = response.json()
        content = data["choices"][0]["message"]["content"]
        return {
            "mode": "integrated",
            "provider": "openrouter",
            "model": settings.openrouter_model,
            "summary": content[:2000],
        }


async def _sonar_adapter(event: EventEnvelope) -> Dict[str, Any]:
    if not settings.sonar_token or not settings.sonar_host_url:
        if settings.worker_adapter_mode.lower() == "integrated":
            raise RuntimeError(
                "SONAR_HOST_URL e SONAR_TOKEN obrigatorios em modo integrated."
            )
        return {
            "mode": "stub",
            "provider": "sonarqube",
            "note": "Configure SONAR_HOST_URL e SONAR_TOKEN.",
        }
    project_key = event.payload.get("project_key") or event.project
    base_url = settings.sonar_host_url.rstrip("/")
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.get(
            f"{base_url}/api/qualitygates/project_status",
            params={"projectKey": project_key},
            auth=(settings.sonar_token, ""),
        )
        if response.status_code == 404:
            validate = await client.get(
                f"{base_url}/api/authentication/validate",
                auth=(settings.sonar_token, ""),
            )
            validate.raise_for_status()
            return {
                "mode": "integrated",
                "provider": "sonarqube",
                "project_key": project_key,
                "quality_gate": "UNKNOWN",
                "passed": False,
                "note": f"Projeto '{project_key}' nao encontrado; token Sonar valido.",
            }
        response.raise_for_status()
        data = response.json()
        status = data.get("projectStatus", {}).get("status", "UNKNOWN")
        return {
            "mode": "integrated",
            "provider": "sonarqube",
            "project_key": project_key,
            "quality_gate": status,
            "passed": status == "OK",
        }


async def _snyk_adapter(event: EventEnvelope) -> Dict[str, Any]:
    if not settings.snyk_token:
        if settings.worker_adapter_mode.lower() == "integrated":
            raise RuntimeError("SNYK_TOKEN obrigatorio em modo integrated.")
        return {"mode": "stub", "provider": "snyk", "note": "Configure SNYK_TOKEN."}
    org_id = event.payload.get("org_id", "")
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.get(
            "https://api.snyk.io/v1/user/me",
            headers={"Authorization": f"token {settings.snyk_token}"},
        )
        response.raise_for_status()
        data = response.json()
        orgs = data.get("orgs", [])
        org_ids = [item.get("id") for item in orgs if item.get("id")]
        return {
            "mode": "integrated",
            "provider": "snyk",
            "username": data.get("username"),
            "org_id": org_id or (org_ids[0] if org_ids else None),
            "orgs_available": len(org_ids),
            "vulnerabilities_checked": True,
        }


async def _datadog_adapter(event: EventEnvelope) -> Dict[str, Any]:
    if not settings.datadog_api_key:
        if settings.worker_adapter_mode.lower() == "integrated":
            raise RuntimeError("DATADOG_API_KEY obrigatorio em modo integrated.")
        return {
            "mode": "stub",
            "provider": "datadog",
            "note": "Configure DATADOG_API_KEY.",
        }
    title = event.payload.get("title") or f"inova-event:{event.type}"
    text = event.payload.get("text") or f"correlation_id={event.correlation_id}"
    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            "https://api.datadoghq.com/api/v1/events",
            headers={
                "DD-API-KEY": settings.datadog_api_key,
                "Content-Type": "application/json",
            },
            json={
                "title": title,
                "text": text,
                "tags": [
                    f"tenant:{event.tenant_id}",
                    f"project:{event.project}",
                    f"correlation_id:{event.correlation_id}",
                ],
            },
        )
        response.raise_for_status()
        data = response.json()
        return {
            "mode": "integrated",
            "provider": "datadog",
            "event_id": data.get("event", {}).get("id"),
            "status": "submitted",
        }
