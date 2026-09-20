"""AC-2 — presence, binding and state, each derived from the schema alone.

The three columns that tell a designer what a field *does*: whether the payload
always carries it, whether the client prints the value or plots it, and which
UI state it can drive.

The binding cases are the load-bearing ones. GGU-41 asks which fields arrive
pre-formatted, and the answer must not be "the ones called `display`": the two
string cases below are the **same** fragment and classify differently purely
because of what sits beside them in the object.
"""

from typing import Any

import pytest

from app.presentation.schema_facts import NONE, binding, is_pair, presence, state

DECIMAL: dict[str, Any] = {"anyOf": [{"type": "number"}, {"type": "string"}]}
A_STRING: dict[str, Any] = {"type": "string", "maxLength": 32}
MONEY_PAIR: dict[str, Any] = {"amount": DECIMAL, "display": A_STRING}


@pytest.mark.parametrize(
    ("spec", "required", "expected"),
    [
        ({"type": "string"}, True, "required"),
        ({"type": "array", "default": []}, False, "default `[]`"),
        ({"type": "string"}, False, "optional"),
    ],
    ids=["required", "defaulted", "neither"],
)
def test_presence_says_whether_the_payload_always_carries_the_field(
    spec: dict[str, Any], expected: str, *, required: bool
) -> None:
    assert presence(spec, required=required) == expected


@pytest.mark.parametrize(
    ("spec", "paired", "expected"),
    [
        ({"const": "x"}, False, "constant"),
        ({"enum": ["up", "down"]}, False, "enum"),
        ({"type": "array"}, False, "container"),
        ({"properties": {}}, False, "container"),
        (DECIMAL, False, "raw"),
        ({"type": "boolean"}, False, "flag"),
        (A_STRING, True, "display"),
        (A_STRING, False, "text"),
    ],
    ids=[
        "const",
        "enum",
        "array",
        "object",
        "decimal",
        "boolean",
        "string-beside-a-figure",
        "string-alone",
    ],
)
def test_binding_derives_pre_formatting_from_the_pair_not_from_the_name(
    spec: dict[str, Any], expected: str, *, paired: bool
) -> None:
    assert binding(spec, paired=paired) == expected


def test_a_display_string_is_classified_without_ever_being_named_display() -> None:
    """The rule is the ADR-E pair, so a differently named string still works."""
    assert binding(A_STRING, paired=True) == "display"
    assert binding(A_STRING, paired=False) == "text"


def test_only_an_object_that_is_nothing_but_a_pair_counts_as_one() -> None:
    """Both `*Display` fragments are pairs; a whole payload never is."""
    assert is_pair(MONEY_PAIR) is True
    assert is_pair({"value": DECIMAL, "display": A_STRING}) is True
    assert is_pair({"label": A_STRING, "text": A_STRING}) is False
    assert is_pair({"a": DECIMAL, "b": DECIMAL}) is False


def test_a_payload_carrying_a_bare_figure_does_not_make_its_title_display() -> None:
    """The bug the `len == 2` clause fixes, in the shape `order.ticket.v1` has.

    An editable integer sits at the top level beside `title`. Under a looser
    rule — "any string in an object that holds a figure" — every string in
    that payload would be reported as pre-formatted, and a designer would be
    told the title arrives formatted when it is just a title.
    """
    ticket = {
        "view": A_STRING,
        "title": A_STRING,
        "top_n": {"type": "integer"},
        "total": {"type": "object"},
    }

    assert is_pair(ticket) is False
    assert binding(A_STRING, paired=is_pair(ticket)) == "text"


@pytest.mark.parametrize(
    ("spec", "nullable", "expected"),
    [
        ({"type": "array"}, False, "empty"),
        ({"type": "string"}, True, "null"),
        ({"enum": ["up", "down"]}, False, "variant"),
        ({"type": "boolean"}, False, "variant"),
        ({"type": "string"}, False, NONE),
    ],
    ids=["array", "nullable", "enum", "boolean", "plain"],
)
def test_state_names_only_the_states_the_schema_can_prove(
    spec: dict[str, Any], expected: str, *, nullable: bool
) -> None:
    assert state(spec, nullable=nullable) == expected
