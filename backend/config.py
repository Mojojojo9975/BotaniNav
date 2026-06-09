# backend/config.py
#
# Single source of truth for all backend configuration.
# Reads from environment variables / .env file.

from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    # ── Server ────────────────────────────────────────────────────────────────
    app_title: str = "BotaniNav API"
    app_version: str = "1.0.0"
    debug: bool = False

    # ── Database ──────────────────────────────────────────────────────────────
    # SQLite for simplicity — swap to PostgreSQL with:
    #   database_url: str = "postgresql+asyncpg://user:pass@host/db"
    database_url: str = "sqlite+aiosqlite:///./botanicnav.db"

    # ── Auth ──────────────────────────────────────────────────────────────────
    # Comma-separated list of valid API keys
    api_keys: str = "dev-key,abc123"

    # ── Google Maps ───────────────────────────────────────────────────────────
    google_maps_api_key: str = ""

    # ── External plant DB (puutarhakanta) ─────────────────────────────────────
    plant_db_base_url: str = "https://puutarhakanta-api.onrender.com"

    # ── Navigation ────────────────────────────────────────────────────────────
    arrival_threshold_metres: float = 5.0
    ws_push_interval_seconds: float = 2.0

    @property
    def api_key_set(self) -> set[str]:
        return {k.strip() for k in self.api_keys.split(",") if k.strip()}

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


@lru_cache
def get_settings() -> Settings:
    return Settings()
