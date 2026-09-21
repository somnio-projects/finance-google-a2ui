"""GGU-81 AC-3 — ``$ref`` is resolved on the way out, never dropped.

A dropped reference leaves a field with no type and no bound: the model is
told an argument exists and nothing about what it may hold. That is the
advertised-but-unenforced failure `tests/unit/agent/test_tool_argument_bounds`
exists to prevent, arriving by a different door.
"""

from typing import Any

import pytest

from app.core.errors import ConfigurationError
from app.infra.model.tool_schema import to_gemini_schema

TICKER = {"type": "string", "maxLength": 10, "examples": ["BTC"]}
RESOLVED = {"type": "string", "maxLength": 10}


@pytest.mark.parametrize(
    ("node", "expected"),
    [
        (
            {"type": "array", "maxItems": 20, "items": {"$ref": "#/$defs/Ticker"}},
            {"type": "array", "maxItems": 20, "items": RESOLVED},
        ),
        (
            {"anyOf": [{"$ref": "#/$defs/Ticker"}, {"type": "null"}]},
            {"anyOf": [RESOLVED, {"type": "null"}]},
        ),
        ({"oneOf": [{"$ref": "#/$defs/Ticker"}]}, {"oneOf": [RESOLVED]}),
        ({"allOf": [{"$ref": "#/$defs/Ticker"}]}, {"allOf": [RESOLVED]}),
        ({"not": {"$ref": "#/$defs/Ticker"}}, {"not": RESOLVED}),
    ],
    ids=["items", "anyOf", "oneOf", "allOf", "not"],
)
def test_to_gemini_schema_resolves_a_reference_wherever_it_hides(
    node: dict[str, Any], expected: dict[str, Any]
) -> None:
    """Every sub-schema position is walked, or a bound goes missing."""
    document = {"$defs": {"Ticker": TICKER}, **node}

    assert to_gemini_schema(document) == expected


def test_to_gemini_schema_lets_the_referring_node_override_the_definition() -> None:
    """A ``$ref`` beside a description means "that shape, described here"."""
    schema = to_gemini_schema(
        {
            "$defs": {"Method": {"type": "string", "enum": ["FIFO", "LIFO"]}},
            "properties": {
                "lot_method": {
                    "$ref": "#/$defs/Method",
                    "description": "Which lots the sale consumes first.",
                    "default": "FIFO",
                }
            },
        }
    )

    assert schema["properties"]["lot_method"] == {
        "type": "string",
        "enum": ["FIFO", "LIFO"],
        "description": "Which lots the sale consumes first.",
        "default": "FIFO",
    }


def test_to_gemini_schema_rejects_a_reference_to_nothing() -> None:
    """Better to name the broken tool than to send Gemini a typeless field."""
    with pytest.raises(ConfigurationError, match="resolves to nothing"):
        to_gemini_schema({"properties": {"x": {"$ref": "#/$defs/Missing"}}})


def test_to_gemini_schema_rejects_a_cyclic_reference() -> None:
    """A self-referential argument cannot be written out, and must not hang."""
    document = {
        "$defs": {"Node": {"properties": {"child": {"$ref": "#/$defs/Node"}}}},
        "properties": {"root": {"$ref": "#/$defs/Node"}},
    }

    with pytest.raises(ConfigurationError, match="is cyclic"):
        to_gemini_schema(document)
