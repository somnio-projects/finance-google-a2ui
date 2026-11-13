"""What a model's tokens cost, by date (spec 0058 §3.1).

One declared, versioned table and one pure function. The table is read by a
person from the Google AI Studio pricing page (Standard tier) and written here
with the date it was read as ``PRICE_TABLE_VERSION``; a price change is an
edit to this file and a bump of that string, in a reviewed PR.

**The date is an argument.** A price band is chosen by the turn's own date,
which the caller takes from the injected ``Clock`` — this module never reads a
clock. The first band of every model starts at ``OPEN_BAND`` because the
table records when we *read* a price, not when Google *set* it: a turn dated
before the reading is priced at the earliest known rate rather than not at all.

**Thinking is output.** Gemini bills ``thoughtsTokenCount`` at the output rate,
and ``cachedContentTokenCount`` is a part of ``promptTokenCount`` billed at the
cached rate:

    cost = (prompt - cached)·in + cached·cachedIn + (candidates + thoughts)·out
"""

from collections.abc import Mapping
from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from typing import Final

from app.core.model_usage import TokenUsage

#: When the table below was read off the pricing page.
PRICE_TABLE_VERSION: Final[str] = "2026-11-13"
#: The start of every model's first band (see the module docstring).
OPEN_BAND: Final[date] = date.min
#: Prices are quoted per this many tokens.
PER_TOKENS: Final[Decimal] = Decimal(1_000_000)


@dataclass(frozen=True, slots=True)
class TokenPrices:
    """One price band of one model, in USD per ``PER_TOKENS`` tokens."""

    effective_from: date
    input: Decimal
    cached_input: Decimal
    output: Decimal


PRICES: Final[Mapping[str, tuple[TokenPrices, ...]]] = {
    "gemini-3.8-flash": (
        TokenPrices(
            effective_from=OPEN_BAND,
            input=Decimal("0.75"),
            cached_input=Decimal("0.075"),
            output=Decimal("3.75"),
        ),
        TokenPrices(
            effective_from=date(2027, 1, 1),
            input=Decimal("1.50"),
            cached_input=Decimal("0.15"),
            output=Decimal("7.50"),
        ),
    ),
}


def prices_for(model: str, *, on: date) -> TokenPrices | None:
    """Return the band of ``model`` in force on ``on``, or None when unpriced."""
    bands = PRICES.get(model, ())
    current = [band for band in bands if band.effective_from <= on]
    return current[-1] if current else None


def estimate_cost(model: str, usage: TokenUsage, *, on: date) -> Decimal | None:
    """Estimate what ``usage`` cost on ``model``, in USD.

    Args:
        model: The model id the calls were made against.
        usage: The summed token counts.
        on: The date the calls were made, from the injected clock.

    Returns:
        The exact ``Decimal`` estimate; ``0`` when nothing was billed, for any
        model; None when tokens were billed against a model with no price.
    """
    if usage.billed_calls == 0:
        return Decimal(0)
    band = prices_for(model, on=on)
    if band is None:
        return None
    cached = min(usage.cached, usage.prompt)
    spent = (
        (usage.prompt - cached) * band.input
        + cached * band.cached_input
        + (usage.candidates + usage.thoughts) * band.output
    )
    return spent / PER_TOKENS


__all__ = [
    "OPEN_BAND",
    "PER_TOKENS",
    "PRICES",
    "PRICE_TABLE_VERSION",
    "TokenPrices",
    "estimate_cost",
    "prices_for",
]
