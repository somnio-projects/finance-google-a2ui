"""The footer total says which way it points (spec 0049 AC-3, OD-4).

Asserted against ``realized_total`` directly, because the case worth having —
a sub-cent loss that prints ``$0.00`` — is one no scenario the seeded portfolio
can satisfy produces, and a branch only reachable through the seed is a branch
that ships unexercised.
"""

from decimal import Decimal

import pytest

from app.domain.sale_results import SaleSimulation
from app.presentation.options import DisplayOptions
from app.presentation.taxlot_render import realized_total

#: The options every figure in this file is formatted under unless a test
#: overrides them, so a precision change is one line rather than many.
DEFAULTS = DisplayOptions()

#: An arbitrary basis large enough that every realised figure below leaves
#: `proceeds` non-negative, which pydantic requires of both.
BASIS = Decimal(1000)


def _sale_realising(realized: Decimal) -> SaleSimulation:
    """A simulation whose only interesting field is what it realised.

    The other figures are consistent with it but not the subject: `closes()` is
    a method the domain's own tests exercise, not a validator, so nothing here
    depends on them beyond being valid.
    """
    return SaleSimulation(
        symbol="BTC",
        price=Decimal(1),
        quantity=Decimal(1),
        # The basis is the fixed side: `proceeds` and `cost_basis` are both
        # bounded at zero, so moving the basis to reach a gain would build an
        # invalid simulation rather than an interesting one.
        proceeds=BASIS + realized,
        cost_basis=BASIS,
        realized_pl=realized,
        remaining_quantity=Decimal(0),
        remaining_cost_basis=Decimal(0),
        remaining_lots=0,
        consumed=(),
    )


@pytest.mark.parametrize(
    ("realized", "expected_direction", "expected_display"),
    [
        (Decimal("120.00"), "up", "+$120.00"),
        (Decimal("-120.00"), "down", "-$120.00"),
        (Decimal("-0.004"), "flat", "$0.00"),
    ],
    ids=["a_gain_points_up", "a_loss_points_down", "a_half_cent_loss_is_flat"],
)
def test_the_footer_total_points_the_way_its_string_reads(
    realized: Decimal, expected_direction: str, expected_display: str
) -> None:
    """AC-3 — `direction` is decided from the **rounded** figure (0049 OD-4).

    The third case is the one worth the parametrize. A loss of four tenths of a
    cent prints `$0.00`, and a red total beside a zero is a contradiction the
    reader has no way to resolve (spec 0011 AC-6). Asserted here rather than
    through `render`, because no scenario the seeded portfolio can satisfy
    realises a sub-cent result — the case would otherwise ship unexercised.
    """
    total = realized_total(_sale_realising(realized), DEFAULTS)

    assert total.direction == expected_direction
    assert total.amount.display == expected_display
    assert total.label == "Realised P/L"
