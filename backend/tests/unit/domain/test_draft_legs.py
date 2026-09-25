"""Spec 0031 — the ``legs`` string, read and written by the domain.

The option is one bounded string, and the stepper the client draws is two
more of them the backend wrote (OD-2, OD-3). Every assertion here is on the
text a caller sends or receives, because that text *is* the contract.
"""

import re
from decimal import Decimal

import pytest

from app.domain.draft_legs import (
    LEGS_PATTERN,
    MAX_LEG_QUANTITY,
    LegRequest,
    format_legs,
    parse_legs,
    stepped,
    with_quantity,
)

DEFAULT = "BTC:0.06,ETH:1.0,SOL:16"
LEGS = (
    LegRequest(symbol="BTC", quantity=Decimal("0.06")),
    LegRequest(symbol="ETH", quantity=Decimal("1.0")),
    LegRequest(symbol="SOL", quantity=Decimal("16")),
)


def test_parse_reads_the_legs_in_the_order_written() -> None:
    """AC-3 — the ticket lays legs out as asked, never re-sorted."""
    assert parse_legs(DEFAULT) == LEGS


def test_format_writes_back_exactly_what_parse_read() -> None:
    """The round trip is the identity, so an echo is byte-equal to the ask."""
    assert format_legs(parse_legs(DEFAULT)) == DEFAULT


def test_a_repeated_ticker_is_refused_as_the_options_own_error() -> None:
    """A regular expression cannot say "named once"; the parser does."""
    with pytest.raises(ValueError, match="'BTC' appears more than once"):
        parse_legs("BTC:1,BTC:2")


def test_a_ticker_outside_the_reference_is_refused_the_same_way() -> None:
    """Unknown symbols are a 422 at the boundary, not a lookup miss deeper in."""
    with pytest.raises(ValueError, match="'XRP' is not in the market reference"):
        parse_legs("XRP:1")


@pytest.mark.parametrize(
    ("text", "accepted"),
    [
        ("BTC:3", True),
        ("BTC:3,ETH:2,SOL:14,ARB:1,AAVE:1", True),
        ("BTC:3,ETH:2,SOL:14,ARB:1,AAVE:1,LINK:1", False),
        ("btc:3", False),
        ("BTC:0.06", True),
        ("BTC:0.12345678", True),
        ("BTC:0.123456789", False),
        ("BTC:1234567890", False),
        ("BTC:3,", False),
        ("", False),
    ],
    ids=[
        "one-leg",
        "five-legs",
        "six-legs",
        "lowercase",
        "fractional",
        "eight-decimals",
        "nine-decimals",
        "ten-digits",
        "trailing-comma",
        "empty",
    ],
)
def test_the_pattern_is_the_whole_truth_about_the_shape(
    text: str, *, accepted: bool
) -> None:
    """AC-4 — the bound the model and the widget read is the one enforced."""
    assert bool(re.fullmatch(LEGS_PATTERN, text)) is accepted


def test_with_quantity_moves_one_leg_and_keeps_the_order() -> None:
    moved = with_quantity(LEGS, "ETH", Decimal("0.7"))

    assert [leg.symbol for leg in moved] == ["BTC", "ETH", "SOL"]
    assert [leg.quantity for leg in moved] == [
        Decimal("0.06"),
        Decimal("0.7"),
        Decimal("16"),
    ]


def test_stepped_writes_the_whole_option_a_tap_sends() -> None:
    """OD-3 — the client never adds one; it sends the string it was handed.

    How far one tap moves is the *asset's* step (spec 0044 OD-6): SOL steps by
    a whole unit and BTC by a hundredth, and one step size could not serve
    both.
    """
    assert stepped(LEGS, "SOL", 1) == "BTC:0.06,ETH:1.0,SOL:17"
    assert stepped(LEGS, "BTC", -1) == "BTC:0.05,ETH:1.0,SOL:16"
    assert stepped(LEGS, "ETH", 1) == "BTC:0.06,ETH:1.1,SOL:16"


def test_stepped_is_none_where_the_published_bound_ends() -> None:
    """A disabled control, never a value the backend would refuse."""
    at_zero = (LegRequest(symbol="BTC", quantity=Decimal(0)),)
    at_max = (LegRequest(symbol="BTC", quantity=MAX_LEG_QUANTITY),)

    assert stepped(at_zero, "BTC", -1) is None
    assert stepped(at_zero, "BTC", 1) == "BTC:0.01"
    assert stepped(at_max, "BTC", 1) is None
    assert stepped(at_max, "BTC", -1) == f"BTC:{MAX_LEG_QUANTITY - Decimal('0.01')}"
