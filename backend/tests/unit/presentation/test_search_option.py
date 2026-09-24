"""The search both tabs share (spec 0035 §3.3, AC-6, AC-7, AC-8).

Kept in one module because the rule is one rule: the same needle, the same
folding, the same "blank is no filter", matched against **domain** fields on
two different projections. Two half-tests in two files would let the two
drift, which is exactly what 0035 OD-6 is about.
"""

import pytest

from app.domain.portfolio import Portfolio
from app.presentation.activity_rows import ActivityOptions
from app.presentation.positions_payload import CLASS_FILTERS, EMPTY
from app.presentation.positions_rows import HoldingsPositionsOptions
from app.presentation.search import SearchOptions, matches
from app.presentation.views.activity_timeline import render as render_activity
from app.presentation.views.holdings_positions import render as render_holdings


def _titles(portfolio: Portfolio, **options: object) -> list[str]:
    payload = render_activity(portfolio, ActivityOptions(**options))  # pyright: ignore[reportArgumentType]
    return [entry.title for group in payload.groups for entry in group.entries]


def _symbols(portfolio: Portfolio, **options: object) -> list[str]:
    payload = render_holdings(portfolio, HoldingsPositionsOptions(**options))  # pyright: ignore[reportArgumentType]
    return [row.symbol for row in payload.positions]


@pytest.mark.parametrize(
    ("query", "expected"),
    [(None, ""), ("", ""), ("   ", ""), (" NvDa ", "nvda")],
    ids=["absent", "empty", "whitespace", "folded_and_stripped"],
)
def test_the_needle_is_folded_and_a_blank_one_is_no_filter(
    query: str | None, expected: str
) -> None:
    assert SearchOptions(query=query).needle == expected


def test_matches_keeps_everything_when_there_is_nothing_to_match() -> None:
    assert matches("", None) is True
    assert matches("voo", "VOO", None) is True
    assert matches("voo", None, "a memo") is False


def test_a_search_over_the_ledger_matches_the_symbol(portfolio: Portfolio) -> None:
    """AC-6: `query=nvda` keeps only the NVDA rows, in any case."""
    titles = _titles(portfolio, query="NvDa")
    assert titles == ["Bought 30 NVDA", "Bought 60 NVDA"]


def test_a_search_over_the_ledger_matches_the_memo(portfolio: Portfolio) -> None:
    """AC-6: the deposits' words are a domain field, so they are searchable."""
    assert _titles(portfolio, query="payroll") == ["Deposit — Payroll"] * 6
    assert _titles(portfolio, query="4021") == ["Deposit — Bank transfer"]


def test_the_chip_and_the_search_compose_with_and(portfolio: Portfolio) -> None:
    """AC-6: `Sells` plus `voo` is the VOO sale, not every sell and every VOO."""
    assert _titles(portfolio, kind="sell", query="voo") == ["Sold 20 VOO"]
    assert len(_titles(portfolio, query="voo")) > 1


def test_a_blank_search_over_the_ledger_returns_everything(
    portfolio: Portfolio,
) -> None:
    """AC-6: a focused-then-emptied field must show the list again."""
    assert len(_titles(portfolio, query="   ")) == len(_titles(portfolio))


def test_an_activity_search_that_matches_nothing_is_a_sentence_not_an_error(
    portfolio: Portfolio,
) -> None:
    """AC-8: an empty result is a successful render with words in it."""
    payload = render_activity(portfolio, ActivityOptions(query="zzzz"))

    assert payload.groups == ()
    assert payload.query == "zzzz"
    assert payload.empty == "No activity matches this filter."


def test_the_class_filter_keeps_one_asset_class(portfolio: Portfolio) -> None:
    """AC-7: the chips the payload ships are the ones that work."""
    assert [chip.key for chip in CLASS_FILTERS] == [
        "all",
        "equities",
        "bonds",
        "alternatives",
        "cash",
    ]
    assert [chip.label for chip in CLASS_FILTERS] == [
        "All",
        "Equities",
        "Bonds",
        "Alternatives",
        "Cash",
    ]
    assert _symbols(portfolio, asset_class="bonds") == ["BND", "AGG", "TIP"]
    assert _symbols(portfolio, asset_class="cash") == ["USD"]


def test_a_search_over_the_holdings_matches_the_symbol_and_the_name(
    portfolio: Portfolio,
) -> None:
    """AC-7: `vanguard` is in three display names and no ticker."""
    assert _symbols(portfolio, query="vanguard") == ["VOO", "BND", "VNQ"]
    assert _symbols(portfolio, query="nvda") == ["NVDA"]


def test_the_two_holdings_filters_compose_with_and(portfolio: Portfolio) -> None:
    assert _symbols(portfolio, asset_class="bonds", query="vanguard") == ["BND"]


def test_the_header_is_the_whole_portfolios_however_the_list_is_filtered(
    portfolio: Portfolio,
) -> None:
    """AC-7, the ruling in OD-4: a search narrows the list, never the total."""
    everything = render_holdings(portfolio, HoldingsPositionsOptions())
    narrowed = render_holdings(portfolio, HoldingsPositionsOptions(query="nvda"))

    assert narrowed.total == everything.total
    assert narrowed.gain == everything.gain
    (row,) = narrowed.positions
    original = next(p for p in everything.positions if p.symbol == "NVDA")
    assert row.weight == original.weight


def test_a_holdings_search_that_matches_nothing_is_a_sentence_not_an_error(
    portfolio: Portfolio,
) -> None:
    """AC-8, the Holdings half."""
    payload = render_holdings(portfolio, HoldingsPositionsOptions(query="zzzz"))

    assert payload.positions == ()
    assert payload.empty == EMPTY
    assert payload.total.amount.display == "$482,915.20"
