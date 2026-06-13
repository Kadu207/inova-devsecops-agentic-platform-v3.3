import hashlib
import hmac

from workers.webhook_ingress.main import _verify_signature


def test_verify_signature_accepts_valid_hmac(monkeypatch):
    monkeypatch.setattr(
        "workers.webhook_ingress.main.settings.webhook_secret", "test-secret"
    )
    body = b'{"subject":"task.audit.requested","payload":{}}'
    digest = hmac.new(b"test-secret", body, hashlib.sha256).hexdigest()
    assert _verify_signature(body, f"sha256={digest}")


def test_verify_signature_rejects_invalid(monkeypatch):
    monkeypatch.setattr(
        "workers.webhook_ingress.main.settings.webhook_secret", "test-secret"
    )
    body = b'{"subject":"task.audit.requested"}'
    assert not _verify_signature(body, "sha256=deadbeef")


def test_verify_signature_allows_dev_without_secret(monkeypatch):
    monkeypatch.setattr("workers.webhook_ingress.main.settings.webhook_secret", "")
    monkeypatch.setattr("workers.webhook_ingress.main.settings.app_env", "development")
    assert _verify_signature(b"{}", None)
