"""GGU-14 — the model is taught the catalogues from the registries, not by hand."""

from app.agent.prompt import (
    SECTION_BREAK,
    SYSTEM_PROMPT,
    TOOL_SELECTION_RULES,
    compose,
)
from app.agent.registry import load_tools
from app.presentation.registry import REGISTRY
from app.services.prompt_service import build_system_prompt, tool_catalog


def test_every_registered_tool_reaches_the_model() -> None:
    """Registering a tool is what teaches the model about it — AC-1.

    A hand-written list would let a tool ship that the model never learns
    exists, which looks exactly like the model ignoring it.
    """
    tools = load_tools()

    prompt = build_system_prompt(tools=tools, views=REGISTRY.all())

    for name in tools.names():
        assert name in prompt


def test_every_registered_view_reaches_the_model() -> None:
    """Same promise for the projections (ADR-K D-14)."""
    prompt = build_system_prompt(tools=load_tools(), views=REGISTRY.all())

    for projection in REGISTRY.all():
        assert projection.id in prompt


def test_each_tool_is_described_in_the_words_it_registered() -> None:
    tools = load_tools()

    catalog = tool_catalog(tools.specs())

    for spec in tools.specs():
        assert f"- {spec.name} — {spec.description}" in catalog


def test_the_prompt_keeps_the_rules_that_are_code_not_registry() -> None:
    prompt = build_system_prompt(tools=load_tools(), views=REGISTRY.all())

    assert SYSTEM_PROMPT in prompt
    assert TOOL_SELECTION_RULES in prompt


def test_the_tool_rules_name_no_tool() -> None:
    """The one place that could drift from the registry, kept empty.

    A rule mentioning a tool by name would be hand-written catalogue text in
    disguise, and would go stale the moment a tool is renamed.
    """
    registered = load_tools().names()

    assert [name for name in registered if name in TOOL_SELECTION_RULES] == []


def test_the_argument_schema_is_not_repeated_in_the_prompt() -> None:
    """The model gets schemas through the tool-calling API, not as prose.

    Stating them twice invites the two copies to disagree, and spends context
    on something the transport already carries.
    """
    catalog = tool_catalog(load_tools().specs())

    assert "properties" not in catalog
    assert "$defs" not in catalog


def test_compose_drops_a_section_that_has_nothing_to_say() -> None:
    """An empty registry must not leave a dangling heading with no entries."""
    composed = compose(tools="", views="")

    assert composed == f"{SYSTEM_PROMPT}{SECTION_BREAK}{TOOL_SELECTION_RULES}"


def test_compose_keeps_the_sections_in_a_readable_order() -> None:
    composed = compose(tools="TOOLS-HERE", views="VIEWS-HERE")

    assert composed.index(TOOL_SELECTION_RULES) < composed.index("TOOLS-HERE")
    assert composed.index("TOOLS-HERE") < composed.index("VIEWS-HERE")


def test_the_prompt_is_stable_across_two_builds() -> None:
    first = build_system_prompt(tools=load_tools(), views=REGISTRY.all())
    second = build_system_prompt(tools=load_tools(), views=REGISTRY.all())

    assert first == second
