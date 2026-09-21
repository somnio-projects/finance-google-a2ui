"""Reading Gemini's ``generateContent`` response (spec 0006 §3.4, GGU-88).

Split out of ``payload.py`` when the response half grew something of its own
to carry. The two now answer different questions: this module decides *what
the provider said*, while ``payload.py`` decides *what we say next*.

**Gemini 3 attaches a ``thoughtSignature`` to every ``functionCall``**, and
the next call is refused without it:

    Function call is missing a thought_signature in functionCall parts. This
    is required for tools to work correctly.

The signature is opaque — we never read it, never shorten it and never
generate one. It is lifted off the part here into ``ToolCall.provider_state``
and splatted back beside the call by ``payload.py``, so the round trip is
verbatim and neither end has to understand it. A signature that were dropped
would end the turn at a 400 on the *second* model call, after the tool has
already run: GGU-88.

The body is parsed into pydantic models before anything reads it, so a body
that is merely *JSON* but not a Gemini reply fails here, loudly and early.
"""

from typing import Any, Final

from pydantic import BaseModel, ConfigDict, Field

from app.core.model import ModelReply, ToolCall

#: The provider's own key for the per-call signature. It is written exactly
#: as received, under the name it was received: the echo is a copy, not a
#: translation.
THOUGHT_SIGNATURE: Final[str] = "thoughtSignature"


class _FunctionCall(BaseModel):
    """A ``functionCall`` part of a Gemini candidate."""

    model_config = ConfigDict(populate_by_name=True)

    name: str = Field(min_length=1)
    args: dict[str, Any] = Field(default_factory=dict)


class _Part(BaseModel):
    """One part of a candidate's content: prose, a call, or both.

    ``thoughtSignature`` sits **beside** ``functionCall`` on the part, not
    inside it, which is why it is modelled here and not on ``_FunctionCall``.
    """

    model_config = ConfigDict(populate_by_name=True)

    text: str | None = None
    function_call: _FunctionCall | None = Field(default=None, alias="functionCall")
    thought_signature: str | None = Field(default=None, alias=THOUGHT_SIGNATURE)


class _Content(BaseModel):
    """The content block of a candidate."""

    parts: list[_Part] = Field(default_factory=list)


class _Candidate(BaseModel):
    """One candidate answer."""

    content: _Content = Field(default_factory=_Content)


class GeminiResponse(BaseModel):
    """The subset of ``generateContent``'s response this adapter reads."""

    candidates: list[_Candidate] = Field(default_factory=list)


def _provider_state(part: _Part) -> dict[str, object]:
    """Keep whatever the provider attached to a call, for the echo back.

    Args:
        part: The candidate part carrying the call.

    Returns:
        The opaque state to round-trip, empty when the provider sent none —
        a model that does not use signatures stays unaffected.
    """
    if part.thought_signature is None:
        return {}
    return {THOUGHT_SIGNATURE: part.thought_signature}


def from_response(payload: object) -> ModelReply:
    """Parse a ``generateContent`` response into a ``ModelReply``.

    Args:
        payload: The decoded JSON body.

    Returns:
        The assistant's text and the tool calls it asked for, each carrying
        the provider state that has to travel back with it (GGU-88).

    Raises:
        ValueError: When the body is not a Gemini reply, or carries no
            candidate. ``pydantic.ValidationError`` is a ``ValueError``, so one
            ``except`` in the client covers both.
    """
    parsed = GeminiResponse.model_validate(payload)
    if not parsed.candidates:
        msg = "response carried no candidate"
        raise ValueError(msg)
    parts = parsed.candidates[0].content.parts
    text = "".join(part.text for part in parts if part.text)
    calls = tuple(
        ToolCall(
            call_id=f"{index}-{part.function_call.name}",
            name=part.function_call.name,
            arguments=part.function_call.args,
            provider_state=_provider_state(part),
        )
        for index, part in enumerate(parts)
        if part.function_call is not None
    )
    return ModelReply(text=text, tool_calls=calls)


__all__ = ["THOUGHT_SIGNATURE", "GeminiResponse", "from_response"]
