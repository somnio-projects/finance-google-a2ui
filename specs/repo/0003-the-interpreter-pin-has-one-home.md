# 0003 — The Python interpreter pin has one home

- **Area:** repo
- **Status:** Implemented
- **Ticket:** [GGU-125](https://somniosoftware.atlassian.net/browse/GGU-125) · **Related specs / ADRs:** [frontend/0017](../frontend/0017-the-client-runs-in-the-stack-and-ships-itself.md) (the Flutter half, GGU-94), [frontend/0029](../frontend/0029-the-conventions-are-checked.md), [repo/0002](0002-retire-the-client-flutter-app.md), [ADR-H](../../docs/adr/ADR-H-ci-ship-gate.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-25

## 1. Problem

`.claude/rules/ci-conventions.md` §5 asks three questions of every gate check.
The third one — **under what does that command run?** — was written from GGU-94,
where `frontend-ci.yaml` pinned `FLUTTER_VERSION` in an `env:` block no local
command could read, a laptop's older Dart called three correctly-formatted files
unformatted, and a day went into a branch that was never broken. The answer
became a file (`frontend/.fvmrc`) plus an assertion in
`scripts/check_gate_pairs.sh`, which now ends with:

```
repo.gate-pairs: frontend pins Flutter 3.47.5 in frontend/.fvmrc, and nowhere else
```

**The identical defect existed in the Python half of this repository for its
entire life, and nothing was watching.** Until 2026-09-25 the same fact was
declared **six** times:

| Declaration | Read by |
|---|---|
| `backend/.python-version` | `uv sync`, `uv run`, every local command |
| `backend/pyproject.toml` `requires-python` | every resolver |
| `backend/pyproject.toml` `[tool.basedpyright] pythonVersion` | `py.typecheck` |
| `backend/Dockerfile` `FROM python:X.Y` (builder) | the image build |
| `backend/Dockerfile` `FROM python:X.Y` (runtime) | the image that ships |
| `PYTHON_VERSION` in `backend-ci.yaml` **and** `repo-ci.yaml` `env:` | **only GitHub Actions** |

The last row is the defect: a pin in the one place a developer's machine cannot
read, handed to `astral-sh/setup-uv`. It was found **by hand** while upgrading
to 3.14 (#130) — five declarations were bumped, the invisible sixth said `3.12`,
and CI failed pointing sideways. Dependabot's #122 would have reached the same
wall from the other direction. That is exactly the situation the Flutter
assertion was written to end, for one language.

**The sharpest part is that the CI-only pin was not even winning.** Measured on
uv 0.11.19, from this repository:

| request | `uv python find` resolves |
|---|---|
| `backend/.python-version` = 3.14, no env var (`--project backend`, from the repo root) | **3.14** |
| the same, plus `UV_PYTHON=3.12` (what `setup-uv`'s `python-version` input sets) | **3.14** — the env var is inert |
| a project with no pin file, `UV_PYTHON=3.12` | 3.12 |

So the second home was a declaration that *looked* authoritative, was invisible
locally, and did nothing — until a uv bump or a stray `--python` flag turns it
back on. **A pin whose effect depends on the tool's version is a claim, not a
pin**, and a value that agrees today is still a second home.

## 2. Scope

**In:**

- Delete `PYTHON_VERSION` from `backend-ci.yaml` and `repo-ci.yaml`, and the
  `python-version:` input from all four `astral-sh/setup-uv` steps. The drift is
  **removed**, not policed (AC-2 before AC-1).
- Extend `scripts/check_gate_pairs.sh` with a Python half mirroring the Flutter
  half: one pin file per solution, no workflow restating it, no second pin file,
  and the declarations that *cannot* be deleted compared against it.
- Widen the `repo-gate-pairs` pre-commit hook's `files:` so a bump to
  `backend/.python-version`, `backend/pyproject.toml` or `backend/Dockerfile`
  runs the check on the laptop that made it.
- Record the seventh instance in `.claude/rules/ci-conventions.md` §5.

**Out:**

- Changing the Python version. This branch keeps 3.14 everywhere; #130 did the
  upgrade and this spec makes it a property.
- A `scripts/tests/` suite for `check_gate_pairs.sh`. It has none today, and the
  Flutter half is held by mutation runs recorded in review (§5 here does the
  same). Writing one is worth doing for *both* halves at once, as a separate
  ticket — see §6.
- `docker-compose.yml`, which names no interpreter: it builds `backend/`.

## 3. Decisions

- **D-1 — Removing the drift beats policing it.** The workflows now name no
  interpreter at all. `uv` reads `backend/.python-version` from the project
  directory and installs what it names, so `setup-uv` needs only its own
  version. Rule 1 of the new half therefore fails on the **line**, not on the
  value: `PYTHON_VERSION: "3.14"` — the correct value — is red, because the
  defect is the second home.
- **D-2 — `python-version-file:` is the allowed form, and is deliberately not
  matched.** A step that *reads* the pin is the fix; the regex stops at
  `python-version:` and lets `python-version-file: backend/.python-version`
  through. A future step that genuinely needs the string has a way to ask.
- **D-3 — `requires-python`, `pythonVersion` and the two `FROM` lines are
  compared, not forbidden.** They cannot be deleted: package metadata, the
  type-checker's target and the base image are each read by a different tool,
  and `FROM` cannot read a file (an `ARG` would just be the CI-only pin again,
  one file over). Where a declaration must exist, the check compares it and
  prints **both** values.
- **D-4 — `py_pin_dirs` is a list, like `pin_apps`.** One pin per *solution*,
  not per repository. A second Python service is one word in that string.
- **D-5 — Anti-vacuity, twice.** A Dockerfile with no `FROM python:X.Y` line
  fails rather than passing by finding nothing, and the whole Python half
  refuses to report success on fewer than three compared declarations. Every
  defect §5 records looked like a green check that had stopped looking.
- **D-6 — Python needs no `py.toolchain` gate step, and that is a difference in
  the tools rather than in the standard.** `frontend.toolchain` exists because
  `dart format` does not consult the SDK constraint in `pubspec.yaml`, so a
  wrong SDK runs the gate happily. `uv` does the opposite: it narrows every
  interpreter request by `requires-python` and installs a compatible one, so
  `UV_PYTHON=3.12` against `requires-python = ">=3.14"` still resolves 3.14
  (measured). The interpreter the backend gate runs under is therefore decided
  by tracked files already — what was missing was an assertion that those files
  **agree**, which is what this change adds. If a future tool reads one of them
  and not the others, the first entry of the backend gate is where it goes.
- **D-7 — The claim in the comments is the measured one.** An earlier draft of
  this change asserted that `UV_PYTHON` *overrides* `.python-version`. It does
  not, on uv 0.11.19 (§1). The comments now say what was measured, because a
  rule file that over-claims is the third instance in §5's own list.

## 4. Acceptance criteria

- **AC-1** — `scripts/check_gate_pairs.sh` fails when any tracked declaration of
  the interpreter version disagrees with `backend/.python-version`, printing
  every offending file and the value it names.
- **AC-2** — No workflow names an interpreter version. The check fails if one
  does, whatever value it names, and names the file and the line.
- **AC-3** — `pyproject.toml`'s `requires-python` and `pythonVersion`, and both
  `FROM python:` lines in `backend/Dockerfile`, are compared against the pin.
- **AC-4** — The check has been shown to **reject**: one mutation per rule, with
  the output pasted in the pull request (§5).
- **AC-5** — The list shape survives: a second Python solution is one word in
  `py_pin_dirs`, exactly as `pin_apps` promises for a second app.
- **AC-6** — §5 of `.claude/rules/ci-conventions.md` records this as its seventh
  instance, and says that the pattern now has two languages.

## 5. Test plan — the mutations, and what each proves

`repo.gate-pairs` is a shell check with no unit suite, so its evidence is a
mutation per rule. Each was applied to a clean tree, the check run, and the tree
restored. The PR body carries the verbatim output.

| # | Mutation | Proves | Expected |
|---|---|---|---|
| M1 | `PYTHON_VERSION: "3.14"` back in `backend-ci.yaml` — the **correct** value | AC-2: the line is the defect, not the value | red, names the file and the line |
| M2 | `python-version: "3.14"` on `setup-uv` in `repo-ci.yaml` | AC-2 covers the input, not just the env var | red |
| M2b | `python-version-file: backend/.python-version` instead | D-2: reading the pin is allowed | **green** |
| M3 | `requires-python = ">=3.13,<3.14"` | AC-3 | red, prints both values and the string it must read |
| M4 | `pythonVersion = "3.13"` | AC-3 | red, prints both values |
| M5 | one `FROM python:3.13-slim` | AC-3 | red, prints the line and both values |
| M6 | `.python-version` bumped to 3.15 alone — the #130 mistake | AC-1 end to end | red, **all four** derived declarations named |
| M7 | both `FROM python:` lines replaced with `debian:trixie-slim` | D-5 anti-vacuity | red on the missing base *and* on the declaration count |
| M8 | a tracked `backend/.tool-versions` | the second-pin-file rule | red |

`bash scripts/check_shell.sh` and `bash scripts/check_spelling.sh` cover the
script itself as a shell file and as prose.

## 6. Open decisions

| Decision | Owner | Default if nobody objects |
|---|---|---|
| A `scripts/tests/test_check_gate_pairs.sh` covering **both** halves, the shape `frontend.toolchain` / `toolchain-test` and `repo.spec-numbers` / `spec-numbers-test` already use | TL | Filed as a follow-up ticket rather than done here: the Flutter half predates this branch and a suite that covers only the new half would assert the newer rule is the trustworthy one |
| **`infra/` has the same defect and it is out of scope here.** `infra-ci.yaml` pins `terraform_version: "1.9.8"` in a workflow input, `infra/versions.tf` declares `required_version = ">= 1.9"`, and there is **no** tracked pin file for a local `terraform` to read — so `infra.fmt` and `infra.validate` run under an unstated Terraform exactly as `frontend.format` once did. Found while writing this spec, deliberately not fixed in it: the fix is a new tracked file plus a rule, which is a ticket, not a line | TL | Filed as a follow-up; this spec's shape (one file, compared declarations, an anti-vacuity floor) is the answer when it is picked up |
