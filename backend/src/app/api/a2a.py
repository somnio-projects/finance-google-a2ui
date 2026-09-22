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

from app.agent.contracts import ToolContext
from app.api.a2a_openapi import ENVELOPE_BODY, EVENT_STREAM, TURN_RESPONSE
from app.api.deps import (
    PrincipalDep,
    RequestIdDep,
    get_a2a_service,
    get_surface_action_service,
    get_tool_context,
)
from app.api.feature_gate import require_feature
from app.api.openapi import problem_responses
from app.services.a2a_actions import prepared_prompt
from app.services.a2a_dispatch import message_of, parse
from app.services.a2a_service import A2aService
from app.services.surface_action_service import SurfaceActionService

router = APIRouter(tags=["a2a"])

A2aDep = Annotated[A2aService, Depends(get_a2a_service)]
ActionsDep = Annotated[SurfaceActionService, Depends(get_surface_action_service)]
ContextDep = Annotated[ToolContext, Depends(get_tool_context)]


@router.post(
    "/",
    dependencies=[require_feature("agent.a2a", default=True)],
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
        "agent card does not. The `agent.a2a` flag switches this route off — "
        "404 `feature-disabled` before the body runs. Spec 0010 AC-2, AC-4."
    ),
    responses={
        200: TURN_RESPONSE,
        # 413: the body-limit middleware sees this body like any other.
        # 503: the turn opens a database session through its tool context.
        **problem_responses(401, 404, 413, 429, 500, 503),
    },
    openapi_extra={"requestBody": ENVELOPE_BODY},
)
async def call(
    request: Request,
    principal: PrincipalDep,
    service: A2aDep,
    actions: ActionsDep,
    context: ContextDep,
    request_id: RequestIdDep,
) -> StreamingResponse | JSONResponse:
    """Dispatch one JSON-RPC call to the agent host.

    Args:
        request: The raw request, because JSON-RPC is one envelope for many
            methods and the body cannot be typed by the route.
        principal: The authenticated caller; the turn runs as this subject.
        service: The protocol adapter, which owns the dispatch.
        actions: The surface-action dispatcher, for a `data` part.
        context: The subject-scoped tool context.
        request_id: Correlation id, carried into an audited action's event.

    Returns:
        An event stream for `message/stream`, or a JSON-RPC error body at
        HTTP 200 for anything the adapter refused — including a surface
        action it would not run (spec 0022 AC-4, AC-5, AC-13).
    """
    body = await _decode(request)
    envelope = parse(body)
    if isinstance(envelope, dict):
        return JSONResponse(content=envelope)
    message = message_of(envelope)
    if isinstance(message, dict):
        return JSONResponse(content=message)
    prompt = await prepared_prompt(
        actions,
        principal=principal,
        message=message,
        rpc_id=envelope.id,
        request_id=request_id,
    )
    if isinstance(prompt, dict):
        return JSONResponse(content=prompt)
    return StreamingResponse(
        service.stream(
            message=message, prompt=prompt, task_id=str(uuid4()), context=context
        ),
        media_type=EVENT_STREAM,
        headers={"Cache-Control": "no-store"},
    )


async def _decode(request: Request) -> object:
    """Return the decoded body, or a sentinel the adapter will refuse.

    A body that is not JSON at all is the adapter's problem to report, not a
    transport error — so it is turned into something `parse` rejects rather
    than allowed to raise here.
    """
    try:
        return await request.json()
    except ValueError:
        return None


__all__ = ["router"]
