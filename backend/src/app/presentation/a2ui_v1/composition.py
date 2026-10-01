"""Which component may sit inside which (ADR-M D-4).

The catalog publishes these rules as ``allowedParents`` / ``allowedChildren``
and the renderer enforces them; the turn reads the same table to decide that
an order ticket and its payoff curve are one surface. One table, two readers,
so the agent cannot compose a tree its own catalog calls invalid.

Only the **exceptions** are written down. Every other component may be the
root of a surface or sit in a ``Section``; the children each container
accepts are derived from the parents table, never listed twice.
"""

import re
from collections.abc import Iterable, Mapping
from typing import Final

#: The reserved container ``createSurface`` instantiates (A2UI v1.0 §catalog).
SURFACE: Final[str] = "Surface"
#: The one layout component this catalog adds to the projections' own.
SECTION: Final[str] = "Section"
#: Where a component may sit when the table below says nothing about it.
DEFAULT_PARENTS: Final[tuple[str, ...]] = (SURFACE, SECTION)

#: ADR-M D-4, verbatim. A payoff curve only means something under the order it
#: prices; a driver detail may stand alone or open under its waterfall.
PARENTS: Final[Mapping[str, tuple[str, ...]]] = {
    "RiskPayoffChart": ("OrderTicket", "MultiLegOrderTicket"),
    "DriverDetail": (SURFACE, "AttributionWaterfall"),
    SECTION: (SURFACE,),
}

_WORD_BREAK: Final[re.Pattern[str]] = re.compile(r"(?<!^)(?=[A-Z])")


def allowed_parents(component: str) -> tuple[str, ...]:
    """Return the component types ``component`` may sit inside.

    Args:
        component: A catalog component name.

    Returns:
        Its declared parents, or ``DEFAULT_PARENTS`` when D-4 names none.
    """
    return PARENTS.get(component, DEFAULT_PARENTS)


def allowed_children(component: str, catalog: Iterable[str]) -> tuple[str, ...]:
    """Return the catalog components that may sit inside ``component``.

    Args:
        component: The would-be container.
        catalog: Every component name the catalog defines.

    Returns:
        Those whose parents include ``component``, sorted; empty for a leaf.
    """
    return tuple(sorted(name for name in catalog if component in allowed_parents(name)))


def nests_only(component: str) -> bool:
    """Say whether ``component`` can never be the root of a surface."""
    return SURFACE not in allowed_parents(component)


def accepts(parent: str, child: str) -> bool:
    """Say whether the turn should draw ``child`` inside ``parent``.

    Only a child that cannot stand on its own is composed: a driver detail
    *may* open under a waterfall, but a turn that drew both meant two answers,
    and folding one into the other would hide that.
    """
    return nests_only(child) and parent in allowed_parents(child)


def label(component: str) -> str:
    """Return the accessible label of ``component``: its name, as words.

    ``MultiLegOrderTicket`` reads ``Multi leg order ticket`` — a short phrase
    a screen reader can announce, derived rather than hand-written so a new
    component is labelled the day it is registered.
    """
    return _WORD_BREAK.sub(" ", component).capitalize()


__all__ = [
    "DEFAULT_PARENTS",
    "PARENTS",
    "SECTION",
    "SURFACE",
    "accepts",
    "allowed_children",
    "allowed_parents",
    "label",
    "nests_only",
]
