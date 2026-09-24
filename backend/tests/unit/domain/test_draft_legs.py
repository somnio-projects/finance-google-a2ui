"""Spec 0031 — the ``legs`` string, read and written by the domain.

The option is one bounded string, and the stepper the client draws is two
more of them the backend wrote (OD-2, OD-3). Every assertion here is on the
text a caller sends or receives, because that text *is* the contract.
"""

import re

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

DEFAULT = "NVDA:3,AVGO:2,AMD:14"
LEGS = (
    LegRequest(symbol="NVDA", quantity=3),
    LegRequest(symbol="AVGO", quantity=2),
    LegRequest(symbol="AMD", quantity=14),
)


def test_parse_reads_the_legs_in_the_order_written() -> None:
    """AC-3 — the ticket lays legs out as asked, never re-sorted."""
    assert parse_legs(DEFAULT) == LEGS


def test_format_writes_back_exactly_what_parse_read() -> None:
    """The round trip is the identity, so an echo is byte-equal to the ask."""
    assert format_legs(parse_legs(DEFAULT)) == DEFAULT


def test_a_repeated_ticker_is_refused_as_the_options_own_error() -> None:
    """A regular expression cannot say "named once"; the parser does."""
    with pytest.raises(ValueError, match="'NVDA' appears more than once"):
        parse_legs("NVDA:1,NVDA:2")


def test_a_ticker_outside_the_reference_is_refused_the_same_way() -> None:
    """Unknown symbols are a 422 at the boundary, not a lookup miss deeper in."""
    with pytest.raises(ValueError, match="'XRP' is not in the market reference"):
        parse_legs("XRP:1")


@pytest.mark.parametrize(
    ("text", "accepted"),
    [
        ("NVDA:3", True),
        ("NVDA:3,AVGO:2,AMD:14,AAPL:1,MSFT:1", True),
        ("NVDA:3,AVGO:2,AMD:14,AAPL:1,MSFT:1,PG:1", False),
        ("nvda:3", False),
        ("NVDA:3.5", False),
        ("NVDA:1234567", False),
        ("NVDA:3,", False),
        ("", False),
    ],
    ids=[
        "one-leg",
        "five-legs",
        "six-legs",
        "lowercase",
        "fractional",
        "seven-digits",
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
    moved = with_quantity(LEGS, "AVGO", 7)

    assert [leg.symbol for leg in moved] == ["NVDA", "AVGO", "AMD"]
    assert [leg.quantity for leg in moved] == [3, 7, 14]


def test_stepped_writes_the_whole_option_a_tap_sends() -> None:
    """OD-3 — the client never adds one; it sends the string it was handed."""
    assert stepped(LEGS, "AMD", 1) == "NVDA:3,AVGO:2,AMD:15"
    assert stepped(LEGS, "NVDA", -1) == "NVDA:2,AVGO:2,AMD:14"


def test_stepped_is_none_where_the_published_bound_ends() -> None:
    """A disabled control, never a value the backend would refuse."""
    at_zero = (LegRequest(symbol="NVDA", quantity=0),)
    at_max = (LegRequest(symbol="NVDA", quantity=MAX_LEG_QUANTITY),)

    assert stepped(at_zero, "NVDA", -1) is None
    assert stepped(at_zero, "NVDA", 1) == "NVDA:1"
    assert stepped(at_max, "NVDA", 1) is None
    assert stepped(at_max, "NVDA", -1) == f"NVDA:{MAX_LEG_QUANTITY - 1}"
