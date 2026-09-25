"""How a holding period is worded (spec 0049 OD-2, AC-2).

Two claims, and the second is the one worth having. The first is the wording
itself. The second is that the **threshold is the tax rule's**, not a number
this module picked: ``core.period_display.LONG_TERM_DAYS`` is a copy, because
``core`` may not import ``domain``, and a copy nobody compares is the defect
`.claude/rules/ci-conventions.md` §5 keeps finding. So it is compared.
"""

import pytest

from app.core.period_display import LONG_TERM_DAYS, holding_period_display
from app.domain.terms import LONG_TERM_DAYS as DOMAIN_LONG_TERM_DAYS


def test_the_boundary_is_the_tax_rules_own() -> None:
    # The docstring in period_display.py claims these agree. This is what makes
    # the claim true rather than believed: change either one and the duration
    # starts contradicting the pill printed beside it.
    assert LONG_TERM_DAYS == DOMAIN_LONG_TERM_DAYS


@pytest.mark.parametrize(
    ("days", "expected"),
    [
        (0, "0 mo"),
        (364, "12 mo"),
        (365, "12 mo"),
        (366, "1.0 yr"),
        (400, "1.1 yr"),
    ],
    ids=[
        "acquired_today",
        "the_day_before_the_boundary",
        "on_the_boundary_is_still_months",
        "one_day_past_it_is_years",
        "just_over_a_year",
    ],
)
def test_holding_period_display_words_the_period(days: int, expected: str) -> None:
    assert holding_period_display(days) == expected


@pytest.mark.parametrize(
    ("days", "expected"),
    [(130, "4 mo"), (237, "8 mo"), (1497, "4.1 yr"), (2008, "5.5 yr")],
    ids=["4_mo", "8_mo", "4_1_yr", "5_5_yr"],
)
def test_the_artboards_own_four_strings_come_back(days: int, expected: str) -> None:
    """The units and the rounding came from the design, so they are held to it.

    These are the four durations the UI Kit frame draws
    (`specs/frontend/assets/0027-taxlot-uikit/`), with the day counts its lot
    dates imply at its `as_of`. The first draft of this rule printed days below
    the boundary and every one of them was wrong; ``8 mo`` is 7.8 average
    months, so it is also the case that pins the rounding — truncation answers
    ``7 mo`` here and only rounding draws what the designer drew.
    """
    assert holding_period_display(days) == expected


def test_holding_period_display_refuses_a_negative_period() -> None:
    # The domain refuses a lot dated after `as_of` long before this is reached,
    # so a negative here means a caller did its own arithmetic. A loud failure
    # beats a plausible "-1 mo" on a screen.
    with pytest.raises(ValueError, match="cannot be held for -1 days"):
        holding_period_display(-1)
