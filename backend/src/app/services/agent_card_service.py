"""Build the agent card from settings and the tool registry (ADR-D D-7).

The skills are generated from the registered tools for the same reason the
prompt catalogues are (ADR-K D-14): a hand-written skill list advertises
capabilities the agent may no longer have, and a client chooses an agent by
reading exactly this.
"""

from app.agent.registry import ToolRegistry
from app.core.config import Settings
from app.schemas.agent_card import AgentCard, AgentSkill

DESCRIPTION = (
    "Answers questions about a simulated investment portfolio by composing "
    "interface from a fixed catalog rather than by writing prose. Every "
    "figure comes from a deterministic tool; the model never computes one."
)
SKILL_TAGS = ("finance", "portfolio")


def build_agent_card(
    settings: Settings, tools: ToolRegistry, *, version: str
) -> AgentCard:
    """Return the card a client reads before it holds a token.

    Args:
        settings: Where `public_base_url` and the app name come from.
        tools: The registry whose tools become the advertised skills.
        version: The running release identifier.

    Returns:
        The card. Its `url` is the **public** base URL, never the bind
        address — the sample advertised `http://0.0.0.0:8080`, which no client
        can reach, and ADR-D D-7 exists because of it.
    """
    return AgentCard(
        name=settings.app_name,
        description=DESCRIPTION,
        url=settings.public_base_url,
        version=version,
        skills=tuple(
            AgentSkill(
                id=spec.name,
                name=spec.name.replace("_", " "),
                description=spec.description,
                tags=SKILL_TAGS,
            )
            for spec in tools.specs()
        ),
    )


__all__ = ["DESCRIPTION", "build_agent_card"]
