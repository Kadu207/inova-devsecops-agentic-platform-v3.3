"""HTTP webhook que publica eventos validados no NATS (staging/VPS)."""

from __future__ import annotations

import asyncio
import hashlib
import hmac
import json
import threading
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, HTTPServer
from typing import Any
from uuid import uuid4

from runtime.contract_validation import validate_envelope
from runtime.events import EventEnvelope
from runtime.logging import configure_logging
from runtime.nats_bus import NatsEventBus
from runtime.settings import settings

log = configure_logging("workers.webhook_ingress")

ALLOWED_SUBJECTS = frozenset(
    {
        "task.orchestrate.requested",
        "task.audit.requested",
        "task.opencode.requested",
    }
)


def _verify_signature(body: bytes, signature: str | None) -> bool:
    secret = settings.webhook_secret.strip()
    if not secret:
        return settings.app_env.lower() != "production"
    if not signature or not signature.startswith("sha256="):
        return False
    expected = hmac.new(secret.encode("utf-8"), body, hashlib.sha256).hexdigest()
    return hmac.compare_digest(signature.removeprefix("sha256="), expected)


def _build_event(data: dict[str, Any], subject: str) -> EventEnvelope:
    payload = data.get("payload")
    if payload is None:
        payload = {
            k: v
            for k, v in data.items()
            if k
            not in {
                "tenant_id",
                "project",
                "correlation_id",
                "branch",
                "commit",
                "subject",
                "type",
            }
        }
    return EventEnvelope(
        type=subject,
        tenant_id=data.get("tenant_id", settings.tenant_id),
        project=data.get("project", settings.project_name),
        correlation_id=data.get("correlation_id") or str(uuid4()),
        payload=payload,
    )


async def run_ingress() -> None:
    bus = await NatsEventBus("webhook_ingress").connect()
    loop = asyncio.get_running_loop()
    publish_queue: asyncio.Queue[tuple[str, EventEnvelope]] = asyncio.Queue()

    async def publisher() -> None:
        while True:
            subject, event = await publish_queue.get()
            try:
                await bus.publish(subject, event)
            except Exception:
                log.exception(
                    "publish_failed",
                    extra={"subject": subject, "correlation_id": event.correlation_id},
                )
            finally:
                publish_queue.task_done()

    asyncio.create_task(publisher())

    def enqueue(subject: str, event: EventEnvelope) -> None:
        loop.call_soon_threadsafe(publish_queue.put_nowait, (subject, event))

    class WebhookHandler(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def log_message(self, fmt: str, *args: Any) -> None:
            log.info("http_request", extra={"line": fmt % args})

        def _json_response(self, status: HTTPStatus, payload: dict[str, Any]) -> None:
            body = json.dumps(payload).encode("utf-8")
            self.send_response(status)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Connection", "close")
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self) -> None:
            if self.path.rstrip("/") == "/health":
                self._json_response(
                    HTTPStatus.OK,
                    {"status": "ok", "service": "webhook-ingress"},
                )
                return
            self._json_response(HTTPStatus.NOT_FOUND, {"error": "not_found"})

        def do_POST(self) -> None:
            if self.path.rstrip("/") != "/webhook/publish":
                self._json_response(HTTPStatus.NOT_FOUND, {"error": "not_found"})
                return

            length = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(length)
            signature = self.headers.get("X-Inova-Signature")

            if not _verify_signature(body, signature):
                self._json_response(HTTPStatus.UNAUTHORIZED, {"error": "invalid_signature"})
                return

            try:
                data = json.loads(body.decode("utf-8"))
            except json.JSONDecodeError:
                self._json_response(HTTPStatus.BAD_REQUEST, {"error": "invalid_json"})
                return

            subject = data.get("subject") or data.get("type")
            if not subject or subject not in ALLOWED_SUBJECTS:
                self._json_response(
                    HTTPStatus.BAD_REQUEST,
                    {"error": "subject_not_allowed", "allowed": sorted(ALLOWED_SUBJECTS)},
                )
                return

            try:
                event = _build_event(data, subject)
                validate_envelope(event, subject)
            except Exception as exc:
                self._json_response(
                    HTTPStatus.BAD_REQUEST,
                    {"error": "validation_failed", "detail": str(exc)},
                )
                return

            enqueue(subject, event)
            self._json_response(
                HTTPStatus.ACCEPTED,
                {
                    "status": "accepted",
                    "subject": subject,
                    "correlation_id": event.correlation_id,
                },
            )

    host = settings.webhook_listen_host
    port = settings.webhook_listen_port
    server = HTTPServer((host, port), WebhookHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    log.info("listening", extra={"host": host, "port": port})

    try:
        while True:
            await asyncio.sleep(3600)
    finally:
        server.shutdown()


def main() -> None:
    asyncio.run(run_ingress())


if __name__ == "__main__":
    main()
