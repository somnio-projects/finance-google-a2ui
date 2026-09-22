"""What one turn reports about itself, and what it must never report.

Split out of the turn loop because it answers a different question: the loop
decides *what the answer is*, this decides *what an operator gets to see*. The
loop was also at the 150-line ceiling, and observability is the part that grows
every time someone wants one more counter.

**The negative rule is the important one** (spec 0006 AC-13): the prompt, the
model's reply, the tool results and the subject never reach a log line. A
demo's conversation is the user's, and a log is the easiest place to leak it
without noticing. Tests assert the key set exactly, not merely that the
forbidden keys are absent, so a new field cannot be added silently.
"""

from datetime import timedelta
from typing import Final

import structlog

from app.agent.contracts import TurnState
from app.core.logging import get_logger
from app.core.protocols import ErrorReporter

log: structlog.stdlib.BoundLogger = get_logger(__name__)

TURN_METRIC: Final[str] = "agent.turn"


def record_turn(
    reporter: ErrorReporter,
    state: TurnState,
    *,
    model: str,
    outcome: str,
    elapsed: timedelta,
) -> None:
    """Emit the turn's single metric and single log line.

    **Why the surfaces are counted.** This line carried ``iterations`` and
    ``tool_calls`` and nothing about what the turn drew, so a turn that
    composed four surfaces and a turn that answered in prose produced
    identical telemetry. That is the whole point of this product, and it was
    the one thing the turn did not report: on 2026-09-22 the agent was found
    describing an allocation "by sector" while the surface under it was
    grouped by holding, and no log line anywhere could have shown it. A view
    id is a catalog identifier — not a prompt, a reply, a tool argument or a
    subject — so §5's logging rule is untouched.

    Args:
        reporter: Where the counter goes.
        state: The turn's accumulated counters.
        model: Name of the model client that served the turn.
        outcome: ``ok``, ``truncated`` or a failure code.
        elapsed: How long the turn took.
    """
    views = sorted({intent.view for intent in state.renders})
    reporter.increment(
        TURN_METRIC,
        # `composed` and not a surface count: a tag's value set becomes a
        # time series, and "did this turn draw anything" is the question.
        # The count and the ids are log fields, where cardinality is free.
        tags={"model": model, "outcome": outcome, "composed": str(bool(views))},
    )
    log.info(
        TURN_METRIC,
        model=model,
        outcome=outcome,
        duration_ms=int(elapsed.total_seconds() * 1000),
        iterations=state.iterations,
        tool_calls=state.tool_calls,
        surfaces=len(state.renders),
        views=views,
    )


__all__ = ["TURN_METRIC", "record_turn"]
