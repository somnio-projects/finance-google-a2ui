# ADR-C — Backend module layout

- **Status:** Accepted (TL, 2026-09-18)
- **Gates:** GGU-45 (dev tooling + CI)
- **Evidence anchor:** `main` @ `410bb9d`

## Context

> **In the context of** a backend inherited from Google's A2A sample as five flat top-level modules,
> **facing** `.claude/rules/python/module-structure.md` rules 1/4/5/6/9 which mandate a `src/`
> layout, inward-pointing layers, `Protocol` boundaries, a single composition root and structlog,
> **we decided** to perform the **packaging move** (`src/` package) inside GGU-45 and to **defer the
> layering**, **and neglected** (i) staying flat for all of Epic 0 and (ii) doing the full layered
> restructure now, **to achieve** a correct import graph and tool configuration written once against
> the final layout, **accepting that** GGU-45 grows from ~3h to ~5-6h while gating every other
> ticket.

`backend_python/` is today `agent.py`, `agent_executor.py`, `tools.py`, `prompt_builder.py`,
`__main__.py` imported as bare top-level modules, with `pyproject.toml` `packages = ["."]` —
packaging the working directory.

Measured against the repo's own rules: R1 (`src/` layout) violated · R2 (`__all__`) n/a, no package
· R4 (layering) violated — `agent_executor.py:132,149` does domain arithmetic and calls the data
loader directly · R5 (`Protocol` boundaries) violated · R6 (single composition root) partial ·
R9/R10 (structlog) violated.

**Why the move belongs in GGU-45 and not a later ticket:** GGU-45 lands first and bakes the layout
into `[tool.pytest.ini_options]` rootdir/pythonpath, pyright `include`, and `[tool.coverage] source`.
Deciding after GGU-45 means redoing GGU-45. Restructuring is also cheapest before GGU-3, GGU-46 and
GGU-5 write new modules into a flat tree.

**Why the layering is deferred:** you cannot layer a domain that does not exist yet. GGU-5 has not
been written. Layering after it lands is a better-informed job.

## Decision

- **D-1** GGU-45 moves `backend_python/` to `src/a2ui_crypto_market/` with `__init__.py` + `__all__`, replacing bare top-level imports with real package imports.
- **D-2** `pyproject.toml` becomes `packages = ["src/a2ui_crypto_market"]`. `packages = ["."]` is a latent build hazard and is removed.
- **D-3** The Dockerfile entry point is updated off `uv run .`.
- **D-4** GGU-45 writes ruff / pytest / pyright / coverage config against the **new** layout, once.
- **D-5** The `api/application/domain/infrastructure` split with `Protocol` boundaries and a `bootstrap.py` composition root is **deferred** to a ticket scheduled **after GGU-5 lands and before Epic 1's tool tickets (GGU-36–39)**. Four more tools on an unlayered package is the point of no return.
- **D-6** Until D-5 lands, new backend modules MUST NOT import "upward": `portfolio.py` (GGU-5) MUST NOT import from `agent.py`, `agent_executor.py` or `__main__.py`. This preserves the extraction seam at zero cost.
- **D-7** `logging.basicConfig` remains the single logging configuration point for Epic 0. Migration to structlog (rules R9/R10) is deferred and repo-wide — **not** per-file, so GGU-5 MUST use stdlib `logging` for consistency.

## Consequences

The critical path lengthens by ~2-3h at Wave 0, accepted knowingly. Every existing import site
changes in one PR, so GGU-45 must land before any parallel backend work begins. The deviation from
R4/R5/R9 is recorded here once, superseding the per-ticket "flag the tension" footnotes in GGU-3 and
GGU-5.
