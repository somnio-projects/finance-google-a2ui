"""The Actions table of the frozen contract, rendered from a declaration.

Tested directly rather than through the registry. While `surface.actions`
ships off no projection declares an action (`app.actions.capability`), so a
registry-driven test would render the empty case only and leave the table
itself unexecuted — a renderer nobody has run is a renderer that breaks the
day GGU-31 flips the constant.
"""

from app.actions.declared import declared_action
from app.actions.defined.ask_suggested import ACTION as CHIP
from app.actions.defined.drill_attribution import ACTION as DRILL
from app.presentation.catalog_actions import ACTION_HEADER, NO_ACTIONS, actions_table


def test_a_surface_that_declares_nothing_says_so_rather_than_printing_a_table() -> None:
    assert actions_table([]) == NO_ACTIONS


def test_the_table_prints_the_bound_the_arguments_model_enforces() -> None:
    """The choices a designer reads are the ones ``validated_args`` accepts."""
    rendered = actions_table([declared_action(DRILL).model_dump(mode="json")])

    assert " | ".join(ACTION_HEADER) in rendered
    assert "`drill.attribution.v1`" in rendered
    assert "Break this down" in rendered
    assert "`driver`" in rendered
    assert "'XOM'" in rendered


def test_every_registered_action_renders_one_row() -> None:
    rows = [declared_action(action).model_dump(mode="json") for action in (DRILL, CHIP)]

    rendered = actions_table(rows)

    assert rendered.count("drill.attribution.v1") == 1
    assert rendered.count("ask.suggested.v1") == 1


def test_a_text_control_prints_its_pattern_where_choices_would_go() -> None:
    """``declared.py`` supports a text control, so the table must render one."""
    row = {
        "action": "probe.thing.v1",
        "label": "Probe",
        "arg": "slug",
        "control": "text",
        "choices": [],
        "pattern": "^[a-z]{1,8}$",
    }

    rendered = actions_table([row])

    assert "^[a-z]{1,8}$" in rendered
