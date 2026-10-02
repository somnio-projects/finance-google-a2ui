"""``holdings.positions.v1`` over the seeded portfolio (spec 0028 AC-1, AC-2)."""

from app.domain.portfolio import Portfolio
from app.presentation.positions_rows import HoldingsPositionsOptions
from app.presentation.views.holdings_positions import (
    VIEW_ID,
    fitness,
    render,
    surface,
)


def test_the_header_states_the_total_and_the_all_time_gain(
    portfolio: Portfolio,
) -> None:
    payload = render(portfolio, HoldingsPositionsOptions())
    assert payload.view == VIEW_ID
    assert payload.title == "Holdings"
    assert (payload.total.label, payload.total.amount.display) == (
        "Total value",
        "$482,915.20",
    )
    assert (payload.gain.amount.display, payload.gain.percent.display) == (
        "+$61,204",
        "+14.5%",
    )
    assert (payload.gain.trend, payload.gain.period) == ("up", "all-time unrealized")
    assert payload.ask_label == "Ask the assistant about this"


def test_rows_run_by_value_with_cash_last(portfolio: Portfolio) -> None:
    payload = render(portfolio, HoldingsPositionsOptions())
    symbols = [row.symbol for row in payload.positions]
    assert symbols[:5] == ["BTC", "ETH", "SOL", "LINK", "ARB"]
    assert symbols[-1] == "USDC"
    ascending = render(portfolio, HoldingsPositionsOptions(sort="value_asc"))
    assert [row.symbol for row in ascending.positions][-1] == "USDC"
    assert ascending.positions[0].symbol == "AAVE"
    by_name = render(portfolio, HoldingsPositionsOptions(sort="label"))
    assert [row.symbol for row in by_name.positions][:2] == ["AAVE", "ARB"]


def test_a_position_row_is_the_design_row(portfolio: Portfolio) -> None:
    payload = render(portfolio, HoldingsPositionsOptions())
    btc = payload.positions[0]
    # The second line counts the asset in its own units — "2.1 BTC", not
    # "2.1 sh" (GGU-122, spec 0046 OD-1).
    assert (btc.name, btc.detail) == ("Bitcoin", "2.1 BTC · avg $41,698.00")
    assert btc.value.display == "$134,925.00"
    assert btc.unrealized is not None
    assert (btc.unrealized.amount.display, btc.unrealized.percent.display) == (
        "+$47,359",
        "+54.1%",
    )
    assert (btc.unrealized.trend, btc.unrealized.period) == ("up", "all-time")
    assert (btc.day.display, btc.day_trend) == ("+3.7%", "up")
    assert (btc.price.display, btc.weight.display) == ("$64,250.00", "27.9%")
    assert btc.is_cash is False
    assert btc.ask.text == "Tell me about my BTC position"


def test_the_cash_row_has_no_result_and_its_own_words(portfolio: Portfolio) -> None:
    payload = render(portfolio, HoldingsPositionsOptions())
    cash = payload.positions[-1]
    assert (cash.symbol, cash.detail, cash.is_cash) == ("USDC", "Settlement fund", True)
    assert cash.unrealized is None
    assert (cash.day.display, cash.day_trend) == ("0.0%", "flat")
    assert cash.ask.text == "What is my cash doing?"


def test_a_loser_is_signed_and_marked_down(portfolio: Portfolio) -> None:
    payload = render(portfolio, HoldingsPositionsOptions())
    arb = next(row for row in payload.positions if row.symbol == "ARB")
    assert arb.unrealized is not None
    assert (arb.unrealized.amount.display, arb.unrealized.trend) == (
        "-$2,835",
        "down",
    )


def test_the_locale_reaches_every_figure(portfolio: Portfolio) -> None:
    payload = render(portfolio, HoldingsPositionsOptions(locale="de-DE", precision=0))
    assert payload.total.amount.display == "482.915 $"
    assert payload.positions[0].detail == "2.1 BTC · avg 41.698,00 $"


def test_surface_and_fitness(portfolio: Portfolio, empty_portfolio: Portfolio) -> None:
    drawn = surface(render(portfolio, HoldingsPositionsOptions()))
    assert drawn.component == "PositionList"
    assert drawn.view == VIEW_ID
    assert set(drawn.props) == {
        "total",
        "gain",
        "askLabel",
        "assetClass",
        "query",
        "empty",
        "filters",
        "positions",
    }
    assert fitness(portfolio) == 0 == fitness(empty_portfolio)
    assert render(empty_portfolio, HoldingsPositionsOptions()).positions == ()
