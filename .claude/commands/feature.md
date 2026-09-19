---
description: Deliver a backend feature with the team lifecycle — spec → plan → implement by layer → 100 % gate → reviewer → PR → harness log
argument-hint: "[GGU-n and/or short description]"
---

Work to deliver: $ARGUMENTS

Follow the Spec-Driven Development lifecycle end to end (repo
`somnio-projects/finance-google-a2ui`, base branch `develop`, Jira project `GGU`):

1. **Spec**: find or create `specs/backend/NNNN-<feature>.md` from
   `specs/TEMPLATE.md`. Fill Problem, Scope, API contract, Data model,
   Security notes, numbered Acceptance Criteria, Test plan, Open decisions.
   Stop and wait for my explicit ok on the spec before writing code.
2. **Plan**: list the files to touch per layer (migration → model → schema →
   repository → service → controller → `api/deps.py` → `api/router.py`) and
   the tests per AC. Flag anything that would break the 150-line budget or
   the layering table in `.claude/rules/backend/architecture.md`.
3. **Branch**: off `origin/develop`, `feat/GGU-n_short_desc` (or `fix/`,
   `chore/`), per the `git-branch-format` skill. Every PR targets `develop`;
   `main` only receives release PRs.
4. **Implement** in layer order, one test file alongside each source file.
   Use the fakes in `backend/tests/conftest.py`; anything touching PostgreSQL
   goes to `backend/tests/integration/`. Keep the security rules
   (`.claude/rules/backend/security.md`) — new routes are authenticated and
   audited unless the spec says otherwise.
5. **Gate**: `cd backend && make gate` — ruff, format, basedpyright, file
   budget, pytest at 100 % branch coverage. Then `make audit`. Fix until
   green; never lower a threshold.
6. **Mutation check** when auth, rate limiting or error masking changed:
   disable the guard, confirm the tests go red, restore.
7. **Review**: launch the `backend-reviewer` agent and resolve every blocker.
8. **Docs & log**: update `backend/docs/*.md` that describe changed behaviour,
   mark the spec `Implemented`, append the iteration to
   `.claude/harness-log.md` (code + harness changes + what the next dev must
   know). If a durable decision was made, save it to memory too.
9. **PR**: push and open it with `gh pr create` — base `develop`, title
   `type(scope): description`, body with `Spec: specs/backend/NNNN-...`,
   `Test decision: ...`, the gate output, and the GGU ticket link. English,
   no AI attribution.
10. **Wrap-up**: report the PR URL and the harness-log entry.
