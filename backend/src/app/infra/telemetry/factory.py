"""Pick the ``ErrorReporter`` implementation from settings."""

from app.core.config import Settings
from app.core.protocols import ErrorReporter
from app.infra.telemetry.null_reporter import NullErrorReporter
from app.infra.telemetry.sentry_reporter import SentryErrorReporter


def build_error_reporter(settings: Settings, *, release: str) -> ErrorReporter:
    """Return Sentry when a DSN is configured, otherwise the null reporter."""
    if settings.sentry_dsn is None:
        return NullErrorReporter()
    return SentryErrorReporter(
        dsn=settings.sentry_dsn.get_secret_value(),
        environment=settings.environment,
        release=release,
        traces_sample_rate=settings.sentry_traces_sample_rate,
    )


__all__ = ["build_error_reporter"]
