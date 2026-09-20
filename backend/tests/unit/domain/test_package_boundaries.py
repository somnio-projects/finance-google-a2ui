"""AC-9, AC-5 — the package's structural promises, checked against the source.

These are the two rules a reviewer cannot see by reading one file: the domain
never reads a wall clock (ADR-F D-6) and never imports outward (ADR-C D-6).
The shared AST helpers live in ``tests/boundaries.py`` — ``app.presentation``
makes the same promises and asserts them the same way (spec 0005 AC-14).
"""

from pathlib import Path

import app.domain
from tests.boundaries import (
    float_users,
    imports_outside,
    outward_imports,
    sources,
    wall_clock_readers,
)

PACKAGE = Path(app.domain.__file__).parent


def test_domain_never_reads_the_wall_clock() -> None:
    assert wall_clock_readers(sources(PACKAGE)) == []


def test_domain_has_no_outward_imports() -> None:
    assert outward_imports(sources(PACKAGE)) == {}


def test_domain_only_imports_core_from_outside_itself() -> None:
    allowed = {"app.core.errors", "app.core.logging", "app.core.protocols"}
    assert imports_outside(sources(PACKAGE), own_prefix="app.domain") <= allowed


def test_only_the_money_module_mentions_float() -> None:
    assert float_users(sources(PACKAGE), allowed="money.py") == []
