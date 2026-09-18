# ADR-H — CI and ship-gate contract

- **Status:** **Proposed** — ratify alongside GGU-45's output
- **Gates:** GGU-45

## Context

> **In the context of** a backlog where every ticket ends with "Done = ship gate green" while
> `.claude/ship-gate.json` is `{"required": []}` and `.github/` does not exist, **facing** the choice
> between enforcing a gate now or leaving it as prose, **we decided** to commit the gate as
> executable commands run on every PR, **and neglected** a soft advisory gate, **to achieve** an
> enforceable definition of Done, **accepting that** early PRs must clear a bar the repo does not
> currently meet.

Today `flutter test` passes on a broken app: the entire Flutter suite is one widget test that pumps
the app and asserts nothing. Any "tests green" claim before that file is replaced is empty.

## Decision

- **D-1** Python gate, run in the backend package: `ruff check .` · `ruff format --check .` · `basedpyright` · `pytest --cov --cov-branch`. The checker choice is **basedpyright**, recorded in `pyproject.toml`.
- **D-2** Flutter gate, run in `client_flutter/`: `dart format --output=none --set-exit-if-changed .` · `dart analyze --fatal-infos --fatal-warnings` · `flutter test` · `flutter build web`.
- **D-3** Coverage `fail_under` starts at **50-60** and ratchets to the rule's 80 by the end of Epic 1. Starting at 80 blocks PR1 on a repo with zero tests. The interim value and the ratchet schedule are recorded here so the deviation is a decision, not an oversight.
- **D-4** iOS/Android builds are **not** in the PR gate (deferred to GGU-27). **GGU-1 AC6 is amended to web-only** — as originally written, GGU-1 could never be marked Done under this gate.
- **D-5** A secret scan is a required step (see [ADR-G](ADR-G-secret-handling.md) D-5).
- **D-6** `client_flutter/e2e_test/` is **excluded** from the PR gate — it needs a real API key, a live backend and long timeouts. It gets an opt-in workflow. Note it is **broken at `410bb9d`**: its harness spawns the backend from a path that does not exist.
- **D-7** The existing backend does not pass ruff/basedpyright strict today (deprecated `Optional`/`Dict` imports, f-strings in logging calls, missing docstrings). GGU-45 MUST either fix these or land a **time-boxed, itemized** per-rule ignore list with a burn-down ticket. It MUST NOT lower the rule set.
- **D-8** Coverage is reviewed **per-file**, not as a single percentage. The network-bound validate/retry and part-parsing paths will sit near 0%; a headline 70% with those at zero is worse than an honest 45%.
- **D-9** The TL commits `.claude/ship-gate.json`. GGU-45 produces it for sign-off.

## Consequences

The first PRs after GGU-45 will be noisier than usual. D-7's itemized ignore list is the release
valve; a blanket ignore would make the gate decorative.
