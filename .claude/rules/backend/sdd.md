---
description: Spec-Driven Development workflow — every backend feature starts as a spec under specs/, the spec is the contract for code, tests and the PR, and each iteration is recorded in the harness log. Loads when touching specs or the harness.
paths:
  - "specs/**/*.md"
  - ".claude/**"
  - "docs/DEV_HARNESS.md"
alwaysApply: false
---

# Spec-driven development rules

## Specs are the source of truth

- No backend feature starts without `specs/backend/NNNN-<feature>.md` created from `specs/TEMPLATE.md`. `NNNN` is the next free number; the filename never changes once the spec is merged.
- A spec has: Problem · Scope (in / out) · API contract (paths, DTOs, error codes) · Data model & migration · Security notes (auth, audit, data) · Acceptance criteria (numbered, testable) · Test plan (unit + integration, mapped to ACs) · Open decisions (owner + default).
- Code, tests and the PR cite acceptance criteria by number (`AC-3`). A PR that changes the contract updates the spec in the same PR and flags it under `Spec:` in the description.
- Specs are living documents: status `Draft → Approved → Implemented → Superseded`. Superseded specs stay in place with a pointer to the replacement.

## Iterations are recorded

- Every PR appends an entry to `.claude/harness-log.md`: date, spec, what changed in code **and** in the harness (rules, hooks, commands, docs), and what the next person should know.
- When a rule in `.claude/rules/**`, a hook or `CLAUDE.md` changes, say why in the log entry — the harness is versioned like code.
- Memory (the agent's persistent notes) mirrors decisions that are not derivable from the repo: who decided, when, and the alternatives rejected.

## Lifecycle (`/feature`)

spec → plan (files to touch, per layer) → implement in layer order (migration, model, schema, repository, service, controller, deps, router) → `make gate` → `backend-reviewer` → PR → harness log. Humans approve the spec at the start and the PR at the end; the agent owns everything in between.
