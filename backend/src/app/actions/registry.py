"""The action registry — one registration, three consumers (spec 0022 AC-2).

Registering an action from its **own** module publishes it to the dispatcher,
to the ``SurfaceActionRef`` a projection declares, and to the generated
contract. Adding an action therefore costs one new module under ``defined/``
and edits nothing here: there is no list of ids, no enum and no ``if/elif`` in
this file, and there must never be one — the ADR-K D-15 guarantee, applied to
actions.

Two things this registry **refuses**, both at import time rather than at
request time:

* an id that is not ``<verb>.<subject>.v<N>`` — the client resolves ids it did
  not invent, so the id space has to be a shape and not a convention;
* ``mutating=True`` — this showcase has no broker and no execution path, and
  refusing the whole category is what makes "nobody adds a trade-placing
  action by accident" a property of the code rather than of a reviewer's
  memory (spec 0022 AC-9, §5; the 0018 OD-2 honesty measure, one level up).
"""

import re
from typing import Final

from app.actions.contracts import SurfaceAction
from app.actions.errors import UnknownActionError
from app.core.errors import ConfigurationError

#: ``drill.attribution.v1`` — a lowercase verb, a dotted subject, a version.
ACTION_ID_PATTERN: Final[str] = r"^[a-z][a-z0-9]*(\.[a-z0-9-]+)+\.v[0-9]+$"
_ACTION_ID = re.compile(ACTION_ID_PATTERN)


class ActionRegistry:
    """Every registered action, addressable by id and ordered by it."""

    def __init__(self) -> None:
        """Create an empty registry."""
        self._actions: dict[str, SurfaceAction] = {}

    def add(self, action: SurfaceAction) -> None:
        """Register ``action``.

        Args:
            action: The action to publish to every consumer.

        Raises:
            ConfigurationError: When its id is malformed or already taken, or
                when it declares itself mutating — none of which a request
                should be able to discover, so all three fail at import.
        """
        if action.mutating:
            msg = (
                f"action {action.id!r} declares mutating=True; this service has "
                "no execution path (spec 0022 AC-9)"
            )
            raise ConfigurationError(msg)
        if _ACTION_ID.match(action.id) is None:
            msg = f"action id {action.id!r} does not match {ACTION_ID_PATTERN}"
            raise ConfigurationError(msg)
        if action.id in self._actions:
            msg = f"action {action.id!r} is already registered"
            raise ConfigurationError(msg)
        self._actions[action.id] = action

    def get(self, action_id: str) -> SurfaceAction:
        """Return the action registered under ``action_id``.

        Args:
            action_id: The id the surface sent back.

        Returns:
            The registered action.

        Raises:
            UnknownActionError: When nothing is registered under that id.
        """
        try:
            return self._actions[action_id]
        except KeyError as exc:
            msg = f"action {action_id!r} is not registered"
            raise UnknownActionError(msg) from exc

    def all(self) -> tuple[SurfaceAction, ...]:
        """Return every registered action, ordered by id."""
        return tuple(self._actions[key] for key in sorted(self._actions))

    def remove(self, action_id: str) -> None:
        """Forget ``action_id`` if registered — for tests that add their own."""
        self._actions.pop(action_id, None)


ACTIONS: Final[ActionRegistry] = ActionRegistry()


def register(action: SurfaceAction) -> SurfaceAction:
    """Publish ``action`` from its own module and return it."""
    ACTIONS.add(action)
    return action


__all__ = [
    "ACTIONS",
    "ACTION_ID_PATTERN",
    "ActionRegistry",
    "UnknownActionError",
    "register",
]
