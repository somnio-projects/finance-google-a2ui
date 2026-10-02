"""What a caller may ask a scenario comparison for, and how it resolves.

The options model and the rules that turn its two ``None`` defaults into a
concrete scenario. They sit together because they are one contract: the
defaults are only honest if the rule behind each of them is written next to
the field that documents it.

``symbol`` and ``quantity`` are **scalar** and ``methods`` is the only list, so
a card comparing two symbols or two sale sizes cannot be *expressed* — the
refusal is structural rather than validated (spec 0017 OD-3).
"""

from decimal import Decimal
from typing import Annotated, Final

from pydantic import Field, field_validator

from app.domain.lot_selection import LotMethod
from app.domain.scenario_tax import (
    DEFAULT_LONG_RATE,
    DEFAULT_SHORT_RATE,
    MAX_RATE,
    RATE_PATTERN,
    TaxRates,
)
from app.domain.symbols import Ticker
from app.presentation.options import DisplayOptions

#: One column per method the domain offers. Derived from the enum, so a fourth
#: method raises the cap in the commit that adds it, never in a different one.
MAX_SCENARIOS: Final[int] = len(LotMethod)
DEFAULT_METHODS: Final[tuple[LotMethod, ...]] = tuple(LotMethod)
#: Twelve integer digits — the ceiling the sale tool bounds a size with.
MAX_QUANTITY: Final[Decimal] = Decimal(10) ** 12

Units = Annotated[Decimal, Field(gt=0, le=MAX_QUANTITY, decimal_places=8)]


class ScenarioComparisonOptions(DisplayOptions):
    """Declared knobs of ``scenario.comparison.v1``; nothing else is accepted."""

    symbol: Ticker | None = Field(
        default=None,
        description=(
            "Position to cost the sale against, in any case; omit for the one "
            "whose open tax lots are worth the most, ties broken by ticker."
        ),
        examples=["BTC"],
    )
    quantity: Units | None = Field(
        default=None,
        description=(
            "Units the sale disposes of; omit for that position's smallest "
            "open lot — the smallest sale that still makes the methods differ."
        ),
        examples=["0.18"],
    )
    methods: tuple[LotMethod, ...] = Field(
        default=DEFAULT_METHODS,
        min_length=2,
        max_length=MAX_SCENARIOS,
        description=(
            "Lot-selection methods to compare, in the order they are shown. At "
            "least two, all distinct — two identical columns would claim a "
            "difference that does not exist."
        ),
        examples=[["FIFO", "HIFO"]],
    )

    short_term_rate: str = Field(
        default=str(DEFAULT_SHORT_RATE),
        pattern=RATE_PATTERN,
        description=(
            "Rate applied to the short-term part of a gain, as a decimal "
            "string. A **declared assumption**, printed on the card beside "
            "the figure it produces — this demo knows no taxpayer, so a rate "
            "nobody chose would be a tax claim nobody could check (GGU-134)."
        ),
        examples=["0.35"],
    )
    long_term_rate: str = Field(
        default=str(DEFAULT_LONG_RATE),
        pattern=RATE_PATTERN,
        description=(
            "Rate applied to the long-term part of a gain, as a decimal "
            "string. The reason the short/long split is worth showing."
        ),
        examples=["0.15"],
    )
    include_wait: bool = Field(
        default=False,
        description=(
            "Add the *Wait for long-term* column: the same sale past every "
            "lot's first anniversary, so all of it is long-term. It varies "
            "the timing, not the lot ordering, and it holds the price still."
        ),
        examples=[True],
    )

    def rates(self) -> TaxRates:
        """The declared rates for this render, as exact decimals."""
        return TaxRates(
            short_term=Decimal(self.short_term_rate),
            long_term=Decimal(self.long_term_rate),
        )

    @field_validator("short_term_rate", "long_term_rate")
    @classmethod
    def _within_bound(cls, value: str) -> str:
        """Reject a rate above the published bound.

        The pattern admits four decimals but cannot state a maximum, so the
        bound is said here — as the option's own error, so both callers see a
        422 naming the field (ADR-K D-3).
        """
        if Decimal(value) > MAX_RATE:
            msg = f"rate must not exceed {MAX_RATE}"
            raise ValueError(msg)
        return value

    @field_validator("methods")
    @classmethod
    def _distinct(cls, value: tuple[LotMethod, ...]) -> tuple[LotMethod, ...]:
        """Reject a repeated method rather than silently deduplicating it."""
        if len(set(value)) != len(value):
            msg = "methods must be distinct"
            raise ValueError(msg)
        return value


__all__ = ["ScenarioComparisonOptions"]
