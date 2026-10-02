"""Spec 0053 AC-2 — the generated v1.0 catalog, held to the vendored schema.

Validity against ``catalog_definition.json`` is necessary and not sufficient:
the schema cannot see the v1.0 catalog *rules* (one ``component`` const per
key, only ``anyComponent``/``anyFunction`` under ``$defs``, UAX #31 names, no
``theme``) nor ADR-M's composition table, so each is asserted on its own.
"""

import re
from typing import Any

from app.presentation.a2ui_v1.catalog import catalog, catalog_document
from app.presentation.a2ui_v1.catalog_components import components_by_name
from app.presentation.a2ui_v1.wire import CATALOG_ID, CATALOG_PATH, RENDER_VIEW
from app.presentation.prompt import prompt_fragment
from app.presentation.registry import REGISTRY
from tests.a2ui_v1_schemas import errors
from tests.unit.presentation.conftest import committed

UAX31_ASCII = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
TICKETS = ["MultiLegOrderTicket", "OrderTicket"]


def _catalog() -> dict[str, Any]:
    return catalog(REGISTRY.all())


def test_catalog_validates_against_the_vendored_definition() -> None:
    assert errors("catalog_definition.json", _catalog()) == []


def test_catalog_id_is_both_the_schema_id_and_the_catalog_id() -> None:
    document = _catalog()

    assert document["$id"] == document["catalogId"] == CATALOG_ID
    assert document["protocolVersion"] == "1.0"
    assert "theme" not in document


def test_catalog_has_one_component_per_adapter_name_plus_section() -> None:
    grouped = components_by_name(REGISTRY.all())
    components = _catalog()["components"]

    assert sorted(components) == sorted([*grouped, "Section"])
    assert grouped["AttributionWaterfall"] == [
        "attribution.waterfall.v1",
        "attribution.window.v1",
    ]


def test_every_component_is_discriminated_by_its_own_key() -> None:
    components = _catalog()["components"]

    for name, definition in components.items():
        assert UAX31_ASCII.match(name), name
        assert definition["properties"]["component"] == {"const": name}
        assert "component" in definition["required"]


def test_defs_hold_only_the_two_external_entry_points() -> None:
    defs = _catalog()["$defs"]

    assert sorted(defs) == ["anyComponent", "anyFunction"]
    refs = [item["$ref"] for item in defs["anyComponent"]["oneOf"]]
    assert refs == [f"#/components/{name}" for name in _catalog()["components"]]
    assert defs["anyFunction"] == {"oneOf": [{"$ref": f"#/functions/{RENDER_VIEW}"}]}


def test_composition_rules_are_adr_m_d4() -> None:
    components = _catalog()["components"]

    assert components["RiskPayoffChart"]["allowedParents"] == TICKETS[::-1]
    assert components["DriverDetail"]["allowedParents"] == [
        "Surface",
        "AttributionWaterfall",
    ]
    assert components["Section"]["allowedParents"] == ["Surface"]
    for ticket in TICKETS:
        assert components[ticket]["allowedChildren"] == ["RiskPayoffChart"]
    assert components["AttributionWaterfall"]["allowedChildren"] == ["DriverDetail"]
    assert components["PortfolioSummary"]["allowedParents"] == ["Surface", "Section"]
    assert "allowedChildren" not in components["PortfolioSummary"]


def test_section_lays_out_only_what_may_stand_in_a_section() -> None:
    section = _catalog()["components"]["Section"]

    assert section["required"] == ["component", "children"]
    assert "RiskPayoffChart" not in section["allowedChildren"]
    assert "DriverDetail" not in section["allowedChildren"]
    assert "PortfolioSummary" in section["allowedChildren"]


def test_render_view_is_renderer_only_and_returns_an_object() -> None:
    function = _catalog()["functions"][RENDER_VIEW]

    assert function["returnType"] == "object"
    assert function["allowedCallers"] == "rendererOnly"
    assert function["properties"]["call"] == {"const": RENDER_VIEW}
    args = function["properties"]["args"]
    assert args["required"] == ["componentId", "view", "options"]
    assert args["properties"]["view"]["enum"] == [p.id for p in REGISTRY.all()]


def test_instructions_are_the_prompt_fragment_verbatim() -> None:
    assert _catalog()["instructions"] == prompt_fragment(REGISTRY.all())


def test_the_checked_in_catalog_is_current() -> None:
    assert committed(CATALOG_PATH) == catalog_document(REGISTRY.all())
