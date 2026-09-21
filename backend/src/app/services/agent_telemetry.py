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

    Args:
        reporter: Where the counter goes.
        state: The turn's accumulated counters.
        model: Name of the model client that served the turn.
        outcome: ``ok``, ``truncated`` or a failure code.
        elapsed: How long the turn took.
    """
    reporter.increment(TURN_METRIC, tags={"model": model, "outcome": outcome})
    log.info(
        TURN_METRIC,
        model=model,
        outcome=outcome,
        duration_ms=int(elapsed.total_seconds() * 1000),
        iterations=state.iterations,
        tool_calls=state.tool_calls,
    )


__all__ = ["TURN_METRIC", "record_turn"]
