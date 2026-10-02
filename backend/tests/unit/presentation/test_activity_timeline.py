"""``activity.timeline.v1`` over the seeded ledger (spec 0028 AC-3..AC-6)."""

from datetime import date

import pytest

from app.domain.portfolio import Portfolio
from app.presentation.activity_entries import when_label
from app.presentation.activity_rows import (
    THIS_WEEK,
    TODAY,
    ActivityOptions,
    section_label,
)
from app.presentation.views.activity_timeline import (
    VIEW_ID,
    fitness,
    render,
    surface,
)

AS_OF = date(2026, 9, 18)


def _entries(portfolio: Portfolio, **options: object) -> list[tuple[str, str]]:
    payload = render(portfolio, ActivityOptions(**options))  # pyright: ignore[reportArgumentType]
    return [
        (group.label, entry.title)
        for group in payload.groups
        for entry in group.entries
    ]


def test_sections_run_from_today_through_the_week_into_the_months(
    portfolio: Portfolio,
) -> None:
    payload = render(portfolio, ActivityOptions())
    assert payload.view == VIEW_ID
    assert payload.kind == "all"
    assert [chip.label for chip in payload.filters] == [
        "All",
        "Buys",
        "Sells",
        "Staking",
        "Deposits",
    ]
    labels = [group.label for group in payload.groups]
    assert labels[:4] == [TODAY, THIS_WEEK, "SEPTEMBER 2026", "AUGUST 2026"]
    assert labels[-1] == "JULY 2024"


def test_each_kind_is_written_the_way_the_design_draws_it(portfolio: Portfolio) -> None:
    payload = render(portfolio, ActivityOptions())
    rows = {entry.key: entry for group in payload.groups for entry in group.entries}
    reward = rows["txn-0017"]
    assert (reward.title, reward.detail) == (
        "Staking — ETH",
        "$3,480.00/unit · 0.075 units · protocol reward",
    )
    assert (reward.amount.display, reward.tone, reward.badge) == (
        "+$261.00",
        "up",
        "Staking",
    )
    deposit = rows["txn-0033"]
    assert (deposit.title, deposit.detail) == (
        "Deposit — Transfer in",
        "Coinbase ••4021 · Wed",
    )
    assert (deposit.amount.display, deposit.tone) == ("+$5,000.00", "up")
    payroll = rows["txn-0034"]
    assert (payroll.title, payroll.detail) == ("Deposit — Payroll", "Recurring · Sep 4")
    buy = rows["txn-0009"]
    assert (buy.title, buy.detail) == ("Bought 12 ETH", "12 units @ $4,175.00 · Nov 22")
    assert (buy.amount.display, buy.tone, buy.badge) == ("-$50,100.00", "flat", "Buy")
    assert buy.realized is None and buy.term is None


@pytest.mark.parametrize(
    ("kind", "count"),
    [("buy", 9), ("staking_reward", 16), ("deposit", 9)],
    ids=["buys", "staking-rewards", "deposits"],
)
def test_the_filter_keeps_one_kind(portfolio: Portfolio, kind: str, count: int) -> None:
    payload = render(portfolio, ActivityOptions(kind=kind))  # pyright: ignore[reportArgumentType]
    entries = [entry for group in payload.groups for entry in group.entries]
    assert len(entries) == count
    assert {entry.kind for entry in entries} == {kind}
    assert payload.kind == kind


def test_the_limit_keeps_the_newest_rows(portfolio: Portfolio) -> None:
    assert len(_entries(portfolio, limit=3)) == 3
    assert [title for _, title in _entries(portfolio, limit=1)] == ["Staking — ETH"]


def test_the_labels_follow_the_locale(portfolio: Portfolio) -> None:
    payload = render(portfolio, ActivityOptions(locale="de-DE"))
    assert payload.groups[2].label == "SEPTEMBER 2026"
    assert payload.groups[1].entries[0].detail.endswith("· Mi")


def test_the_day_labels_step_from_today_to_the_month() -> None:
    assert section_label(AS_OF, as_of=AS_OF, locale="en-US") == TODAY
    assert when_label(AS_OF, as_of=AS_OF, locale="en-US") == "Today"
    assert when_label(date(2026, 9, 12), as_of=AS_OF, locale="en-US") == "Sat"
    assert when_label(date(2026, 9, 11), as_of=AS_OF, locale="en-US") == "Sep 11"


def test_surface_and_fitness(portfolio: Portfolio, empty_portfolio: Portfolio) -> None:
    drawn = surface(render(portfolio, ActivityOptions()))
    assert drawn.component == "ActivityTimeline"
    assert drawn.view == VIEW_ID
    assert drawn.title == "Activity"
    assert set(drawn.props) == {
        "note",
        "kind",
        "query",
        "empty",
        "filters",
        "groups",
    }
    assert fitness(portfolio) == 0 == fitness(empty_portfolio)
    assert render(empty_portfolio, ActivityOptions()).groups == ()
