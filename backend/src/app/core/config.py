"""Application settings — 12-factor configuration loaded once at startup.

Every required variable has no default, so a missing value fails fast with a
``ValidationError`` before the first request is served (SOC 2 CC6.1: no
implicit insecure defaults).
"""

from functools import lru_cache
from typing import Annotated, Literal

from pydantic import Field, PostgresDsn, SecretStr, field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

Environment = Literal["local", "test", "staging", "production"]
AuthProviderName = Literal["jwt", "oidc"]
# ``NoDecode``: pydantic-settings would otherwise JSON-decode list fields from
# the environment; we accept plain comma-separated values (see ``_split_csv``).
CsvList = Annotated[list[str], NoDecode]


class Settings(BaseSettings):
    """Typed view over the process environment.

    Attributes are grouped by concern; see ``.env.example`` for documentation
    of each variable and ``docs/SECURITY.md`` for why the defaults are strict.
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        frozen=True,
    )

    # --- runtime -----------------------------------------------------------
    app_name: str = "finance-a2ui-backend"
    environment: Environment = "local"
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR"] = "INFO"
    public_base_url: str = Field(
        default="http://localhost:8000",
        description="Advertised origin; never derived from the bind address.",
    )

    # --- database ----------------------------------------------------------
    database_url: PostgresDsn
    database_pool_size: int = Field(default=5, ge=1, le=50)
    database_echo: bool = False

    # --- http hardening ----------------------------------------------------
    cors_allowed_origins: CsvList = Field(default_factory=list)
    trusted_hosts: CsvList = Field(default_factory=lambda: ["*"])
    max_request_body_bytes: int = Field(default=1_048_576, ge=1_024)
    rate_limit_per_minute: int = Field(default=120, ge=1)

    # --- authentication ----------------------------------------------------
    auth_provider: AuthProviderName = "jwt"
    auth_audience: str
    auth_issuer: str
    auth_jwt_secret: SecretStr | None = None
    auth_oidc_jwks_url: str | None = None
    auth_leeway_seconds: int = Field(default=30, ge=0, le=300)

    # --- observability -----------------------------------------------------
    sentry_dsn: SecretStr | None = None
    sentry_traces_sample_rate: float = Field(default=0.0, ge=0.0, le=1.0)

    @field_validator("cors_allowed_origins", "trusted_hosts", mode="before")
    @classmethod
    def _split_csv(cls, value: object) -> object:
        """Accept comma-separated strings from the environment."""
        if isinstance(value, str):
            return [item.strip() for item in value.split(",") if item.strip()]
        return value

    @property
    def is_production(self) -> bool:
        """Return True when running with production hardening."""
        return self.environment == "production"

    @property
    def database_url_str(self) -> str:
        """Return the DSN as a plain string for the SQLAlchemy engine."""
        return str(self.database_url)


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Build the settings once per process (cached factory)."""
    return Settings()  # pyright: ignore[reportCallIssue] - env-driven


__all__ = ["AuthProviderName", "CsvList", "Environment", "Settings", "get_settings"]
