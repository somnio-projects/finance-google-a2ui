"""Build the system prompt from the two registries (GGU-14).

Neither registry may reach the other: ``app.agent`` must not import
``app.presentation`` (spec 0006 AC-14, asserted over the parsed source). This
service is where they meet, because a service may import both.

**Nothing here is hand-written catalogue text.** The tools come from the tool
registry and the views from the projection registry (ADR-K D-14), so a tool or
a view that ships without reaching the model is impossible: registering it is
what teaches the model about it.
"""

from collections.abc import Sequence

from app.agent.prompt import compose
from app.agent.registry import ToolRegistry
from app.core.model import ToolSpec
from app.presentation.prompt import prompt_fragment
from app.presentation.registry import Projection


def tool_catalog(specs: Sequence[ToolSpec]) -> str:
    """Render the registered tools as the lines the model chooses from.

    Args:
        specs: Every registered tool's specification.

    Returns:
        One line per tool — its name and what it answers. The argument schema
        is not repeated here: the model receives it through the tool-calling
        API itself, and stating it twice invites the two copies to disagree.
    """
    return "\n".join(f"- {spec.name} — {spec.description}" for spec in specs)


def build_system_prompt(*, tools: ToolRegistry, views: Sequence[Projection]) -> str:
    """Return the system prompt every turn of this process is held to.

    Args:
        tools: The tool registry, already populated by discovery.
        views: Every registered projection.

    Returns:
        The fixed rules followed by both generated catalogues. Built once at
        startup rather than per turn: the registries do not change while the
        process runs, and rebuilding it per request would spend the demo's
        latency budget on string joining.
    """
    return compose(tools=tool_catalog(tools.specs()), views=prompt_fragment(views))


__all__ = ["build_system_prompt", "tool_catalog"]
