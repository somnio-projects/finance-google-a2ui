"""``POST /a2ui/v1/a2a`` — the agent, speaking A2UI v1.0 (ADR-M D-2).

JSON-RPC like ``POST /`` and for the same reason (ADR-J): A2A is Google's
protocol, not a resource. Same bearer auth, same ``agent.a2a`` kill switch,
same two error shapes — RFC 9457 before the envelope is parsed, JSON-RPC
error objects inside it. The v0.9 route beside it is untouched.
"""

from typing import Annotated
from uuid import uuid4

from fastapi import APIRouter, Depends, Request
from fastapi.responses import JSONResponse, StreamingResponse

from app.agent.contracts import ToolContext
from app.api.a2ui_v1.openapi_shapes import ENVELOPE_BODY, EVENT_STREAM, TURN_RESPONSE
from app.api.deps import PrincipalDep, RequestIdDep, get_tool_context
from app.api.deps.a2ui_v1 import get_a2ui_v1_service
from app.api.feature_gate import require_feature
from app.api.openapi import problem_responses
from app.services.a2ui_v1_service import A2uiV1Service

router = APIRouter(tags=["a2a"])

ServiceDep = Annotated[A2uiV1Service, Depends(get_a2ui_v1_service)]
ContextDep = Annotated[ToolContext, Depends(get_tool_context)]


@router.post(
    "/a2a",
    dependencies=[require_feature("agent.a2a", default=True)],
    operation_id="call_a2ui_v1_method",
    response_model=None,
    summary="Call an A2A method, answered in A2UI v1.0",
    description=(
        "The A2UI v1.0 agent surface (ADR-M, spec 0053). Accepts "
        "`message/stream` and answers `text/event-stream`: a text part runs a "
        "turn whose surfaces arrive as `createSurface` data parts; a data part "
        "holding `callAgentFunction(renderView)` re-renders one component "
        "**without the model**; a data part holding `action` runs the action's "
        "composed turn. `message.metadata.a2uiRendererCapabilities` must list "
        "the finance catalog, or the call is a JSON-RPC error naming it. "
        "**JSON-RPC, not REST**: refusals are HTTP 200 with an error object. "
        "Requires a bearer token; `agent.a2a` switches it off with a 404."
    ),
    responses={
        200: TURN_RESPONSE,
        **problem_responses(401, 404, 413, 429, 500, 503),
    },
    openapi_extra={"requestBody": ENVELOPE_BODY},
)
async def call_v1(
    request: Request,
    principal: PrincipalDep,
    service: ServiceDep,
    context: ContextDep,
    request_id: RequestIdDep,
) -> StreamingResponse | JSONResponse:
    """Answer one JSON-RPC call on the v1.0 wire.

    Args:
        request: The raw request; one envelope serves many methods.
        principal: The authenticated caller.
        service: The v1.0 protocol adapter, which owns every decision.
        context: The subject-scoped tool context.
        request_id: Correlation id, for an audited action's event.

    Returns:
        The event stream, or a JSON-RPC error body at HTTP 200.
    """
    outcome = await service.call(
        await _decode(request),
        principal=principal,
        context=context,
        task_id=str(uuid4()),
        request_id=request_id,
    )
    if isinstance(outcome, dict):
        return JSONResponse(content=outcome)
    return StreamingResponse(
        outcome, media_type=EVENT_STREAM, headers={"Cache-Control": "no-store"}
    )


async def _decode(request: Request) -> object:
    """Return the decoded body, or ``None`` for the adapter to refuse."""
    try:
        return await request.json()
    except ValueError:
        return None


__all__ = ["router"]
