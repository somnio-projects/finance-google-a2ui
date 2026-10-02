"""What the demo's turns call, and with which arguments (spec 0033, 0052).

Split out of ``demo_script`` when a fifth chip pushed that module past the
150-line budget. The seam is the one the file already had by paragraph:
**what a turn calls** is here, **what it then says** stays there. A tool name
and a set of arguments are the demo's inputs; a sentence with holes in it is
its output.

Tool names are spelled as the model would spell them; a test resolves each one
against the discovered registry, so a renamed tool fails the gate rather than
a demo.
"""

from collections.abc import Mapping
from typing import Final

ATTRIBUTION: Final[str] = "compute_attribution"
HOLDINGS: Final[str] = "get_holdings_summary"
SALE: Final[str] = "simulate_sale"
COMPARE: Final[str] = "compare_lot_methods"
DRAFT: Final[str] = "draft_order"

#: Flow B's sale and Flow C's order, as the design states them. A user's own
#: amount is an argument, not a figure: the tool turns it into units.
DESIGN_SALE: Final[Mapping[str, object]] = {
    "symbol": "BTC",
    "amount_usd": "20000",
    "lot_method": "FIFO",
}

#: The same sale as :data:`DESIGN_SALE` with the method left out, because the
#: comparison costs it under **every** method — naming one would contradict
#: the question the chip asks. ``compare_lot_methods`` forbids extras, so
#: passing ``lot_method`` here would be a validation error rather than a
#: quietly ignored argument.
DESIGN_COMPARISON: Final[Mapping[str, object]] = {
    "symbol": "BTC",
    "amount_usd": "20000",
}

DESIGN_ORDER: Final[Mapping[str, object]] = {
    "amount": "10000",
    "basket": "majors",
}

__all__ = [
    "ATTRIBUTION",
    "COMPARE",
    "DESIGN_COMPARISON",
    "DESIGN_ORDER",
    "DESIGN_SALE",
    "DRAFT",
    "HOLDINGS",
    "SALE",
]
