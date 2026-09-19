"""AC-14 — the package's structural promises, checked against the source.

A projection is pure by contract (ADR-K D-6), and a docstring saying so does
not make it true. These assertions parse the package: no outward import, no
framework import, no wall-clock read anywhere under ``app/presentation/``.
The helpers are shared with the domain suite (``tests/boundaries.py``).
"""

from pathlib import Path

import app.presentation
from tests.boundaries import (
    FORBIDDEN_PREFIXES,
    imports_outside,
    outward_imports,
    sources,
    wall_clock_readers,
)

PACKAGE = Path(app.presentation.__file__).parent
NO_FRAMEWORKS = (*FORBIDDEN_PREFIXES, "sqlalchemy", "fastapi", "starlette")
ALLOWED_OUTSIDE = ("app.core.", "app.domain.")


def _modules() -> list[Path]:
    return sources(PACKAGE, recursive=True)


def test_presentation_has_no_outward_imports() -> None:
    assert outward_imports(_modules(), forbidden=NO_FRAMEWORKS) == {}


def test_presentation_only_imports_core_and_domain_from_outside_itself() -> None:
    outside = imports_outside(_modules(), own_prefix="app.presentation")
    assert all(module.startswith(ALLOWED_OUTSIDE) for module in outside), outside


def test_presentation_never_reads_the_wall_clock() -> None:
    assert wall_clock_readers(_modules()) == []


def test_every_view_module_registers_exactly_one_projection() -> None:
    modules = [
        path
        for path in sorted((PACKAGE / "views").glob("*.py"))
        if path.name != "__init__.py"
    ]
    assert modules, "no view modules found"
    for path in modules:
        source = path.read_text(encoding="utf-8")
        assert source.count("= register(") == 1, path.name
