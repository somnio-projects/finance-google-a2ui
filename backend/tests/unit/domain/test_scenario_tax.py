"""Spec 0051 — an estimated tax at rates the caller declares (GGU-134)."""

from decimal import Decimal

import pytest

from app.domain.money import ZERO
from app.domain.scenario_tax import (
    DEFAULT_LONG_RATE,
    DEFAULT_SHORT_RATE,
    TaxRates,
    estimated_tax,
    net_after_tax,
)

RATES = TaxRates(short_term=DEFAULT_SHORT_RATE, long_term=DEFAULT_LONG_RATE)


def test_each_half_is_taxed_at_its_own_rate() -> None:
    """AC-1 — the short/long split is the whole reason two rates exist."""
    tax = estimated_tax(
        short_term_pl=Decimal(1000), long_term_pl=Decimal(1000), rates=RATES
    )

    assert tax == Decimal(1000) * DEFAULT_SHORT_RATE + Decimal(1000) * DEFAULT_LONG_RATE


@pytest.mark.parametrize(
    ("short", "long_term"),
    [(Decimal(-500), Decimal(1000)), (Decimal(1000), Decimal(-500))],
)
def test_a_loss_is_not_a_refund(short: Decimal, long_term: Decimal) -> None:
    """AC-1 — only gains are taxed; a negative half contributes nothing.

    Taxing a loss at a negative rate would invent a second claim — about
    offsets this demo cannot see — to soften the first.
    """
    tax = estimated_tax(short_term_pl=short, long_term_pl=long_term, rates=RATES)
    gain = max(short, ZERO) + max(long_term, ZERO)

    assert tax > ZERO
    assert tax < gain


def test_a_loss_on_both_halves_is_taxed_at_nothing() -> None:
    """AC-1 — a sale at a loss owes nothing, and is not owed anything."""
    assert (
        estimated_tax(
            short_term_pl=Decimal(-100), long_term_pl=Decimal(-200), rates=RATES
        )
        == ZERO
    )


def test_holding_longer_is_never_dearer() -> None:
    """AC-1 — the property the *Wait for long-term* column exists to show.

    Asserted as a relationship over the same realised result rather than as a
    pair of literals: whatever the figure is, moving a gain from the short
    half to the long half cannot raise the tax while the long rate is the
    lower one.
    """
    realized = Decimal(5000)
    now = estimated_tax(short_term_pl=realized, long_term_pl=ZERO, rates=RATES)
    waited = estimated_tax(short_term_pl=ZERO, long_term_pl=realized, rates=RATES)

    assert waited < now


def test_net_is_what_the_tax_leaves() -> None:
    """AC-1 — one subtraction, in the domain, so no client performs it."""
    assert net_after_tax(Decimal(1000), Decimal(350)) == Decimal(650)
