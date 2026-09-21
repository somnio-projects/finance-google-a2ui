"""AC-4 — ``holdings.allocation.v1`` rendered over the seeded portfolio.

Every number asserted here is a literal, because the render is pure and the
portfolio is seeded at a frozen ``as_of``: if one of these strings changes,
the payload a widget binds changed, and that is a contract change.
"""

from decimal import Decimal

import pytest

from app.domain.portfolio import Portfolio
from app.presentation.views.holdings_allocation import (
    OTHER_KEY,
    VIEW_ID,
    HoldingsAllocationOptions,
    HoldingsAllocationPayload,
    fitness,
    render,
    surface,
)


def test_render_lists_one_category_per_holding(portfolio: Portfolio) -> None:
    payload = render(portfolio, HoldingsAllocationOptions(top_n=20))
    assert payload.view == VIEW_ID
    assert [category.key for category in payload.categories] == [
        "BTC",
        "ETH",
        "SOL",
        "LINK",
        "DOGE",
    ]
    assert payload.total.amount.display == "$65,038.60"


def test_every_number_is_displayed_next_to_its_exact_decimal(
    portfolio: Portfolio,
) -> None:
    payload = render(portfolio, HoldingsAllocationOptions())
    btc = payload.categories[0]
    assert btc.value.display == "$38,550.00"
    assert btc.value.amount == Decimal("38550.000000")  # exact, unrounded
    assert btc.weight.display == "59.27%"
    assert btc.weight.value > Decimal("0.59")


def test_render_honours_top_n_with_a_residual_bucket(portfolio: Portfolio) -> None:
    payload = render(portfolio, HoldingsAllocationOptions(top_n=2))
    assert [category.key for category in payload.categories] == ["BTC", "ETH", "other"]
    residual = payload.categories[-1]
    assert residual.key == OTHER_KEY
    assert residual.value.display == "$10,586.10"
    assert residual.weight.display == "16.28%"


def test_render_drops_the_residual_bucket_when_not_wanted(
    portfolio: Portfolio,
) -> None:
    payload = render(portfolio, HoldingsAllocationOptions(top_n=2, include_other=False))
    assert [category.key for category in payload.categories] == ["BTC", "ETH"]
    assert payload.total.amount.display == "$65,038.60"  # the total still counts all


def test_render_adds_no_residual_when_nothing_is_left_over(
    portfolio: Portfolio,
) -> None:
    payload = render(portfolio, HoldingsAllocationOptions(top_n=20))
    assert OTHER_KEY not in {category.key for category in payload.categories}


@pytest.mark.parametrize(
    ("sort", "expected"),
    [
        ("value_desc", ["BTC", "ETH", "SOL"]),
        ("value_asc", ["DOGE", "LINK", "SOL"]),
        ("label", ["Bitcoin", "Chainlink", "Dogecoin"]),
    ],
    ids=["value_desc", "value_asc", "label"],
)
def test_render_honours_sort(
    portfolio: Portfolio, sort: str, expected: list[str]
) -> None:
    payload = render(
        portfolio,
        HoldingsAllocationOptions(sort=sort, top_n=3, include_other=False),  # pyright: ignore[reportArgumentType]
    )
    field = "label" if sort == "label" else "key"
    assert [getattr(row, field) for row in payload.categories] == expected


def test_render_honours_precision(portfolio: Portfolio) -> None:
    payload = render(portfolio, HoldingsAllocationOptions(precision=0, top_n=1))
    assert payload.categories[0].value.display == "$38,550"
    assert payload.categories[0].weight.display == "59%"


def test_surface_maps_the_payload_onto_the_donut(portfolio: Portfolio) -> None:
    payload = render(portfolio, HoldingsAllocationOptions(top_n=1))
    rendered = surface(payload)
    assert rendered.component == "HoldingsSummary"
    assert rendered.view == VIEW_ID
    assert rendered.props["center"]["amount"]["display"] == "$65,038.60"
    assert rendered.props["slices"][0]["label"] == "Bitcoin"


def test_fitness_scores_one_for_any_portfolio_with_holdings(
    portfolio: Portfolio, empty_portfolio: Portfolio
) -> None:
    assert fitness(portfolio) == 1
    assert fitness(empty_portfolio) == 0


def test_payload_declares_its_discriminator_literal() -> None:
    assert HoldingsAllocationPayload.model_fields["view"].default == VIEW_ID
