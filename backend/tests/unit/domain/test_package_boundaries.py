"""AC-9, AC-5 — the package's structural promises, checked against the source.

These are the two rules a reviewer cannot see by reading one file: the domain
never reads a wall clock (ADR-F D-6) and never imports outward (ADR-C D-6).
Both are asserted over the parsed source, so a docstring mentioning them does
not count as a violation and a real one cannot hide behind a comment.
"""

import ast
from pathlib import Path

import app.domain
from tests.unit.import_graph import foreign_imports, outward_imports
from tests.unit.import_graph import tree as parse

PACKAGE = Path(app.domain.__file__).parent


def _sources() -> list[Path]:
    modules = sorted(PACKAGE.glob("*.py"))
    assert modules, "the domain package has no modules to check"
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
        if any(_reads_a_wall_clock(node) for node in ast.walk(parse(path)))
    ]
    assert offenders == []


def test_domain_has_no_outward_imports() -> None:
    assert outward_imports(_sources()) == {}


def test_domain_only_imports_core_from_outside_itself() -> None:
    allowed = {"app.core.errors", "app.core.logging", "app.core.protocols"}

    assert foreign_imports(_sources(), package="app.domain") <= allowed


def test_only_the_money_module_mentions_float() -> None:
    offenders = [
        path.name
        for path in _sources()
        if path.name != "money.py"
        and any(_touches_float(node) for node in ast.walk(parse(path)))
    ]
    assert offenders == []
