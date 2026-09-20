"""Spec 0006 AC-2 and AC-14 — the structural promises, checked over the source.

Three rules a reviewer cannot see by reading one file: ``app.agent`` is an
inner layer that never imports outward, the turn loop touches neither a
framework nor a session, and the provider API key is read in exactly one
module. The AST helpers are shared with the domain and presentation suites in
``tests/boundaries.py`` — one reader, three callers.
"""

from pathlib import Path

import app.agent
import app.services.agent_service
from tests.boundaries import imported_modules, imports_outside, outward_imports, sources

AGENT_PACKAGE = Path(app.agent.__file__).parent
SRC_ROOT = AGENT_PACKAGE.parent.parent
SERVICE_FORBIDDEN = ("fastapi", "starlette", "sqlalchemy", "app.models", "app.api")


def _agent_sources() -> list[Path]:
    return sources(AGENT_PACKAGE, recursive=True)


def test_agent_package_has_no_outward_imports() -> None:
    assert outward_imports(_agent_sources()) == {}


def test_agent_package_only_imports_core_and_domain_from_outside_itself() -> None:
    outside = imports_outside(_agent_sources(), own_prefix="app.agent")

    assert [
        m for m in sorted(outside) if not m.startswith(("app.core", "app.domain"))
    ] == []


def test_agent_service_imports_no_framework_and_no_session_module() -> None:
    imported = imported_modules(Path(app.services.agent_service.__file__))

    assert [m for m in imported if m.startswith(SERVICE_FORBIDDEN)] == []
    assert [m for m in imported if "session" in m] == []


def test_the_api_key_setting_is_referenced_only_by_config_and_the_factory() -> None:
    readers = sorted(
        path.relative_to(SRC_ROOT).as_posix()
        for path in (SRC_ROOT / "app").rglob("*.py")
        if "gemini_api_key" in path.read_text(encoding="utf-8")
    )

    # What this guard is for: the key is DECLARED in config and CONSUMED in the
    # factory, and no third module branches on whether it is set. `config` is
    # two files only because of the 150-line budget — `config_parsing` holds the
    # validators that turn raw environment strings into these fields, so naming
    # the field there is the declaration, not a call site. If a module outside
    # `app/core/config*` or the model adapter appears in this list, that is the
    # failure the test was written for.
    assert readers == [
        "app/core/config.py",
        "app/core/config_parsing.py",
        "app/infra/model/factory.py",
    ]


def test_get_secret_value_for_the_model_key_lives_only_in_the_adapter() -> None:
    callers = sorted(
        path.relative_to(SRC_ROOT).as_posix()
        for path in (SRC_ROOT / "app" / "infra" / "model").rglob("*.py")
        if "get_secret_value" in path.read_text(encoding="utf-8")
    )

    assert callers == ["app/infra/model/gemini_client.py"]
