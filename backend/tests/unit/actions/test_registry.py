"""AC-2, AC-9 — what the action registry publishes, and what it refuses.

The refusals are the interesting half. ``mutating=True`` is rejected at
**import**, not at request time, so nobody can add a trade-placing action to a
service that has no broker without first amending spec 0022 and ADR-K; and a
malformed id is rejected for the same reason the view registry rejects a
duplicate — the id space a client resolves against has to be a shape, not a
convention somebody remembered.
"""

from collections.abc import Iterator

import pytest

from app.actions.contracts import ActionArgs
from app.actions.defined import LOADED, load_actions
from app.actions.errors import UnknownActionError
from app.actions.registry import ACTIONS, ActionRegistry, register
from app.actions.spec import SurfaceActionSpec
from app.core.errors import ConfigurationError

PROBE_ID = "probe.thing.v1"


class _ProbeArgs(ActionArgs):
    """No arguments; the registry does not care how many there are."""


def _probe_prompt(args: _ProbeArgs) -> str:
    """Compose the throwaway action's turn input."""
    del args
    return "probe"


def _spec(action_id: str = PROBE_ID, **overrides: object) -> SurfaceActionSpec:
    """Build a throwaway action the registry can be handed."""
    fields: dict[str, object] = {
        "id": action_id,
        "label": "Probe",
        "args": _ProbeArgs,
        "prompt": _probe_prompt,
    }
    return SurfaceActionSpec(**(fields | overrides))  # type: ignore[arg-type]


@pytest.fixture
def probe() -> Iterator[SurfaceActionSpec]:
    """Register a throwaway action and take it back out afterwards."""
    spec = _spec()
    register(spec)
    yield spec
    ACTIONS.remove(PROBE_ID)


def test_an_action_registers_from_its_own_module_and_is_resolvable(
    probe: SurfaceActionSpec,
) -> None:
    """AC-2 — the registry is the only thing a dispatch consults."""
    assert ACTIONS.get(PROBE_ID) is probe
    assert probe in ACTIONS.all()


def test_the_registry_is_ordered_by_id() -> None:
    ids = [action.id for action in ACTIONS.all()]

    assert ids == sorted(ids)


def test_an_unknown_action_id_is_refused_rather_than_guessed() -> None:
    with pytest.raises(UnknownActionError, match="is not registered"):
        ACTIONS.get("no.such.v1")


def test_a_mutating_action_cannot_be_registered() -> None:
    """AC-9 — the category is refused, not merely unused."""
    with pytest.raises(ConfigurationError, match="declares mutating=True"):
        register(_spec(mutating=True))


@pytest.mark.parametrize(
    "action_id",
    ["nodots", "Upper.Case.v1", "drill.attribution", "drill.attribution.v", "1.a.v1"],
    ids=["no_dots", "uppercase", "no_version", "empty_version", "leading_digit"],
)
def test_a_malformed_action_id_is_refused_at_import(action_id: str) -> None:
    with pytest.raises(ConfigurationError, match="does not match"):
        register(_spec(action_id))


def test_registering_the_same_id_twice_fails_at_import(
    probe: SurfaceActionSpec,
) -> None:
    del probe
    with pytest.raises(ConfigurationError, match="already registered"):
        register(_spec())


def test_removing_an_unregistered_id_is_a_no_op() -> None:
    registry = ActionRegistry()

    registry.remove("never.registered.v1")

    assert registry.all() == ()


def test_adding_an_action_edits_no_shared_file() -> None:
    """AC-2 — discovery walks the package; there is no import list to forget."""
    assert LOADED == load_actions()
    assert set(LOADED) == {"ask_suggested", "drill_attribution"}
    assert {action.id for action in ACTIONS.all()} >= {
        "ask.suggested.v1",
        "drill.attribution.v1",
    }
