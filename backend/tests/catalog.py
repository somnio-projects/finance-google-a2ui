"""The projections this backend ships, named once.

Four test files used to hold their own copy of this list. Adding a chart meant
remembering all four, and five agents adding four charts in parallel produced
four different spellings of the same idea — one extended the list, one derived
it from the registry, one loosened equality to containment.

So it lives here, the way ``EXPECTED_TOOLS`` does for the agent's tools
(``tests/unit/agent/test_registry.py``). The list is deliberately **written
down** rather than read from ``REGISTRY``: a test that derives its expectation
from the thing under test cannot fail. A projection registered without being
named here should break the build loudly, not ship invisible — which is the
same reason ADR-K D-15 removes the *import* list and keeps the *assertion* one.

Adding a chart is one line here, and the failure tells you so by name.
"""

from typing import Final

#: Every registered projection id, in the order ``REGISTRY.all()`` returns
#: them — which is sorted, and asserted to be sorted.
SHIPPED_VIEWS: Final[tuple[str, ...]] = (
    "attribution.waterfall.v1",
    "holdings.allocation.v1",
    "order.ticket.v1",
    "payoff.curve.v1",
    "portfolio.summary.v1",
    "scenario.comparison.v1",
    "taxlots.table.v1",
)

#: The two that predate the catalog work and serve the portfolio endpoints.
#: Kept separate because several tests need a projection that `fitness` can
#: actually select, and the four Flow B/C charts all score 0 by design.
SELECTABLE_VIEWS: Final[tuple[str, ...]] = (
    "attribution.waterfall.v1",
    "holdings.allocation.v1",
)

__all__ = ["SELECTABLE_VIEWS", "SHIPPED_VIEWS"]
