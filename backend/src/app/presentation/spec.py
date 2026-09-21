"""``ProjectionSpec`` — the ``Projection`` a view module builds (ADR-K D-7).

A view module fills this dataclass with its own id, options model, DTO, pure
``render``, A2UI adapter and fitness, then hands it to ``register``. It is the
only implementation of the Protocol the project ships; a projection that needs
a different shape may implement the Protocol itself without changing anything
here.

``example`` is a **property**, not a field: rendering the projection over the
fixed sample portfolio is how the documented example stays true to the DTO for
free (spec 0005 OD-2). A hand-written example is a second source of truth, and
the one that goes stale.
"""

from collections.abc import Callable, Mapping
from dataclasses import dataclass
from typing import Any

from pydantic import BaseModel

from app.domain.portfolio import Portfolio
from app.presentation.fragments import ProjectionDto
from app.presentation.guidance import Guidance
from app.presentation.sample import sample_portfolio
from app.presentation.surfaces import Surface


@dataclass(frozen=True, slots=True)
class ProjectionSpec:
    """One projection, as the module that owns it declares it."""

    id: str
    summary: str
    endpoints: tuple[str, ...]
    options: type[BaseModel]
    dto: type[ProjectionDto]
    render: Callable[[Portfolio, Any], ProjectionDto]
    surface: Callable[[Any], Surface]
    fitness: Callable[[Portfolio], int]
    #: The do/don't pair the model is taught, when design has written one.
    #: Defaulted so a view whose design page was never exported registers
    #: without inventing guidance for itself (``presentation.guidance``).
    guidance: Guidance | None = None

    @property
    def example(self) -> Mapping[str, Any]:
        """Render this projection over the sample portfolio, at its defaults."""
        return self.render(sample_portfolio(), self.options()).model_dump(mode="json")


__all__ = ["ProjectionSpec"]
