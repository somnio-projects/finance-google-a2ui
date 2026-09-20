"""What a tool is, what it is given, and what one turn produces (spec 0006 §3.2).

A tool is a small async callable over the domain. It receives a
``ToolContext`` — the subject and the portfolio provider, and nothing else —
so a tool cannot open a session, reach a repository or read ``Settings`` even
by accident. It returns a ``ToolOutcome``: the JSON payload the model reads,
plus an optional render intent.

**Numbers-from-tools.** Every figure inside ``ToolOutcome.data`` is a
pre-formatted ``*Display`` string produced through ``app.core.display``
(ADR-E D-2/D-3, ADR-K D-5). The model copies those strings; it never rounds,
never formats and never computes.
"""

from collections.abc import Mapping
from dataclasses import dataclass, field
from typing import Protocol

from pydantic import BaseModel, ConfigDict, Field

from app.domain.provider import PortfolioProvider

VIEW_PATTERN = r"^[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*\.v[0-9]+$"


@dataclass(frozen=True, slots=True)
class ToolContext:
    """Everything a tool is allowed to reach while it runs."""

    subject: str
    portfolios: PortfolioProvider


class RenderIntent(BaseModel):
    """A request to render a registered projection (ADR-K D-11).

    This is the **minimal** shape the agent host produces and the presentation
    layer consumes. Resolving it, validating the options against the
    projection's option model and falling back on rejection (ADR-K D-12) are
    GGU-49's, not this package's — nothing here renders anything.
    """

    model_config = ConfigDict(frozen=True)

    view: str = Field(
        pattern=VIEW_PATTERN,
        max_length=64,
        description="Projection id, ``<component>.<variant>.v<N>``.",
    )
    options: Mapping[str, object] = Field(
        default_factory=dict, description="Declared options for that projection."
    )


@dataclass(frozen=True, slots=True)
class ToolOutcome:
    """What one tool run produced."""

    data: Mapping[str, object]
    render: RenderIntent | None = None


class Tool(Protocol):
    """A deterministic, side-effect-free read the model may ask for."""

    @property
    def name(self) -> str:
        """Stable identifier the model calls (``get_holdings_summary``)."""
        ...

    @property
    def description(self) -> str:
        """What the tool answers, written for the model to choose by."""
        ...

    @property
    def parameters(self) -> Mapping[str, object]:
        """JSON Schema object describing the accepted arguments."""
        ...

    async def run(
        self, arguments: Mapping[str, object], context: ToolContext
    ) -> ToolOutcome:
        """Run the tool over ``context`` and return its payload."""
        ...


@dataclass(frozen=True, slots=True)
class TurnResult:
    """The outcome of one agent turn (spec 0006 §3.3).

    Attributes:
        message: The assistant's answer.
        render_intents: Views the turn asks the client to render, in order.
        tool_calls: How many tool calls were executed.
        iterations: How many model calls the turn spent.
        truncated: True when the iteration bound ended the turn.
    """

    message: str
    render_intents: tuple[RenderIntent, ...] = ()
    tool_calls: int = 0
    iterations: int = 0
    truncated: bool = False


@dataclass(slots=True)
class TurnState:
    """Mutable counters a turn accumulates, so telemetry never branches.

    Attributes:
        iterations: Model calls spent so far.
        tool_calls: Tool calls executed so far.
        renders: Every render intent collected, in order.
        emitted: How many of ``renders`` have already left the loop as events.
    """

    iterations: int = 0
    tool_calls: int = 0
    renders: list[RenderIntent] = field(default_factory=list)
    emitted: int = 0

    def take_renders(self) -> tuple[tuple[int, RenderIntent], ...]:
        """Return the render intents collected since the last call, with indexes.

        Returns:
            Each new intent paired with its position in the turn. Draining
            here rather than diffing in the loop is what lets a surface be
            emitted the moment it exists (ADR-K D-19).
        """
        fresh = tuple(enumerate(self.renders[self.emitted :], start=self.emitted))
        self.emitted = len(self.renders)
        return fresh


__all__ = [
    "VIEW_PATTERN",
    "RenderIntent",
    "Tool",
    "ToolContext",
    "ToolOutcome",
    "TurnResult",
    "TurnState",
]
