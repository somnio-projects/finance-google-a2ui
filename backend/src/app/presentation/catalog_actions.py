"""The actions table of the frozen contract (spec 0022 AC-11).

Its own module beside ``catalog_tables`` because it answers a different
question — *what may this surface send back* rather than *what does it show* —
and because that file is at the budget. Both render Markdown from a schema,
never from a literal: the bounds a designer reads here are the ones
``validated_args`` enforces, because both come from the action's own arguments
model.
"""

from collections.abc import Mapping, Sequence
from typing import Any, Final

from app.presentation.catalog_tables import table

ACTION_HEADER: Final[tuple[str, ...]] = (
    "Action",
    "Label",
    "Argument",
    "Control",
    "Accepts",
)
NO_ACTIONS: Final[str] = "_This surface sends nothing back: tapping it starts no turn._"


def actions_table(actions: Sequence[Mapping[str, Any]]) -> str:
    """Render what a surface may send back, or say that it sends nothing.

    Args:
        actions: The ``SurfaceActionRef`` dumps the projection published.

    Returns:
        One row per offered action, with the bound its own arguments model
        enforces — so design reads the same values the backend accepts.
    """
    if not actions:
        return NO_ACTIONS
    rows = [
        (
            f"`{action['action']}`",
            str(action["label"]),
            f"`{action['arg']}`",
            str(action["control"]),
            ", ".join(f"'{choice}'" for choice in action["choices"])
            or str(action["pattern"]),
        )
        for action in actions
    ]
    return table(ACTION_HEADER, rows)


__all__ = ["ACTION_HEADER", "NO_ACTIONS", "actions_table"]
