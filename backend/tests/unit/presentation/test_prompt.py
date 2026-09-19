"""AC-11 — the prompt fragments are generated, never hand-copied (ADR-K D-14).

The assertions read the registry and the options schemas and compare them with
the rendered text, so a fragment that drifts from the catalog fails here
instead of teaching the model a view that no longer exists.
"""

import pytest

from app.presentation.options import ProjectionOptions
from app.presentation.prompt import (
    NO_OPTIONS,
    PROMPT_HEADER,
    option_bounds,
    prompt_fragment,
)
from app.presentation.registry import REGISTRY
from app.presentation.spec import ProjectionSpec
from app.presentation.views.holdings_allocation import (
    HoldingsAllocationPayload,
    render,
    surface,
)


def test_fragment_lists_every_projection_with_its_purpose() -> None:
    text = prompt_fragment(REGISTRY.all())
    assert text.startswith(PROMPT_HEADER)
    for projection in REGISTRY.all():
        assert f"- {projection.id} — {projection.summary}" in text


def test_fragment_is_generated_from_the_options_schema() -> None:
    text = prompt_fragment(REGISTRY.all())
    for projection in REGISTRY.all():
        for name in projection.options.model_json_schema()["properties"]:
            assert f"{name} (" in text
    assert "top_n (integer 1..20)" in text
    assert "currency (only 'USD')" in text


def test_fragment_says_none_for_a_projection_without_options() -> None:
    class NoKnobs(ProjectionOptions):
        """A projection that declares nothing at all."""

    spec = ProjectionSpec(
        id="bare.thing.v1",
        summary="Nothing to tune.",
        endpoints=(),
        options=NoKnobs,
        dto=HoldingsAllocationPayload,
        render=render,
        surface=surface,
        fitness=lambda _: 0,
    )
    assert f"  options: {NO_OPTIONS}" in prompt_fragment([spec])


@pytest.mark.parametrize(
    ("spec", "expected"),
    [
        ({"const": "USD"}, "only 'USD'"),
        ({"enum": ["a", "b"]}, "one of 'a', 'b'"),
        ({"type": "integer", "minimum": 1, "maximum": 20}, "integer 1..20"),
        ({"type": "boolean"}, "true or false"),
        ({"anyOf": [{"type": "array"}, {"type": "null"}]}, "list of names"),
    ],
    ids=["const", "enum", "integer", "boolean", "optional-array"],
)
def test_option_bounds_describes_each_schema_shape(
    spec: dict[str, object], expected: str
) -> None:
    assert option_bounds(spec) == expected
