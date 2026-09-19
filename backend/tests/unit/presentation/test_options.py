"""AC-3 — declared options only; nothing is interpreted (ADR-K D-3).

These are the negative cases that prove an options model can actually refuse
something. A model without ``extra="forbid"`` passes every positive test in
this file forever, which is exactly why the rejections are asserted first.
"""

from decimal import Decimal

import pytest
from pydantic import BaseModel, ValidationError

from app.core.errors import ValidationFailedError
from app.presentation.options import (
    CurrencyOptions,
    DisplayOptions,
    FieldSelection,
    PrecisionOptions,
    SortOptions,
    TopNOptions,
)

MIXINS = (CurrencyOptions, PrecisionOptions, SortOptions, TopNOptions, FieldSelection)


@pytest.mark.parametrize("mixin", MIXINS, ids=[m.__name__ for m in MIXINS])
def test_every_option_field_is_described_and_exemplified(
    mixin: type[BaseModel],
) -> None:
    for name, field in mixin.model_fields.items():
        assert field.description, f"{mixin.__name__}.{name} has no description"
        assert field.examples, f"{mixin.__name__}.{name} has no example"


@pytest.mark.parametrize("mixin", MIXINS, ids=[m.__name__ for m in MIXINS])
def test_every_options_model_rejects_an_undeclared_field(
    mixin: type[BaseModel],
) -> None:
    with pytest.raises(ValidationError, match="Extra inputs are not permitted"):
        mixin.model_validate({"definitely_not_declared": 1})


@pytest.mark.parametrize(
    ("payload", "expected"),
    [
        ({"currency": "EUR"}, "currency"),
        ({"precision": 9}, "precision"),
        ({"top_n": 0}, "top_n"),
        ({"sort": "random"}, "sort"),
        ({"locale": "fr-FR"}, "locale"),
    ],
    ids=["currency", "precision", "top_n", "sort", "locale"],
)
def test_out_of_range_values_are_rejected(
    payload: dict[str, object], expected: str
) -> None:
    class Every(DisplayOptions, SortOptions, TopNOptions):
        """Every knob at once, so one table covers all the bounds."""

    with pytest.raises(ValidationError, match=expected):
        Every.model_validate(payload)


def test_display_options_format_under_their_own_precision_and_locale() -> None:
    options = DisplayOptions(precision=1, locale="de-DE")
    assert options.money(Decimal("1234.56")).display == "1.234,6 $"
    assert options.percentage(Decimal("0.125")).display == "12,5%"


def test_field_selection_defaults_to_every_section() -> None:
    assert FieldSelection().selected(("buckets", "notes")) == ("buckets", "notes")


def test_field_selection_keeps_the_declared_order_of_the_subset() -> None:
    chosen = FieldSelection(fields=("notes",)).selected(("buckets", "notes"))
    assert chosen == ("notes",)


def test_field_selection_rejects_an_unknown_section() -> None:
    with pytest.raises(ValidationFailedError, match=r"unknown section\(s\) \['nope'\]"):
        FieldSelection(fields=("nope",)).selected(("buckets",))


def test_options_models_are_frozen() -> None:
    options = PrecisionOptions()
    with pytest.raises(ValidationError, match="frozen"):
        options.precision = 3
