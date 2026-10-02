"""No tool, present or future, sends Gemini a keyword it refuses (GGU-81).

~1180 tests were green while every agent turn failed, because every one of
them used ``NullModelClient`` or a fake: nothing ever looked at the bytes that
leave for the provider. This file does, without a socket — it builds the real
outgoing body from the **real registry** and reads it.

Driven over the registry rather than per tool, for the reason
``tests/unit/agent/test_tool_argument_bounds.py`` gives: the next tool is
covered the day it registers, not the day someone remembers.
"""

from typing import Any

import pytest

from app.agent.registry import load_tools
from app.core.model import ToolSpec
from app.infra.model.payload import to_request
from tests.unit.infra.model.wire_schema import bound_keys_in, rejected_keys_in

#: Snapshotted at import, before any test registers a double into the
#: process-wide registry — the same reason the argument-bounds gate does it.
SHIPPED = load_tools().specs()


def _declarations(specs: tuple[ToolSpec, ...]) -> dict[str, dict[str, Any]]:
    """Return the ``parameters`` this backend would really put on the wire."""
    body = to_request(system="you answer portfolio questions", messages=[], tools=specs)
    tools = body["tools"]
    assert isinstance(tools, list)
    return {
        declaration["name"]: declaration["parameters"]
        for declaration in tools[0]["functionDeclarations"]
    }


WIRE = _declarations(SHIPPED)


@pytest.mark.parametrize("tool", sorted(WIRE), ids=sorted(WIRE))
def test_the_outgoing_schema_of_every_tool_carries_no_refused_keyword(
    tool: str,
) -> None:
    """AC-4. ``additionalProperties`` and ``examples`` are how this broke."""
    assert rejected_keys_in(WIRE[tool]) == set(), (
        f"{tool} would be sent to Gemini carrying keywords the API refuses; "
        f"the request comes back 400 and the turn reports the provider down"
    )


@pytest.mark.parametrize("tool", sorted(WIRE), ids=sorted(WIRE))
def test_every_argument_keeps_its_shape_and_its_bounds_on_the_wire(
    tool: str,
) -> None:
    """AC-3: translating the schema must not quietly widen an argument."""
    declared = next(spec for spec in SHIPPED if spec.name == tool)
    properties = declared.parameters["properties"]
    assert isinstance(properties, dict)
    sent = WIRE[tool]["properties"]

    assert set(sent) == set(properties), "an argument went missing on the wire"
    for field, schema in properties.items():
        assert sent[field], f"{tool}.{field} crossed as an empty schema"
        lost = bound_keys_in(schema) - bound_keys_in(sent[field])
        assert not lost, f"{tool}.{field} lost {sorted(lost)} on the way out"


def test_the_finder_would_catch_a_refused_keyword() -> None:
    """The gate above is worthless if it passes everything.

    Both shapes have shipped in this repo: the root ``additionalProperties``
    every tool carries, and an ``examples`` buried in an array's items.
    """
    root = {"additionalProperties": False}
    assert rejected_keys_in(root) == {"additionalProperties"}
    assert rejected_keys_in(
        {"properties": {"symbols": {"items": {"examples": ["BTC"]}}}}
    ) == {"examples"}
    assert rejected_keys_in([{"anyOf": [{"const": "SELL"}]}]) == {"const"}
    assert rejected_keys_in({"type": "string", "maxLength": 10}) == set()


def test_the_bound_check_would_catch_a_dropped_constraint() -> None:
    """The guard above is worthless if it cannot see a bound disappear.

    It could not. ``BOUND_KEYS`` listed only keywords Gemini *accepts*, so
    every one of them survived the allow-list and ``lost`` was empty whatever
    the sanitiser did. The two cases below are the ones that were invisible:
    a refused bound at the top level, and one nested inside ``items``.
    """
    assert bound_keys_in({"type": "number", "exclusiveMinimum": 0}) == {
        "exclusiveMinimum"
    }
    assert bound_keys_in({"items": {"multipleOf": 5}}) == {"multipleOf"}
    assert bound_keys_in({"anyOf": [{"uniqueItems": True}]}) == {"uniqueItems"}
    assert bound_keys_in({"type": "string", "description": "free text"}) == set()

    declared = {"type": "array", "items": {"type": "number", "multipleOf": 5}}
    stripped = {"type": "array", "items": {"type": "number"}}
    assert bound_keys_in(declared) - bound_keys_in(stripped) == {"multipleOf"}


def test_at_least_one_tool_was_checked() -> None:
    """A registry that failed to load would make every case above vacuous."""
    assert WIRE, "no tool schema was checked — did the registry load?"
