"""Pick the ``ModelClient`` implementation from settings.

The same contract as ``build_error_reporter``: configuration is read once,
here, and every call site downstream just uses a ``ModelClient``. Nothing in
``app.services`` or ``app.agent`` ever asks whether a key exists.

Without a key the stack runs ``ScriptedModelClient`` (spec 0033): the demo's
flows replay from a table of prompts, and anything else is answered with the
sentence the null client always gave. A configured key switches the script
off entirely — there is no mixed mode (0033 OD-4).
"""

from app.core.config import Settings
from app.core.protocols import ModelClient
from app.infra.model.gemini_client import GeminiModelClient
from app.infra.model.scripted_client import ScriptedModelClient


def build_model_client(settings: Settings) -> ModelClient:
    """Return Gemini when a key is configured, otherwise the scripted demo."""
    if settings.gemini_api_key is None:
        return ScriptedModelClient()
    return GeminiModelClient(
        api_key=settings.gemini_api_key,
        model=settings.gemini_model,
        base_url=settings.gemini_base_url,
        timeout_seconds=settings.gemini_timeout_seconds,
        max_attempts=settings.gemini_max_attempts,
    )


__all__ = ["build_model_client"]
