"""The projection registry — one registration, four consumers (ADR-K D-7/D-14).

Registering a projection from its **own** module publishes it to the OpenAPI
document, the ``GET /v1/views`` catalog, the generated prompt fragments and the
A2UI adapter at once. Adding a chart therefore costs one new module under
``views/`` and edits nothing here (ADR-K D-15): there is no list of ids, no
enum and no ``if/elif`` in this file, and there must never be one. If a chart
cannot be added without touching a shared file, the seam is wrong — fix it
rather than extending the chain.
"""

from collections.abc import Callable, Mapping
from typing import Any, Final, Protocol

from pydantic import BaseModel

from app.core.errors import ConfigurationError
from app.domain.portfolio import Portfolio
from app.presentation.errors import UnknownViewError
from app.presentation.fragments import ProjectionDto
from app.presentation.surfaces import Surface


class Projection(Protocol):
    """One named, versioned projection and everything its consumers need."""

    @property
    def id(self) -> str:
        """Versioned identifier, ``<component>.<variant>.v<N>``."""
        ...

    @property
    def summary(self) -> str:
        """One line of purpose, for the catalog and the prompt fragments."""
        ...

    @property
    def endpoints(self) -> tuple[str, ...]:
        """The endpoints that serve this projection."""
        ...

    @property
    def options(self) -> type[BaseModel]:
        """The bounded options model a caller may fill."""
        ...

    @property
    def dto(self) -> type[ProjectionDto]:
        """The payload type, discriminated by its ``view`` literal."""
        ...

    @property
    def example(self) -> Mapping[str, Any]:
        """A rendered example payload, for OpenAPI and the catalog."""
        ...

    @property
    def render(self) -> Callable[[Portfolio, Any], ProjectionDto]:
        """Pure ``(portfolio, options) → DTO``: no I/O, no clock, no rules."""
        ...

    @property
    def surface(self) -> Callable[[Any], Surface]:
        """The A2UI adapter turning the payload into a surface."""
        ...

    @property
    def fitness(self) -> Callable[[Portfolio], int]:
        """How well the projection suits the data; ``0`` = never auto-selected."""
        ...


class ProjectionRegistry:
    """Every registered projection, addressable by id and ordered by it."""

    def __init__(self) -> None:
        """Create an empty registry."""
        self._projections: dict[str, Projection] = {}

    def add(self, projection: Projection) -> None:
        """Register ``projection``.

        Args:
            projection: The projection to publish to every consumer.

        Raises:
            ConfigurationError: When its id is already registered. Two
                projections sharing an id make the discriminated union
                ambiguous, so it fails at import, not at request time.
        """
        if projection.id in self._projections:
            msg = f"projection {projection.id!r} is already registered"
            raise ConfigurationError(msg)
        self._projections[projection.id] = projection

    def get(self, view: str) -> Projection:
        """Return the projection registered under ``view``.

        Args:
            view: The projection id the caller or the model asked for.

        Returns:
            The registered projection.

        Raises:
            UnknownViewError: When nothing is registered under ``view``.
        """
        try:
            return self._projections[view]
        except KeyError as exc:
            msg = f"view {view!r} is not registered"
            raise UnknownViewError(msg) from exc

    def all(self) -> tuple[Projection, ...]:
        """Return every registered projection, ordered by id."""
        return tuple(self._projections[key] for key in sorted(self._projections))

    def remove(self, view: str) -> None:
        """Forget ``view`` if it is registered — for tests that add their own."""
        self._projections.pop(view, None)


REGISTRY: Final[ProjectionRegistry] = ProjectionRegistry()


def register(projection: Projection) -> Projection:
    """Publish ``projection`` from its own module and return it (ADR-K D-7)."""
    REGISTRY.add(projection)
    return projection


__all__ = [
    "REGISTRY",
    "Projection",
    "ProjectionRegistry",
    "register",
]
