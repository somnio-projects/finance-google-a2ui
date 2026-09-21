"""AC-10 — the rule that picks a view when nobody chose one (ADR-K D-13).

The rule ranks the registry by each projection's own ``fitness``; it never
branches on an id, which is what keeps it additive when a chart is added.
"""

from app.domain.portfolio import Portfolio
from app.presentation.registry import REGISTRY, Projection
from app.presentation.selection import select_view
from app.presentation.spec import ProjectionSpec
from app.presentation.views.holdings_allocation import (
    HoldingsAllocationOptions,
    HoldingsAllocationPayload,
    render,
    surface,
)

DEFAULT = "holdings.allocation.v1"


def scored(view_id: str, score: int) -> ProjectionSpec:
    """Build a throwaway projection with a fixed fitness."""
    return ProjectionSpec(
        id=view_id,
        summary="A throwaway projection with a fixed score.",
        endpoints=(),
        options=HoldingsAllocationOptions,
        dto=HoldingsAllocationPayload,
        render=render,
        surface=surface,
        fitness=lambda _: score,
    )


def test_selection_prefers_the_waterfall_when_the_portfolio_has_a_loser(
    portfolio: Portfolio,
) -> None:
    chosen = select_view(portfolio, projections=REGISTRY.all(), default=DEFAULT)
    assert chosen == "attribution.waterfall.v1"


def test_selection_falls_back_to_allocation_without_a_loser(
    winners_only: Portfolio,
) -> None:
    chosen = select_view(winners_only, projections=REGISTRY.all(), default=DEFAULT)
    assert chosen == "holdings.allocation.v1"


def test_selection_uses_the_endpoint_default_when_nothing_fits(
    empty_portfolio: Portfolio,
) -> None:
    chosen = select_view(empty_portfolio, projections=REGISTRY.all(), default=DEFAULT)
    assert chosen == DEFAULT


def test_selection_uses_the_default_for_an_empty_registry(
    portfolio: Portfolio,
) -> None:
    assert select_view(portfolio, projections=[], default=DEFAULT) == DEFAULT


def test_selection_breaks_ties_on_the_lowest_id(portfolio: Portfolio) -> None:
    tied: list[Projection] = [scored("zzz.thing.v1", 3), scored("aaa.thing.v1", 3)]
    assert select_view(portfolio, projections=tied, default=DEFAULT) == "aaa.thing.v1"
