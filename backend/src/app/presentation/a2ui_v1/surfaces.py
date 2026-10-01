"""One rendered view → one surface; a ticket and its curve → one (ADR-M D-3, D-4).

A turn yields its render intents one at a time (ADR-K D-19). Most become a
surface the moment they are rendered. A component that cannot stand alone —
the payoff curve — instead joins the surface of the container right before it,
so a container is **held** until the next view arrives or the turn ends.
Order is never changed: a held surface is always released before anything
that came after it.
"""

from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from typing import Any, Final

from app.presentation.a2ui_v1.composition import (
    PARENTS,
    accepts,
    label,
    nests_only,
)
from app.presentation.a2ui_v1.messages import Message, bound, create_surface
from app.presentation.a2ui_v1.wire import ROOT


@dataclass(frozen=True, slots=True)
class RenderedView:
    """One view of a turn, rendered and ready to be drawn.

    Attributes:
        index: Its position in the turn; the surface id is derived from it.
        component: The A2UI component its adapter names.
        view: The projection id.
        options: The options it was rendered with.
        payload: The DTO as JSON, exactly as the REST read serves it.
    """

    index: int
    component: str
    view: str
    options: Mapping[str, Any]
    payload: Mapping[str, Any]

    @property
    def child_id(self) -> str:
        """The id it takes inside another surface: its view's family, ``payoff``."""
        return self.view.split(".", 1)[0]


#: The components a nest-only child may be composed into, read off D-4 — the
#: tickets, not the waterfall: a driver detail can stand alone, so a waterfall
#: is never held back waiting for one.
CONTAINERS: Final[frozenset[str]] = frozenset(
    parent
    for child, parents in PARENTS.items()
    if nests_only(child)
    for parent in parents
)


def _node(
    component_id: str, view: RenderedView, children: Sequence[str]
) -> dict[str, Any]:
    """Return one component of the adjacency list."""
    node: dict[str, Any] = {
        "id": component_id,
        "component": view.component,
        "data": {"path": f"/{component_id}"},
        "accessibility": {"label": label(view.component)},
    }
    if children:
        node["children"] = list(children)
    return node


def surface_message(task_id: str, group: Sequence[RenderedView]) -> Message:
    """Return the ``createSurface`` for one root view and its composed children.

    Args:
        task_id: The turn's correlation id; the surface id is
            ``<task_id>-<index of the root view>``.
        group: The root view first, then any child composed into it.
    """
    root, *children = group
    nodes = [_node(ROOT, root, [child.child_id for child in children])]
    nodes.extend(_node(child.child_id, child, ()) for child in children)
    model = {ROOT: bound(root.view, root.options, root.payload)}
    model.update(
        {
            child.child_id: bound(child.view, child.options, child.payload)
            for child in children
        }
    )
    return create_surface(f"{task_id}-{root.index}", nodes, model)


class SurfaceComposer:
    """Group a turn's rendered views into surfaces, in order (ADR-M D-4)."""

    def __init__(self) -> None:
        """Start with nothing held."""
        self._held: list[RenderedView] = []

    def add(self, view: RenderedView) -> list[tuple[RenderedView, ...]]:
        """Take one rendered view and return the surfaces now complete.

        Returns:
            Zero, one or two groups, each a root view and its children.
        """
        if self._held and accepts(self._held[0].component, view.component):
            self._held.append(view)
            return []
        ready = self.flush()
        if view.component in CONTAINERS:
            self._held = [view]
            return ready
        return [*ready, (view,)]

    def flush(self) -> list[tuple[RenderedView, ...]]:
        """Release whatever is held, at the end of the turn or before a new view."""
        held, self._held = self._held, []
        return [tuple(held)] if held else []


__all__ = ["CONTAINERS", "RenderedView", "SurfaceComposer", "surface_message"]
