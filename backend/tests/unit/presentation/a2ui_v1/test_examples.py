"""Spec 0053 AC-1 — the wire examples are valid, and they are what we emit.

``docs/a2ui/v1.0/examples/`` is the contract ``frontend_v1/`` binds. Two
things are asserted about it: every file validates against the vendored
schemas in the direction it travels, with ``catalog.json`` resolved to the
generated catalog; and the builders, fed the example's own inputs, produce the
example **byte for byte** — so a builder change that would break the client
fails here first. The payloads are the registry's own examples (the files were
rendered from them), which is also asserted.
"""

from pathlib import Path
from typing import Any

import pytest

from app.presentation.a2ui_v1.messages import (
    bound,
    data_part,
    function_error,
    function_value,
    update_data_model,
)
from app.presentation.a2ui_v1.surfaces import (
    RenderedView,
    SurfaceComposer,
    surface_message,
)
from app.presentation.published import component_of
from app.presentation.registry import REGISTRY
from tests.a2ui_v1_schemas import EXAMPLES, errors, load

AGENT_TO_RENDERER = sorted(
    [*EXAMPLES.glob("surface.*.json"), *EXAMPLES.glob("agent_function_*.json")]
)
RENDERER_TO_AGENT = sorted(
    [*EXAMPLES.glob("action.*.json"), *EXAMPLES.glob("call_agent_function.*.json")]
)


def test_every_example_is_claimed_by_one_direction() -> None:
    assert sorted(EXAMPLES.glob("*.json")) == sorted(
        [*AGENT_TO_RENDERER, *RENDERER_TO_AGENT]
    )
    assert len(AGENT_TO_RENDERER) == 4
    assert len(RENDERER_TO_AGENT) == 2


@pytest.mark.parametrize("path", AGENT_TO_RENDERER, ids=lambda p: p.name)
def test_agent_examples_validate_against_agent_to_renderer(path: Path) -> None:
    part = load(path)

    assert part["metadata"] == {"mimeType": "application/a2ui+json"}
    assert errors("agent_to_renderer_list.json", part["data"]) == []


@pytest.mark.parametrize("path", RENDERER_TO_AGENT, ids=lambda p: p.name)
def test_renderer_examples_validate_against_renderer_to_agent(path: Path) -> None:
    assert errors("renderer_to_agent_list.json", load(path)["data"]) == []


def test_a_component_the_catalog_lacks_is_rejected() -> None:
    """Anti-vacuity: the catalog reference resolves and constrains."""
    part = load(EXAMPLES / "surface.portfolio_summary.json")
    part["data"][0]["createSurface"]["components"][0]["component"] = "Spreadsheet"

    assert errors("agent_to_renderer_list.json", part["data"]) != []


def test_a_component_with_an_undeclared_property_is_rejected() -> None:
    part = load(EXAMPLES / "surface.portfolio_summary.json")
    part["data"][0]["createSurface"]["components"][0]["text"] = "hello"

    assert errors("agent_to_renderer_list.json", part["data"]) != []


def _view(view: str, options: dict[str, Any], index: int = 0) -> RenderedView:
    """Render nothing: take the registry's example, as the files were made."""
    projection = REGISTRY.get(view)
    return RenderedView(
        index=index,
        component=component_of(projection),
        view=view,
        options=options,
        payload=dict(projection.example),
    )


def test_the_summary_surface_is_built_byte_for_byte() -> None:
    group = (_view("portfolio.summary.v1", {"range": "1m"}),)

    built = data_part([surface_message("turn-7f3a", group)])

    assert built == load(EXAMPLES / "surface.portfolio_summary.json")


def test_a_ticket_and_its_payoff_are_composed_byte_for_byte() -> None:
    composer = SurfaceComposer()
    held = composer.add(_view("order.ticket.v2", {}))
    groups = [*held, *composer.add(_view("payoff.curve.v1", {}, 1)), *composer.flush()]

    assert held == []
    assert len(groups) == 1
    built = data_part([surface_message("turn-9c21", groups[0])])
    assert built == load(EXAMPLES / "surface.order_ticket_with_payoff.json")


def test_the_render_view_answer_is_built_byte_for_byte() -> None:
    view = _view("portfolio.summary.v1", {"range": "1y"})

    built = data_part(
        [
            function_value("call-01", {"componentId": "root", "view": view.view}),
            update_data_model(
                "turn-7f3a-0", "/root", bound(view.view, view.options, view.payload)
            ),
        ]
    )

    assert built == load(EXAMPLES / "agent_function_response.render_view.json")


def test_the_render_view_refusal_is_built_byte_for_byte() -> None:
    message = "Option 'range' must be one of: 1d, 1w, 1m, ytd, 1y, all."

    built = data_part([function_error("call-02", "INVALID_FUNCTION_CALL", message)])

    assert built == load(EXAMPLES / "agent_function_response.invalid.json")
