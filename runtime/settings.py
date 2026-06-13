from pydantic import field_validator
from pydantic_settings import BaseSettings


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
    sonar_host_url: str = ""
    sonar_token: str = ""
    snyk_token: str = ""
    webhook_secret: str = ""
    webhook_listen_host: str = "0.0.0.0"
    webhook_listen_port: int = 8787

    class Config:
        env_file = ".env"
        extra = "ignore"

    @field_validator("database_url")
    @classmethod
    def reject_default_secrets_in_production(cls, value: str, info):
        app_env = info.data.get("app_env", "development")
        if app_env.lower() == "production" and "change_me" in value:
            raise ValueError(
                "DATABASE_URL must not use default credentials in production."
            )
        return value


settings = Settings()
