"""No-op ``ErrorReporter`` used when no telemetry backend is configured.

Call sites never check "is Sentry configured?" — they always report, and
this adapter makes reporting free when there is nowhere to send it.
"""

from collections.abc import Mapping


class NullErrorReporter:
    """Discard everything; keeps the same interface as the real reporters."""

    def capture_exception(self, exc: BaseException) -> None:
        """Ignore the exception."""
        del exc

    def increment(self, metric: str, *, tags: Mapping[str, str] | None = None) -> None:
        """Ignore the metric."""
        del metric, tags


__all__ = ["NullErrorReporter"]
