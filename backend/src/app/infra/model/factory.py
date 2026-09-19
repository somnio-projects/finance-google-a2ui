"""Pick the ``ModelClient`` implementation from settings.

The same contract as ``build_error_reporter``: configuration is read once,
here, and every call site downstream just uses a ``ModelClient``. Nothing in
``app.services`` or ``app.agent`` ever asks whether a key exists.
"""

from app.core.config import Settings
from app.core.protocols import ModelClient
from app.infra.model.gemini_client import GeminiModelClient
from app.infra.model.null_client import NullModelClient


def build_model_client(settings: Settings) -> ModelClient:
    """Return Gemini when a key is configured, otherwise the null client."""
    if settings.gemini_api_key is None:
        return NullModelClient()
    return GeminiModelClient(
        api_key=settings.gemini_api_key,
        model=settings.gemini_model,
        base_url=settings.gemini_base_url,
        timeout_seconds=settings.gemini_timeout_seconds,
        max_attempts=settings.gemini_max_attempts,
    )


__all__ = ["build_model_client"]
