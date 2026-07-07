"""Application configuration.

All settings come from environment variables prefixed APP_ (12-factor).
In Kubernetes these are injected via ConfigMap (non-sensitive) and
Secret (sensitive); locally via a .env file.
"""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "restaurant-api"
    environment: str = "local"
    log_level: str = "INFO"

    # "memory" = in-process sample data (local dev, unit tests).
    # "dynamodb" = real table (cluster).
    repository_backend: str = "memory"

    aws_region: str = "us-east-1"
    dynamodb_table: str = "restaurants"

    model_config = SettingsConfigDict(env_prefix="APP_", env_file=".env", extra="ignore")


@lru_cache
def get_settings() -> Settings:
    """Cached settings instance; cache cleared in tests when overriding."""
    return Settings()
