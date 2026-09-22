"""The human-facing endpoint table, rendered from the document (spec 0035 OD-4).

`backend/README.md` used to carry a hand-written list of routes, and it had
fallen behind the router by five operations. This renders the table from the
same document `/openapi.json` serves and the same facts the audit reads, so
"every route, with its method, path, auth, purpose and spec" is a property
`make openapi-check` proves rather than one a reviewer remembers to check.
"""

import re
from collections.abc import Sequence
from typing import Any, Final

from app.api.route_facts import RouteFacts

ENDPOINTS_PATH: Final[str] = "backend/docs/ENDPOINTS.md"
FIX_COMMAND: Final[str] = "cd backend && make openapi-docs"
#: A spec number (`0027`) or an ADR letter (`ADR-K`) named in a description.
REFERENCE: Final[re.Pattern[str]] = re.compile(r"\b(0\d{3}|ADR-[A-Z])\b")

HEADER: Final[str] = (
    "# Endpoints\n\n"
    f"GENERATED FILE — do not edit by hand. Regenerate with: `{FIX_COMMAND}`\n\n"
    "Every operation `GET /openapi.json` serves, read from the built application:\n"
    "the method and path from the router, **Auth** and **Flag** from the route's\n"
    "dependency tree (`api/route_facts.py`), the purpose from its `summary` and\n"
    "the spec from its `description`. `make openapi-check` fails when this table\n"
    "and the document disagree, so a route cannot ship undocumented here.\n\n"
    "`public` routes need no token (`.claude/rules/backend/security.md`);\n"
    "`bearer` ones take `Authorization: Bearer <token>`. A **Flag** names the\n"
    "feature flag that answers 404 `feature-disabled` while it is off. The\n"
    "interactive document is `/docs` and the raw one `/openapi.json`, both off\n"
    "in production.\n\n"
    "| Method | Path | Auth | Flag | Purpose | Spec |\n"
    "|---|---|---|---|---|---|\n"
)


def references(description: str) -> str:
    """The spec numbers and ADRs a description names, deduplicated, in order."""
    seen: list[str] = []
    for match in REFERENCE.findall(description):
        if match not in seen:
            seen.append(match)
    return ", ".join(seen) or "—"


def _row(op: dict[str, Any], facts: RouteFacts) -> str:
    """One table row for one operation."""
    auth = "bearer" if facts.authenticated else "public"
    flag = f"`{facts.feature_key}`" if facts.feature_key else "—"
    return (
        f"| `{facts.method.upper()}` | `{facts.path}` | {auth} | {flag} "
        f"| {op.get('summary', '')} | {references(str(op.get('description', '')))} |"
    )


def endpoint_table(document: dict[str, Any], facts: Sequence[RouteFacts]) -> str:
    """Render the Markdown table, one row per operation in route order.

    Args:
        document: ``app.openapi()``.
        facts: ``route_facts(app)`` for the same application.
    """
    rows = [_row(fact.operation(document), fact) for fact in facts]
    return HEADER + "\n".join(rows) + "\n"


__all__ = ["ENDPOINTS_PATH", "FIX_COMMAND", "endpoint_table", "references"]
