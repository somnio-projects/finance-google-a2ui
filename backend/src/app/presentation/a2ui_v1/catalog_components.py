"""The ``components`` map of the v1.0 catalog, read off the registry (ADR-M D-5).

One component per distinct A2UI component name the projections' own adapters
emit — ``AttributionWaterfall`` serves two views and is one component — plus
``Section``, the only layout this catalog adds. Nothing here names a view: a
projection registered tomorrow appears here with no file edited (ADR-K D-15).

Every component binds its whole payload through one ``data`` pointer
(ADR-M D-3), so the schema of a component is small on purpose: the shape of
what it binds is the projection's DTO, published in ``CONTRACT.md``.
``id``, ``catalogId`` and ``accessibility`` are composed by the envelope
(``ComponentCommon``) and are therefore not repeated here, as the v1.0 catalog
rules require.
"""

from collections.abc import Mapping, Sequence
from typing import Any, Final

from app.presentation.a2ui_v1.composition import (
    SECTION,
    allowed_children,
    allowed_parents,
)
from app.presentation.published import component_of
from app.presentation.registry import Projection

#: The ``common_types.json`` definitions a component may reference.
DATA_BINDING: Final[str] = "common_types.json#/$defs/DataBinding"
CHILD_LIST: Final[str] = "common_types.json#/$defs/ChildList"

_DATA: Final[str] = (
    "JSON Pointer to `{view, options, payload}` in the surface data model: the "
    "projection id, the options it was rendered with and its DTO, exactly as "
    "`GET /v1/portfolios/current/views` serves it. The renderer binds the "
    "payload and computes nothing (ADR-K, ADR-M D-3)."
)
_CHILDREN: Final[str] = "Ids of the components drawn inside this one (ADR-M D-4)."
_SECTION: Final[str] = (
    "A plain vertical group of components at the top of a surface. Layout "
    "only: it binds no data and formats nothing."
)


def components_by_name(projections: Sequence[Projection]) -> dict[str, list[str]]:
    """Group the registered view ids by the component that draws them.

    Args:
        projections: The registry's contents, ordered by id.

    Returns:
        Component name → its view ids, both sorted, so the bytes depend only
        on the registry.
    """
    grouped: dict[str, list[str]] = {}
    for projection in projections:
        grouped.setdefault(component_of(projection), []).append(projection.id)
    return {name: sorted(grouped[name]) for name in sorted(grouped)}


def _description(views: Sequence[str], summaries: Mapping[str, str]) -> str:
    """Name the views a component draws, each with its one line of purpose."""
    return " ".join(f"`{view}`: {summaries[view]}" for view in views)


def _definition(
    name: str, *, binds: bool, description: str, catalog: Sequence[str]
) -> dict[str, Any]:
    """Assemble one component definition with its composition rules.

    Args:
        name: The component name, also its discriminator constant.
        binds: Whether it binds a payload (every projection) or only lays
            out children (``Section``, whose children are then required).
        description: What it draws.
        catalog: Every component name, to derive the children it accepts.
    """
    properties: dict[str, Any] = {"component": {"const": name}}
    if binds:
        properties["data"] = {"$ref": DATA_BINDING, "description": _DATA}
    children = allowed_children(name, catalog)
    if children:
        properties["children"] = {"$ref": CHILD_LIST, "description": _CHILDREN}
    definition: dict[str, Any] = {
        "type": "object",
        "description": description,
        "allowedParents": list(allowed_parents(name)),
        "properties": properties,
        "required": ["component", "data" if binds else "children"],
    }
    if children:
        definition["allowedChildren"] = list(children)
    return definition


def components(projections: Sequence[Projection]) -> dict[str, dict[str, Any]]:
    """Return the catalog's ``components`` map.

    Args:
        projections: The registry's contents, ordered by id.

    Returns:
        One definition per component name plus ``Section``, keyed and sorted
        by name.
    """
    summaries = {projection.id: projection.summary for projection in projections}
    grouped = components_by_name(projections)
    catalog = sorted([*grouped, SECTION])
    defined = {
        name: _definition(
            name,
            binds=True,
            description=_description(views, summaries),
            catalog=catalog,
        )
        for name, views in grouped.items()
    }
    defined[SECTION] = _definition(
        SECTION, binds=False, description=_SECTION, catalog=catalog
    )
    return {name: defined[name] for name in catalog}


def any_component(names: Sequence[str]) -> dict[str, Any]:
    """Return ``$defs.anyComponent``: one ``$ref`` per component, discriminated."""
    return {
        "oneOf": [{"$ref": f"#/components/{name}"} for name in names],
        "discriminator": {"propertyName": "component"},
    }


__all__ = [
    "CHILD_LIST",
    "DATA_BINDING",
    "any_component",
    "components",
    "components_by_name",
]
