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
- **The agent does not merge.** Opening the PR ends the agent's part of the lifecycle. The branch stays open and the ticket stays **In Review** until the **TL explicitly confirms the merge** — for `develop` and for `main`, and regardless of how clean the gate is. When several PRs are waiting, list them and carry on with other work; never merge one because it looks obviously fine. Only after the TL names a PR (or says to merge them all) does the agent merge it and move the ticket to **Done**.
- **PR title** carries the ticket: `type(scope): GGU-n — description`. **PR body** carries: a detailed description (spec, ACs, decisions), the **test evidence** (unit + integration output, coverage) **and a manual run** against the running stack with the real commands and their real responses pasted in, in the form below. No manual run, no merge.

## The manual run (GGU-93)

A manual run is the one piece of evidence this process treats as
unfalsifiable — *a human watched it work*. On 2026-09-21 one was performed,
pasted and **entirely false**: the container had been built from a working tree
six commits behind `develop`, and both "defects" it reported had been fixed in
#61 and #66. The commands were real, the HTTP responses were real, the JSON was
real. Nothing in the transcript, and nothing this rule used to require, said
**which build answered**.

### 1. The identity already exists — read it, do not invent one

`GET /health` returns `{"status":"ok","version":"<version>+<short sha>"}`.
`APP_RELEASE` → `Settings.app_release` → `core/release.py::resolve_release` →
`HealthService`, injected by `backend-cd` for a deployed revision (spec
`backend/0007` AC-5) and by you for a local stack. There is no second
mechanism and a PR must not add one.

### 2. The manual run OPENS with it, fetched live

The first pasted command is the one that prints the sha, and the body states
the branch it belongs to:

````markdown
### Manual run — branch `fix/GGU-93_verification_is_checkable`

```console
$ git rev-parse --short HEAD
c6dd5b2
$ APP_RELEASE="$(git rev-parse --short HEAD)" docker compose up --build -d
$ curl -s localhost:8000/health
{"status":"ok","version":"0.1.0+c6dd5b2"}
```
…then the commands the change is actually about.
````

Typed from memory does not count; the point is the value the **running
service** reports, not the one you believe it should.

### 3. It is checked, not trusted

```bash
gh pr view <n> --json body -q .body > /tmp/body.md
bash scripts/check_manual_run.sh /tmp/body.md
```

Three verdicts: the build **is** the head (pass); it is an **ancestor** of the
head (fail — it ran, and it did not exercise this branch); it is **anything
else** (fail — it is not in this branch at all).

> The middle verdict is why this is stricter than "an ancestor of the PR's
> head", which is what GGU-93 AC-3 asked for. Implemented literally, that test
> would have **passed the pull request that produced the ticket**: the branch
> was cut from the stale commit, so the stale commit was a perfectly good
> ancestor. Ancestry proves the build is from this line of history; only
> identity with the head proves it contains the change under review.

A run against a long-lived deployed environment is legitimately behind, and is
**context, not evidence**: paste it as well, never instead. Reading one is
worth the habit — the dev service was answering `0.1.0+9a94346`, twenty-six
commits behind `develop`, while the Flutter client was being built against it,
and the identity had been sitting on `/health` the whole time.

### 4. Say what was NOT run — the same template for both halves (GGU-93 AC-5, GGU-94 AC-5)

The defect underneath both tickets is that **the evidence format has no field
for what was not run**, so an incomplete verification and a complete one
produce identical-looking PR bodies. Every PR therefore carries a
`Verification` block that is explicit in both directions:

```markdown
### Verification
- `cd backend && make gate` — green, <sha>
- `cd frontend && make gate` — green, Flutter 3.47.5 / Dart 3.13.4 (`frontend/tool/check_toolchain.sh`)
- **Not run:** `docker compose up` — `backend/.env` is unreachable from an agent worktree.
  Consequence: no manual run against a live stack; the projection change is covered by the
  integration suite only.
```

A gate that was not run is named, with the **reason** and the **consequence**.
"Not run" is an acceptable line in a pull request; a missing line is not. An
agent that cannot reach a green gate writes this block rather than a sentence
that could be read either way.
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
| The **shape** of anything structural | a Mermaid diagram in `docs/diagrams/`, updated in the same PR (`.claude/rules/diagrams.md`) |
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

spec → plan (files to touch, per layer) → implement in layer order (migration, model, schema, repository, service, controller, deps, router) → `make gate` → `backend-reviewer` → PR → harness log. Humans approve the spec at the start and the merge at the end; the agent owns everything in between and stops at the open PR.
