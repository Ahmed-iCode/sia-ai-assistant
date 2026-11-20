import json
from typing import List, Union
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    PROJECT_NAME: str = "AI Task Assistant API"
    ENVIRONMENT: str = "development"
    API_V1_STR: str = "/api/v1"

    # Security
    SECRET_KEY: str = "ai_task_assistant_super_secret_jwt_key_at_least_32_chars_long"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days

    # Database
    DATABASE_URL: str = "sqlite:///./task_assistant.db"

    # CORS
    BACKEND_CORS_ORIGINS: Union[List[str], str] = ["*"]
    CORS_ORIGINS: Union[List[str], str] = ""

    # Scheduler & Timezone
    SCHEDULER_INTERVAL_SECONDS: int = 60
    DEFAULT_TIMEZONE: str = "Africa/Cairo"

    # AI & Audio Services
    GEMINI_API_KEY: str = ""
    GROQ_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-3.0-flash"
    WHISPER_MODEL: str = "whisper-large-v3-turbo"

    @field_validator("BACKEND_CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> List[str]:
        if isinstance(v, str):
            if not v.startswith("["):
                return [i.strip() for i in v.split(",") if i.strip()]
            try:
                parsed = json.loads(v)
                if isinstance(parsed, list):
                    return [str(item) for item in parsed]
            except Exception:
                pass
            return [v]
        return v

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_custom_cors_origins(cls, v: Union[str, List[str], None]) -> List[str]:
        if not v:
            return []
        if isinstance(v, str):
            if not v.startswith("["):
                return [i.strip() for i in v.split(",") if i.strip()]
            try:
                parsed = json.loads(v)
                if isinstance(parsed, list):
                    return [str(item) for item in parsed]
            except Exception:
                pass
            return [v]
        return v

    @property
    def merged_cors_origins(self) -> List[str]:
        origins = set()
        if isinstance(self.BACKEND_CORS_ORIGINS, list):
            origins.update(self.BACKEND_CORS_ORIGINS)
        elif isinstance(self.BACKEND_CORS_ORIGINS, str) and self.BACKEND_CORS_ORIGINS:
            origins.update([i.strip() for i in self.BACKEND_CORS_ORIGINS.split(",") if i.strip()])

        if isinstance(self.CORS_ORIGINS, list):
            origins.update(self.CORS_ORIGINS)
        elif isinstance(self.CORS_ORIGINS, str) and self.CORS_ORIGINS:
            origins.update([i.strip() for i in self.CORS_ORIGINS.split(",") if i.strip()])

        result = [o for o in origins if o]
        return result if result else ["*"]


settings = Settings()
