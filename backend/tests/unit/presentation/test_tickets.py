"""AC-5, AC-6 — the vocabulary that makes a surface editable.

`app.presentation.tickets` is what a projection uses to say "this field is an
input, and here is what it may hold". Its one rule is that the bound comes
from the options model's own JSON schema, so these tests build an options
model and check the descriptors against *that schema*, never against a copy.
"""

from decimal import Decimal
from typing import Literal

import pytest
from pydantic import Field, ValidationError

from app.presentation.options import ProjectionOptions
from app.presentation.ticket_displays import price, quantity
from app.presentation.tickets import MAX_CHOICES, TicketInput, declared_inputs

LABELS = {"mode": "Mode", "code": "Code"}


class Probe(ProjectionOptions):
    """One enum option and one pattern-bounded string, to cover both shapes."""

    mode: Literal["fast", "slow"] = Field(default="fast", description="How.")
    code: str = Field(default="A1", pattern=r"^[A-Z][0-9]$", description="Which.")


def test_declared_inputs_describes_an_enum_option_as_a_bounded_choice() -> None:
    field = declared_inputs(Probe(), LABELS)[0]

    assert (field.option, field.label, field.control) == ("mode", "Mode", "choice")
    assert field.choices == ("fast", "slow")
    assert field.pattern is None


def test_declared_inputs_describes_a_string_option_by_the_pattern_it_enforces() -> None:
    field = declared_inputs(Probe(), LABELS)[1]

    assert (field.option, field.control, field.pattern) == (
        "code",
        "text",
        r"^[A-Z][0-9]$",
    )
    assert field.choices == ()


def test_declared_inputs_carries_the_current_value_back_to_the_widget() -> None:
    fields = declared_inputs(Probe(mode="slow", code="Z9"), LABELS)

    assert [field.value for field in fields] == ["slow", "Z9"]


def test_declared_inputs_offers_only_the_options_the_surface_labelled() -> None:
    """A declared option absent from the labels is still accepted, just not shown."""
    fields = declared_inputs(Probe(), {"mode": "Mode"})

    assert [field.option for field in fields] == ["mode"]
    assert "code" in Probe.model_json_schema()["properties"]


def test_a_descriptor_cannot_publish_an_unbounded_list_of_choices() -> None:
    with pytest.raises(ValidationError, match="at most 16 items"):
        TicketInput(
            option="mode",
            label="Mode",
            control="choice",
            value="fast",
            choices=tuple(str(index) for index in range(MAX_CHOICES + 1)),
        )


@pytest.mark.parametrize(
    ("units", "expected"),
    [
        (Decimal("0.60000000"), "0.6"),
        (Decimal(3), "3"),
        (Decimal("3927.729772191673"), "3927.72977219"),
    ],
    ids=["trailing-zeros", "whole", "rounded-to-eight-places"],
)
def test_quantity_trims_a_unit_count_to_what_a_reader_needs(
    units: Decimal, expected: str
) -> None:
    pair = quantity(units)

    assert pair.display == expected
    assert pair.units == units


@pytest.mark.parametrize(
    ("value", "expected"),
    [(Decimal("64250.00"), "$64,250.00"), (Decimal("0.1273"), "$0.1273")],
    ids=["exact-in-cents", "sub-dollar"],
)
def test_price_quotes_a_unit_price_finely_enough_to_multiply_by(
    value: Decimal, expected: str
) -> None:
    pair = price(value)

    assert pair.display == expected
    assert pair.amount == value
