"""The two interactivity declarations, read the way each consumer reads them.

Shared by the registry walk and by the drift probe. Kept beside them rather
than in ``conftest.py`` because these are plain functions, not fixtures, and
because the *independence* of the two readings is the whole point: one comes
from the generator's own calls, the other is computed here, so a bug that made
them agree by construction would defeat the comparison.
"""

from collections.abc import Mapping
from typing import Any

from app.presentation.catalog_tables import interactive_fields, option_inputs
from app.presentation.inventory import inventory
from app.presentation.registry import REGISTRY, Projection
from app.presentation.sample import sample_portfolio
from app.presentation.tickets import TicketInput

PROJECTIONS = list(REGISTRY.all())
IDS = [projection.id for projection in PROJECTIONS]


def offered(projection: Projection) -> set[str]:
    """Return the options this projection's payload offers as controls."""
    payload = projection.render(sample_portfolio(), projection.options())
    return {
        field.option
        for field in getattr(payload, "inputs", ())
        if isinstance(field, TicketInput)
    }


def reported_paths(projection: Projection) -> tuple[str, ...]:
    """Return the field paths the generated contract marks editable.

    Built through the generator's own calls rather than by re-implementing the
    name match, so this test cannot pass a rule the document does not use.
    """
    fields = inventory(
        projection.dto.model_json_schema(),
        inputs=option_inputs(projection.options.model_json_schema()),
    )
    return interactive_fields(fields)


def payload_field_names(schema: Mapping[str, Any]) -> set[str]:
    """Every field name a payload declares, at any depth."""
    names: set[str] = set()
    for node in (schema, *schema.get("$defs", {}).values()):
        names |= set(node.get("properties", {}))
    return names


def name_matched(projection: Projection) -> set[str]:
    """Return the options a payload field is named after (the OD-3 rule).

    Computed independently of ``inventory`` on purpose: the assertions
    compare the document's claim against this, so deriving both from the
    same walk would make them agree by construction.
    """
    declared = set(projection.options.model_fields)
    return declared & payload_field_names(projection.dto.model_json_schema())


def reported(projection: Projection) -> set[str]:
    """Return the *options* the contract reports as editable, by name."""
    return {path.rsplit(".", 1)[-1] for path in reported_paths(projection)}


def value_at(payload: Mapping[str, Any], path: str) -> Any:
    """Return the value a reported path points at in a rendered payload."""
    current: Any = payload
    for step in path.split("."):
        if step.endswith("[]"):
            current = current[step[:-2]]
            if not current:
                return None
            current = current[0]
        else:
            current = current[step]
    return current


def disagreement(projection: Projection) -> str:
    """Spell out both declarations, so a failure needs no investigation."""
    return (
        f"{projection.id}: the payload offers controls for "
        f"{sorted(offered(projection))} but the generated contract reports "
        f"{sorted(reported(projection))} as editable "
        f"(paths {list(reported_paths(projection))}). "
        "Name every editable payload field exactly as the option that sets it "
        "(presentation.md §4, spec 0019 OD-3)."
    )


__all__ = [
    "IDS",
    "PROJECTIONS",
    "disagreement",
    "name_matched",
    "offered",
    "payload_field_names",
    "reported",
    "reported_paths",
    "value_at",
]
