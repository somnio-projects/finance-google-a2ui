"""GGU-100 (spec 0032) — the waterfall's headline and its per-step figures.

Beside ``test_attribution_waterfall.py`` rather than in it, under the budget.
What the design's pill and selected tooltip print is **bound** from these
fields; the client computes none of them (N-1..N-4).
"""

from decimal import Decimal

import pytest

from app.domain.portfolio import Portfolio
from app.presentation.attribution_walk import move_of, net_of
from app.presentation.views.attribution_waterfall import (
    AttributionWaterfallOptions,
    render,
)


def test_render_headlines_the_net_as_a_signed_pair_with_a_direction(
    portfolio: Portfolio,
) -> None:
    """AC-1/AC-2 — the pill is bound, not computed: end minus start."""
    payload = render(portfolio, AttributionWaterfallOptions())

    assert payload.net.label == "Net"
    assert payload.net.amount.amount == payload.end.amount.amount - (
        payload.start.amount.amount
    )
    assert (payload.net.amount.display, payload.net.percent.display) == (
        "+$61,204.05",
        "+14.51%",
    )
    assert payload.net.direction == "up"


def test_render_gives_each_step_what_its_selected_state_shows(
    portfolio: Portfolio,
) -> None:
    """AC-3 — move, units and price as pairs, plus the written lines."""
    payload = render(portfolio, AttributionWaterfallOptions())
    nvidia = next(step for step in payload.buckets if step.key == "NVDA")

    # 0.45725 rounds half-even to 45.72 (ADR-E D-3), and only at display.
    assert nvidia.move.value == Decimal("0.45725")
    assert nvidia.move.display == "+45.72%"
    assert (nvidia.units.display, nvidia.price.display) == ("90", "$1,204.66")
    assert nvidia.detail == "+45.72% · 90 sh · $1,204.66"
    assert nvidia.selected_label == "NVDA selected"
    gold = next(step for step in payload.buckets if step.key == "GLD")
    assert gold.move.display.startswith("-")  # a loser's move is signed too


@pytest.mark.parametrize(
    ("start", "end", "amount", "percent", "direction"),
    [
        ("100", "120", "+$20.00", "+20.00%", "up"),
        ("100", "80", "-$20.00", "-20.00%", "down"),
        ("100", "100", "$0.00", "0.00%", "flat"),
        ("0", "50", "+$50.00", "0.00%", "up"),
    ],
    ids=["gain", "loss", "flat", "from-nothing"],
)
def test_net_of_signs_both_figures_and_names_the_direction(
    start: str, end: str, amount: str, percent: str, direction: str
) -> None:
    """A flat walk prints no sign; a walk from nothing has no ratio to show."""
    net = net_of(
        start=Decimal(start), end=Decimal(end), options=AttributionWaterfallOptions()
    )

    assert (net.amount.display, net.percent.display) == (amount, percent)
    assert net.direction == direction


def test_move_of_honours_the_renders_precision_and_locale() -> None:
    move = move_of(
        Decimal("110"),
        Decimal("100"),
        AttributionWaterfallOptions(precision=1, locale="de-DE"),
    )

    assert move.display == "+10,0%"
