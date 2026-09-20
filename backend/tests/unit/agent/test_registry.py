"""Spec 0006 AC-7 — local registration, discovery, and the duplicate guard."""

from pathlib import Path

import pytest

from app.agent import tools as tools_package
from app.agent.registry import REGISTRY, ToolRegistry, load_tools, register
from app.core.errors import ConfigurationError
from tests.unit.conftest import FakeTool

#: Every tool this backend ships, by the name the model calls. Adding a tool
#: adds its name here — one line, and its discovery is proven. Without this
#: list a commented-out ``register(...)`` leaves the suite fully green and the
#: tool simply never reaches the model (spec 0013 AC-1).
EXPECTED_TOOLS = (
    "compute_attribution",
    "get_holdings_summary",
    "payoff",
    "simulate_sale",
)


def test_register_publishes_the_tool_under_its_own_name() -> None:
    registry = ToolRegistry()
    tool = FakeTool()

    registry.register(tool)

    assert registry.names() == ("fake_tool",)
    assert registry.get("fake_tool") is tool


def test_register_a_duplicate_name_raises_configuration_error() -> None:
    registry = ToolRegistry()
    registry.register(FakeTool())

    with pytest.raises(ConfigurationError, match="already registered"):
        registry.register(FakeTool())


def test_get_an_unregistered_name_returns_none_rather_than_raising() -> None:
    assert ToolRegistry().get("no_such_tool") is None


def test_specs_describe_every_tool_in_a_stable_order() -> None:
    registry = ToolRegistry()
    second = FakeTool()
    second.name = "zz_last"
    registry.register(second)
    registry.register(FakeTool())

    specs = registry.specs()

    assert [spec.name for spec in specs] == ["fake_tool", "zz_last"]
    assert specs[0].description == FakeTool.description
    assert specs[0].parameters == FakeTool.parameters


def test_register_helper_fills_the_process_registry() -> None:
    tool = FakeTool()
    tool.name = "process_registry_probe"

    assert register(tool) is tool
    assert REGISTRY.get("process_registry_probe") is tool


@pytest.mark.parametrize("name", EXPECTED_TOOLS, ids=EXPECTED_TOOLS)
def test_load_tools_discovers_every_tool_without_a_shared_list(name: str) -> None:
    """Each tool is reachable by the name the model calls, and is callable."""
    registry = load_tools()

    assert registry is REGISTRY
    assert name in registry.names()
    tool = registry.get(name)
    assert tool is not None
    assert tool.name == name
    assert [spec.name for spec in registry.specs()].count(name) == 1


def test_every_module_that_registers_a_tool_is_named_in_the_expected_list() -> None:
    """A new tool cannot be discovered by nobody.

    Counts the modules whose source ends in a top-level ``register(...)``
    call and compares that with ``EXPECTED_TOOLS``. Adding a tool without
    listing it here fails, and so does listing one that no module registers —
    which is what keeps the parametrized test above honest as tools are added.
    """
    package = Path(str(tools_package.__file__)).parent
    registering = {
        module.stem
        for module in package.glob("*.py")
        if "\nregister(" in module.read_text(encoding="utf-8")
    }

    assert len(registering) == len(EXPECTED_TOOLS)


def test_load_tools_is_idempotent() -> None:
    first = load_tools().names()

    assert load_tools().names() == first
