"""Shared source-level checks for the framework-free packages.

``app.domain`` (spec 0003 AC-9) and ``app.presentation`` (spec 0005 AC-14)
make the same two structural promises: they never import outward and they
never read a wall clock. Both are asserted over the **parsed source**, so a
docstring that mentions ``datetime.now`` is not a violation and a real one
cannot hide behind a comment.

The helpers live here rather than in each suite because the assertion is the
same one twice, and a third inner package would otherwise copy it again.
"""

import ast
from pathlib import Path

#: Layers an inner, framework-free package must never reach into.
FORBIDDEN_PREFIXES = (
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
CLOCK_READS = {"now", "today", "utcnow"}
CLOCK_OWNERS = {"datetime", "date", "time"}


def sources(package: Path, *, recursive: bool = False) -> list[Path]:
    """Return every module of ``package``, sorted, asserting it is not empty."""
    modules = sorted(package.rglob("*.py") if recursive else package.glob("*.py"))
    assert modules, f"{package.name} has no modules to check"
    return modules


def tree(path: Path) -> ast.Module:
    """Parse one module."""
    return ast.parse(path.read_text(encoding="utf-8"))


def imported_modules(path: Path) -> list[str]:
    """Return every module name ``path`` imports, however it imports it."""
    modules: list[str] = []
    for node in ast.walk(tree(path)):
        if isinstance(node, ast.ImportFrom) and node.module is not None:
            modules.append(node.module)
        elif isinstance(node, ast.Import):
            modules.extend(alias.name for alias in node.names)
    return modules


def outward_imports(
    modules: list[Path], *, forbidden: tuple[str, ...] = FORBIDDEN_PREFIXES
) -> dict[str, list[str]]:
    """Return, per module, the imports that point outward — empty when clean."""
    found = {
        path.name: [
            name for name in imported_modules(path) if name.startswith(forbidden)
        ]
        for path in modules
    }
    return {name: hits for name, hits in found.items() if hits}


def imports_outside(modules: list[Path], *, own_prefix: str) -> set[str]:
    """Return every ``app.*`` module imported from outside ``own_prefix``."""
    return {
        name
        for path in modules
        for name in imported_modules(path)
        if name.startswith("app.") and not name.startswith(own_prefix)
    }


def _reads_a_wall_clock(node: ast.AST) -> bool:
    """Return True when ``node`` is a ``datetime.now``-style attribute access."""
    return (
        isinstance(node, ast.Attribute)
        and node.attr in CLOCK_READS
        and isinstance(node.value, ast.Name)
        and node.value.id in CLOCK_OWNERS
    )


def wall_clock_readers(modules: list[Path]) -> list[str]:
    """Return the modules that read a wall clock — empty when clean."""
    return [
        path.name
        for path in modules
        if any(_reads_a_wall_clock(node) for node in ast.walk(tree(path)))
    ]


def _touches_float(node: ast.AST) -> bool:
    """Return True when ``node`` mentions ``float`` or is a float literal."""
    if isinstance(node, ast.Name):
        return node.id == "float"
    return isinstance(node, ast.Constant) and type(node.value) is float


def float_users(modules: list[Path], *, allowed: str) -> list[str]:
    """Return the modules other than ``allowed`` that mention ``float``."""
    return [
        path.name
        for path in modules
        if path.name != allowed
        and any(_touches_float(node) for node in ast.walk(tree(path)))
    ]
