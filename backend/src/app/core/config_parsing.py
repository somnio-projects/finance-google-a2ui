"""How `Settings` reads list-valued environment variables, and what it refuses.

Split out of `config.py` under the 150-line budget along the seam that was
already there: `config.py` declares **what** the service is configured with,
this declares **how** a raw environment string becomes one of those values and
which values are rejected outright.

The mixin is a plain class, not a model: pydantic collects validators from the
bases, so `Settings` gains these by inheriting, and nothing here can add a
field by accident.
"""

from typing import Annotated

from pydantic import field_validator
from pydantic_settings import NoDecode

#: A comma-separated environment value, decoded by `CsvParsing` rather than
#: by pydantic's JSON decoder. Here rather than in `config.py` so the auth
#: mixin can use it without importing the model that composes it.
CsvList = Annotated[list[str], NoDecode]

WILDCARD = "*"


class CsvParsing:
    """Parse comma-separated environment variables into lists."""

    @field_validator(
        "cors_allowed_origins",
        "trusted_hosts",
        "feature_flags_force_disabled",
        "auth_bootstrap_admins",
        mode="before",
    )
    @classmethod
    def _split_csv(cls, value: object) -> object:
        """Accept comma-separated strings from the environment."""
        if isinstance(value, str):
            return [item.strip() for item in value.split(",") if item.strip()]
        return value

    @field_validator("cors_allowed_origins", mode="after")
    @classmethod
    def _no_wildcard_origin(cls, value: list[str]) -> list[str]:
        """Reject ``*``: CORS runs with credentials; a wildcard is an open door."""
        if WILDCARD in value:
            msg = "CORS_ALLOWED_ORIGINS must list explicit origins, never '*'"
            raise ValueError(msg)
        return value


class OptionalCredentialParsing:
    """Treat an empty optional credential as absent rather than as a value.

    Every field listed here is documented as *unset means fall back*: no key
    yields ``NullModelClient``, no DSN yields the null reporter, and the
    factories branch on ``is None``. But a deployment does not hand these over
    as "absent" — it mounts them, and a secret with nothing in it arrives as
    ``""``. That is not ``None``, so the factories take the configured path
    with an empty credential: ``sentry_sdk.init(dsn="")``, a Gemini client
    holding no key.

    Nothing downstream can recover from that, because by then the distinction
    is gone. So it is collapsed at the boundary, where "the operator left this
    blank" still means what it says. Found while first deploying `dev`, where
    Secret Manager holds both secrets and neither has a value yet.
    """

    @field_validator(
        "auth_jwt_secret",
        "auth_oidc_jwks_url",
        "gemini_api_key",
        "sentry_dsn",
        mode="before",
    )
    @classmethod
    def _blank_optional_is_unset(cls, value: object) -> object:
        """Return ``None`` for a blank string, otherwise the value unchanged."""
        if isinstance(value, str) and not value.strip():
            return None
        return value


__all__ = ["WILDCARD", "CsvParsing", "OptionalCredentialParsing"]
