# DEV_HARNESS — how this repo is developed with Claude Code

This document describes the AI harness (Somnio codelab 2, "Del prompt al
harness") as applied to `finance-google-a2ui`, and how to reproduce the ship
gate by hand. It is the human-readable counterpart of `.claude/`.

## The pieces

| Piece | Where | Role |
|---|---|---|
| Operating manual | `CLAUDE.md` (root index), `backend/CLAUDE.md` | Always loaded. Run/verify commands, conventions the code does not show, do-not-touch. Kept under 200 lines. |
| Rules | `.claude/rules/backend/*.md`, `.claude/rules/python/*.md`, `.claude/rules/flutter/*.md` | Loaded lazily by `paths:` globs when a matching file is touched. Normative. |
| Permissions | `.claude/settings.json` | `deny` for secrets/keys (deterministic), `allow` for the toolchain, `ask` for destructive git/infra. Deny always wins. |
| Hooks | `.claude/hooks/post-edit-check.py` (PostToolUse Edit\|Write), `.claude/hooks/inject-rules.py` (PreToolUse Write) | ruff + basedpyright + 150-line budget on every edited backend file; rules injected when creating files. Exit 2 feeds findings back to the agent. |
| Commands | `.claude/commands/feature.md`, `.claude/commands/spec.md` | `/feature` = full lifecycle; `/spec` = draft a spec. |
| Agents | `.claude/agents/backend-reviewer.md` | Read-only reviewer, verdict APPROVED/FLAGGED. |
| Skills | `.claude/skills/*` | Somnio skills (audits, git formats, harness-audit rubric). |
| Ship gate | `.claude/ship-gate.json` ≡ `backend/Makefile gate` ≡ `.github/workflows/backend-ci.yaml` | Definition of Done. Three sources, identical commands. |
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
| Rules with `paths:` | 10 | ✅ backend + python + flutter |
| Permissions with secret deny | 15 | ✅ |
| Commands/skills | 15 | ✅ `/feature`, `/spec`, Somnio skills |
| Hooks (PostToolUse) | 20 | ✅ ruff + basedpyright + budget |
| Custom agent | 10 | ✅ `backend-reviewer` |
| Autotest → PR lifecycle | 10 | ✅ `/feature` + CI gate |

Run `/harness-audit` to re-score after changes.

## Known traps

- The `deny` on `**/.env.*` also blocks creating `.env.example`; the template is `backend/env.example`.
- Inside the Claude sandbox, `uv` needs `UV_LINK_MODE=copy` (the Makefile sets it) and a writable `UV_CACHE_DIR`; `uv sync` and the integration tests need the sandbox off (certifi's `cacert.pem` matches the `*.pem` deny; the Docker socket and TCP to Postgres are filtered).
- Integration tests run before unit tests alphabetically — never let a fixture leak state into `os.environ` (migrations receive the URL through the Alembic `Config`, not the environment).
- basedpyright prints macOS "trust settings" noise on stderr; it is harmless.
