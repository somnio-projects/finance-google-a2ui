# 0002 — Retire the `client_flutter/` app

- **Area:** repo
- **Status:** In progress
- **Ticket:** *unassigned* (TL request 2026-09-22: *"client_flutter elimina esa carpeta y sus referencias en develop no lo usamos mas"*) · **Related specs / ADRs:** [client/0001](../client/0001-client-foundation.md), [client/0002](../client/0002-client-delivery.md), [client/0003](../client/0003-client-backend-contract.md), [frontend/0001](../frontend/0001-frontend-skeleton.md), [frontend/0017](../frontend/0017-the-client-runs-in-the-stack-and-ships-itself.md), [ADR-H](../../docs/adr/ADR-H-ci-ship-gate.md), [ADR-I](../../docs/adr/ADR-I-client-routing.md), [ADR-L](../../docs/adr/ADR-L-client-architecture.md)
- **Owner:** Lautaro Bertuzzi · **Date:** 2026-09-22

## 1. Problem

This repository shipped **two** Flutter apps. `client_flutter/` was the first —
still substantially Google's `restaurant_finder` sample, adapted only in part
(specs `client/0001`, `client/0002`) — and `frontend/` is the A2UI client
written from scratch to this repository's standard (GGU-91, ADR-L), which is
gated at 100 % line coverage per file, runs in the one local stack and is
deployed to Firebase Hosting by `frontend-cd`.

Keeping the first one is not free, and the cost is not the disk space. It is a
second gate part (`dart.*` / `client.*` / `flutter.*`), a second workflow
(`client-ci.yaml`), a second Dockerfile, a second CSP template, a second SDK
pin, four `.claude/rules/client/*.md` files, a second Dependabot entry, a
second compose file, and a row in every table this repository keeps honest
about itself. Every one of those is a claim that has to be re-read whenever
something near it moves — and `.claude/rules/ci-conventions.md` §4b records
that the `client-ci` row **had already been walked back once** for exactly that
reason. The TL's instruction is to remove it.

The second-order problem is that a deletion of this size is where a repository
quietly loses its history. The rule this project keeps (`specs/README.md`,
`.claude/rules/backend/sdd.md`) is that a spec or an ADR that shipped is
**superseded, not erased**, so a citation by number still resolves. This spec
records which side of that line each artefact fell on.

## 2. Scope

**In — deleted outright** (the artefact's subject no longer exists, so there is
nothing for a pointer to point at):

- `client_flutter/` — 117 tracked files: the pub workspace (`app/`,
  `e2e_test/`), `Dockerfile`, `docker/entrypoint.sh`,
  `docker/nginx.conf.template`, `docker/flutter-sdk-checksums.json`,
  `docker-compose.yml`, `.fvmrc`, `tool/check_tokens.sh`,
  `tool/check_config.sh`, `CLAUDE.md`, `README.md`, `docs/SECURITY.md`.
- `.github/workflows/client-ci.yaml`.
- `.claude/rules/client/{architecture,presentation,testing,security}.md`, and
  their four rows in the root `CLAUDE.md` rules index.
- The six `dart.*` / `client.*` / `flutter.*` entries in
  `.claude/ship-gate.json`, and the seven `client-*` hooks in
  `.pre-commit-config.yaml`.
- `docs/diagrams/11-client-architecture.md` (see §4).
- The `/client_flutter` `pub` entry in `.github/dependabot.yml`.

**In — superseded, kept in place** (see §3).

**In — rewritten because the deletion made them false:** root `CLAUDE.md`,
`README.md` (also rewritten for currency — §6), `docker-compose.yml`,
`.gitignore`, `.vscode/launch.json`, `NOTICE`, root `SECURITY.md`,
`.claude/rules/ci-conventions.md`, `.claude/rules/diagrams.md`,
`scripts/check_gate_pairs.sh`, `scripts/check_shell.sh`,
`.github/workflows/repo-ci.yaml`, `docs/diagrams/{02,09,13}`,
`docs/diagrams/README.md`, `docs/compliance/{VENDOR_MANAGEMENT,
VULNERABILITY_MANAGEMENT,isms/ISMS_SCOPE}.md`, `specs/README.md`.

