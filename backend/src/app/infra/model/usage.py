"""Reading Gemini's ``usageMetadata`` off one attempt (spec 0058 AC-1/AC-2).

Split from ``reply.py`` because it answers a different question with a
different failure rule. ``reply.py`` decides what the model *said*, and a body
it cannot read is a failed call. This decides what the attempt *cost*, and a
body it cannot read costs **zero** — usage is telemetry, so a malformed block
must never be the reason a turn fails.

Every count is optional on the wire (a 200 with a blocked prompt carries
``promptTokenCount`` and nothing else; a 429 carries no body worth reading),
and an absent count is zero. ``billed_calls`` is 1 exactly when the provider
reported a ``usageMetadata`` block for the attempt, so retried attempts are
counted when — and only when — Gemini says they were billed (0058 OD-3).
"""

import httpx
from pydantic import BaseModel, ConfigDict, Field, ValidationError

from app.core.model_usage import ZERO_USAGE, TokenUsage


class _UsageMetadata(BaseModel):
    """The five counts of ``usageMetadata``, each optional."""

    model_config = ConfigDict(populate_by_name=True)

    prompt: int = Field(default=0, ge=0, alias="promptTokenCount")
    cached: int = Field(default=0, ge=0, alias="cachedContentTokenCount")
    candidates: int = Field(default=0, ge=0, alias="candidatesTokenCount")
    thoughts: int = Field(default=0, ge=0, alias="thoughtsTokenCount")
    total: int = Field(default=0, ge=0, alias="totalTokenCount")


class _Envelope(BaseModel):
    """The one key of a ``generateContent`` body this module reads."""

    usage: _UsageMetadata | None = Field(default=None, alias="usageMetadata")


def usage_from(payload: object) -> TokenUsage:
    """Return the usage a decoded body reports, zero when it reports none.

    Args:
        payload: A decoded JSON body — any shape, including not an object.

    Returns:
        The counts, with ``billed_calls=1`` when ``usageMetadata`` was present;
        ``ZERO_USAGE`` for a body without one, or one that does not parse.
    """
    try:
        envelope = _Envelope.model_validate(payload)
    except ValidationError:
        return ZERO_USAGE
    if envelope.usage is None:
        return ZERO_USAGE
    return TokenUsage(**envelope.usage.model_dump(), billed_calls=1)


def usage_of(response: httpx.Response) -> TokenUsage:
    """Return the usage one HTTP response reports, whatever its status.

    Args:
        response: The provider's answer to one attempt.

    Returns:
        What the body reports; zero when the body is not JSON at all.
    """
    try:
        payload: object = response.json()
    except ValueError:
        return ZERO_USAGE
    return usage_from(payload)


__all__ = ["usage_from", "usage_of"]
