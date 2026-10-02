"""Every argument every tool publishes is bounded — checked for all of them.

Three times in this stack a tool advertised a bound to the model and enforced
none: `get_holdings_summary.symbols` accepted a five-thousand-character
"ticker" while its schema said ten (spec 0011 §5), and `compute_attribution`
carried the same hole into the merge. Each was found by a reviewer reading one
tool, which does not scale — the next tool is written by whoever is next.

So the rule is enforced over the **registry**, not per tool: a new tool is
covered the moment it registers, and a leaf with no bound fails the gate with
the tool and the field named.

What counts as bounded, per JSON Schema leaf:

* a string — `enum`, or a `maxLength`, or a `pattern` that cannot match
  unboundedly (one anchored with a counted quantifier);
* a number — `maximum` (with `minimum` for the other end);
* an array — `maxItems`, **and** a bounded `items` schema, because twenty
  entries of unbounded strings is unbounded input;
* a `null` branch of an `anyOf` — nothing to bound.
"""

import re
from typing import Any

import pytest

from app.agent.registry import load_tools

#: A pattern bounds a string only if it cannot match arbitrarily long input.
#: `^[A-Za-z]{2,10}$` does; `^\w+$` does not. Requiring an anchor and no
#: unbounded quantifier outside a character-count is the cheap, honest test.
UNBOUNDED_QUANTIFIER = re.compile(r"[*+]")


def _pattern_is_bounded(pattern: str) -> bool:
    """Return True when ``pattern`` cannot match unboundedly long input."""
    if not (pattern.startswith("^") and pattern.endswith("$")):
        return False
    return not UNBOUNDED_QUANTIFIER.search(pattern)


def _is_bounded(schema: dict[str, Any]) -> bool:
    """Return True when this JSON Schema leaf constrains its input's size.

    ``boolean`` joined ``null`` when ``compare_lot_methods`` published the
    first boolean argument (GGU-143). That is not a loosening and the
    distinction is worth stating: this check's subject is *can the model make
    this argument arbitrarily large*, and ``type: boolean`` admits exactly two
    values. A bool falling through to ``return False`` was the helper having
    no case for a shape no tool had used yet, not a bound it was enforcing.
    """
    if "anyOf" in schema:
        return all(_is_bounded(branch) for branch in schema["anyOf"])
    if "enum" in schema:
        return True
    kind = schema.get("type")
    if kind in {"null", "boolean"}:
        return True
    if kind == "string":
        return "maxLength" in schema or _pattern_is_bounded(schema.get("pattern", ""))
    if kind in {"integer", "number"}:
        return "maximum" in schema
    if kind == "array":
        items = schema.get("items")
        return "maxItems" in schema and isinstance(items, dict) and _is_bounded(items)
    if kind == "object":
        return "maxProperties" in schema
    return False


#: Snapshotted at import, before any test runs. The registry is process-wide
#: and other tests register doubles into it at runtime; reading it live would
#: make this gate depend on test order and let a double's loose schema fail a
#: check about the tools this backend actually ships.
SHIPPED = load_tools().specs()


def _fields() -> list[tuple[str, str, dict[str, Any]]]:
    """Return every (tool, field, schema) triple the registry publishes."""
    triples: list[tuple[str, str, dict[str, Any]]] = []
    for spec in SHIPPED:
        properties = spec.parameters.get("properties", {})
        assert isinstance(properties, dict)
        for field, schema in properties.items():
            assert isinstance(schema, dict)
            triples.append((spec.name, field, schema))
    return triples


FIELDS = _fields()


@pytest.mark.parametrize(
    ("tool", "field", "schema"),
    FIELDS,
    ids=[f"{tool}.{field}" for tool, field, _ in FIELDS],
)
def test_every_published_argument_is_bounded(
    tool: str, field: str, schema: dict[str, Any]
) -> None:
    """ADR-K D-3: a declared option is a bounded one, or it is not declared."""
    assert _is_bounded(schema), (
        f"{tool}.{field} is published to the model with no bound on its size; "
        f"schema: {schema}"
    )


def test_every_tool_refuses_arguments_it_does_not_declare() -> None:
    """An undeclared argument is rejected, never ignored (spec 0011 OD-7)."""
    for spec in SHIPPED:
        assert spec.parameters.get("additionalProperties") is False, (
            f"{spec.name} does not forbid undeclared arguments"
        )


def test_the_check_would_fail_on_an_unbounded_field() -> None:
    """The guard above is worthless if it passes everything.

    Two shapes that have shipped in this repo and must not pass: a bare
    string, and a capped array whose items are unbounded.
    """
    assert not _is_bounded({"type": "string"})
    assert not _is_bounded({"type": "array", "maxItems": 20, "items": {"type": "str"}})
    assert not _is_bounded({"type": "string", "pattern": r"^\w+$"})
    assert _is_bounded({"type": "string", "maxLength": 10})
    assert _is_bounded({"type": "string", "pattern": r"^[A-Za-z]{2,10}$"})


def test_at_least_one_tool_was_checked() -> None:
    """A registry that fails to load would make every case above vacuous."""
    assert FIELDS, "no tool argument was checked — did the registry load?"
