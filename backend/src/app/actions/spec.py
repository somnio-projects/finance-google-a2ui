"""``SurfaceActionSpec`` — the ``SurfaceAction`` an action module builds.

The twin of ``app.presentation.spec``: a module fills this dataclass with its
own id, label, arguments model and ``prompt`` builder, then hands it to
``register``. It is the only implementation of the Protocol the project ships;
an action needing a different shape may implement the Protocol itself without
changing anything here.
"""

from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

from pydantic import BaseModel

from app.actions.contracts import DirectCall


@dataclass(frozen=True, slots=True)
class SurfaceActionSpec:
    """One action, as the module that owns it declares it.

    Attributes:
        id: Versioned identifier, ``<verb>.<subject>.v<N>``.
        label: The words the affordance shows, published with the declaration.
        args: The bounded arguments model a caller may fill.
        prompt: Composes the turn's input from the validated arguments. It is
            backend code: the caller supplies values, never the sentence.
        direct: Builds the tool call a dispatch runs with no model, from the
            validated arguments; ``None`` leaves the turn to the model
            (spec 0056 AC-2).
        mutating: Whether the action changes anything. ``register`` refuses
            ``True`` outright (spec 0022 AC-9).
        audited: Whether a dispatch writes one ``surface_action.invoke``
            event. Off for both shipped actions (0022 §5).
    """

    id: str
    label: str
    args: type[BaseModel]
    prompt: Callable[[Any], str]
    direct: Callable[[Any], DirectCall] | None = None
    mutating: bool = False
    audited: bool = False


__all__ = ["SurfaceActionSpec"]
