"""Which endpoints serve a projection, named once (ADR-K D-8, D-15).

The catalog promises the client *where* it can ask for a view, so every
projection has to list its serving endpoints. Spelling that tuple out inside
each view module made adding an endpoint an edit to every chart — the mirror
image of the coupling D-15 removes. Naming it here inverts it: a chart imports
a constant, and a new serving endpoint is one line in one file.

This module holds strings, nothing else. It imports nothing, so no view module
gains a dependency by using it.
"""

from typing import Final

#: The client's own read: repeat `view` for several projections at once (D-17).
PORTFOLIO_VIEWS: Final[str] = "GET /v1/portfolios/{portfolio_id}/views"
#: The heterogeneous batch, per-entry status and all (D-18).
VIEW_RENDERS: Final[str] = "POST /v1/view-renders"

#: Every endpoint that can render any portfolio projection. A projection that
#: is genuinely served by only one of them may still declare its own tuple.
PORTFOLIO_ENDPOINTS: Final[tuple[str, ...]] = (PORTFOLIO_VIEWS, VIEW_RENDERS)

__all__ = ["PORTFOLIO_ENDPOINTS", "PORTFOLIO_VIEWS", "VIEW_RENDERS"]
