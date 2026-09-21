"""GGU-81 — the JSON Schema translation Gemini's ``parameters`` field needs.

The keywords asserted here are not opinions: each was posted to the real
``generateContent`` and kept or dropped by its answer. See the module
docstring of ``app.infra.model.tool_schema_keys``. References have their own
file, ``test_tool_schema_refs.py``.
"""

from typing import Any

from app.infra.model.tool_schema import to_gemini_schema
from app.infra.model.tool_schema_keys import REJECTED_KEYS, SUPPORTED_KEYS


def test_to_gemini_schema_drops_the_keys_the_api_refuses() -> None:
    """The two keywords that broke every turn, and their neighbours, go."""
    schema = to_gemini_schema(
        {
            "type": "object",
            "additionalProperties": False,
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "title": "Args",
            "properties": {
                "symbol": {
                    "type": "string",
                    "maxLength": 10,
                    "examples": ["NVDA"],
                    "readOnly": True,
                }
            },
            "required": ["symbol"],
        }
    )

    assert schema == {
        "type": "object",
        "title": "Args",
        "properties": {"symbol": {"type": "string", "maxLength": 10}},
        "required": ["symbol"],
    }


def test_to_gemini_schema_keeps_every_bound_it_is_given() -> None:
    """Sanitising is not simplifying: the constraints the model reads stay."""
    leaf: dict[str, Any] = {
        "type": "string",
        "minLength": 2,
        "maxLength": 10,
        "pattern": "^[A-Z]{2,10}$",
        "description": "Ticker.",
        "default": "NVDA",
        "format": "date-time",
        "nullable": True,
    }

    assert to_gemini_schema(leaf) == leaf


def test_to_gemini_schema_walks_into_a_capped_array() -> None:
    """A refused keyword hides as happily two levels down as at the root."""
    schema = to_gemini_schema(
        {
            "type": "array",
            "maxItems": 20,
            "uniqueItems": True,
            "items": {"type": "string", "maxLength": 10, "examples": ["NVDA"]},
        }
    )

    assert schema == {
        "type": "array",
        "maxItems": 20,
        "items": {"type": "string", "maxLength": 10},
    }


def test_to_gemini_schema_rewrites_const_as_a_single_valued_enum() -> None:
    """``const`` is refused; the value it pins is still a bound worth sending."""
    assert to_gemini_schema({"properties": {"side": {"const": "SELL"}}}) == {
        "properties": {"side": {"enum": ["SELL"]}}
    }


def test_to_gemini_schema_leaves_an_existing_enum_alone() -> None:
    """When both are present the enum is already the wider, truer statement."""
    node = {"type": "string", "const": "SELL", "enum": ["SELL", "BUY"]}

    assert to_gemini_schema(node) == {"type": "string", "enum": ["SELL", "BUY"]}


def test_the_two_measured_lists_do_not_contradict_each_other() -> None:
    """A keyword cannot be both accepted and refused by the same API."""
    assert not SUPPORTED_KEYS & REJECTED_KEYS
