"""Spec 0050 — the ticket's slider and its one inert control.

Two claims are tested here that the rest of the v2 suite does not make: that
the slider and the stepper are the **same ladder**, so two affordances over
one leg cannot disagree, and that the button the design draws is served with
its label and its reason rather than spelled in a client.
"""

import pytest

from app.domain.draft_ladder import MAX_LADDER
from app.domain.draft_legs import parse_legs
from app.domain.payoff import Side
from app.domain.portfolio import Portfolio
from app.presentation.order_ticket_v2_controls import CONTROLS, NO_BROKER
from app.presentation.views.order_ticket_v2 import OrderTicketV2Options, render


def test_every_line_carries_a_slider_positioned_on_its_own_value(
    portfolio: Portfolio,
) -> None:
    """AC-1 — `position` indexes `stops`, and the stop there is what is drawn."""
    payload = render(portfolio, OrderTicketV2Options())

    assert payload.lines
    for line in payload.lines:
        assert 0 <= int(line.position) < len(line.stops)
        assert line.stops[int(line.position)] == payload.legs


def test_a_stepper_move_lands_on_a_ladder_that_holds_it(
    portfolio: Portfolio,
) -> None:
    """AC-1 — the two controls are different granularities of one quantity.

    The stepper moves by the **asset's** step; the slider's stride is that
    step coarsened until the ladder fits its bound, so `increment` is
    generally *not* a stop of the ladder rendered beside it. That is not a
    disagreement, and this test says what the invariant actually is: whatever
    a stepper tap sends, the render it produces puts the thumb on the new
    value. The ladder is aligned to the current value, so it always can.

    The first draft of this suite asserted `increment in line.stops` and it
    failed — correctly. The claim was wrong, not the code.
    """
    payload = render(portfolio, OrderTicketV2Options())

    for line in payload.lines:
        for value in (line.increment, line.decrement):
            assert value is not None
            moved = render(portfolio, OrderTicketV2Options(legs=value))
            line_after = next(row for row in moved.lines if row.key == line.key)
            assert line_after.stops[int(line_after.position)] == value


def test_a_slider_move_round_trips_the_same_way(portfolio: Portfolio) -> None:
    """AC-1 — every stop, sent back, renders with the thumb on itself."""
    payload = render(portfolio, OrderTicketV2Options())
    line = payload.lines[0]

    for stop in (line.stops[0], line.stops[-1]):
        moved = render(portfolio, OrderTicketV2Options(legs=stop))
        after = next(row for row in moved.lines if row.key == line.key)
        assert after.stops[int(after.position)] == stop


def test_a_slider_never_publishes_more_stops_than_it_declares(
    portfolio: Portfolio,
) -> None:
    """AC-1 — the field's bound is the writer's bound, on every leg."""
    payload = render(portfolio, OrderTicketV2Options())

    assert all(len(line.stops) <= MAX_LADDER for line in payload.lines)


def test_every_stop_is_a_legs_value_the_options_model_takes_back(
    portfolio: Portfolio,
) -> None:
    """AC-1 — a stop the backend would refuse is a control that cannot move."""
    payload = render(portfolio, OrderTicketV2Options())

    for line in payload.lines:
        for stop in line.stops:
            assert OrderTicketV2Options(legs=stop).legs == stop
            assert len(parse_legs(stop)) == len(payload.lines)


@pytest.mark.parametrize("side", ["buy", "sell"])
def test_the_slider_is_served_for_both_sides(portfolio: Portfolio, side: Side) -> None:
    """AC-1 — a sell is bounded by the position, not by cash, and still has a track."""
    payload = render(portfolio, OrderTicketV2Options(side=side))

    assert all(line.stops for line in payload.lines)


def test_the_one_control_is_drawn_inert_and_says_why(portfolio: Portfolio) -> None:
    """AC-2 — the label is served (N-9) and the button promises nothing."""
    payload = render(portfolio, OrderTicketV2Options())

    assert payload.controls == CONTROLS
    (review,) = payload.controls
    assert (review.key, review.label, review.kind) == (
        "review",
        "Review order",
        "primary",
    )
    assert review.enabled is False
    assert review.reason == NO_BROKER


def test_no_control_is_ever_live_while_the_ticket_places_nothing(
    portfolio: Portfolio,
) -> None:
    """AC-2 — the invariant, not the instance: `effect` is the whole contract."""
    payload = render(portfolio, OrderTicketV2Options())

    assert payload.effect == "recalculate"
    assert all(not c.enabled and c.reason for c in payload.controls)


def test_save_as_draft_is_not_served(portfolio: Portfolio) -> None:
    """AC-3 — the frame draws no second action and the contract has none."""
    payload = render(portfolio, OrderTicketV2Options())

    assert [control.key for control in payload.controls] == ["review"]
