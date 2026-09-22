#!/usr/bin/env python3
"""Fail when the OpenAPI document is incomplete or the endpoint table is stale.

Spec 0035: `GET /openapi.json` is how the client is written, so it is gated
like code. The document is built exactly as the server builds it, every
operation is audited against what its route can really do
(``app.api.openapi_audit``), and the human-facing endpoint table is
re-rendered and diffed against the checked-in file (``app.api.endpoint_table``).
This file is the only part that touches the disk or the process; everything it
prints is computed by covered code.

Usage:
    python scripts/check_openapi.py            # audit + drift check (the gate)
    python scripts/check_openapi.py --write    # also rewrite docs/ENDPOINTS.md
"""

import sys
from pathlib import Path

from app.api.endpoint_table import ENDPOINTS_PATH, FIX_COMMAND, endpoint_table
from app.api.openapi_audit import audit
from app.api.openapi_shapes import summarise
from app.api.route_facts import route_facts
from app.bootstrap import create_app
from app.core.config import Settings
from app.presentation.catalog_artifacts import Rendered

REPO_ROOT = Path(__file__).resolve().parents[2]


def documentation_settings() -> Settings:
    """Settings good enough to build the routes; nothing here is ever contacted.

    The document depends on the router, not on configuration, so the values
    are placeholders: an unreachable database, a throwaway HS256 secret. No
    ``.env`` is read — the gate must give the same answer on every machine.
    """
    return Settings.model_validate(
        {
            "environment": "test",
            "database_url": "postgresql+asyncpg://app:app@127.0.0.1:1/nowhere",
            "auth_provider": "jwt",
            "auth_issuer": "https://issuer.invalid",
            "auth_audience": "finance-a2ui-openapi-check",
            "auth_jwt_secret": "not-a-secret-only-builds-the-router-0123456789abcdef",
            "cors_allowed_origins": ["http://localhost:3000"],
        },
        context={"_env_file": None},
    )


def check_table(rendered: Rendered) -> bool:
    """Return True when the checked-in endpoint table matches the document."""
    target = REPO_ROOT / rendered.path
    checked_in = target.read_text(encoding="utf-8") if target.exists() else ""
    drift = rendered.drift(checked_in)
    if not drift:
        print(f"{rendered.path} is current")
        return True
    print(drift, end="")
    print(f"\n{rendered.path} is stale — a route changed. Regenerate it:")
    print(f"  {FIX_COMMAND}")
    return False


def main(argv: list[str]) -> int:
    """Return 0 when the document is complete and the table current, 1 otherwise."""
    app = create_app(documentation_settings())
    document, facts = app.openapi(), route_facts(app)
    findings = audit(document, facts)
    for finding in findings:
        print(finding)
    if findings:
        print(f"\n{len(findings)} finding(s) over {len(facts)} operations, by kind:")
        print(summarise(findings))
    else:
        print(f"openapi ok: {len(facts)} operations fully documented")
    rendered = Rendered(path=ENDPOINTS_PATH, generated=endpoint_table(document, facts))
    if "--write" in argv:
        _ = (REPO_ROOT / rendered.path).write_text(rendered.generated, encoding="utf-8")
        print(f"wrote {rendered.path} ({len(facts)} operations)")
        return 1 if findings else 0
    return 0 if check_table(rendered) and not findings else 1


if __name__ == "__main__":  # pragma: no cover - CLI guard
    sys.exit(main(sys.argv[1:]))
