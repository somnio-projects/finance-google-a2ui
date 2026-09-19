"""How `Settings` reads list-valued environment variables, and what it refuses.

Split out of `config.py` under the 150-line budget along the seam that was
already there: `config.py` declares **what** the service is configured with,
this declares **how** a raw environment string becomes one of those values and
which values are rejected outright.

The mixin is a plain class, not a model: pydantic collects validators from the
bases, so `Settings` gains these by inheriting, and nothing here can add a
field by accident.
"""

from pydantic import field_validator

WILDCARD = "*"


class CsvParsing:
    """Parse comma-separated environment variables into lists."""

    @field_validator(
        "cors_allowed_origins",
        "trusted_hosts",
        "feature_flags_force_disabled",
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


__all__ = ["WILDCARD", "CsvParsing"]