**Out — deliberately left alone**, each with a reason:

| Left alone | Reason |
|---|---|
| `.claude/harness-log.md` | Append-only record of what happened. Rewriting a log entry is falsifying it; this work gets a **new** entry. |
| `docs/specs/GGU-6/refinement-report.md` | A dated artefact of the 2026-09-18 refinement pass. It describes the tree **as it was on that day** and is only useful if it stays that way. |
| `.claude/rules/flutter/*.md` | Synced from `somnio-ai-tools` by the Somnio CLI; root `CLAUDE.md` § *Do not touch*. Their `paths:` globs name `client_flutter/*/lib/**`, which now simply never matches — stale, harmless, and not ours to edit. Fix upstream. |
| `.claude/agents/frontend-reviewer.md` | One scope-note line naming the other app. **Write-denied to the agent sandbox**; carried in the PR body as a follow-up. |
| `.claude/harness.json` | Tool-managed (`/harness-init`). Its `objective` string is already stale in three other ways. |
| `frontend/Dockerfile`, `frontend/docker/nginx.conf.template`, `frontend/docker/entrypoint.sh`, `frontend/SECURITY.md` | Comparative **design rationale** — "this is that file with two headers changed, and here is why" — which stays true about why those files look the way they do. They are also under concurrent edit by another branch (CSP), and this spec's change is not worth a conflict in the one file that authorises the Firebase loader. |
| `specs/frontend/0003`, `0004`, `0017`, `specs/infra/0002` | Dated rationale inside merged specs. A spec records the state it was written against; §3's rule applies to a spec's **status**, not to its prose. |

## 3. Superseded, not deleted — and the rule behind each call

`specs/README.md`: *"a replaced spec is marked `Superseded by NNNN` and kept."*
`docs/adr/README.md`: *"Superseded by ADR-N. Kept for history; never deleted."*

| Artefact | Call | Why |
|---|---|---|
| `specs/client/0001-client-foundation.md` | **Superseded by `repo/0002`** | Its subject is gone. It is cited by `client/0002`, `client/0003` and ADR-L; a deleted file breaks all three. `frontend/0001` is not its successor — that app was written from scratch, not adapted, so the pointer says "retired", not "renumbered". |
| `specs/client/0002-client-delivery.md` | **Superseded by `repo/0002`** | Same. Its **OD-1** (where the client is hosted) was never answered for that app and is answered for `frontend/` by `frontend/0017`; the banner says so, because an open decision that was resolved for a *different* app is the kind of thing a reader would otherwise mis-cite. |
| `specs/client/0003-client-backend-contract.md` | **Live — not superseded** | Its subject is the **backend's** contract, not the app. `frontend/` binds it, ADR-L lists it under *Related*, and `specs/frontend/0030` OD-1 argues against `genui` by quoting its §8.3. Only its scope-exclusion bullet was struck. |
| `docs/adr/ADR-I-client-routing.md` | **Superseded by ADR-L** | Its whole subject was that app's navigation. **D-3 outlived it** — ADR-L D-5 restates it verbatim for `frontend/` (the auth gate is one `redirect`) — and ADR-L D-5 is written as an amendment to ADR-I D-1, so the number must still resolve. |
| `docs/adr/ADR-H` **D-2** and **D-6** | **Struck in place** | ADR-H is otherwise live (it is the ship-gate contract). The README's vocabulary already has this case: *"one ruling inside it was replaced… the old `D-n` is struck through and kept."* |
| `specs/client/` as an **area** | **Closed, not removed** | `specs/README.md` now says no new spec goes there and why; `0003` still lives in it. Numbers are never reused. |

## 4. The one deletion that is a judgement: diagram 11

`docs/diagrams/11-client-architecture.md` drew that app's layers. It is
**deleted, not superseded**, and that is the only artefact here where the two
rules point in different directions.

