"""What an outgoing tool schema may carry, and how to look for it.

Extracted from ``test_outgoing_tool_schema.py`` when that file crossed the
150-line budget. The two walkers are the load-bearing part: each descends the
whole schema, because a keyword inside ``items`` or ``anyOf`` binds an
argument exactly as tightly as one beside ``type``, and a check that reads
only the first level cannot see it go.
"""

from app.infra.model.tool_schema_keys import REJECTED_KEYS

#: Keys that carry a constraint. Sanitising must not be an excuse to lose one
#: (AC-3): whatever the tool declared, the model still gets to read.
#:
#: The four at the end are the ones this guard was missing, and they are the
#: only ones that matter: every key above them is *accepted* by Gemini and so
#: survives the allow-list untouched, which made ``lost`` empty by
#: construction. ``exclusiveMinimum``, ``exclusiveMaximum``, ``multipleOf``
#: and ``uniqueItems`` are in ``REJECTED_KEYS`` and are dropped — a tool
#: declaring ``Field(gt=0)`` or ``multiple_of=5`` would have reached the model
#: with no lower bound and no step, with this file green. No shipped tool
#: declares one today; this fails loudly on the first that does, rather than
#: guessing a translation. (``exclusiveMinimum`` is not ``minimum``: rewriting
#: it admits the endpoint the tool excluded.)
BOUND_KEYS = frozenset(
    {
        "enum",
        "maximum",
        "maxItems",
        "maxLength",
        "maxProperties",
        "minimum",
        "minItems",
        "minLength",
        "pattern",
        "exclusiveMaximum",
        "exclusiveMinimum",
        "multipleOf",
        "uniqueItems",
    }
)


def rejected_keys_in(node: object) -> set[str]:
    """Return every refused keyword anywhere below ``node``."""
    if isinstance(node, dict):
        found = {key for key in node if key in REJECTED_KEYS}
        for value in node.values():
            found |= rejected_keys_in(value)
        return found
    if isinstance(node, list):
        return set().union(*(rejected_keys_in(item) for item in node), set())
    return set()


def bound_keys_in(node: object) -> set[str]:
    """Return every constraint-carrying keyword anywhere below ``node``.

    Anywhere, not at the top level: a bound inside ``items`` or ``anyOf`` binds
    the argument just as tightly as one beside ``type``, and a check that only
    reads the first level cannot see it go.
    """
    if isinstance(node, dict):
        found = {key for key in node if key in BOUND_KEYS}
        for value in node.values():
            found |= bound_keys_in(value)
        return found
    if isinstance(node, list):
        return set().union(*(bound_keys_in(item) for item in node), set())
    return set()
