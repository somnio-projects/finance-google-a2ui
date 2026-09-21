# DEV_HARNESS — how this repo is developed with Claude Code

This document describes the AI harness (Somnio codelab 2, "Del prompt al
harness") as applied to `finance-google-a2ui`, and how to reproduce the ship
gate by hand. It is the human-readable counterpart of `.claude/`.

## The pieces

| Piece | Where | Role |
|---|---|---|
| Operating manual | `CLAUDE.md` (root index), `backend/CLAUDE.md`, `frontend/CLAUDE.md` | Always loaded. Run/verify commands, conventions the code does not show, do-not-touch. Kept under 200 lines. |
| Rules | `.claude/rules/backend/*.md`, `.claude/rules/frontend/*.md`, `.claude/rules/python/*.md`, `.claude/rules/flutter/*.md` | Loaded lazily by `paths:` globs when a matching file is touched. Normative. `python/` and `flutter/` are synced from `somnio-ai-tools` and never hand-edited; `backend/` and `frontend/` are this project's. |
| Permissions | `.claude/settings.json` | `deny` for secrets/keys (deterministic), `allow` for the toolchain, `ask` for destructive git/infra. Deny always wins. |
| Hooks | `.claude/hooks/post-edit-check.py` and `post-edit-dart.py` (PostToolUse Edit\|Write), `.claude/hooks/inject-rules.py` (PreToolUse Write) | ruff + basedpyright + budget on every edited backend file; `dart format` + `dart analyze` + budget on every edited frontend file; rules injected when creating files. Exit 2 feeds findings back to the agent. |
| Commands | `.claude/commands/feature.md`, `.claude/commands/spec.md` | `/feature` = full lifecycle; `/spec` = draft a spec. |
| Agents | `.claude/agents/backend-reviewer.md`, `.claude/agents/frontend-reviewer.md` | Read-only reviewers, verdict APPROVED/FLAGGED. |
| Skills | `.claude/skills/*` | Somnio skills (audits, git formats, harness-audit rubric). |
| Ship gate | `.claude/ship-gate.json` ≡ `backend/Makefile gate` ≡ `.github/workflows/backend-ci.yaml`, and `frontend/Makefile gate` ≡ `frontend-ci.yaml` | Definition of Done. Per half: three sources, identical command strings. |
| Specs | `specs/` | Spec-driven development: one spec per feature. |
| Log | `.claude/harness-log.md` | One entry per iteration: code + harness changes. |

Hierarchy of enforcement: *suggestion* → CLAUDE.md/rules · *always* → hook or
gate · *never* → `deny`.

## Reproduce the gate

```bash
git clone https://github.com/somnio-projects/finance-google-a2ui.git && cd finance-google-a2ui/backend
uv sync --all-groups
make gate                       # ruff · format · basedpyright · budget · pytest (100 % branch)
make audit                      # pip-audit
```

Integration tests need Docker (testcontainers pulls `postgres:16-alpine`).
Alternative: `docker compose up -d db` at the repo root, then
`TEST_DATABASE_URL=postgresql+asyncpg://app:app@localhost:5432/finance make test`.

### The frontend half

```bash
cd frontend
flutter pub get --enforce-lockfile   # never plain `pub get` — it re-resolves silently
make gate                            # toolchain · format · analyze · budget · manifest · tests · coverage
```

Flutter **3.47.5** (Dart 3.13.4), pinned in `frontend/.fvmrc` — the one home,
read by `frontend/tool/check_toolchain.sh` and by `frontend-ci.yaml`, which no
longer carries a version of its own (GGU-94). `make gate` proves it first.
Needs no Docker and no database: the three pure-Dart packages run under `dart
test` in about a second, and the widget suite drives the transport with
`MockClient`.

What the frontend gate holds that a reviewer would otherwise have to remember:

| Check | Script | Holds |
|---|---|---|
| file budget | `tool/check_file_budget.dart` | 150 lines, sources and tests |
| layering | `app/test/architecture/layering_test.dart` | the import graph, the single composition root, and the no-formatting/no-arithmetic rule |
| component seam | `tool/generate_component_manifest.dart --check` | adding a component edits no hand-written file |
| coverage | `tool/check_coverage.dart` | 100 % **line** coverage per file (Dart's lcov has no branch data — see ADR-L D-11) |
| documentation | `public_member_api_docs` under `dart analyze --fatal-infos` | a doc comment on every public symbol |

## Lifecycle

```
/spec  →  human approves  →  /feature: plan → implement by layer → make gate → backend-reviewer → PR
                                                                        ↓
                                                          .claude/harness-log.md + memory
```

Humans sit at both ends (approve the spec, merge the PR). Everything in between
is the agent's job and is verified by deterministic tooling, not by trust.

## Scoring (harness-audit rubric)

| Piece | Points | Status |
|---|---|---|
| CLAUDE.md exists, <200 lines, real commands | 20 | ✅ |
| Rules with `paths:` | 10 | ✅ backend + frontend + python + flutter |
| Permissions with secret deny | 15 | ✅ |
| Commands/skills | 15 | ✅ `/feature`, `/spec`, Somnio skills |
| Hooks (PostToolUse) | 20 | ✅ ruff + basedpyright + budget (Python), dart format + analyze + budget (Dart) |
| Custom agent | 10 | ✅ `backend-reviewer`, `frontend-reviewer` |
| Autotest → PR lifecycle | 10 | ✅ `/feature` + CI gate |

Run `/harness-audit` to re-score after changes.

## Known traps

- The `deny` on `**/.env.*` also blocks creating `.env.example`; the template is `backend/env.example`.
- Inside the Claude sandbox, `uv` needs `UV_LINK_MODE=copy` (the Makefile sets it) and a writable `UV_CACHE_DIR`; `uv sync` and the integration tests need the sandbox off (certifi's `cacert.pem` matches the `*.pem` deny; the Docker socket and TCP to Postgres are filtered).
- Integration tests run before unit tests alphabetically — never let a fixture leak state into `os.environ` (migrations receive the URL through the Alembic `Config`, not the environment).
- basedpyright prints macOS "trust settings" noise on stderr; it is harmless.
- **`flutter pub get` silently re-resolves; `--enforce-lockfile` does not.** Use the strict flag everywhere, including CI. A build that resolved differently from the reviewed one is the failure this prevents.
- `dart fix --apply` on Dart 3.13 rewrites `const Foo(…)` into the new `const new(…)` shorthand and can inject a self-import into a barrel file to satisfy `comment_references`. Both are "valid"; both are worse. The two lints are switched off with reasons in `frontend/analysis_options.yaml` (ADR-L D-10) — read a `dart fix` diff before committing it.
- Dart's lcov carries **no branch data**, so "100 % branch coverage" is not expressible for Dart. `frontend/` holds 100 % **line** coverage per file instead, which is why the two halves of this repository state their coverage contracts differently.
