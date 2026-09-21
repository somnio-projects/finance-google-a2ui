"""Import every projection module so its ``register(...)`` call runs.

Discovery is automatic rather than a hand-maintained import list. ADR-K D-15
requires that adding a chart edit **no** shared file, and an import list is a
shared file: the module that forgets to add its line is silently absent from
OpenAPI, from ``/v1/views`` and from the prompt fragments, which is precisely
the class of bug the registry exists to remove.

Dropping a module in this package is therefore the whole wiring step.
"""

from importlib import import_module
from pkgutil import iter_modules
from typing import Final


def load_views() -> tuple[str, ...]:
    """Import every module of this package and return their names, sorted."""
    names = tuple(sorted(info.name for info in iter_modules(__path__)))
    for name in names:
        import_module(f"{__name__}.{name}")
    return names


LOADED: Final[tuple[str, ...]] = load_views()

__all__ = ["LOADED", "load_views"]
