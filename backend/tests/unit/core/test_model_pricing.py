"""Spec 0058 AC-5/AC-6/AC-7 — the price table and the cost it implies."""

from datetime import date
from decimal import Decimal

import pytest

from app.core.model_pricing import (
    OPEN_BAND,
    PRICE_TABLE_VERSION,
    PRICES,
    estimate_cost,
    prices_for,
)
from app.core.model_usage import ZERO_USAGE, TokenUsage

FLASH = "gemini-3.8-flash"
BEFORE_RISE = date(2026, 12, 31)
AFTER_RISE = date(2027, 1, 1)

#: One million of each kind, so every term of the formula is its own price.
MILLION = TokenUsage(
    prompt=3_000_000,
    cached=1_000_000,
    candidates=1_000_000,
    thoughts=1_000_000,
    total=5_000_000,
    billed_calls=2,
)


@pytest.mark.parametrize(
    ("on", "expected"),
    [
        # 2M uncached · 0.75 + 1M cached · 0.075 + 2M output · 3.75
        (BEFORE_RISE, Decimal("9.075")),
        # 2M · 1.50 + 1M · 0.15 + 2M · 7.50
        (AFTER_RISE, Decimal("18.15")),
    ],
    ids=["until-2026-12-31", "from-2027-01-01"],
)
def test_estimate_cost_applies_the_band_of_the_given_date(
    on: date, expected: Decimal
) -> None:
    assert estimate_cost(FLASH, MILLION, on=on) == expected


def test_estimate_cost_bills_thinking_at_the_output_rate() -> None:
    thinking = TokenUsage(thoughts=1_000_000, billed_calls=1)
    output = TokenUsage(candidates=1_000_000, billed_calls=1)

    assert estimate_cost(FLASH, thinking, on=BEFORE_RISE) == Decimal("3.75")
    assert estimate_cost(FLASH, thinking, on=BEFORE_RISE) == estimate_cost(
        FLASH, output, on=BEFORE_RISE
    )


def test_estimate_cost_of_a_small_turn_is_exact_in_decimal() -> None:
    turn = TokenUsage(
        prompt=4210, cached=0, candidates=312, thoughts=488, billed_calls=2
    )

    # 4210 · 0.75 / 1M + 800 · 3.75 / 1M = 0.0031575 + 0.003
    assert estimate_cost(FLASH, turn, on=BEFORE_RISE) == Decimal("0.0061575")


def test_estimate_cost_never_bills_cached_tokens_beyond_the_prompt() -> None:
    odd = TokenUsage(prompt=1_000_000, cached=2_000_000, billed_calls=1)

    assert estimate_cost(FLASH, odd, on=BEFORE_RISE) == Decimal("0.075")


def test_estimate_cost_of_an_unknown_model_with_billed_tokens_is_none() -> None:
    assert estimate_cost("gemini-invented", MILLION, on=BEFORE_RISE) is None


@pytest.mark.parametrize(
    "model", [FLASH, "gemini-invented", "scripted"], ids=["priced", "unknown", "fake"]
)
def test_estimate_cost_of_nothing_billed_is_zero_for_any_model(model: str) -> None:
    assert estimate_cost(model, ZERO_USAGE, on=BEFORE_RISE) == Decimal(0)


def test_prices_for_an_unknown_model_is_none() -> None:
    assert prices_for("gemini-invented", on=BEFORE_RISE) is None


def test_prices_for_a_date_before_any_reading_is_the_open_band() -> None:
    band = prices_for(FLASH, on=date(2020, 1, 1))

    assert band is not None
    assert band.effective_from == OPEN_BAND


def test_the_price_table_is_well_formed() -> None:
    """AC-7 — over the whole table, so the next model is checked the day it lands."""
    assert PRICE_TABLE_VERSION == "2026-11-13"
    assert PRICES, "an empty table would make every check below vacuous"
    for model, bands in PRICES.items():
        assert bands[0].effective_from == OPEN_BAND, model
        starts = [band.effective_from for band in bands]
        assert starts == sorted(set(starts)), model
        for band in bands:
            assert min(band.input, band.cached_input, band.output) >= 0, model
            assert band.cached_input <= band.input, model
