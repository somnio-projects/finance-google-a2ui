"""Structured logging configuration (structlog → JSON).

Configured exactly once from the composition root. Library modules only call
``get_logger``. Tokens, passwords and PII are never logged — the
``redact_sensitive`` processor drops known secret keys defensively.
"""

import logging
from collections.abc import MutableMapping
from typing import Any

import structlog

SENSITIVE_KEYS: frozenset[str] = frozenset(
    {"authorization", "token", "password", "secret", "cookie", "api_key"}
)


def redact_sensitive(
    _logger: object, _method: str, event_dict: MutableMapping[str, Any]
) -> MutableMapping[str, Any]:
    """Replace values of well-known secret keys with a placeholder."""
    for key in list(event_dict):
        if key.lower() in SENSITIVE_KEYS:
            event_dict[key] = "[REDACTED]"
    return event_dict


def configure_logging(level: str) -> None:
    """Configure structlog + stdlib logging for JSON output.

    Args:
        level: Root log level name (``INFO``, ``DEBUG``...).
    """
    logging.basicConfig(level=level, format="%(message)s", force=True)
    structlog.configure(
        processors=[
            structlog.contextvars.merge_contextvars,
            structlog.processors.add_log_level,
            structlog.processors.TimeStamper(fmt="iso", utc=True),
            redact_sensitive,
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer(),
        ],
        wrapper_class=structlog.make_filtering_bound_logger(
            logging.getLevelNamesMapping()[level]
        ),
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=False,
    )


def get_logger(name: str) -> structlog.stdlib.BoundLogger:
    """Return a bound logger for ``name`` without configuring anything."""
    return structlog.get_logger(name)


__all__ = ["SENSITIVE_KEYS", "configure_logging", "get_logger", "redact_sensitive"]
