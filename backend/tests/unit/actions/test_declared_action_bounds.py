"""AC-6 — what an action advertises is what the backend enforces.

The twin of ``tests/unit/presentation/test_declared_input_bounds.py``, and it
exists for the same reason: a published bound the backend does not enforce is
client-side-only validation, and `.claude/rules/backend/testing.md` records
that failure three times.

So the check walks the **registry**, not the two actions that exist today:
every advertised choice is fed back through ``validated_args`` — the same call
the A2A path makes — and anything outside the declaration is refused. The next
action is covered the day it registers, not the day somebody remembers.
"""

import re

import pytest

from app.actions.contracts import SurfaceAction
from app.actions.declared import SurfaceActionRef, declared_action
from app.actions.registry import ACTIONS
from app.actions.resolve import UNDECLARED, composed_prompt, validated_args
from app.core.errors import ValidationFailedError

#: Nothing any action's bound admits, and long enough to expose a missing cap.
OUTSIDE = "☠" * 64
#: A pattern bounds a string only if it cannot match arbitrarily long input.
UNBOUNDED = re.compile(r"[*+]")

ACTIONS_UNDER_TEST = list(ACTIONS.all())
IDS = [action.id for action in ACTIONS_UNDER_TEST]


def _ref(action: SurfaceAction) -> SurfaceActionRef:
    """Return the declaration a surface publishes for ``action``."""
    return declared_action(action)


@pytest.mark.parametrize("action", ACTIONS_UNDER_TEST, ids=IDS)
def test_every_bound_an_action_advertises_is_the_bound_it_enforces(
    action: SurfaceAction,
) -> None:
    """Branch on the control, because ``declared.py`` already supports both.

    Asserting `choices` is non-empty for *every* action would fail the day
    somebody ships the `control="text"` action the descriptor already allows —
    a guard that breaks on a legal shape is a guard that gets deleted.
    """
    ref = _ref(action)
    if ref.control == "choice":
        assert ref.choices, "a choice control with no choices offers nothing"
        for value in ref.choices:
            assert validated_args(action, {ref.arg: value})
        return
    assert ref.pattern, "a text control with no pattern publishes no bound"
    assert ref.pattern.startswith("^") and ref.pattern.endswith("$")
    assert not UNBOUNDED.search(ref.pattern)


@pytest.mark.parametrize("action", ACTIONS_UNDER_TEST, ids=IDS)
def test_a_value_outside_the_published_bound_is_rejected(
    action: SurfaceAction,
) -> None:
    ref = _ref(action)
    with pytest.raises(ValidationFailedError, match=f"argument.*{ref.arg}"):
        validated_args(action, {ref.arg: OUTSIDE})


@pytest.mark.parametrize("action", ACTIONS_UNDER_TEST, ids=IDS)
def test_the_published_bound_is_read_from_the_arguments_schema(
    action: SurfaceAction,
) -> None:
    ref = _ref(action)
    schema = action.args.model_json_schema()["properties"][ref.arg]

    if ref.control == "choice":
        assert tuple(schema["enum"]) == ref.choices
        return
    assert schema["pattern"] == ref.pattern


@pytest.mark.parametrize("action", ACTIONS_UNDER_TEST, ids=IDS)
def test_an_undeclared_argument_is_rejected_without_echoing_its_name(
    action: SurfaceAction,
) -> None:
    """AC-5 — a rejection names the argument, never caller input.

    The *name* of an undeclared key came from the caller, and this message is
    reflected into a JSON-RPC error with a 256-character field behind it, so
    it is replaced by a constant instead of echoed.
    """
    with pytest.raises(ValidationFailedError, match=UNDECLARED):
        validated_args(action, {"<script>alert(1)</script>": "x"})


@pytest.mark.parametrize("action", ACTIONS_UNDER_TEST, ids=IDS)
def test_every_action_composes_a_non_empty_prompt_from_its_defaults(
    action: SurfaceAction,
) -> None:
    """AC-3 — the sentence is the backend's; it must actually exist."""
    prompt = composed_prompt(action, {})

    assert prompt.strip()
    assert action.id not in prompt


@pytest.mark.parametrize("action", ACTIONS_UNDER_TEST, ids=IDS)
def test_no_shipped_action_mutates_or_is_audited(action: SurfaceAction) -> None:
    """AC-9, AC-10 — the catalog decides nothing, so it records nothing."""
    assert not action.mutating
    assert not action.audited


def test_at_least_one_action_was_checked() -> None:
    """A registry that failed to load would make every case above vacuous."""
    assert ACTIONS_UNDER_TEST, "no action was checked — did the registry load?"
