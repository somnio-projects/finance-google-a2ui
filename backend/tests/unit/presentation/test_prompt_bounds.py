"""No registered option may reach the model described as unrecognised.

`prompt_fragment` is the artefact whose whole job is to stop the model
inventing. Before this, `option_bounds` fell through to the literal string
`"list of names"` for anything it did not recognise — so a nullable ticker was
published as `symbol (list of names)`, and a list of enums as
`methods (list of names)`. Two of the four charts added in GGU-41 changed
their own design to route around that wording rather than send the model a
lie, which is how a defect in a shared file becomes four private workarounds.

The rule the gate now holds: every option of every registered projection
describes itself, and the fallback is only ever reached by a schema shape
nothing ships.
"""

import pytest

from app.presentation.option_text import UNKNOWN, option_bounds
from app.presentation.prompt import prompt_fragment
from app.presentation.registry import REGISTRY

PROJECTIONS = REGISTRY.all()
OPTIONS = [
    (spec.id, name, fragment, spec.options.model_json_schema().get("$defs"))
    for spec in PROJECTIONS
    for name, fragment in spec.options.model_json_schema().get("properties", {}).items()
]


@pytest.mark.parametrize(
    ("view", "option", "schema", "defs"),
    OPTIONS,
    ids=[f"{view}.{option}" for view, option, _, _ in OPTIONS],
)
def test_every_declared_option_describes_itself_to_the_model(
    view: str, option: str, schema: dict[str, object], defs: object
) -> None:
    described = option_bounds(schema, defs)  # pyright: ignore[reportArgumentType]

    assert UNKNOWN not in described, (
        f"{view}.{option} reaches the model as {described!r}; the prompt is "
        f"the artefact that stops it inventing, so it must not guess"
    )
    assert described


def test_the_whole_fragment_carries_no_unrecognised_option() -> None:
    """The per-option check above, asserted on the text actually sent."""
    assert UNKNOWN not in prompt_fragment(PROJECTIONS)


def test_a_reference_into_defs_is_followed() -> None:
    """A `$ref` to an enum is the shape that produced `list of names`."""
    defs = {"Method": {"enum": ["FIFO", "LIFO"]}}
    schema = {"type": "array", "maxItems": 3, "items": {"$ref": "#/$defs/Method"}}

    assert option_bounds(schema, defs) == "list of up to 3 (one of 'FIFO', 'LIFO')"


def test_a_nullable_option_names_both_the_value_and_the_omission() -> None:
    schema = {
        "anyOf": [{"type": "string", "pattern": "^[A-Z]{2,10}$"}, {"type": "null"}]
    }

    assert option_bounds(schema) == "string matching ^[A-Z]{2,10}$, or omit it"


def test_the_fallback_still_exists_for_a_shape_nothing_ships() -> None:
    """A guard that can never fire is a guard nobody maintains."""
    assert option_bounds({"not": {"type": "string"}}) == UNKNOWN


def test_at_least_one_option_was_checked() -> None:
    """An empty registry would make every case above vacuous."""
    assert OPTIONS


def test_a_nullable_constant_is_described_inside_its_branch() -> None:
    """`Literal["USD"] | None` puts the const one level down, in the `anyOf`.

    `option_bounds` catches a top-level const before it ever reaches the
    per-type describer, so this is the only shape that exercises the const
    branch there — and it is a shape pydantic really emits.
    """
    schema = {"anyOf": [{"const": "USD"}, {"type": "null"}]}

    assert option_bounds(schema) == "only 'USD', or omit it"
