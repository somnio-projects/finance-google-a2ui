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
- **Ticket status follows the work, and `Done` means merged.** Assign the ticket to the TL's account and move it to **In Progress** before writing anything; move it to **In Review** when the **PR is opened**; move it to **Done** only once that PR is **merged**; use **Blocked** (with a comment naming the blocker) if it stalls. Never mark a ticket Done because the work "is finished" — an open PR is In Review.
- **PR title** carries the ticket: `type(scope): GGU-n — description`. **PR body** carries: a detailed description (spec, ACs, decisions), the **test evidence** (unit + integration output, coverage) **and a manual run** against the running stack with the real commands and their real responses pasted in. No manual run, no merge.
- Code, tests and the PR cite acceptance criteria by number (`AC-3`). A PR that changes the contract updates the spec in the same PR and flags it under `Spec:` in the description.
- Specs are living documents: status `Draft → Approved → Implemented → Superseded`. Superseded specs stay in place with a pointer to the replacement.

## Every decision is written down where the next person's Claude will find it

A decision that lives only in a chat, a PR comment or someone's head does not
exist. Record it, in this order of preference:

| Decision | Goes to |
|---|---|
| Architectural, cross-cutting, hard to reverse | an **ADR** in `docs/adr/` (WH(Y) statement + numbered `D-n` rulings), registered in `docs/adr/README.md` |
| Feature-level (contract, data model, trade-off, rejected option) | the feature **spec** under `specs/`, in *Open decisions* (owner + default) and in the section it constrains |
| A rule the agent must follow every time | a **harness rule** in `.claude/rules/**`, indexed in the root `CLAUDE.md` |
| What changed in an iteration and why | `.claude/harness-log.md` |
| Who decided, when, and what was rejected | the agent's memory, mirroring the record above |

The test: **a new developer opening this repo with Claude must reach the same
decisions without asking anyone.** If they would have to ask, the decision is
not recorded yet.

## Iterations are recorded

- Branches are cut from `develop` and every PR targets `develop` (`main` only via release PR).
- Every PR appends an entry to `.claude/harness-log.md`: date, spec, what changed in code **and** in the harness (rules, hooks, commands, docs), and what the next person should know.
- When a rule in `.claude/rules/**`, a hook or `CLAUDE.md` changes, say why in the log entry — the harness is versioned like code.
- Memory (the agent's persistent notes) mirrors decisions that are not derivable from the repo: who decided, when, and the alternatives rejected.

## Lifecycle (`/feature`)

spec → plan (files to touch, per layer) → implement in layer order (migration, model, schema, repository, service, controller, deps, router) → `make gate` → `backend-reviewer` → PR → harness log. Humans approve the spec at the start and the PR at the end; the agent owns everything in between.
