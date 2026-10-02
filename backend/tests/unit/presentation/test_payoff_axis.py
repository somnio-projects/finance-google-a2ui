"""GGU-146 — the value axis and the words either side of the break-even.

Both blocks exist because the design draws something the client could not
bind without computing it (N-2) or authoring it (N-1). These hold the claims
that makes: the ladder is readable and always contains zero, it is written in
the payload's own money format, and the two words reach the payload.
"""

from decimal import Decimal

import pytest

from app.domain.payoff import PayoffCurve
from app.domain.payoff_pricing import payoff_curve
from app.presentation.payoff_axis import (
    GAIN_LABEL,
    LOSS_LABEL,
    TARGET_RUNGS,
    ticks,
    value_axis,
    zones,
)
from app.presentation.payoff_figures import Shape

SHAPE = Shape(places=2, precision=2, locale="en-US")


def curve(*, entry: str, quantity: str, range_pct: int = 30) -> PayoffCurve:
    """Return a priced curve; the tests vary only what changes the ladder."""
    return payoff_curve(
        symbol="SOL",
        name="Solana",
        entry_price=Decimal(entry),
        quantity=Decimal(quantity),
        side="buy",
        range_pct=range_pct,
        steps=25,
    )


def test_the_ladder_always_contains_the_line_everything_is_read_against() -> None:
    """Zero is the break-even's own rule; a ladder skipping it leaves it bare."""
    assert Decimal(0) in ticks(curve(entry="152.40", quantity="3.28"), SHAPE)


@pytest.mark.parametrize(
    ("entry", "quantity"),
    [("152.40", "3.28"), ("1.00", "1"), ("60000", "0.5"), ("0.13", "10000")],
    ids=["solana", "unit", "bitcoin", "cheap"],
)
def test_the_ladder_is_readable_at_any_scale(entry: str, quantity: str) -> None:
    """Ascending, evenly spaced, and never more rungs than it aimed for.

    Four orders of magnitude apart, because a step search that works on one
    scale and not another is the usual way this arithmetic goes wrong.
    """
    rungs = ticks(curve(entry=entry, quantity=quantity), SHAPE)

    assert rungs == tuple(sorted(rungs))
    assert len(rungs) <= TARGET_RUNGS + 2
    gaps = {rungs[i + 1] - rungs[i] for i in range(len(rungs) - 1)}
    assert len(gaps) == 1


def test_the_ladder_spans_the_curve_it_is_drawn_against() -> None:
    """A rung outside the data, or data outside the rungs, is a wrong axis."""
    priced = curve(entry="152.40", quantity="3.28")
    rungs = ticks(priced, SHAPE)
    values = [point.profit_loss for point in priced.points]
    step = rungs[1] - rungs[0]

    assert min(rungs) >= min(values)
    assert max(rungs) <= max(values)
    # And it does not stop a whole step short of either end, which would leave
    # a labelled ladder that ignores half the curve.
    assert min(rungs) - step < min(values)
    assert max(rungs) + step > max(values)


def test_the_design_s_own_ladder_comes_back() -> None:
    """The artboard draws a 20k span in five rungs of 5k; so does this.

    The one case read off Figma rather than invented, which is what makes the
    step search a measurement rather than a preference. Its curve is
    symmetric where the artboard's is one-sided, so the claim is about the
    span and the step, not about where the ladder starts.
    """
    priced = payoff_curve(
        symbol="SOL",
        name="Solana",
        entry_price=Decimal(100),
        quantity=Decimal(500),
        side="buy",
        range_pct=20,
        steps=21,
    )
    rungs = ticks(priced, SHAPE)

    assert max(rungs) - min(rungs) == Decimal(20_000)
    assert rungs[1] - rungs[0] == Decimal(5_000)
    assert len(rungs) == TARGET_RUNGS


def test_every_rung_is_written_in_this_payload_s_money_format() -> None:
    """The client prints `display` and never formats a rung itself (N-1)."""
    priced = curve(entry="152.40", quantity="3.28")
    written = value_axis(priced, SHAPE)

    assert [pair.display for pair in written] == [
        "-$100.00",
        "$0.00",
        "$100.00",
    ]
    assert [Decimal(pair.amount) for pair in written] == list(ticks(priced, SHAPE))


def test_a_curve_that_never_moves_gets_one_rung() -> None:
    """A zero-quantity order: flat at zero, so there is nothing to space out.

    Built by flattening a real curve's points rather than by constructing an
    invalid one — ``PayoffCurve`` requires three points and ascending prices,
    and a fixture that had to dodge its own validators would be testing a
    shape the domain cannot produce.
    """
    priced = curve(entry="152.40", quantity="3.28")
    flat = priced.model_copy(
        update={
            "points": tuple(
                point.model_copy(update={"profit_loss": Decimal(0)})
                for point in priced.points
            )
        }
    )

    assert ticks(flat, SHAPE) == (Decimal(0),)
    assert [pair.display for pair in value_axis(flat, SHAPE)] == ["$0.00"]


def test_the_region_words_are_the_server_s_and_reach_the_payload() -> None:
    """A client constant here would be English nobody can translate (N-1)."""
    written = zones()

    assert (written.loss, written.gain) == (LOSS_LABEL, GAIN_LABEL)
    assert written.loss != written.gain
