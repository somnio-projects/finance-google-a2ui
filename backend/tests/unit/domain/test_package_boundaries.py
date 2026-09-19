"""AC-9, AC-5 — the package's structural promises, checked against the source.

These are the two rules a reviewer cannot see by reading one file: the domain
never reads a wall clock (ADR-F D-6) and never imports outward (ADR-C D-6).
Both are asserted over the parsed source, so a docstring mentioning them does
not count as a violation and a real one cannot hide behind a comment.
"""

import ast
from pathlib import Path

import app.domain

PACKAGE = Path(app.domain.__file__).parent
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


def _sources() -> list[Path]:
    modules = sorted(PACKAGE.glob("*.py"))
    assert modules, "the domain package has no modules to check"
    return modules


def _tree(path: Path) -> ast.Module:
    return ast.parse(path.read_text(encoding="utf-8"))


def _imported_modules(tree: ast.Module) -> list[str]:
    modules: list[str] = []
    for node in ast.walk(tree):
        if isinstance(node, ast.ImportFrom) and node.module is not None:
            modules.append(node.module)
        elif isinstance(node, ast.Import):
            modules.extend(alias.name for alias in node.names)
    return modules


def _reads_a_wall_clock(node: ast.AST) -> bool:
    return (
        isinstance(node, ast.Attribute)
        and node.attr in {"now", "today", "utcnow"}
        and isinstance(node.value, ast.Name)
        and node.value.id in {"datetime", "date", "time"}
    )


def _touches_float(node: ast.AST) -> bool:
    if isinstance(node, ast.Name):
        return node.id == "float"
    return isinstance(node, ast.Constant) and type(node.value) is float


def test_domain_never_reads_the_wall_clock() -> None:
    offenders = [
        path.name
        for path in _sources()
        if any(_reads_a_wall_clock(node) for node in ast.walk(_tree(path)))
    ]
    assert offenders == []


def test_domain_has_no_outward_imports() -> None:
    offenders = {
        path.name: [
            module
            for module in _imported_modules(_tree(path))
            if module.startswith(FORBIDDEN_PREFIXES)
        ]
        for path in _sources()
    }
    assert {name: found for name, found in offenders.items() if found} == {}


def test_domain_only_imports_core_from_outside_itself() -> None:
    allowed = {"app.core.errors", "app.core.logging", "app.core.protocols"}
    inside = {
        module
        for path in _sources()
        for module in _imported_modules(_tree(path))
        if module.startswith("app.") and not module.startswith("app.domain")
    }
    assert inside <= allowed


def test_only_the_money_module_mentions_float() -> None:
    offenders = [
        path.name
        for path in _sources()
        if path.name != "money.py"
        and any(_touches_float(node) for node in ast.walk(_tree(path)))
    ]
    assert offenders == []
