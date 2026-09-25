# CI and pre-commit conventions

Applies to every workflow in `.github/workflows/` and to
`.pre-commit-config.yaml`. Two goals, in this order: **a reader understands the
run at a glance**, and **we do not pay CI minutes for what a laptop can prove**.

## 1. Where a check belongs

| Prove it… | …here | Why |
|---|---|---|
| Formatting, lint, types, file budget, freshness of a generated artefact, complexity, dead code, duplication, docstrings, typos, unit tests, secrets in the diff, `terraform fmt`, workflow syntax | **pre-commit** (`pre-commit install`) | instant feedback, zero CI cost |
| Full `make gate` including the DB-backed suite | **pre-push** hook | catches it before it ever reaches a runner |
| The same checks on a clean machine, integration tests against a real PostgreSQL, container build + CVE scan, secret scan over the **full history**, dependency CVEs | **CI** | a laptop cannot guarantee these |
| Anything slow, scheduled or org-wide (weekly scans, SBOM) | **scheduled workflow** | keeps the PR path fast |

A new check is added to pre-commit **first**. It goes to CI only if it needs
something the developer's machine cannot provide, or if it must be proven on a
clean checkout.

## 2. Naming contract

- **Workflow file**: `<area>-ci.yaml` (`backend-ci`, `infra-ci`), plus purpose-named ones (`scheduled-scan`).
- **Job name**: `"<Area> · <what it proves>"` — *what it proves*, never the tool list.
  `"Tests · pytest with 100% branch coverage on PostgreSQL 16"`, not `"pytest"`.
- **Step name**: `"<Verb> <object> (<tool>)"` — imperative verb, the object in plain words, the tool in parentheses.
  `"Audit the locked runtime dependencies for CVEs (pip-audit)"`, not `"py.audit"` or `"Run make audit"`.
- Every job ends in a `Report · …` job that writes a table to `$GITHUB_STEP_SUMMARY`, so the run is readable without opening a log.
- Never leave a bare `- uses:` without a `name:`.

## 3. Cost rules

- `concurrency: cancel-in-progress` on every workflow, keyed by ref — **and by
  `github.workflow` too on any workflow that declares `workflow_call:`**. A
  reusable workflow evaluates `concurrency` in the **caller's** context, so a
  key of `${{ github.ref }}` alone puts every caller on one branch into one
  group and `cancel-in-progress` makes the second caller cancel the first
  one's gate. This rule said "keyed by ref" until GGU-130, and following it
  literally is what broke a delivery: `repo-ci` is called by both `backend-cd`
  and `frontend-cd`, the two were dispatched 23 s apart on `develop`, and the
  frontend's call cancelled the backend's `repo` job — leaving `publish` and
  `deploy` skipped, the client shipped and the API not. `repo.gate-pairs`
  rule 4 now fails a callable workflow whose key is not per-caller.
- `paths:` filters so a docs-only change does not start a build.
- `timeout-minutes` on every job (no runaway runners).
- Expensive jobs (`image`, deploy) declare `needs:` on the cheap ones — a branch that fails lint never pays for a build.
- Cache the dependency install (`setup-uv` with `cache-dependency-glob`), use `cache-from/to: type=gha` for Docker layers.
- Prefer a **service container** over starting containers inside the job (testcontainers) when CI supports it.
- Artifacts get an explicit `retention-days` (14 for coverage, 90 for security evidence).
- Pin every action to a released tag and every tool image to a version — a floating tag is both a supply-chain risk and a cache miss.

## 4. Quality gates the project keeps

**Backend.** `make gate` == pre-push == CI, in this order: `lint` (ruff check +
format), `typecheck` (basedpyright strict), `budget` (150 lines),
`catalog-check`, `openapi-check`, `quality` (xenon complexity · vulture dead
code · interrogate 100 % docstrings · deptry dependency hygiene · pylint
duplication and design limits · codespell), `test` (pytest, 100 % branch
coverage), `audit` (pip-audit). Thresholds live in `backend/pyproject.toml`;
they go **up**, never down, and never in a feature PR.

