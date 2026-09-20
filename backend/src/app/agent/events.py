"""What a turn emits while it runs (ADR-K D-19, ADR-D).

A turn used to be a single value: you waited for it, then you had everything.
That made the A2A stream well-formed but not incremental — the client received
a `working` status and then, one burst later, every surface at once. ADR-K
D-19 wants the opposite: perceived latency should be the time to the *first*
widget.

So the loop yields. ``SurfaceReady`` leaves the loop the moment the tool that
produced it returns; ``TurnCompleted`` is always the last event of a turn that
did not raise. The two are deliberately separate types rather than one event
with a nullable field: a consumer that only forwards surfaces cannot then
forget the terminal case, because it will not type-check without it.
"""

from dataclasses import dataclass

from app.agent.contracts import RenderIntent, TurnResult


@dataclass(frozen=True, slots=True)
class SurfaceReady:
    """One render intent, emitted as soon as its tool returned.

    Attributes:
        index: Position of this intent in the turn, from zero — the client
            orders surfaces by it rather than by arrival.
        intent: The registered view the tool asked the client to render.
    """

    index: int
    intent: RenderIntent


@dataclass(frozen=True, slots=True)
class TurnCompleted:
    """The turn's finished result; always the last event of a turn.

    Attributes:
        result: The answer, every render intent in order, and the counters.
    """

    result: TurnResult


#: Everything a turn can emit. A new member is a change every consumer must
#: handle, which is the point: the exhaustiveness is checked by the type checker.
TurnEvent = SurfaceReady | TurnCompleted

__all__ = ["SurfaceReady", "TurnCompleted", "TurnEvent"]
