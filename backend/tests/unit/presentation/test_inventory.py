"""AC-3 — the field inventory is walked out of the payload schema.

The walk is checked against a real registered projection rather than a mock:
whatever ``attribution.waterfall.v1`` declares is what the rows must say, so a
renamed field fails here as well as in the generated document.

AC-4 is the interactive rule. ``order.ticket.v1`` does not exist yet, so the
editable path is proven with a projection defined inside this test whose
payload field is named after one of its declared options — which is exactly the
contract the incoming projection has to satisfy.
"""

from collections.abc import Mapping
from typing import Any, Literal

from pydantic import Field

from app.domain.portfolio import Portfolio
from app.presentation.catalog_tables import option_inputs
from app.presentation.fragments import ProjectionDto
from app.presentation.inventory import MAX_DEPTH, InventoryField, inventory
from app.presentation.options import TopNOptions
from app.presentation.registry import REGISTRY

WATERFALL = "attribution.waterfall.v1"


def _paths(
    schema: dict[str, Any], inputs: Mapping[str, str] | None = None
) -> dict[str, InventoryField]:
    """Index one payload schema's inventory by field path."""
    return {row.path: row for row in inventory(schema, inputs=inputs or {})}


def test_inventory_walks_into_lists_and_nested_objects() -> None:
    rows = _paths(REGISTRY.get(WATERFALL).dto.model_json_schema())

    assert rows["buckets"].binding == "container"
    assert rows["buckets"].state == "empty"
    assert rows["buckets[].delta.display"].binding == "display"
    assert rows["buckets[].delta.amount"].binding == "raw"
    assert rows["start.amount.display"].kind == "string ≤32 chars"


def test_inventory_marks_every_money_string_as_pre_formatted() -> None:
    rows = inventory(REGISTRY.get(WATERFALL).dto.model_json_schema(), inputs={})
    displays = [row.path for row in rows if row.binding == "display"]

    assert displays == [
        "start.amount.display",
        "end.amount.display",
        "buckets[].delta.display",
        "buckets[].cumulative.display",
    ]
    assert all(row.binding != "raw" or ".amount" in row.path for row in rows)


def test_inventory_reports_the_discriminator_and_the_required_fields() -> None:
    rows = _paths(REGISTRY.get(WATERFALL).dto.model_json_schema())

    assert rows["view"].binding == "constant"
    assert rows["view"].kind == f"const {WATERFALL!r}"
    assert rows["title"].presence == "required"
    assert rows["annotations"].presence == "default `[]`"


def test_a_read_only_projection_marks_no_field_as_editable() -> None:
    rows = inventory(
        REGISTRY.get(WATERFALL).dto.model_json_schema(),
        inputs={"precision": "input · integer 0..8"},
    )

    assert {row.interaction for row in rows} == {"—"}


class TicketPayload(ProjectionDto):
    """A payload that echoes one of its own options, so the widget can edit it."""

    view: Literal["ticket.probe.v1"] = Field(
        default="ticket.probe.v1", description="Projection discriminator."
    )
    top_n: int = Field(description="How many rows the ticket is showing.")


def test_a_payload_field_named_after_an_option_is_an_input_with_its_bounds() -> None:
    inputs = option_inputs(TopNOptions.model_json_schema())
    rows = _paths(TicketPayload.model_json_schema(), inputs)

    assert rows["top_n"].interaction == "input · integer 1..20"
    assert rows["view"].interaction == "—"


def test_the_walk_stops_before_a_self_referencing_schema_runs_away() -> None:
    node: dict[str, Any] = {
        "type": "object",
        "properties": {"child": {"$ref": "#/$defs/Node"}},
    }
    schema = {**node, "$defs": {"Node": node}}

    rows = inventory(schema, inputs={})

    assert len(rows) == MAX_DEPTH + 1
    assert rows[-1].path == "child." * MAX_DEPTH + "child"


def test_a_render_of_the_projection_carries_every_field_the_inventory_lists(
    portfolio: Portfolio,
) -> None:
    projection = REGISTRY.get(WATERFALL)
    payload = projection.render(portfolio, projection.options()).model_dump(mode="json")
    rows = inventory(projection.dto.model_json_schema(), inputs={})

    top_level = {row.path for row in rows if "." not in row.path}
    assert top_level == set(payload)