**That list omitted `openapi-check` entirely until GGU-129**, which is worth
more than a correction, because of *where* it sat: this section also carries the
ruling that *"a new artefact is an entry in
`presentation/catalog_artifacts.ARTIFACTS`, **not a new gate step**"* — and
`openapi-check` is exactly a second regenerate-and-diff artefact check that
arrived as a new gate step, in the paragraph that says not to. Whether that was
the right call is a separate question; the section describing the gate must at
least name it. `repo.gate-pairs` cannot catch this: it compares command strings
against workflows, and an enumeration in prose is neither.

`catalog-check` sits between `budget` and `quality`: it re-renders **every**
generated catalog artefact — `docs/catalog/CONTRACT.md` (GGU-41, spec
`backend/0019`) and `docs/catalog/view-catalog.snapshot.json` (GGU-53, spec
`backend/0021`) — from the projection registry into a buffer and diffs each
against the checked-in file. One command, one render pass: a new artefact is an
entry in `presentation/catalog_artifacts.ARTIFACTS`, not a new gate step, so
`ship-gate.json` and the workflows keep matching verbatim.

**A generated artefact is gated by regeneration, never by trust.** Anything the
build produces is checked in *and* re-rendered by the gate and diffed, and the
check fails with the exact command that fixes it. A second such artefact copies
that shape rather than relying on a reviewer remembering to look.

**Client — retired 2026-09-22, and one ruling outlived it.** `client_flutter/`
was the older of two Flutter apps. It had its own gate here (`dart.*`,
`client.*`, `flutter.*`), its own two grep gates and its own workflow
(`client-ci.yaml`). All of it was removed with the directory (spec
`repo/0002`); `frontend/` is the only Flutter app this repository ships.

What survives that deletion is §5's third question, because it was found in
that app: `client_flutter/Dockerfile` carried `ARG FLUTTER_VERSION=3.47.5`
beside a `.fvmrc` pinning **3.47.3**, so the image shipped a bundle compiled by
an SDK the gate never proved the app against — *under what does the command
run?* failing in a file the check was not reading. `repo.gate-pairs` therefore
reads Dockerfiles: an app's Dockerfile may not name a Flutter version, and must
be shown to `COPY` the pin in. Both halves are mutation-tested, `frontend/` is
held to them today, and `pin_apps` in `scripts/check_gate_pairs.sh` stays a
**list** of apps rather than the word `frontend`, so a second app arriving is
one word rather than a rewrite of the rule.

**Frontend.** `cd frontend && make gate`, opening with `toolchain` for the
reason §5 records, and carrying two suites a runner cannot exercise any other
way: `toolchain-test` (a stubbed SDK) and `verify-release-test` (a stubbed
curl). The second is the delivery check — `frontend/tool/verify_release.sh`
asks a deployed origin for `/release.json` and fails if it is not the commit
that was built — and on a runner it can only ever be seen *accepting*, because
the deploy it follows has just succeeded. Same shape as `repo.manual-run`: the
gate runs the proof that the check rejects.

**One build script, two consumers.** `frontend/tool/build_web.sh` owns the
`flutter build web` flags, and both `frontend/Dockerfile` and `frontend-cd`
call it. Neither is a ship-gate command, so `repo.gate-pairs` cannot compare
them — which is exactly why the flags must not be written twice. A container
compiled with different flags than the bundle that ships is a rehearsal of
something else.

## 4b. One pipeline per stack, and delivery is a button

**Nothing runs on a merge.** `backend-ci` has no `push:` trigger (it would run
the same gate twice on the same commit) and `backend-cd` has none either —
delivery is `workflow_dispatch` only. The cost model for this project is: pay
on pull requests, where a regression is actually caught, and pay for a deploy
when somebody asks for one.

That is safe only because `develop` is branch protected, so every change
arrives through a pull request and is gated there. If protection is ever
removed, the push triggers have to come back with it.

**A change to one stack must not start the other stack's pipeline.** Every
*stack* workflow is scoped by `paths:` to the directory it proves. The
repository-wide one is not, on purpose:

