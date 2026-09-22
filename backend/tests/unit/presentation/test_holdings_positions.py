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
    assert symbols[:5] == ["NVDA", "AAPL", "GLD", "MSFT", "VOO"]
    assert symbols[-1] == "USD"
    ascending = render(portfolio, HoldingsPositionsOptions(sort="value_asc"))
    assert [row.symbol for row in ascending.positions][-1] == "USD"
    assert ascending.positions[0].symbol == "TIP"
    by_name = render(portfolio, HoldingsPositionsOptions(sort="label"))
    assert [row.symbol for row in by_name.positions][:2] == ["AAPL", "USD"]


def test_a_position_row_is_the_design_row(portfolio: Portfolio) -> None:
    payload = render(portfolio, HoldingsPositionsOptions())
    nvda = payload.positions[0]
    assert (nvda.name, nvda.detail) == ("NVIDIA Corp", "90 sh · avg $826.67")
    assert nvda.value.display == "$108,419.40"
    assert nvda.unrealized is not None
    assert (nvda.unrealized.amount.display, nvda.unrealized.percent.display) == (
        "+$34,019",
        "+45.7%",
    )
    assert (nvda.unrealized.trend, nvda.unrealized.period) == ("up", "all-time")
    assert (nvda.day.display, nvda.day_trend) == ("+4.2%", "up")
    assert (nvda.price.display, nvda.weight.display) == ("$1,204.66", "22.5%")
    assert nvda.is_cash is False
    assert nvda.ask.text == "Tell me about my NVDA position"


def test_the_cash_row_has_no_result_and_its_own_words(portfolio: Portfolio) -> None:
    payload = render(portfolio, HoldingsPositionsOptions())
    cash = payload.positions[-1]
    assert (cash.symbol, cash.detail, cash.is_cash) == ("USD", "Settlement fund", True)
    assert cash.unrealized is None
    assert (cash.day.display, cash.day_trend) == ("0.0%", "flat")
    assert cash.ask.text == "What is my cash doing?"


def test_a_loser_is_signed_and_marked_down(portfolio: Portfolio) -> None:
    payload = render(portfolio, HoldingsPositionsOptions())
    pypl = next(row for row in payload.positions if row.symbol == "PYPL")
    assert pypl.unrealized is not None
    assert (pypl.unrealized.amount.display, pypl.unrealized.trend) == (
        "-$5,825",
        "down",
    )


def test_the_locale_reaches_every_figure(portfolio: Portfolio) -> None:
    payload = render(portfolio, HoldingsPositionsOptions(locale="de-DE", precision=0))
    assert payload.total.amount.display == "482.915 $"
    assert payload.positions[0].detail == "90 sh · avg 826,67 $"


def test_surface_and_fitness(portfolio: Portfolio, empty_portfolio: Portfolio) -> None:
    drawn = surface(render(portfolio, HoldingsPositionsOptions()))
    assert drawn.component == "PositionList"
    assert drawn.view == VIEW_ID
    assert set(drawn.props) == {"total", "gain", "askLabel", "positions"}
    assert fitness(portfolio) == 0 == fitness(empty_portfolio)
    assert render(empty_portfolio, HoldingsPositionsOptions()).positions == ()
