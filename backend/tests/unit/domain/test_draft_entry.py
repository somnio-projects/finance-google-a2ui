"""Spec 0054 AC-1 — the entry template leaves exactly one hole."""

import re
from decimal import Decimal

import pytest

from app.domain.draft_entry import UNITS_PLACEHOLDER, entry_template
from app.domain.draft_legs import LEGS_PATTERN, LegRequest, parse_legs

pytestmark = pytest.mark.unit

LEGS = (
    LegRequest(symbol="BTC", quantity=Decimal("0.6")),
    LegRequest(symbol="ETH", quantity=Decimal("1.0")),
)


def test_the_typed_leg_is_the_only_hole() -> None:
    assert entry_template(LEGS, "BTC") == "BTC:{units},ETH:1.0"


def test_the_other_legs_are_written_as_rendered() -> None:
    assert entry_template(LEGS, "ETH") == "BTC:0.6,ETH:{units}"


def test_a_template_is_never_itself_a_valid_option() -> None:
    assert re.fullmatch(LEGS_PATTERN, entry_template(LEGS, "BTC")) is None


def test_a_typed_quantity_makes_it_the_option_the_backend_parses() -> None:
    typed = entry_template(LEGS, "BTC").replace(UNITS_PLACEHOLDER, "0.25")

    assert parse_legs(typed)[0] == LegRequest(symbol="BTC", quantity=Decimal("0.25"))