| workflow | runs on | scope | exists? |
|---|---|---|---|
| `repo-ci` | pull requests | **no `paths:` filter** — spelling, secrets, shell lint, gate pairs, spec numbering, manual-run check | yes |
| `backend-ci` | pull requests | `backend/**`, `docs/catalog/**`, `docker-compose.yml`, its own file | yes |
| `frontend-ci` | pull requests | `frontend/**`, its own file | yes |
| `infra-ci` | pull requests | `infra/**`, the delivery workflows | yes |
| ~~`client-ci`~~ | — | `client_flutter/**` | **gone** — the app it gated was retired 2026-09-22 (spec `repo/0002`) |
| `backend-cd` | **the button only** | — | yes |
| `frontend-cd` | **the button only** | — | yes |

**`client-ci`'s row went yes → no → yes → gone, and the history is the
lesson.** The table once listed it as though it were one of the scoped
workflows, with no marker, from before `frontend-ci` was written — while
nothing covered `client_flutter/**`. Its container, its nginx CSP template and
`docker/entrypoint.sh` — which validates an origin and substitutes it into
`connect-src` — were built, linted and scanned by nothing, while this file
asserted a pipeline. That was corrected to say **no**; GGU-1 (PR #26/#30) then
wrote the workflow, so the row said **yes** again, this time because the file
was there. On 2026-09-22 the app itself was retired and the workflow deleted
with it, so the row is struck through rather than removed.

**A row in this table is a claim about the repository, and a claim gets a truth
value.** The rule that survives is not "client-ci exists" and not "client-ci is
gone"; it is that the row has to be walked to whatever is true **in the same
pull request that changes the workflow directory**. It has been walked three
times now, in both directions, and every one of those changes was a file being
added or deleted one directory away from this sentence.

The struck-through row is kept for one more reason: it is the only place that
records that this repository once ran **two** pipelines over **two** Flutter
apps, which was the table working rather than a duplication. Two separate
deployables get two gates, and a change to one must never pay for the other's
build. If a second Flutter app ever returns, it gets its own row, not a job
bolted onto `frontend-ci`.

A new stack gets its own `<area>-ci.yaml` with its own `paths:`. Adding jobs to
an existing workflow so that "everything runs together" is the thing this table
exists to prevent: a Dart formatting fix must never pay for a PostgreSQL
container, and a Python change must never wait on a Flutter build.

**But a check whose subject is "any file in this repository" is not a stack
check and must not be scoped.** Secret scanning and shell linting were both
per-stack and both were therefore false: gitleaks sat in `backend-ci` while
the security policy claimed it ran on every pull request, and shellcheck sat in
`infra-ci` over two globs while both container entry points went unlinted. The
test is the check's subject, not its current location — if you cannot name a
directory it does *not* apply to, it belongs in `repo-ci`.

**The button lives on the default branch.** GitHub reads `workflow_dispatch`
from the default branch only, so a delivery workflow that exists only on
`develop` is invisible in the Actions tab and `gh workflow run` answers *"not
found on the default branch"*. Releasing `develop` into `main` is what makes
the button appear.

## 5. When you change one, change its pair

`.claude/ship-gate.json` is the Definition of Done. It has **four** parts,
each with a runner and a workflow that must stay identical to it.

**The count in that sentence has been wrong twice, in both directions, which
is this rule's own failure mode in miniature.** It said three until `repo.*`
and `frontend.*` arrived and nobody updated it; it then said five after the
`dart.*` / `client.*` / `flutter.*` part left with `client_flutter/`
(2026-09-22, spec `repo/0002`). `ship-gate.json`'s own `_note` was the other
half of the same defect — it still opened with "in three parts" while this
sentence said five. **Adding or removing a part means editing the number here,
the row below, and that `_note`, in the same commit.**

| Part | Runner | Workflow | Also in |
|---|---|---|---|
| `py.*` | `cd backend && make gate` | `backend-ci.yaml` | pre-commit (the cheap steps) + pre-push (the whole gate) |
| `infra.*` | the `infra.*` commands from the repository root — there is no root Makefile | `infra-ci.yaml` (`delivery-scripts`) | pre-commit |
| `repo.*` | the `repo.*` commands from the repository root | `repo-ci.yaml` | pre-commit |
| `frontend.*` | `cd frontend && make gate` | `frontend-ci.yaml` | pre-commit (the cheap steps) |

**This table is now checked by a machine.** `repo.gate-pairs`
(`scripts/check_gate_pairs.sh`) parses `ship-gate.json` and greps each `cmd`,
as a fixed string, against every file in `.github/workflows/`. A gate entry
with no verbatim workflow step fails the build and prints both strings. It
runs in `repo-ci` and in pre-commit whenever `ship-gate.json` or any workflow
moves.

It exists because this rule is the one that keeps breaking. Every instance
below was caught by a person comparing two files by eye, and the third was
caught *after* the author believed they had mutation-checked it. Three
instances of one defect class is where you stop asking reviewers to be careful
and write the check. What it deliberately does **not** assert is the reverse
direction — a workflow may legitimately run steps that are not gate checks
(checkout, SDK setup, artifact upload) and whole jobs that are deliberately
outside the gate (`backend-ci`'s `image`, `frontend-ci`'s `build`). It also
cannot check the "Also in" column, because some gate checks are upstream
pre-commit hooks (`gitleaks`, `codespell`) with no command string to compare.

**`repo-ci.yaml` deliberately has no `paths:` filter**, which every other
workflow here does have. A repository-wide check placed in a scoped workflow
runs only when that scope changes — exactly when it is least needed. It is
seconds long, so running it on every pull request costs nothing worth saving.
A new `repo.*` check belongs here only if it genuinely spans the repository;
anything that proves one stack goes in that stack's workflow.

**"Identical" means the command, not the intent.** `infra.shell-lint` was
missing from `ship-gate.json` while `infra-ci` had been running
`shellcheck infra/scripts/deploy_cloud_run.sh infra/scripts/tests/*.sh` all
along. Both halves were individually sensible and nobody compared them, so a
shellcheck finding **in a test script** passed every local check and failed on
a runner — after the branch had already merged.

The lesson is narrow and worth keeping: when you add a check to a workflow,
copy its command string into `ship-gate.json` rather than describing what it
does. A paraphrase is where the two drift.

**`repo.spelling` is the second instance of the same defect**, found while
renumbering a spec. `make gate` ran `codespell src tests docs scripts` from
inside `backend/`; the pre-commit hook ran codespell over the whole
repository. Both were individually sensible and nobody compared them, so a
typo in `specs/`, root `docs/` or `.claude/` **passed a green gate** and was
caught only at commit time — and only if the author had not bypassed the hook.
Proven both ways: a typo added to `specs/README.md` exits 65 under the new
check and exits 0 under the old scope.

The two halves also disagreed on *configuration*, not just scope: the hook
read `backend/pyproject.toml`, whose word list knows nothing about the Flutter
or documentation vocabulary, so it flagged `bloc` on every Flutter file it
touched. Both now read `.codespellrc`. **Two configurations for one check is
the same drift as two command strings.**

**And then `repo.spelling` itself over-claimed, which is the sharpest version
of this rule so far.** The check shipped as a bare `codespell` run, and
codespell's directory walk skips entries whose name begins with a dot — so
`.claude/` and `.github/` were never opened. Naming them on the command line
does not help; the same walk applies once it descends. Meanwhile the check's
own configuration comment and this file both said the gap it closed included
`.claude/`. The proof was sitting in the repository: a misspelling of `unparsable`
in `.claude/harness-log.md`, and the gate green.

Measured, with a typo planted in `.claude/rules/ci-conventions.md`:

| Gate | exit | hits on the planted file |
|---|---|---|
| `bash scripts/check_spelling.sh` | 1 | **1** |
| bare `codespell` | 65 | **0** |

The old form was red — for unrelated findings in `uv.lock` and
`backend/reports/` — while blind to the file the mutation targeted. **A red
gate is not evidence that it is red for your reason.**

The fix removes the walk from the question: `git ls-files` hands codespell an
explicit list. The script also refuses to report success on an implausibly
small file list, or on a list containing nothing under `.claude/` or
`.github/` — the anti-vacuity idiom `infra/scripts/tests/` already uses,
applied to the check that most needed it.

**And the fourth instance is the one that reframes the rule: both halves can
be internally consistent and still prove the wrong thing.** `infra.shell-lint`
and its workflow step matched byte for byte — §5 was satisfied — and the check
was still wrong, because its *subject* was wrong. It named
`infra/scripts/deploy_cloud_run.sh infra/scripts/tests/*.sh`, and the two
scripts this repository ships in containers were outside it. Pointing
shellcheck at them for the first time, on 2026-09-20, found a finding in each
(SC2086 in `backend/docker/entrypoint.sh`, SC2016 in
`client_flutter/docker/entrypoint.sh` — both deliberate constructs that now
carry justified `disable` directives). That second file went with its app on
2026-09-22; `scripts/check_shell.sh` asserts `frontend/docker/entrypoint.sh`
by name in its place, because an assertion over a file that no longer exists
passes for the wrong reason. The same was true of gitleaks in the
other direction: it sat in `backend-ci`, matched its documentation, and could
not see a client-only pull request.

So §5 has two questions, not one:

1. **Do the two halves run the same command?** — now machine-checked by
   `repo.gate-pairs`.
2. **Does that command cover what its name claims?** — not machine-checkable,
   and the one that has cost the most. Ask it of the *subject*: if you cannot
   name a directory the check does not apply to, it does not belong in a
   `paths:`-scoped workflow. Both of these moved to `repo.*` for that reason.

**The fifth instance is not a command at all — it is the toolchain the command
runs under (GGU-94).** Both halves of `frontend.format` matched byte for byte,
`repo.gate-pairs` was green, and the check still could not be trusted, because
the *interpreter* was unstated. `frontend-ci.yaml` pinned `FLUTTER_VERSION:
"3.47.5"` in an env var no local command could read, and `frontend/pubspec.yaml`
declared `sdk: ^3.13.0` which `dart format` does not consult. A laptop carrying
Homebrew's `dart-sdk 3.12.1` — *below* the declared floor — therefore ran the
gate happily and reported three tracked files as unformatted:

| toolchain | `dart format --output=none --set-exit-if-changed .` |
|---|---|
| `dart-sdk 3.12.1` | 3 changed, **exit 65** |
| the pinned 3.47.5 / 3.13.4 | 0 changed, **exit 0** |

`develop` was correctly formatted the whole time. Again: **a red gate is not
evidence that it is red for your reason.** The pin now lives in one file,
`frontend/.fvmrc`, read by `frontend/tool/check_toolchain.sh` and by
every SDK-setup step in the workflow, and `frontend.toolchain` is the first
entry of the frontend gate so the failure names the toolchain instead of
impersonating a branch problem.

So §5 has a third question:

3. **Under what does that command run?** A version pinned where only CI can
   read it is not a pin; it is a claim CI happens to satisfy. If a check
   depends on a tool version, the version is a file in the repository and both
   halves read it.

**And `repo.manual-run` is the same rule applied to evidence rather than to
code (GGU-93).** `sdd.md` required "a manual run with the real commands and
their real responses pasted in", and a transcript satisfying it word for word
was produced from a container built six commits behind `develop`. The rule had
no field for *which build answered*. `scripts/check_manual_run.sh` now reads a
PR body and compares the `<version>+<sha>` on `/health` with the branch head;
what the gate runs is its **suite**, because the check needs a PR body and the
gate has none. A check that has never been shown to reject is the same defect
one level up, so the suite asserts the four rejections and only one pass.

**The sixth instance is the one §5 was always going to reach: a property with
no command at all (GGU-105).** `specs/README.md` says *"Numbers are per area,
zero-padded, never reused"* and *"One row per file … so a missing spec and a
duplicated one are both visible at a glance."* Both halves were false on
`develop`: two files were numbered `frontend/0002` and **nine** spec files had
no index row, including both halves of that collision. There was nothing to
compare, because only one half existed — the sentence was doing a check's job.

`repo.spec-numbers` (`scripts/check_spec_numbers.sh`) is the other half:
filename shape, uniqueness per area (naming **both** files), and one index row
per spec in both directions. `repo.spec-numbers-test` is its suite, the
`frontend.toolchain` / `frontend.toolchain-test` pair applied here, and it
plants a collision, an unpadded number, an unindexed spec, an orphan row, a
duplicated row, an emptied area and a corpus too small to believe.

Two things it deliberately does **not** claim, because §5's second question
has to be answered *before* the name is chosen rather than after:

- **"Never reused" is not machine-checkable here.** In git history a
  renumbering is a delete plus an add, indistinguishable from a reuse, and the
  check would have failed on GGU-59's own legitimate rename. It is protected by
  the index rule instead — a superseded spec keeps its file and its row.
- **Ordering is not asserted, and the claim was removed rather than enforced.**
  The index said it was "ordered by area then number" and was not. A claim this
  repository cannot keep is the whole subject of the ticket, so the sentence
  went; reordering seventy rows is not what makes a collision fail.

The frontend half of GGU-105 needed no gate entry at all, which is also §5
working: *"the Color-in-lib rule"* proves one stack, so it is a test
(`app/test/architecture/color_rules_test.dart`) inside `frontend.test`, beside
the four architecture tests that already fail on a mechanism. A check whose
subject is one directory does not belong in `repo-ci`, in either direction.

**The seventh instance is the third question in a second language, and the
lesson is that a rule written from one stack quietly exempts the others
(GGU-125).** Question 3 above was answered for Flutter and the answer was made
machine-checkable — `repo.gate-pairs` ends by printing that `frontend/.fvmrc` is
the only home of the Flutter pin. Nothing was watching Python, and it carried
the same defect from the day the backend was written: `backend-ci.yaml` and
`repo-ci.yaml` each set `PYTHON_VERSION` in an `env:` block, handed to
`astral-sh/setup-uv`, while `backend/.python-version`, `backend/pyproject.toml`
(`requires-python` **and** `pythonVersion`) and `backend/Dockerfile` (two `FROM`
lines) declared the same fact. **Six declarations, one of them readable only by
GitHub Actions.** It was found by hand during the 3.14 upgrade (#130): five were
bumped, the sixth still said `3.12`, and CI failed pointing somewhere else.

Two things make this instance worth more than "do it for Python too":

- **The CI-only pin was not even winning.** Measured on uv 0.11.19, a
  `.python-version` of 3.14 beats `UV_PYTHON=3.12`, so the workflow pin sat
  there for months being *inert while reading as authoritative* — and a uv bump
  or a stray `--python` flag turns it back on. A pin whose effect depends on the
  tool's version is a claim, not a pin. The check therefore fails on the
  **line**, not on the value: `PYTHON_VERSION: "3.14"`, the correct value, is
  red, because the defect is the second home.
- **The drift is removed, not policed.** `uv` reads `backend/.python-version`
  from the project directory and installs what it names, so no workflow needs to
  say anything; `python-version-file:` stays allowed, because a step that
  *reads* the pin is the fix. Where a declaration cannot be deleted —
  `requires-python`, `pythonVersion`, `FROM python:X.Y` — it is **compared**,
  and the failure prints every offending file with both values.

`py_pin_dirs` is a list, exactly as `pin_apps` is, for the same reason: one pin
per *solution*. Spec [`repo/0003`](../../specs/repo/0003-the-interpreter-pin-has-one-home.md)
records the nine mutations that show each rule rejecting, including the
anti-vacuity ones — a Dockerfile that stops naming an interpreter fails rather
than passing by finding nothing.

So question 3 gets a clause it did not have: **ask it of every toolchain the
repository runs, not only the one that last cost a day.** `infra/` is the open
case at the time of writing — `infra-ci.yaml` pins `terraform_version: "1.9.8"`
in a workflow input, `infra/versions.tf` declares `required_version = ">= 1.9"`,
and no tracked file pins it for a laptop at all. It is recorded in
`repo/0003` §6 rather than fixed there, because a rule that lists its own
unfinished cases is what this section is for.

A PR that changes one without its pair is incomplete. A new runner goes in
this table rather than in a comment — and the count in the sentence above it
goes up in the same edit.
