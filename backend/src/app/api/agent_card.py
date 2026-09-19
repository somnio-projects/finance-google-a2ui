"""The agent card: how a client discovers this agent before it has a token.

Separate from the JSON-RPC controller beside it because it answers a different
question — *what is this agent* rather than *do this* — and because it is the
one route here that is unauthenticated.
"""

from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.deps import get_agent_card
from app.api.openapi import problem_responses
from app.schemas.agent_card import AgentCard

router = APIRouter(tags=["a2a"])

CardDep = Annotated[AgentCard, Depends(get_agent_card)]


@router.get(
    "/.well-known/agent-card.json",
    response_model=AgentCard,
    response_model_by_alias=True,
    operation_id="read_agent_card",
    summary="Describe this agent to a client",
    description=(
        "The bootstrap document: what this agent is, where to post to, which "
        "A2UI version it speaks and what it can be asked for. "
        "**Unauthenticated by contract** — a client cannot hold a token before "
        "it has read this. Spec 0010 AC-1, OD-1."
    ),
    responses=problem_responses(429, 500),
)
def agent_card(card: CardDep) -> AgentCard:
    """Return the agent card, built once at startup from settings."""
    return card


__all__ = ["router"]
