from pydantic import field_validator
from pydantic_settings import BaseSettings

from runtime.secret_loader import apply_runtime_secrets

apply_runtime_secrets()


class Settings(BaseSettings):
    app_env: str = "development"
    project_name: str = "inova-devsecops-agentic-platform"
    tenant_id: str = "inova-ti"
    nats_url: str = "nats://localhost:4222"
    nats_stream: str = "INOVA_TASKS"
    nats_consumer_prefix: str = "inova"
    database_url: str = (
        "postgresql://inova:inova_dev_password_change_me@localhost:5432/inova_platform"
    )
    openrouter_api_key: str = ""
    openrouter_model: str = "deepseek/deepseek-v4-pro"
    opencode_container: str = "opencode"
    datadog_api_key: str = ""
    datadog_site: str = "datadoghq.com"
    sonar_host_url: str = ""
    sonar_token: str = ""
    snyk_token: str = ""
    webhook_secret: str = ""
    webhook_listen_host: str = "127.0.0.1"
    webhook_listen_port: int = 8787
    worker_adapter_mode: str = "auto"
    observability_datadog_enabled: bool = False
    grafana_url: str = ""
    grafana_api_key: str = ""
    grafana_admin_password: str = ""
    vault_addr: str = ""
    vault_token: str = ""
    vault_token_file: str = ""
    vault_kv_mount: str = "secret"
    vault_secret_path: str = "inova/runtime"
    nats_tls_ca: str = ""
    nats_tls_cert: str = ""
    nats_tls_key: str = ""
    postgres_sslmode: str = "disable"

    class Config:
        env_file = ".env"
        extra = "ignore"

    @field_validator("database_url")
    @classmethod
    def reject_default_secrets_in_production(cls, value: str, info):
        app_env = info.data.get("app_env", "development")
        if (
            app_env.lower() in {"production", "staging"}
            and "change_me" in value.lower()
        ):
            raise ValueError(
                "DATABASE_URL must not use default credentials in staging/production."
            )
        if app_env.lower() == "production" and "sslmode=require" not in value.lower():
            raise ValueError("DATABASE_URL must include sslmode=require in production.")
        return value


settings = Settings()
