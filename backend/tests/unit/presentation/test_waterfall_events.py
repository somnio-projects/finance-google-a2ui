"""AC-5..AC-6 of spec 0023 — a tapped segment can actually start a turn.

The design catalog's waterfall declares ``"events": ["onSegmentTap(key)"]``:
tapping a contribution sends that contribution's ``key`` to the agent. This
backend implements the same affordance as the registered action
``drill.attribution.v1``, whose one argument ``driver`` is bounded to the
curated market reference.

Two declarations of one fact, so a test compares them rather than a comment
claiming they agree. Before GGU-53 they could not have agreed: ``Bucket``
carried no ``key`` at all, only a prose ``label`` (*"NVIDIA Corp"*), while
``driver`` accepts symbols (*"NVDA"*) — so the surface advertised an action no
client could invoke from the payload it was attached to. The declaration was
published, the bound was enforced, and the two had no value in common.
"""

from typing import Final, get_args

from app.actions.declared import declared_action
from app.actions.defined.drill_attribution import ACTION as DRILL
from app.actions.defined.drill_attribution import Driver
from app.domain.portfolio import Portfolio
from app.presentation.views.attribution_waterfall import (
    AttributionWaterfallOptions,
    render,
    surface,
)

#: The values the drill action's own arguments model accepts.
ACCEPTED_DRIVERS: Final[frozenset[str]] = frozenset(get_args(Driver))


def test_every_rendered_segment_carries_a_key_the_drill_action_accepts(
    portfolio: Portfolio,
) -> None:
    """AC-5 — what a tap can send is what the action's bound accepts."""
    payload = render(portfolio, AttributionWaterfallOptions())
    keys = {bucket.key for bucket in payload.buckets}

    # Anti-vacuity: an empty walk would make the subset check trivially true.
    assert keys, "the seeded portfolio rendered no segments to tap"
    assert keys <= ACCEPTED_DRIVERS, (
        f"segments {sorted(keys - ACCEPTED_DRIVERS)} cannot be sent as `driver`"
    )


def test_the_declared_action_publishes_the_same_bound_it_enforces() -> None:
    """AC-6 — the choices a client reads are the values the backend accepts."""
    published = declared_action(DRILL)

    assert published.arg == "driver"
    assert published.control == "choice"
    assert set(published.choices) == ACCEPTED_DRIVERS


def test_a_segment_key_is_the_symbol_and_never_the_prose_label(
    portfolio: Portfolio,
) -> None:
    """The distinction the whole fix rests on: `key` is sendable, `label` is not.

    A regression that set ``key=row.name`` would still render, still publish
    and still pass every shape assertion in the suite — and every tap would be
    rejected. So the two are asserted to differ, on a holding where they do.
    """
    payload = render(portfolio, AttributionWaterfallOptions())
    bitcoin = next(bucket for bucket in payload.buckets if bucket.key == "NVDA")

    assert bitcoin.label == "NVIDIA Corp"
    assert bitcoin.key != bitcoin.label


def test_the_surface_hands_the_client_the_key_inside_each_step(
    portfolio: Portfolio,
) -> None:
    """The key has to survive into the A2UI props, or the client never sees it."""
    payload = render(portfolio, AttributionWaterfallOptions())
    steps = surface(payload).props["steps"]

    assert [step["key"] for step in steps] == [b.key for b in payload.buckets]
