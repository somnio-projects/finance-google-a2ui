"""Import every action module so its ``register(...)`` call runs.

Discovery is automatic rather than a hand-maintained import list, for the
reason ``app.presentation.views`` gives: an import list is a shared file, and
the module that forgets to add its line is silently absent from the registry,
from the declarations a surface publishes and from the generated contract.

Dropping a module in this package is therefore the whole wiring step. The
package is named ``defined`` rather than ``actions`` only so the import path
does not read ``app.actions.actions`` (spec 0022 §2).
"""

from importlib import import_module
from pkgutil import iter_modules
from typing import Final


def load_actions() -> tuple[str, ...]:
    """Import every module of this package and return their names, sorted."""
    names = tuple(sorted(info.name for info in iter_modules(__path__)))
    for name in names:
        import_module(f"{__name__}.{name}")
    return names


LOADED: Final[tuple[str, ...]] = load_actions()

__all__ = ["LOADED", "load_actions"]
