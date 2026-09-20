"""Application settings — 12-factor configuration loaded once at startup.

Every required variable has no default, so a missing value fails fast with a
``ValidationError`` before the first request is served (SOC 2 CC6.1: no
implicit insecure defaults). Variables are documented in ``env.example``.
"""

from datetime import timedelta
from functools import lru_cache
from typing import Annotated, Literal

from pydantic import Field, PostgresDsn, SecretStr, model_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict

from app.core.config_parsing import WILDCARD, CsvParsing, OptionalCredentialParsing

# Must stay in step with `infra/variables.tf`'s `environment` validation: that
# list is what a deployment can be called, this is what the process will accept
# being called, and a name in one and not the other is a container that dies at
# startup on a `ValidationError` — which is how `dev` was found, after the
# environment existed. `infra/scripts/tests/test_dev_environment.sh` now
# compares the two, because neither `terraform validate` nor `make gate` can:
# each side is internally consistent, and nothing was reading both.
# `local` and `test` are extra here on purpose — they never reach Terraform.
Environment = Literal["local", "test", "dev", "staging", "production"]
AuthProviderName = Literal["jwt", "oidc"]
# ``NoDecode``: pydantic-settings would otherwise JSON-decode list fields from
# the environment; we accept plain comma-separated values
# (see ``app.core.config_parsing``).
CsvList = Annotated[list[str], NoDecode]


class Settings(CsvParsing, OptionalCredentialParsing, BaseSettings):
    """Typed view over the process environment.

    Attributes are grouped by concern; see ``env.example`` for documentation
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
    app_release: str = Field(
        default="",
        max_length=128,
        description=(
            "Release identifier injected by the delivery pipeline "
            "(`<version>+<short sha>`). Blank locally: the packaged version is "
            "reported instead (spec 0007 AC-5)."
        ),
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

    # --- feature flags (spec 0002) ----------------------------------------
    feature_flags_cache_ttl_seconds: int = Field(default=15, ge=0, le=3600)
    feature_flags_force_disabled: CsvList = Field(default_factory=list)

    # --- authentication ----------------------------------------------------
    auth_provider: AuthProviderName = "jwt"
    auth_audience: str
    auth_issuer: str
    auth_jwt_secret: SecretStr | None = None
    auth_oidc_jwks_url: str | None = None
    auth_leeway_seconds: int = Field(default=30, ge=0, le=300)
    # None = decide by environment (required in production, optional elsewhere)
    auth_admin_require_mfa: bool | None = None

    # --- agent host (spec 0006) -------------------------------------------
    # Unset key = NullModelClient, exactly as an unset SENTRY_DSN means the
    # null reporter: call sites never branch on configuration.
    gemini_api_key: SecretStr | None = None
    gemini_model: str = Field(default="gemini-3.8-flash", min_length=1, max_length=64)
    gemini_base_url: str = Field(
        default="https://generativelanguage.googleapis.com/v1beta",
        min_length=1,
        max_length=255,
    )
    gemini_timeout_seconds: float = Field(default=20.0, ge=1.0, le=120.0)
    gemini_max_attempts: int = Field(default=3, ge=1, le=5)
    agent_max_tool_iterations: int = Field(default=4, ge=1, le=10)

    # --- data retention (docs/compliance/DATA_RETENTION.md) --------------
    audit_retention_days: int = Field(default=400, ge=30, le=3650)

    # --- observability -----------------------------------------------------
    sentry_dsn: SecretStr | None = None
    sentry_traces_sample_rate: float = Field(default=0.0, ge=0.0, le=1.0)

    @model_validator(mode="after")
    def _production_requires_explicit_hosts(self) -> "Settings":
        """In production the Host allow-list must be real, not ``*``."""
        if self.environment == "production" and WILDCARD in self.trusted_hosts:
            msg = "TRUSTED_HOSTS must be an explicit list when ENVIRONMENT=production"
            raise ValueError(msg)
        return self

    @property
    def audit_retention(self) -> timedelta:
        """``audit_retention_days`` as a ``timedelta``."""
        return timedelta(days=self.audit_retention_days)

    @property
    def admin_mfa_required(self) -> bool:
        """Whether ``admin``-scoped operations must present an MFA ``amr``."""
        if self.auth_admin_require_mfa is None:
            return self.is_production
        return self.auth_admin_require_mfa

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
