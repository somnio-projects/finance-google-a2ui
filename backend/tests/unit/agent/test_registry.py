"""Spec 0006 AC-7 — local registration, discovery, and the duplicate guard."""

import pytest

from app.agent.registry import REGISTRY, ToolRegistry, load_tools, register
from app.core.errors import ConfigurationError
from tests.unit.conftest import FakeTool


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


def test_load_tools_discovers_the_reference_tool_without_a_shared_list() -> None:
    registry = load_tools()

    assert registry is REGISTRY
    assert "get_holdings_summary" in registry.names()


def test_load_tools_is_idempotent() -> None:
    first = load_tools().names()

    assert load_tools().names() == first
