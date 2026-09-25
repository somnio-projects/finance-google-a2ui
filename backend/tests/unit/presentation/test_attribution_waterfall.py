"""AC-5 — ``attribution.waterfall.v1`` rendered over the seeded portfolio.

The walk is the projection's whole contract: the cumulative of the last
bucket must land exactly on the end total, or the chart lies about where the
money went.
"""

import pytest

from app.core.errors import ValidationFailedError
from app.domain.portfolio import Portfolio
from app.presentation.views.attribution_waterfall import (
    SECTIONS,
    VIEW_ID,
    AttributionWaterfallOptions,
    AttributionWaterfallPayload,
    fitness,
    render,
    surface,
)


def test_render_walks_cost_basis_to_market_value(portfolio: Portfolio) -> None:
    payload = render(portfolio, AttributionWaterfallOptions())
    assert payload.view == VIEW_ID
    assert payload.start.label == "Cost basis"
    assert payload.end.label == "Market value"
    assert payload.buckets[-1].cumulative == payload.end.amount  # the walk lands
    assert len(payload.buckets) == len(portfolio.holdings())


def test_render_orders_buckets_by_absolute_move(portfolio: Portfolio) -> None:
    payload = render(portfolio, AttributionWaterfallOptions())
    moves = [abs(bucket.delta.amount) for bucket in payload.buckets]
    assert moves == sorted(moves, reverse=True)


def test_render_marks_direction_per_bucket(portfolio: Portfolio) -> None:
    payload = render(portfolio, AttributionWaterfallOptions())
    directions = {bucket.direction for bucket in payload.buckets}
    assert directions == {"up", "down"}  # the seed has winners and losers
    for bucket in payload.buckets:
        expected = "up" if bucket.delta.amount >= 0 else "down"
        assert bucket.direction == expected


@pytest.mark.parametrize(
    ("locale", "expected"),
    [
        ("en-US", "$421,711.15"),
        ("es-AR", "US$ 421.711,15"),
        ("de-DE", "421.711,15 $"),
    ],
    ids=["en-US", "es-AR", "de-DE"],
)
def test_render_honours_locale(
    portfolio: Portfolio, locale: str, expected: str
) -> None:
    payload = render(
        portfolio,
        AttributionWaterfallOptions(locale=locale),  # pyright: ignore[reportArgumentType]
    )
    assert payload.start.amount.display == expected


def test_render_honours_precision(portfolio: Portfolio) -> None:
    payload = render(portfolio, AttributionWaterfallOptions(precision=0))
    assert payload.start.amount.display == "$421,711"


def test_render_annotates_the_movers_and_the_net(portfolio: Portfolio) -> None:
    payload = render(portfolio, AttributionWaterfallOptions())
    assert [note.label for note in payload.annotations][-1] == "Net"
    assert len(payload.annotations) == 3  # two movers plus the net


@pytest.mark.parametrize(
    ("fields", "has_buckets", "has_notes"),
    [
        (None, True, True),
        (("buckets",), True, False),
        (("annotations",), False, True),
    ],
    ids=["all-sections", "buckets-only", "annotations-only"],
)
def test_render_trims_unselected_sections(
    portfolio: Portfolio,
    fields: tuple[str, ...] | None,
    has_buckets: bool,
    has_notes: bool,
) -> None:
    payload = render(portfolio, AttributionWaterfallOptions(fields=fields))
    assert bool(payload.buckets) is has_buckets
    assert bool(payload.annotations) is has_notes
    assert payload.start.amount.display  # the totals are never trimmed


def test_render_rejects_an_unknown_section(portfolio: Portfolio) -> None:
    options = AttributionWaterfallOptions(fields=("holdings",))
    with pytest.raises(ValidationFailedError, match="unknown section"):
        render(portfolio, options)


def test_surface_maps_the_payload_onto_the_waterfall(portfolio: Portfolio) -> None:
    rendered = surface(render(portfolio, AttributionWaterfallOptions()))
    assert rendered.component == "AttributionWaterfall"
    assert rendered.view == VIEW_ID
    assert rendered.props["start"]["label"] == "Cost basis"
    assert rendered.props["net"]["amount"]["display"] == "+$61,204.05"
    assert rendered.props["steps"][0]["delta_label"] == "Contribution"
    assert len(rendered.props["steps"]) == 7
    assert rendered.props["notes"][-1] == "$61,204.05"  # net, written server-side


def test_fitness_needs_a_winner_and_a_loser(
    portfolio: Portfolio, winners_only: Portfolio, empty_portfolio: Portfolio
) -> None:
    assert fitness(portfolio) == 2
    assert fitness(winners_only) == 0
    assert fitness(empty_portfolio) == 0


def test_payload_declares_its_discriminator_literal() -> None:
    assert AttributionWaterfallPayload.model_fields["view"].default == VIEW_ID
    assert SECTIONS == ("buckets", "annotations")
