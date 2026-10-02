"""What a v1.0 renderer reads before its first call (ADR-M D-5, D-8).

Two documents, both derived rather than written: the agent card from the v0.9
card the composition root already built (same name, release and skills — one
tool registry, two cards), and the catalog from the projection registry, the
same render ``make catalog`` checks in.
"""

from collections.abc import Sequence
from typing import Final

from app.presentation.a2ui_v1.catalog import catalog_document
from app.presentation.registry import Projection
from app.schemas.a2ui_v1_card import V1AgentCard
from app.schemas.agent_card import AgentCard

#: Where a v1.0 renderer posts, relative to ``PUBLIC_BASE_URL``.
RPC_PATH: Final[str] = "/a2ui/v1/a2a"


def build_v1_card(card: AgentCard) -> V1AgentCard:
    """Return the v1.0 card for the agent the v0.9 ``card`` describes.

    Args:
        card: The v0.9 card, built once at startup from settings.

    Returns:
        The same agent, advertised on ``/a2ui/v1/a2a`` with protocol ``1.0``
        and the A2UI v1.0 extension naming the finance catalog.
    """
    return V1AgentCard(
        name=card.name,
        description=card.description,
        url=card.url.rstrip("/") + RPC_PATH,
        version=card.version,
        skills=card.skills,
    )


def v1_catalog(projections: Sequence[Projection]) -> str:
    """Return the catalog document, byte for byte the checked-in file.

    Args:
        projections: The registry's contents, ordered by id.
    """
    return catalog_document(projections)


__all__ = ["RPC_PATH", "build_v1_card", "v1_catalog"]
