"""The rule that picks a projection when nobody chose one (ADR-K D-13).

The demo must be reproducible, so the choice is **code, not vibes**: each
projection scores itself against the data through its own ``fitness``, the
highest score wins and ties break on ascending id. Ranking the registry rather
than branching on ids is what keeps the rule additive — a new chart brings its
own ``fitness`` and this module never changes (ADR-K D-15).

The endpoint still owns a documented default (ADR-K D-2), used when nothing in
the registry fits the data at all — an empty portfolio, for instance.
"""

from collections.abc import Sequence

from app.domain.portfolio import Portfolio
from app.presentation.registry import Projection


def select_view(
    portfolio: Portfolio, *, projections: Sequence[Projection], default: str
) -> str:
    """Return the id of the projection the data calls for.

    Args:
        portfolio: The data the projections score themselves against.
        projections: Every registered projection.
        default: The endpoint's documented default projection id.

    Returns:
        The best-scoring projection's id, or ``default`` when the registry is
        empty or nothing scores above zero.
    """
    best = min(projections, key=lambda p: (-p.fitness(portfolio), p.id), default=None)
    if best is None or best.fitness(portfolio) == 0:
        return default
    return best.id


__all__ = ["select_view"]
