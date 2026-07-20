from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    environment: str = "development"
    supabase_url: str = ""
    supabase_publishable_key: str = ""
    supabase_secret_key: str = ""

    def require_supabase(self) -> None:
        missing = [
            name
            for name, value in (
                ("SUPABASE_URL", self.supabase_url),
                ("SUPABASE_PUBLISHABLE_KEY", self.supabase_publishable_key),
            )
            if not value.strip()
        ]
        if missing:
            raise RuntimeError(f"Missing configuration: {', '.join(missing)}")

    def require_supabase_secret(self) -> None:
        if not self.supabase_secret_key.strip():
            raise RuntimeError("Missing configuration: SUPABASE_SECRET_KEY")


@lru_cache
def get_settings() -> Settings:
    return Settings()
