"""The A2A surface: JSON-RPC at the service root.

The only non-RESTful routes in this service, and deliberately so (ADR-J):
A2A is the protocol Google's client SDK speaks, and it is JSON-RPC posted to
the root. It is still documented in OpenAPI under its own tag, because "not
REST" is not a licence for "not documented" (ADR-J D-3).

One thing a reader should not have to discover: **errors come in two
shapes.** `/v1/**` answers RFC 9457 problem documents;
  this surface answers JSON-RPC error objects. A failure *before* the envelope
  is parsed is still an HTTP-level problem document, so a client parses both.
"""

from typing import Annotated
from uuid import uuid4

from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import ValidationError

from app.agent.contracts import ToolContext
from app.api.deps import PrincipalDep, get_a2a_service, get_tool_context
from app.api.openapi import problem_responses
from app.schemas.a2a import (
    INVALID_PARAMS,
    METHOD_NOT_FOUND,
    UNSUPPORTED_OPERATION,
    JsonRpcError,
    JsonRpcFailure,
    JsonRpcRequest,
    StreamParams,
)
from app.services.a2a_service import A2aService

router = APIRouter(tags=["a2a"])

STREAM_METHOD = "message/stream"
CANCEL_METHOD = "tasks/cancel"
EVENT_STREAM = "text/event-stream"

A2aDep = Annotated[A2aService, Depends(get_a2a_service)]
ContextDep = Annotated[ToolContext, Depends(get_tool_context)]


def _failure(request_id: str | int | None, code: int, message: str) -> JSONResponse:
    """Answer a JSON-RPC error with HTTP 200, as the protocol requires."""
    failure = JsonRpcFailure(
        id=request_id, error=JsonRpcError(code=code, message=message)
    )
    return JSONResponse(content=failure.model_dump(mode="json"))


@router.post(
    "/",
    operation_id="call_a2a_method",
    # The body is one envelope for many methods and the answer is either an
    # event stream or a JSON-RPC object, so FastAPI cannot derive a response
    # model from the return annotation. The shapes are documented below.
    response_model=None,
    summary="Call an A2A method (JSON-RPC)",
    description=(
        "The A2A protocol surface. Accepts `message/stream` and answers "
        "`text/event-stream`. **This is JSON-RPC, not REST** — errors are "
        "JSON-RPC error objects with HTTP 200, unlike `/v1/**`, which answers "
        "RFC 9457 problem documents (ADR-J D-3). Requires a bearer token; the "
        "agent card does not. Spec 0010 AC-2, AC-4."
    ),
    responses={
        200: {
            "content": {EVENT_STREAM: {}, "application/json": {}},
            "description": (
                "A stream of task events for `message/stream`, or a JSON-RPC "
                "error object for an unknown or unsupported method."
            ),
        },
        **problem_responses(401, 429, 500),
    },
)
async def call(
    request: Request,
    principal: PrincipalDep,
    service: A2aDep,
    context: ContextDep,
) -> StreamingResponse | JSONResponse:
    """Dispatch one JSON-RPC call to the agent host.

    Args:
        request: The raw request, because JSON-RPC is one envelope for many
            methods and the body cannot be typed by the route.
        principal: The authenticated caller; the turn runs as this subject.
        service: The protocol adapter.
        context: The subject-scoped tool context.

    Returns:
        An event stream for `message/stream`, or a JSON-RPC error object.
    """
    del principal  # resolved so the route is authenticated; the context carries it
    try:
        envelope = JsonRpcRequest.model_validate(await request.json())
    except (ValidationError, ValueError):
        return _failure(None, INVALID_PARAMS, "Malformed JSON-RPC request.")

    if envelope.method == CANCEL_METHOD:
        # ADR-D D-9: the client calls this on every cancellation and nothing
        # implements it. Answering a documented "unsupported" beats a 500.
        return _failure(
            envelope.id, UNSUPPORTED_OPERATION, "tasks/cancel is not supported."
        )
    if envelope.method != STREAM_METHOD:
        return _failure(
            envelope.id, METHOD_NOT_FOUND, f"Unknown method {envelope.method!r}."
        )

    try:
        params = StreamParams.model_validate(envelope.params)
    except ValidationError:
        return _failure(
            envelope.id, INVALID_PARAMS, "Invalid parameters for message/stream."
        )

    return StreamingResponse(
        service.stream(message=params.message, task_id=str(uuid4()), context=context),
        media_type=EVENT_STREAM,
        headers={"Cache-Control": "no-store"},
    )


__all__ = ["router"]
