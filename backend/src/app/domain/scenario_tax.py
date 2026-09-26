"""An estimated tax on a simulated sale, at rates the caller states (spec 0051).

The redesign's Comparison centres on two rows this product did not have:
**Est. tax** and **Net after tax**, with a footer claiming one method *"saves
$2,240 in tax"*. The arithmetic is trivial; the inputs are not. A rate implies
a taxpayer — a jurisdiction, a filing status, a bracket — and none of that is
in the seed, the domain or the contract (GGU-134).

So the rate is **not invented, it is declared**: two bounded options with
stated defaults, printed on the card as a sentence the reader can check
(spec 0051 OD-1). The figure is then honest for whoever set it, and honest
about being illustrative for everyone else. The alternative — a rate hardcoded
in a presenter with no disclosure — is the defect this repository catalogues,
applied to money somebody might act on.

**Only gains are taxed.** A realised loss is not a refund: this demo knows
nothing about the other disposals it could offset, or about the wash-sale rule
it explicitly declines to model. Taxing a loss at a negative rate would invent
a second claim to hide the first.
"""

from dataclasses import dataclass
from decimal import Decimal
from typing import Final

from app.domain.money import ZERO

#: An illustrative short-term rate. Chosen to be recognisable rather than
#: authoritative, and printed on the card beside the figure it produces.
DEFAULT_SHORT_RATE: Final[Decimal] = Decimal("0.35")
#: The illustrative long-term rate, and the reason the split matters at all.
DEFAULT_LONG_RATE: Final[Decimal] = Decimal("0.15")
#: The bound the options publish. Above this a "rate" is not a tax rate.
MAX_RATE: Final[Decimal] = Decimal("0.60")
#: What a rate may look like on the wire: zero to just under one, four
#: decimals. **Here** rather than in the options model, because both the
#: projection's options and the read endpoint's query model publish it and two
#: spellings of one bound is where they drift.
RATE_PATTERN: Final[str] = r"^0(\.[0-9]{1,4})?$"


@dataclass(frozen=True, slots=True)
class TaxRates:
    """The two rates one render is costed at, as the caller declared them."""

    short_term: Decimal
    long_term: Decimal


def estimated_tax(
    *, short_term_pl: Decimal, long_term_pl: Decimal, rates: TaxRates
) -> Decimal:
    """Return the tax the two halves of a realised result would attract.

    Args:
        short_term_pl: The part realised on lots held a year or less.
        long_term_pl: The part realised on lots held longer.
        rates: The declared rates for this render.

    Returns:
        The exact, unrounded figure. Each half is taxed only when it is a
        **gain**; a loss contributes nothing rather than a credit.
    """
    short = short_term_pl * rates.short_term if short_term_pl > ZERO else ZERO
    long_term = long_term_pl * rates.long_term if long_term_pl > ZERO else ZERO
    return short + long_term


def net_after_tax(realized_pl: Decimal, tax: Decimal) -> Decimal:
    """Return what is left of ``realized_pl`` once ``tax`` is taken."""
    return realized_pl - tax


__all__ = [
    "DEFAULT_LONG_RATE",
    "DEFAULT_SHORT_RATE",
    "MAX_RATE",
    "RATE_PATTERN",
    "TaxRates",
    "estimated_tax",
    "net_after_tax",
]
