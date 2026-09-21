"""Which JSON Schema keywords Gemini's ``parameters`` field takes (GGU-81).

``generateContent`` does not take JSON Schema. Its ``parameters`` field is an
OpenAPI 3 ``Schema`` proto decoded with proto3 JSON rules, and those **reject**
an unknown field rather than ignoring it. One stray keyword and the whole
request is a ``400``, which the adapter reports as ``model provider
unavailable`` — which is why every agent turn failed while the logs blamed the
provider.

**These two lists were measured against the API, not recalled from
documentation.** Each candidate keyword was posted on its own, at the
``parameters`` root and inside a property, and classified by the answer:
either ``200``, or ``Unknown name "<key>" at
'tools[0].function_declarations[0].parameters…': Cannot find field``.

Re-measure when the model or the API version changes: the probe is one POST
per keyword, and the answer names the one it refused. The translation that
applies these lists is ``tool_schema.py``.
"""

from typing import Final

#: Accepted — measured 2026-09-20 against ``gemini-3.8-flash`` on ``v1beta``.
#: Anything not named here is dropped on the way out, so a keyword a future
#: pydantic emits cannot break a turn before anyone has heard of it.
SUPPORTED_KEYS: Final[frozenset[str]] = frozenset(
    {
        "type",
        "format",
        "title",
        "description",
        "nullable",
        "default",
        "enum",
        "properties",
        "required",
        "items",
        "anyOf",
        "oneOf",
        "allOf",
        "not",
        "minimum",
        "maximum",
        "minLength",
        "maxLength",
        "pattern",
        "minItems",
        "maxItems",
        "minProperties",
        "maxProperties",
        "propertyOrdering",
    }
)

#: Refused — the same measurement, each one answered with ``Cannot find
#: field``. Kept as a fact of its own so a test can assert the outgoing
#: payload carries none of them, instead of re-deriving the answer from the
#: allow-list it is meant to check.
REJECTED_KEYS: Final[frozenset[str]] = frozenset(
    {
        "$comment",
        "$defs",
        "$ref",
        "$schema",
        "additionalItems",
        "additionalProperties",
        "const",
        "contains",
        "dependentRequired",
        "deprecated",
        "examples",
        "exclusiveMaximum",
        "exclusiveMinimum",
        "multipleOf",
        "patternProperties",
        "prefixItems",
        "propertyNames",
        "readOnly",
        "unevaluatedProperties",
        "uniqueItems",
        "writeOnly",
    }
)

#: Supported keywords whose value is a list of sub-schemas, and those whose
#: value is a single one. Both have to be walked, or a ``$ref`` nested in a
#: union would survive the crossing.
BRANCH_LISTS: Final[frozenset[str]] = frozenset({"anyOf", "oneOf", "allOf"})
BRANCH_NODES: Final[frozenset[str]] = frozenset({"items", "not"})

__all__ = ["BRANCH_LISTS", "BRANCH_NODES", "REJECTED_KEYS", "SUPPORTED_KEYS"]
