"""Decide what one A2A call is asking for, or why it cannot be answered.

Split from the streaming half because it answers a different question — *what
did the client ask* rather than *what happened while we answered* — and
because ADR-J D-2 makes this whole package the protocol adapter, so the
controller must not carry the branching (`.claude/rules/backend/architecture.md`).

**Every error message here is a fixed string.** The caller controls `method`,
and `repr()` of 64 control characters is longer than the error field's own
bound — so interpolating it raised a `ValidationError` inside the very helper
that exists to avoid a transport error, and the surface answered **500**. The
error *code* identifies the fault; echoing the caller's input back adds
nothing and costs correctness.
"""

from typing import Final

from pydantic import ValidationError

from app.schemas.a2a import (
    INVALID_PARAMS,
    METHOD_NOT_FOUND,
    UNSUPPORTED_OPERATION,
    ClientMessage,
    JsonRpcError,
    JsonRpcFailure,
    JsonRpcRequest,
    StreamParams,
)

STREAM_METHOD: Final[str] = "message/stream"
CANCEL_METHOD: Final[str] = "tasks/cancel"

MALFORMED: Final[str] = "Malformed JSON-RPC request."
UNKNOWN_METHOD: Final[str] = "Unknown method."
CANCEL_UNSUPPORTED: Final[str] = "tasks/cancel is not supported."
BAD_PARAMS: Final[str] = "Invalid parameters for message/stream."


def failure(request_id: str | int | None, code: int, message: str) -> dict[str, object]:
    """Build a JSON-RPC error response body.

    Args:
        request_id: The id to echo, so the client can correlate.
        code: A JSON-RPC error code.
        message: One of this module's fixed strings — never caller input.

    Returns:
        The body to answer with, at HTTP 200: JSON-RPC reports faults inside
        the envelope, not through the transport.
    """
    return JsonRpcFailure(
        id=request_id, error=JsonRpcError(code=code, message=message)
    ).model_dump(mode="json")


def parse(body: object) -> JsonRpcRequest | dict[str, object]:
    """Validate one envelope, or return the failure body to answer with.

    Args:
        body: The decoded request body, of whatever shape arrived.

    Returns:
        The envelope when it is well formed, otherwise the JSON-RPC error
        body. Returning rather than raising keeps the controller free of
        branching on exception types.
    """
    try:
        return JsonRpcRequest.model_validate(body)
    except ValidationError:
        return failure(None, INVALID_PARAMS, MALFORMED)


def message_of(envelope: JsonRpcRequest) -> ClientMessage | dict[str, object]:
    """Return the message to run, or the failure body for this method.

    Args:
        envelope: A validated JSON-RPC envelope.

    Returns:
        The client's message when the method is `message/stream` and its
        parameters validate, otherwise the JSON-RPC error body.
    """
    if envelope.method == CANCEL_METHOD:
        # ADR-D D-9 leaves this unowned: the client calls it on every
        # cancellation and nothing implements it, so it used to be a 500.
        return failure(envelope.id, UNSUPPORTED_OPERATION, CANCEL_UNSUPPORTED)
    if envelope.method != STREAM_METHOD:
        return failure(envelope.id, METHOD_NOT_FOUND, UNKNOWN_METHOD)
    try:
        return StreamParams.model_validate(envelope.params).message
    except ValidationError:
        return failure(envelope.id, INVALID_PARAMS, BAD_PARAMS)


__all__ = [
    "BAD_PARAMS",
    "CANCEL_METHOD",
    "CANCEL_UNSUPPORTED",
    "MALFORMED",
    "STREAM_METHOD",
    "UNKNOWN_METHOD",
    "failure",
    "message_of",
    "parse",
]
