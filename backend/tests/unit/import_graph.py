"""Read the import graph out of the source, for the layering tests.

Both inner packages — ``app.domain`` (spec 0003 AC-9) and ``app.agent``
(spec 0006 AC-14) — promise the same thing: they never import outward. The
promise is asserted over the parsed source rather than by convention, so a
docstring naming a forbidden module is not a violation and a real import
cannot hide behind a comment. One copy of the reader, two callers.
"""

import ast
from pathlib import Path

OUTWARD_PREFIXES = (
    "app.api",
    "app.services",
    "app.repositories",
    "app.models",
    "app.schemas",
    "app.infra",
    "app.auth",
    "app.bootstrap",
    "app.main",
)


def tree(path: Path) -> ast.Module:
    """Parse one module."""
    return ast.parse(path.read_text(encoding="utf-8"))


def imported_modules(node: ast.Module) -> list[str]:
    """Return every module name the tree imports, in any form."""
    modules: list[str] = []
    for child in ast.walk(node):
        if isinstance(child, ast.ImportFrom) and child.module is not None:
            modules.append(child.module)
        elif isinstance(child, ast.Import):
            modules.extend(alias.name for alias in child.names)
    return modules


def outward_imports(paths: list[Path]) -> dict[str, list[str]]:
    """Return, per module name, the outward imports it makes (empty when clean)."""
    found = {
        path.name: [
            module
            for module in imported_modules(tree(path))
            if module.startswith(OUTWARD_PREFIXES)
        ]
        for path in paths
    }
    return {name: modules for name, modules in found.items() if modules}


def foreign_imports(paths: list[Path], *, package: str) -> set[str]:
    """Return every ``app.*`` module imported from outside ``package``."""
    return {
        module
        for path in paths
        for module in imported_modules(tree(path))
        if module.startswith("app.") and not module.startswith(package)
    }
