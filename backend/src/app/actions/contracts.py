"""What a surface action is, and what it is allowed to be (spec 0022 §3.1).

An action is **an id the client did not invent plus arguments drawn from bounds
the same payload published**. The sentence the turn actually receives is
composed here, in backend code, by the action's own ``prompt`` — an f-string
over arguments a pydantic model has already validated. A template the *client*
sends would be a free-form DSL, which ADR-K D-3 forbids; a template the
*backend* owns is an ordinary function.

``mutating`` exists so the registry can refuse the whole category (spec 0022
AC-9): this showcase has no broker and no execution path, and a flag that can
only be ``False`` is what stops a trade-placing action being added without
first amending the spec and the ADR. ``audited`` is the seam for the first
action that decides something — declared and tested now so it inherits a trail
rather than an omission (0022 §5, OD-4).
"""

from collections.abc import Callable
from typing import Any, Protocol

from pydantic import BaseModel, ConfigDict


class SurfaceAction(Protocol):
    """One registered action and everything the dispatcher needs from it."""

    @property
    def id(self) -> str:
        """Versioned identifier, ``<verb>.<subject>.v<N>``."""
        ...

    @property
    def label(self) -> str:
        """The words on the affordance, published with the declaration."""
        ...

    @property
    def args(self) -> type[BaseModel]:
        """The bounded arguments model; ``extra="forbid"``, scalars only."""
        ...

    @property
    def prompt(self) -> Callable[[Any], str]:
        """Compose the turn's input from validated arguments, server-side."""
        ...

    @property
    def mutating(self) -> bool:
        """Whether the action changes anything; always ``False`` here."""
        ...

    @property
    def audited(self) -> bool:
        """Whether a dispatch writes ``surface_action.invoke``."""
        ...


class ActionArgs(BaseModel):
    """Base of every arguments model: nothing undeclared is ever accepted.

    ``extra="forbid"`` is the whole of D-3 on this path — an argument the
    action does not declare is a rejection, never a value quietly ignored.
    """

    model_config = ConfigDict(frozen=True, extra="forbid")


__all__ = ["ActionArgs", "SurfaceAction"]
