"""AC-1..AC-8 — ``order.ticket.v1`` over the seeded portfolio.

Every number asserted here is a literal: the render is pure and the market
reference is fixed, so a changed string is a changed contract. The payload
puts a quantity, a price and a notional next to one another, so the
relationships between them are asserted too, not only the parts
(`.claude/rules/backend/testing.md`).
"""

from decimal import Decimal
from typing import get_args

import pytest

from app.domain.market import MARKET_REFERENCE
from app.domain.portfolio import Portfolio
from app.presentation.order_sizing import LABELS, OrderTicketOptions, Symbol
from app.presentation.registry import REGISTRY
from app.presentation.views.order_ticket import (
    DISCLOSURE,
    EFFECT,
    PROJECTION,
    VIEW_ID,
    fitness,
    render,
    surface,
)


def test_the_symbols_a_ticket_offers_are_exactly_the_market_reference() -> None:
    """AC-6 — two declarations of one fact, compared instead of trusted."""
    assert set(get_args(Symbol)) == {asset.symbol for asset in MARKET_REFERENCE}


def test_render_prices_the_default_order_from_the_market_reference(
    portfolio: Portfolio,
) -> None:
    """AC-2 — one unit of the first curated asset, priced and formatted."""
    payload = render(portfolio, OrderTicketOptions())

    assert payload.view == VIEW_ID
    assert (payload.symbol, payload.name, payload.side) == (
        "NVDA",
        "NVIDIA Corp",
        "buy",
    )
    assert payload.quantity.display == "1"
    assert payload.entry_price.display == "$1,204.66"
    assert payload.notional.amount.display == "$1,204.66"


def test_a_dollar_size_is_divided_by_the_price_here_not_by_the_model(
    portfolio: Portfolio,
) -> None:
    """AC-3 — `size_in="usd"` states the units, and the notional closes on it."""
    payload = render(
        portfolio, OrderTicketOptions(symbol="XOM", size="500", size_in="usd")
    )

    assert payload.quantity.display == "14.6113384"
    assert payload.entry_price.display == "$34.22"
    assert payload.notional.amount.display == "$500.00"


def test_the_three_figures_printed_together_multiply_back_to_one_another(
    portfolio: Portfolio,
) -> None:
    """AC-4 — a reader multiplies across the row, so the row must survive it."""
    payload = render(
        portfolio, OrderTicketOptions(symbol="XOM", size="500", size_in="usd")
    )
    shown_units = Decimal(payload.quantity.display)
    shown_price = Decimal(payload.entry_price.display.removeprefix("$"))

    assert round(shown_units * shown_price, 2) == Decimal("500.00")


def test_an_order_for_nothing_renders_an_empty_ticket_rather_than_an_error(
    portfolio: Portfolio,
) -> None:
    """AC-5 — the published pattern admits `0`, so the render must too."""
    payload = render(portfolio, OrderTicketOptions(size="0"))

    assert payload.quantity.display == "0"
    assert payload.notional.amount.display == "$0.00"


def test_render_formats_every_figure_under_the_requested_locale(
    portfolio: Portfolio,
) -> None:
    """AC-7 — locale and precision are declared options like any other."""
    payload = render(
        portfolio, OrderTicketOptions(symbol="AAPL", locale="de-DE", precision=4)
    )

    assert payload.notional.amount.display == "233,1800 $"


def test_the_inputs_are_the_declared_options_with_their_current_values(
    portfolio: Portfolio,
) -> None:
    """AC-5 — editing is re-rendering, so the payload names the options."""
    payload = render(portfolio, OrderTicketOptions(symbol="VOO", side="sell"))

    assert [field.option for field in payload.inputs] == list(LABELS)
    assert [field.label for field in payload.inputs] == list(LABELS.values())
    by_option = {field.option: field for field in payload.inputs}
    assert by_option["symbol"].value == "VOO"
    assert by_option["side"].value == "sell"
    assert by_option["side"].choices == ("buy", "sell")
    assert by_option["size"].control == "text"


def test_the_ticket_declares_one_effect_and_no_way_to_place_an_order(
    portfolio: Portfolio,
) -> None:
    """AC-8 — there is no broker here, and the payload must not imply one."""
    payload = render(portfolio, OrderTicketOptions())
    props = surface(payload).props

    assert payload.effect == EFFECT == "recalculate"
    assert "broker" in DISCLOSURE and "nothing is ever sent" in DISCLOSURE
    assert set(payload.model_dump()).isdisjoint({"submit", "action", "order_id"})
    assert set(props).isdisjoint({"submit", "onSubmit", "endpoint", "href"})


def test_surface_maps_the_payload_onto_the_ticket_component(
    portfolio: Portfolio,
) -> None:
    """AC-9 — one adapter per projection, so a genui bump stays contained."""
    payload = render(portfolio, OrderTicketOptions())
    emitted = surface(payload)

    assert (emitted.component, emitted.view) == ("OrderTicket", VIEW_ID)
    assert emitted.props["entryPrice"]["display"] == "$1,204.66"
    assert [field["option"] for field in emitted.props["inputs"]] == list(LABELS)


@pytest.mark.parametrize("subject", ["seeded", "empty"], ids=["seeded", "empty"])
def test_the_ticket_is_never_chosen_by_the_selection_rule(
    subject: str, portfolio: Portfolio, empty_portfolio: Portfolio
) -> None:
    """AC-10 — a ticket answers an intent, never a shape of data."""
    assert fitness(portfolio if subject == "seeded" else empty_portfolio) == 0


def test_the_projection_is_registered_and_renders_its_own_example() -> None:
    """AC-1 — removing the `register(...)` call must turn this red."""
    assert REGISTRY.get(VIEW_ID) is PROJECTION
    assert PROJECTION.example["view"] == VIEW_ID
