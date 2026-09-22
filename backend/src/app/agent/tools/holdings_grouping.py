"""How the allocation chart beside a holdings answer may be sliced.

Its own module for the same reason ``holdings_sort`` is one: the vocabulary
is a fact about the *projection*, and `holdings_query` is already at the file
budget carrying the argument model.

The projection is the authority. ``holdings.allocation.v1`` declares
``group_by`` in its own options model, and ``RenderIntentService`` validates
every intent against it and rejects anything else (ADR-K D-11/D-12), so
nothing here can widen what the client will actually draw. This list exists
only to **offer** the choice to the model, which has no other way to learn
that the choice exists.

Two declarations of one vocabulary is a thing this repository distrusts, so
it is checked rather than asserted:
``test_the_tool_offers_every_grouping_the_projection_declares`` reads the
projection's schema and compares it with ``GROUPINGS``.
"""

from typing import Final, Literal

#: The set as a type, so pydantic rejects anything else at the boundary.
Grouping = Literal["holding", "asset_class", "sector"]

#: Every slicing the allocation chart accepts, in the projection's order.
GROUPINGS: Final[tuple[Grouping, ...]] = ("holding", "asset_class", "sector")

#: What a caller that does not ask gets — one slice per position, which is
#: what the chart has always drawn.
DEFAULT_GROUPING: Final[Grouping] = "holding"

__all__ = ["DEFAULT_GROUPING", "GROUPINGS", "Grouping"]
