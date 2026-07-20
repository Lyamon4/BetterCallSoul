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
    gemini_api_key: str = ""
    gemini_embedding_model: str = "gemini-embedding-2"
    gemini_embedding_dimensions: int = 768

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

    def require_gemini_embeddings(self) -> None:
        if not self.gemini_api_key.strip():
            raise RuntimeError("Missing configuration: GEMINI_API_KEY")
        if self.gemini_embedding_dimensions != 768:
            raise RuntimeError("Gemini embedding dimensions must be 768.")


@lru_cache
def get_settings() -> Settings:
    return Settings()
