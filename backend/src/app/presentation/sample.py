"""The portfolio every documented example is rendered from (spec 0005 OD-2).

Examples are **rendered, never written**. A hand-copied OpenAPI example drifts
from its DTO the first time a field is renamed; one produced by running the
projection itself cannot. ``EXAMPLE_AS_OF`` is a literal instant — this package
reads no clock (ADR-K D-6) — so the document is byte-identical on every build
and a diff in the examples means a real change in a payload.
"""

from datetime import UTC, datetime
from functools import cache
from typing import Final

from app.domain.portfolio import Portfolio
from app.domain.seed import seed_portfolio

EXAMPLE_AS_OF: Final[datetime] = datetime(2026, 1, 15, 12, 0, tzinfo=UTC)


@cache
def sample_portfolio() -> Portfolio:
    """Return the seeded demo portfolio as it stands at ``EXAMPLE_AS_OF``."""
    return seed_portfolio(as_of=EXAMPLE_AS_OF)


__all__ = ["EXAMPLE_AS_OF", "sample_portfolio"]