`.claude/rules/diagrams.md` settles it: *"Draw reality… A diagram must never
imply a capability that does not exist."* A diagram has no "superseded" form —
a picture of a directory that is not there is either wrong or it is prose. The
question it answered (what may import what, in the Flutter client) is
[12](../../docs/diagrams/12-frontend-layers.md)'s for the app that remains, and
12 answers it better, because `frontend/`'s version is enforced by
`app/test/architecture/layering_test.dart` rather than by review.

**The number 11 is retired, not reused.** `docs/diagrams/README.md` says so in
place of the row, and `.claude/rules/diagrams.md` now states the rule, because
a renumbering would silently repoint every citation of "diagram 12" and a
reused `11` would make two different pictures answer to one reference.

## 5. Security notes

No authentication, authorization, audit or data-retention behaviour changes:
nothing deleted here ran in production, held a credential or touched the
database. Three security-posture facts do change and are written down rather
than netted out:

- **A gap closed by removal, not by a control.** `VULNERABILITY_MANAGEMENT.md`
  §1 carried *"the `client_flutter/` image is never built or scanned by CI"*.
  The image is gone, so the row is gone — but the file now says the row closed
  because **the artefact was retired**, not because a scan was written. Those
  are different facts and an auditor is entitled to the difference.
- **Scope shrank; the Dart gaps did not close.** No SAST over Dart and no CVE
  scan of a `pubspec.lock` are still true, now over one graph instead of two.
- **`repo.shell-lint` had lost its teeth, and this deletion is how we found
  out.** Its by-name assertion listed `client_flutter/docker/entrypoint.sh`
  behind `[ -f "$required" ] || continue` — commented *"the tree is allowed to
  lose a file; it is not allowed to skip one"*, which sounds right and makes
  the assertion **vacuous** the moment a name goes stale. Measured: `git mv`-ing
  an entry point out from under the list leaves the check **green**, reporting
  the same "19 scripts linted". Deleting the app would therefore have retired
  that half of the assertion silently. Two changes: the list now names
  `frontend/docker/entrypoint.sh`, which does the same CSP substitution, and a
  name that does not resolve is now a **failure** with the fix in the message.
  The header keeps the original SC2016 finding, because it is the argument for
  the check having repository scope at all.

## 6. Acceptance criteria

1. **AC-1** — `client_flutter/` is absent from the working tree and from
   `git ls-files`.
2. **AC-2** — `grep -rn 'client_flutter\|client-ci'` over the repository
   returns only: the append-only harness log, the dated GGU-6 refinement
   report, the upstream-synced `.claude/rules/flutter/` globs, the four
   `frontend/` container files named in §2, `.claude/agents/` and
   `.claude/harness.json` (both write-denied or tool-managed) — and prose that
   explicitly frames the app as **retired**.
3. **AC-3** — `.claude/ship-gate.json` has **four** parts, and the number
   **four** appears in `ci-conventions.md` §5, in that file's `_note` and in
   the root `CLAUDE.md`. (The count was wrong in *both* files before this
   change, in opposite directions — §5 said five, the `_note` said three.)
4. **AC-4** — `bash scripts/check_gate_pairs.sh` is green and still asserts a
   single SDK pin home for every app in `pin_apps`; `pin_apps` remains a list.
5. **AC-5** — `bash scripts/check_shell.sh` is green, its by-name assertion
   reaches a file that exists, **and it fails when that file is moved away** —
   which it did not do before this change.
6. **AC-6** — `bash infra/scripts/tests/test_rules_index.sh` is green: every
   rule file has a row and every row has a rule file.
7. **AC-7** — `bash scripts/check_spelling.sh`,
   `bash scripts/tests/test_check_manual_run.sh`, `cd backend && make gate`
   and `cd frontend && make gate` are all green.
8. **AC-8** — every artefact in §3 carries its `Superseded` / struck marker and
   a working relative link to this spec, and `specs/README.md`'s index says so.
