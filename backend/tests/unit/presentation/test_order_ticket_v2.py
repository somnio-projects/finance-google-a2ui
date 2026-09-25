"""Spec 0031 AC-1..AC-6 — ``order.ticket.v2`` over the seeded portfolio.

Every number is a literal: the render is pure and the market reference is
fixed, so a changed string is a changed contract. The figures that appear
together — a leg's shares, price and value; the total and the cash it leaves —
are asserted together, not only apart (`.claude/rules/backend/testing.md`).
"""

from app.domain.portfolio import Portfolio
from app.presentation.views.order_ticket_v2 import (
    VIEW_ID,
    OrderTicketV2Options,
    render,
)


def test_render_strikes_the_design_legs_at_the_seeded_prices(
    portfolio: Portfolio,
) -> None:
    """AC-2 — three legs, each with its units, price, value and weight."""
    payload = render(portfolio, OrderTicketV2Options())

    assert payload.view == VIEW_ID
    assert payload.title == "Draft order · Buy · 3 legs"
    assert (payload.badge, payload.side) == ("editable", "buy")
    assert [
        (
            line.key,
            line.name,
            line.quantity.display,
            line.price.display,
            line.notional.display,
            line.weight.display,
        )
        for line in payload.lines
    ] == [
        ("BTC", "Bitcoin", "0.06", "$64,250.00", "$3,855.00", "39.44%"),
        ("ETH", "Ethereum", "1", "$3,480.00", "$3,480.00", "35.61%"),
        ("SOL", "Solana", "16", "$152.40", "$2,438.40", "24.95%"),
    ]


def test_render_states_the_impact_pre_formatted(portfolio: Portfolio) -> None:
    """AC-5 — the panel: total, units, fees, cash and each group's shift."""
    impact = render(portfolio, OrderTicketV2Options()).impact

    assert (impact.total.label, impact.total.amount.display) == (
        "Total order",
        "$9,773.40",
    )
    assert (impact.units.label, impact.units.units.display) == ("Est. shares", "17.06")
    assert (impact.fees.label, impact.fees.amount.display) == (
        "Est. fees · sim",
        "$0.00",
    )
    assert impact.cash_remaining.amount.display == "$41,990.60"
    # Three groups, not one: the design's legs settle on three chains (0044).
    assert [
        (s.label, s.before.display, s.after.display) for s in impact.weight_shifts
    ] == [
        ("Portfolio weight · Bitcoin", "27.94%", "28.74%"),
        ("Portfolio weight · Ethereum", "49.49%", "50.21%"),
        ("Portfolio weight · Solana", "11.85%", "12.36%"),
    ]


def test_the_legs_option_is_echoed_under_its_own_name(portfolio: Portfolio) -> None:
    """AC-3 — the naming *is* the interactivity declaration (0019 OD-3)."""
    payload = render(portfolio, OrderTicketV2Options(legs="SOL:5,BTC:1"))

    assert payload.legs == "SOL:5,BTC:1"
    assert [line.symbol for line in payload.lines] == ["SOL", "BTC"]


def test_a_buy_within_cash_is_not_blocked(portfolio: Portfolio) -> None:
    """AC-6 — the fillable case declares `none` and carries no sentence."""
    constraints = render(portfolio, OrderTicketV2Options()).constraints

    assert constraints.max_cash.amount.display == "$51,764.00"
    assert constraints.breach == "none"
    assert constraints.shortfall is None
    assert constraints.message is None


def test_a_buy_beyond_cash_is_blocked_with_the_shortfall_written(
    portfolio: Portfolio,
) -> None:
    """AC-6 — the client reads a flag and a string; it subtracts nothing."""
    payload = render(portfolio, OrderTicketV2Options(legs="BTC:1.0,ETH:1.0,SOL:16"))

    assert payload.badge == "blocked"
    assert payload.impact.total.amount.display == "$70,168.40"
    assert payload.impact.cash_remaining.amount.display == "-$18,404.40"
    assert payload.constraints.breach == "over_cash"
    assert payload.constraints.shortfall is not None
    assert payload.constraints.shortfall.display == "$18,404.40"
    assert payload.constraints.message == (
        "Exceeds available cash — reduce order by $18,404.40."
    )


def test_a_sell_raises_cash_and_moves_the_group_down(portfolio: Portfolio) -> None:
    """OD-7 — the mirror; never blocked here."""
    payload = render(portfolio, OrderTicketV2Options(side="sell"))

    assert payload.title == "Draft order · Sell · 3 legs"
    assert payload.impact.cash_remaining.amount.display == "$61,537.40"
    assert payload.impact.weight_shifts[0].after.display == "27.14%"
    assert payload.constraints.breach == "none"


def test_render_formats_every_figure_under_the_requested_locale(
    portfolio: Portfolio,
) -> None:
    """Locale and precision are declared options like any other."""
    payload = render(portfolio, OrderTicketV2Options(locale="de-DE", precision=1))

    assert payload.impact.total.amount.display == "9.773,4 $"
    assert payload.lines[0].price.display == "64.250,00 $"
    assert payload.lines[0].weight.display == "39,4%"
