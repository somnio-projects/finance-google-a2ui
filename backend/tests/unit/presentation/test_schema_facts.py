"""AC-2 — the type and the bound of a field, read off its schema.

Each rule is exercised against a hand-written schema fragment, one shape per
case, so a change to the wording or to the rule shows up here before it shows
up in the generated contract. The fragments are the shapes pydantic actually
emits — a ``Decimal`` as ``anyOf[number, string]``, an optional as
``anyOf[X, null]``, a ``Literal`` as ``const``.

The roles those types play (presence, binding, state) are pinned next door, in
``test_schema_roles``.
"""

from typing import Any

import pytest

from app.presentation.schema_facts import (
    bound,
    collapse,
    describe,
    is_numeric,
    variant_types,
)

DECIMAL: dict[str, Any] = {"anyOf": [{"type": "number"}, {"type": "string"}]}
OPTIONAL_ARRAY: dict[str, Any] = {
    "anyOf": [{"type": "array", "maxItems": 8}, {"type": "null"}],
    "default": None,
}


@pytest.mark.parametrize(
    ("spec", "expected"),
    [
        ({"type": "string"}, set()),
        (DECIMAL, {"number", "string"}),
        (OPTIONAL_ARRAY, {"array"}),
        ({"anyOf": [{"$ref": "#/$defs/Total"}]}, {"object"}),
    ],
    ids=["plain", "decimal", "optional-array", "ref-member"],
)
def test_variant_types_lists_the_real_members_only(
    spec: dict[str, Any], expected: set[str]
) -> None:
    assert variant_types(spec) == expected


@pytest.mark.parametrize(
    ("spec", "expected"),
    [
        (DECIMAL, True),
        ({"type": "integer"}, True),
        ({"type": "string"}, False),
        ({"type": "boolean"}, False),
    ],
    ids=["decimal", "integer", "string", "boolean"],
)
def test_is_numeric_recognises_a_figure_however_it_is_spelled(
    spec: dict[str, Any], *, expected: bool
) -> None:
    assert is_numeric(spec) is expected


def test_collapse_unwraps_an_optional_and_keeps_the_nodes_own_keys() -> None:
    collapsed = collapse(OPTIONAL_ARRAY)

    assert collapsed["type"] == "array"
    assert collapsed["maxItems"] == 8
    assert collapsed["default"] is None
    assert "anyOf" not in collapsed


def test_collapse_leaves_a_genuine_union_alone() -> None:
    assert collapse(DECIMAL) == DECIMAL


@pytest.mark.parametrize(
    ("spec", "expected"),
    [
        ({"type": "string", "maxLength": 32}, "≤32 chars"),
        ({"type": "array", "maxItems": 8}, "≤8 items"),
        ({"type": "integer", "minimum": 1, "maximum": 20}, "1..20"),
        ({"type": "string"}, ""),
    ],
    ids=["max-length", "max-items", "range", "unbounded"],
)
def test_bound_reads_the_declared_limit(spec: dict[str, Any], expected: str) -> None:
    assert bound(spec) == expected


@pytest.mark.parametrize(
    ("spec", "expected"),
    [
        ({"const": "holdings.allocation.v1"}, "const 'holdings.allocation.v1'"),
        ({"enum": ["up", "down"]}, "enum up / down"),
        (DECIMAL, "decimal"),
        ({"anyOf": [{"type": "string"}, {"type": "boolean"}]}, "boolean / string"),
        ({"type": "string", "maxLength": 64}, "string ≤64 chars"),
        ({"properties": {}}, "object"),
    ],
    ids=["const", "enum", "decimal", "other-union", "bounded-string", "object"],
)
def test_describe_names_the_type_and_its_bound(
    spec: dict[str, Any], expected: str
) -> None:
    assert describe(spec) == expected