9. **AC-9** — the root `README.md` contains no claim that is false on the day
   it is read: no "under construction", no "upstream sample, unmodified", no
   "delivery pipeline never run", no "A2A not built", no "run the Flutter
   client → not yet". The simulated-data honesty **survives verbatim in
   substance** — that part was never wrong.

## 7. Test plan

There is no code in this change, so there are no unit or integration tests to
add. What proves it is the gate, and the gate is the point: this repository's
checks are written so that a deletion of this size cannot pass quietly.

| AC | Proven by |
|---|---|
| AC-1 | `git ls-files \| grep client_flutter` — empty |
| AC-2 | the grep in the AC, read by hand; the residue is enumerated in §2 |
| AC-3 | read by hand — no machine reads a prose count, which is exactly why it has been wrong twice |
| AC-4 | `bash scripts/check_gate_pairs.sh` (`repo.gate-pairs`, also in `repo-ci`) |
| AC-5 | `bash scripts/check_shell.sh` (`repo.shell-lint`) |
| AC-6 | `bash infra/scripts/tests/test_rules_index.sh` (`infra.rules-index`) |
| AC-7 | `bash scripts/check_spelling.sh`, `bash scripts/tests/test_check_manual_run.sh`, `cd backend && make gate`, `cd frontend && make gate` |
| AC-8 | link check by hand; `specs/README.md` index |
| AC-9 | read by hand against the deployed URLs |

**Mutation checks required:** yes, for the two scripts whose *subject* moved,
because §5 of `ci-conventions.md` is explicit that a check can match its pair
byte for byte and still prove the wrong thing:

- `check_gate_pairs.sh` — deleting `frontend/.fvmrc` must fail it, and adding
  `frontend/.flutter-version` must fail it. Otherwise `pin_apps="frontend"`
  might have emptied the loop rather than narrowed it.
- `check_shell.sh` — renaming `frontend/docker/entrypoint.sh` must fail it.
  **It did not**, on the first run: the `|| continue` guard satisfied the
  assertion, exit 0. That is the finding in §5, and the guard was replaced. The
  mutation now exits 1 and names the file; restored, the check exits 0.

## 8. Open decisions

| # | Question | Owner | Default if unresolved |
|---|---|---|---|
| OD-1 | `.claude/agents/frontend-reviewer.md` carries a one-line scope note naming the other app. The agent sandbox denies writes to `.claude/agents/`. | TL | Leave it; a human edits the line. It is a scope note on a read-only reviewer, so the failure mode is a stale sentence, not a wrong review. |
| OD-2 | `.claude/rules/flutter/*.md` carry `paths:` globs for `client_flutter/*/lib/**`. They are synced from `somnio-ai-tools` and `CLAUDE.md` forbids editing them here. | TL | Leave them; a glob that matches nothing costs nothing. Raise it upstream so the next repository does not inherit it. |
| OD-3 | Four `frontend/` container files argue their decisions **against** the retired app's ("this is that template with two headers changed"). | TL | Keep the prose. It is why those files look the way they do, and the history is the reason a reviewer should not "simplify" them back. Revisit if it confuses a reader. |
| OD-4 | Jira: GGU-1 and GGU-82 are tickets against the deleted app; GGU-7 (Epic 1, "adapt the sample") is moot. | TL | Nothing is closed by this PR. The agent does not move tickets it was not given. |
| OD-5 | `.claude/harness.json`'s `objective` describes `backend_python` + `client_flutter`, and is now wrong in three ways. | TL | Leave it; `/harness-init` owns that file. |

## 9. Rollout & observability

No feature flag, no migration, no metric, no log event. Nothing deployed
changes: `client_flutter/` was never deployed anywhere, which is the fact that
made this decision easy (`client/0002` OD-1 was still open on the day the app
was deleted, one month after its container was built and hardened).

The one operational note: `docker compose -f client_flutter/docker-compose.yml`
no longer exists. Anyone who had that in a shell alias gets "no such file". The
replacement is the default `docker compose up --build`, which brings up
Postgres, the backend and the A2UI client under the one project
`finance-a2ui`.
