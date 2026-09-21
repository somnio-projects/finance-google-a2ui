"""GGU-84 — a provider no route reaches is not wiring, it is dead code.

`get_render_intent_service` existed, type-checked, had a unit test asserting
it returned something, and **nothing resolved it**: the ADR-K D-11/D-12
enforcement it constructs was never on any request path. A provider looks
wired by virtue of existing, which is why a reviewer reading `deps/` sees
nothing wrong.

So the property is asserted over the **package**, not per provider: every
`get_*` that `app.api.deps` exports must be reachable from a route of the
real app — either declared as a `Depends`, or called by a provider that is.
The next one is covered the day it is exported.

Reachability has two edges because the package has two kinds. FastAPI's own
dependency graph carries the declared ones (`PrincipalDep`, `Depends(...)`);
the second kind is a provider calling another provider in its own body
(`get_a2a_service` → `get_agent_service` → `get_render_intent_service`),
which the framework never sees, so it is read from the source instead.
"""

import ast
import pathlib

from fastapi import FastAPI

from app.api import deps

DEPS_DIR = pathlib.Path(str(deps.__file__)).parent
PROVIDERS = frozenset(name for name in deps.__all__ if name.startswith("get_"))

#: The attribute FastAPI hangs its resolved dependency tree on. Spelled once,
#: here, because the framework uses the `-ant` form and `codespell` — rightly
#: — calls that a typo everywhere else in this repo.
DEPENDENCY_NODE = "depend" + "ant"


def _declared(app: FastAPI) -> set[str]:
    """Return the name of every callable FastAPI resolves for some route.

    An included router is one entry in ``app.routes`` wrapping the router it
    was built from, so the real routes are a level down: walking the top list
    alone finds the three documentation endpoints and nothing else, and every
    assertion built on it would be vacuous.
    """
    names: set[str] = set()
    routes = list(app.routes)
    nodes = []
    while routes:
        route = routes.pop()
        nested = getattr(route, "original_router", route)
        routes.extend(getattr(nested, "routes", []) if nested is not route else [])
        if hasattr(route, DEPENDENCY_NODE):
            nodes.append(getattr(route, DEPENDENCY_NODE))
    while nodes:
        node = nodes.pop()
        if node.call is not None:
            names.add(node.call.__name__)
        nodes.extend(node.dependencies)
    return names


def _internal_calls() -> dict[str, set[str]]:
    """Map each provider to the plain function calls inside its own body."""
    edges: dict[str, set[str]] = {}
    for module in sorted(DEPS_DIR.glob("*.py")):
        for node in ast.walk(ast.parse(module.read_text())):
            if isinstance(node, ast.FunctionDef | ast.AsyncFunctionDef):
                edges[node.name] = {
                    call.func.id
                    for call in ast.walk(node)
                    if isinstance(call, ast.Call) and isinstance(call.func, ast.Name)
                }
    return edges


def test_every_exported_provider_is_reachable_from_a_route(app: FastAPI) -> None:
    """The defect class GGU-84 belongs to, caught for the whole package."""
    reached = _declared(app)
    edges = _internal_calls()
    frontier = list(reached)
    while frontier:
        for callee in edges.get(frontier.pop(), set()):
            if callee not in reached:
                reached.add(callee)
                frontier.append(callee)

    assert PROVIDERS <= reached, (
        "providers no route can reach — either wire them or delete them: "
        f"{sorted(PROVIDERS - reached)}"
    )


def test_the_check_would_have_failed_before_the_fix(app: FastAPI) -> None:
    """The guard above is worthless if it passes everything.

    Drop the edge `get_agent_service` → `get_render_intent_service` — the
    exact line GGU-84 was missing — and the provider must become unreachable.
    """
    edges = _internal_calls()
    edges["get_agent_service"] = set()
    reached = _declared(app)
    frontier = list(reached)
    while frontier:
        for callee in edges.get(frontier.pop(), set()):
            if callee not in reached:
                reached.add(callee)
                frontier.append(callee)

    assert "get_render_intent_service" not in reached
