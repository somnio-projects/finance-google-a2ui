"""Spec 0032 — ``attribution.driver.v1`` rendered over the seeded portfolio.

The card is the design's D2 state written down: every figure an ADR-E pair,
every word server-written, nothing for the client to compute.
"""

import pytest

from app.core.errors import ValidationFailedError
from app.domain.portfolio import Portfolio
from app.presentation.driver_payload import CAPTIONS
from app.presentation.views.attribution_driver import (
    DEFAULT_SYMBOL,
    VIEW_ID,
    DriverDetailOptions,
    fitness,
    render,
    surface,
)


def test_render_defaults_to_the_designs_driver(portfolio: Portfolio) -> None:
    payload = render(portfolio, DriverDetailOptions())

    assert payload.view == VIEW_ID
    assert (payload.symbol, payload.name) == (DEFAULT_SYMBOL, "Bitcoin")
    assert payload.caption == "Top contributor today"
    assert (payload.contribution.display, payload.trend) == ("+$4,767.00", "up")


def test_render_writes_the_three_tiles_with_their_captions(
    portfolio: Portfolio,
) -> None:
    """The tile words — labels, ``@`` and ``of`` — are the backend's (N-9)."""
    payload = render(portfolio, DriverDetailOptions())

    assert payload.price_move.label == "Price move"
    assert (payload.price_move.percent.display, payload.price_move.trend) == (
        "+3.66%",
        "up",
    )
    assert payload.price_move.amount.display == "+$2,270.00"
    # The tile names the asset, not a unit Bitcoin does not have: it held
    # 2.1 coins, and "Shares" was the label until GGU-123 (spec 0046 OD-3).
    assert (payload.holding.label, payload.holding.units.display) == (
        "BTC held",
        "2.1",
    )
    assert (
        payload.holding.caption
        == f"@ {payload.holding.price.display}"
        == "@ $64,250.00"
    )
    assert (payload.day_share.label, payload.day_share.percent.display) == (
        "Of day gain",
        "216.58%",
    )
    assert payload.day_share.caption == f"of {payload.day_share.total.display}"
    assert payload.day_share.total.display == "+$2,201.05"


def test_render_describes_a_detractor_in_its_own_words(portfolio: Portfolio) -> None:
    payload = render(portfolio, DriverDetailOptions(symbol="AAVE"))

    assert payload.caption == "Top detractor today"
    assert payload.trend == "down"
    assert payload.contribution.display.startswith("-$")
    assert payload.price_move.trend == "down"
    assert payload.day_share.percent.display.startswith("-")


def test_render_ranks_the_others(portfolio: Portfolio) -> None:
    assert render(portfolio, DriverDetailOptions(symbol="ETH")).caption == (
        "#2 contributor today"
    )
    assert render(portfolio, DriverDetailOptions(symbol="SOL")).caption == (
        "#2 detractor today"
    )
    assert render(portfolio, DriverDetailOptions(symbol="USDC")).caption == (
        "Unchanged today"
    )


def test_every_standing_has_a_caption() -> None:
    """Anti-vacuity for the table: a standing without words would KeyError."""
    assert set(CAPTIONS) == {
        "top_contributor",
        "contributor",
        "top_detractor",
        "detractor",
        "unchanged",
    }


@pytest.mark.parametrize(
    ("locale", "expected"),
    [("en-US", "+$4,767.00"), ("es-AR", "+US$ 4.767,00"), ("de-DE", "+4.767,00 $")],
    ids=["en-US", "es-AR", "de-DE"],
)
def test_render_honours_locale(
    portfolio: Portfolio, locale: str, expected: str
) -> None:
    payload = render(
        portfolio,
        DriverDetailOptions(locale=locale),  # pyright: ignore[reportArgumentType]
    )
    assert payload.contribution.display == expected


def test_render_honours_precision(portfolio: Portfolio) -> None:
    payload = render(portfolio, DriverDetailOptions(precision=0))

    assert payload.contribution.display == "+$4,767"
    assert payload.price_move.percent.display == "+4%"


def test_render_refuses_a_symbol_the_portfolio_does_not_hold(
    portfolio: Portfolio,
) -> None:
    """A valid option with no card behind it is a 422 naming the symbol."""
    with pytest.raises(ValidationFailedError, match="AVAX is not held"):
        render(portfolio, DriverDetailOptions(symbol="AVAX"))


def test_surface_maps_the_payload_onto_the_card(portfolio: Portfolio) -> None:
    rendered = surface(render(portfolio, DriverDetailOptions()))

    assert (rendered.component, rendered.view) == ("DriverDetail", VIEW_ID)
    assert rendered.title == "Bitcoin"
    assert rendered.props["symbol"] == "BTC"
    assert rendered.props["contribution"]["display"] == "+$4,767.00"
    assert rendered.props["priceMove"]["label"] == "Price move"
    assert rendered.props["holding"]["label"] == "BTC held"
    assert rendered.props["holding"]["caption"] == "@ $64,250.00"
    assert rendered.props["dayShare"]["percent"]["display"] == "216.58%"


def test_fitness_never_volunteers_the_card(
    portfolio: Portfolio, empty_portfolio: Portfolio
) -> None:
    assert fitness(portfolio) == 0
    assert fitness(empty_portfolio) == 0
