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

- `concurrency: cancel-in-progress` on every workflow, keyed by ref.
- `paths:` filters so a docs-only change does not start a build.
- `timeout-minutes` on every job (no runaway runners).
- Expensive jobs (`image`, deploy) declare `needs:` on the cheap ones — a branch that fails lint never pays for a build.
- Cache the dependency install (`setup-uv` with `cache-dependency-glob`), use `cache-from/to: type=gha` for Docker layers.
- Prefer a **service container** over starting containers inside the job (testcontainers) when CI supports it.
- Artifacts get an explicit `retention-days` (14 for coverage, 90 for security evidence).
- Pin every action to a released tag and every tool image to a version — a floating tag is both a supply-chain risk and a cache miss.

## 4. Quality gates the project keeps

**Backend.** `make gate` == pre-push == CI, in this order: `lint` (ruff check +
format), `typecheck` (basedpyright strict), `budget` (150 lines), `quality`
(xenon complexity · vulture dead code · interrogate 100 % docstrings · deptry
dependency hygiene · pylint duplication and design limits · codespell), `test`
(pytest, 100 % branch coverage), `audit` (pip-audit). Thresholds live in
`backend/pyproject.toml`; they go **up**, never down, and never in a feature PR.

<<<<<<< HEAD
**Client.** `dart format --set-exit-if-changed` and `dart analyze
--fatal-infos --fatal-warnings`, both **over `app/lib app/test e2e_test`,
never a bare `.`**. `flutter pub get` unpacks plugin sources under
`app/build/` — firebase_auth ships its own tests through Swift Package
Manager — and those trees carry **their own `pubspec.yaml`**, which makes each
of them a separate package root. That is why `analysis_options.yaml`'s
`exclude: ["**/build/**"]` does **not** cover them (it only reaches inside our
own package, and it is kept for the IDE) and why `dart format` cannot be
fixed at all from config: it has no exclude flag. Passing the source
directories is the only thing that holds for both, so both commands carry the
same list and it is one decision. Symptom when this regresses: hundreds of
foreign lints and reformatted files nobody wrote. Then the two grep gates
(`tool/check_tokens.sh` — no colour literals outside `theme/`;
`tool/check_config.sh` — no endpoint URLs outside `config/`), `flutter test
--coverage`, and `flutter build web --release`. The grep gates guard
architecture rather than style, which is why they are gates and not review
notes. The Flutter SDK is pinned in `client_flutter/.fvmrc`; CI reads the same
version, and bumping one without the other makes local and CI disagree
silently.
=======
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
| `repo-ci` | pull requests | **no `paths:` filter** — spelling, secrets, shell lint, gate pairs, manual-run check | yes |
| `backend-ci` | pull requests | `backend/**`, `docs/catalog/**`, `docker-compose.yml`, its own file | yes |
| `frontend-ci` | pull requests | `frontend/**`, its own file | yes |
| `infra-ci` | pull requests | `infra/**`, the delivery workflows | yes |
| `client-ci` | pull requests | `client_flutter/**`, its own file | yes |
| `backend-cd` | **the button only** | — | yes |

**`client-ci` now exists, and the history is worth keeping.** This table once
listed it as though it were one of the scoped workflows, with no marker, from
before `frontend-ci` was written — while nothing covered `client_flutter/**`.
Its container, its nginx CSP template and `docker/entrypoint.sh` — which
validates an origin and substitutes it into `connect-src` — were built, linted
and scanned by nothing, while this file asserted a pipeline. That was corrected
to say **no**, and GGU-1 (PR #26/#30) has since written it, so the row says
**yes** again — this time because the file is there.

**A row in this table is a claim about the repository, and a claim gets a truth
value.** The rule that survives is not "client-ci exists"; it is that the row
had to be walked back once, and the way to keep it honest is to change it in
the same pull request that changes the workflow directory.

`frontend-ci` and `client-ci` are two pipelines over two Flutter apps, which is
the table working, not a duplication: they are separate deployables with
separate gates, and a change to one must not pay for the other's build.

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
>>>>>>> origin/develop

## 5. When you change one, change its pair

`.claude/ship-gate.json` is the Definition of Done and has three parts, each
with a runner and a workflow that must stay identical to it:

| Part | Runner | Workflow | Also in |
|---|---|---|---|
| `py.*` | `cd backend && make gate` | `backend-ci.yaml` | pre-commit (the cheap steps) + pre-push (the whole gate) |
<<<<<<< HEAD
| `dart.*` · `client.*` · `flutter.*` | the entries themselves, from `client_flutter/` and `client_flutter/app/` — there is no client Makefile | `client-ci.yaml` | pre-commit (format, analyze, grep gates, tests) + pre-push (the web build) |
| `infra.*` | `bash infra/scripts/tests/*.sh` from the repository root — there is no root Makefile | `infra-ci.yaml` (`delivery-scripts`) | pre-commit |
=======
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
carry justified `disable` directives). The same was true of gitleaks in the
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
>>>>>>> origin/develop

A PR that changes one without its pair is incomplete. If a fourth runner ever
appears, it goes in this table rather than in a comment.
