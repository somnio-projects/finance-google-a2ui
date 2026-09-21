"""Spec 0026 OD-2 — the donut's rows, grouped three ways, as the design prints them."""

from decimal import Decimal

from app.domain.portfolio import Portfolio
from app.presentation.allocation_rows import OTHER_KEY, rows_for
from app.presentation.views.holdings_allocation import (
    HoldingsAllocationOptions,
    render,
    surface,
)


def _rows(portfolio: Portfolio, **kwargs: object):
    options = HoldingsAllocationOptions(**kwargs)  # pyright: ignore[reportArgumentType]
    return rows_for(
        portfolio.holdings(),
        group_by=options.group_by,
        sort=options.sort,
        top_n=options.top_n,
        include_other=options.include_other,
        digits=options.precision,
        locale=options.locale,
    )


def test_asset_classes_read_exactly_as_the_home_card_prints_them(
    portfolio: Portfolio,
) -> None:
    """Equities 62% $299,407 ▲ +0.9% · Bonds 18% $86,925 ▼ -0.2% · …"""
    rows = _rows(portfolio, group_by="asset_class", precision=0)
    assert [
        (r.label, r.weight.display, r.value.display, r.change.display, r.trend)
        for r in rows
    ] == [
        ("Equities", "62%", "$299,407", "+0.9%", "up"),
        ("Bonds", "18%", "$86,925", "-0.2%", "down"),
        ("Cash", "8%", "$38,633", "0.0%", "flat"),
        ("Alternatives", "12%", "$57,950", "+1.4%", "up"),
    ]


def test_sectors_are_the_six_the_design_names_and_sum_to_the_equities(
    portfolio: Portfolio,
) -> None:
    rows = _rows(portfolio, group_by="sector", precision=0)
    assert [r.label for r in rows] == [
        "Technology",
        "Financials",
        "Healthcare",
        "Consumer",
        "Energy",
        "Other",
    ]
    assert sum((r.weight.value for r in rows), Decimal(0)) == Decimal(1)


def test_grouped_rows_ignore_sort_and_the_other_bucket(portfolio: Portfolio) -> None:
    """A class has a place the reader expects it in; `Cash` is never folded away."""
    rows = _rows(portfolio, group_by="asset_class", sort="value_asc", top_n=1)
    assert [r.key for r in rows] == ["equities", "bonds", "cash", "alternatives"]
    assert OTHER_KEY not in {r.key for r in rows}


def test_holding_rows_still_sort_trim_and_fold_the_rest_into_other(
    portfolio: Portfolio,
) -> None:
    rows = _rows(portfolio, top_n=3)
    assert [r.key for r in rows] == ["NVDA", "AAPL", "GLD", OTHER_KEY]
    other = rows[-1]
    assert other.label == "Other"
    assert other.change.display.endswith("%")
    assert _rows(portfolio, top_n=3, include_other=False)[-1].key == "GLD"
    assert [
        r.label for r in _rows(portfolio, sort="label", top_n=2, include_other=False)
    ] == [
        "Apple Inc.",
        "Cash & sweep",
    ]


def test_every_holding_row_carries_its_own_day_change(portfolio: Portfolio) -> None:
    by_key = {r.key: r for r in _rows(portfolio, top_n=20)}
    assert by_key["NVDA"].change.display == "+4.2%"
    assert by_key["USD"].change.display == "0.0%"
    assert by_key["USD"].trend == "flat"


def test_render_by_class_is_the_design_card(portfolio: Portfolio) -> None:
    payload = render(
        portfolio, HoldingsAllocationOptions(group_by="asset_class", precision=0)
    )
    assert payload.title == "Holdings & allocation"
    assert payload.group_by == "asset_class"
    assert (payload.center.count, payload.center.unit) == ("4", "Classes")
    gain = payload.total_gain
    assert gain is not None
    assert (gain.amount.display, gain.percent.display, gain.trend, gain.period) == (
        "+$61,204",
        "+14.5%",
        "up",
        "all-time",
    )


def test_headline_off_drops_the_gain_block_and_the_adapter_says_so(
    portfolio: Portfolio,
) -> None:
    payload = render(portfolio, HoldingsAllocationOptions(headline=False))
    assert payload.total_gain is None
    assert surface(payload).props["totalGain"] is None
    on = surface(render(portfolio, HoldingsAllocationOptions()))
    assert on.props["totalGain"]["period"] == "all-time"
    assert on.props["groupBy"] == "holding"
    assert on.props["center"] == {"count": "14", "unit": "Holdings"}


def test_sector_center_counts_sectors(portfolio: Portfolio) -> None:
    payload = render(portfolio, HoldingsAllocationOptions(group_by="sector"))
    assert (payload.center.count, payload.center.unit) == ("6", "Sectors")
