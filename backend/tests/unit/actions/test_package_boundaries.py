"""OD-8 — the actions package is framework-free, and the arrow points one way.

``app.actions`` is a peer of ``app.presentation``, not a layer above it. The
dependency that makes the design work is ``presentation → actions`` (a
projection imports the declaration it publishes); the reverse would be
circular, and a docstring saying so does not make it true. These assertions
parse the package.

The last one is the load-bearing one: ``app.presentation`` may import
``app.actions`` (its own boundary test allows the prefix), so nothing but this
check stops the arrow being reversed one import at a time.
"""

from pathlib import Path

import app.actions
from tests.boundaries import (
    FORBIDDEN_PREFIXES,
    imports_outside,
    outward_imports,
    sources,
    wall_clock_readers,
)

PACKAGE = Path(app.actions.__file__).parent
NO_FRAMEWORKS = (*FORBIDDEN_PREFIXES, "sqlalchemy", "fastapi", "starlette")
ALLOWED_OUTSIDE = ("app.core.", "app.domain.")


def _modules() -> list[Path]:
    return sources(PACKAGE, recursive=True)


def test_actions_has_no_outward_imports() -> None:
    assert outward_imports(_modules(), forbidden=NO_FRAMEWORKS) == {}


def test_actions_only_imports_core_and_domain_from_outside_itself() -> None:
    outside = imports_outside(_modules(), own_prefix="app.actions")

    assert all(module.startswith(ALLOWED_OUTSIDE) for module in outside), outside


def test_actions_never_imports_presentation() -> None:
    """The arrow points ``presentation → actions`` and must stay that way."""
    outside = imports_outside(_modules(), own_prefix="app.actions")

    assert not [name for name in outside if name.startswith("app.presentation")]


def test_actions_never_reads_the_wall_clock() -> None:
    assert wall_clock_readers(_modules()) == []


def test_every_action_module_registers_exactly_one_action() -> None:
    """AC-2 — discovery is unambiguous: one module, one ``register(...)``."""
    modules = [
        path
        for path in sorted((PACKAGE / "defined").glob("*.py"))
        if path.name != "__init__.py"
    ]
    assert modules, "no action modules found"
    for path in modules:
        source = path.read_text(encoding="utf-8")
        assert source.count("= register(") == 1, path.name
