#!/usr/bin/env bash
#
# repo.gate-pairs — every ship-gate command string appears VERBATIM in a workflow.
#
# .claude/rules/ci-conventions.md §5 says: "when you add a check to a workflow,
# copy its command string into `ship-gate.json` rather than describing what it
# does. A paraphrase is where the two drift." That rule has been broken three
# times, and each time it was found by a human reading two files side by side:
#
#   1. `infra.shell-lint` was missing from ship-gate.json entirely while
#      infra-ci had been running it all along — a shellcheck finding in a test
#      script passed every local check and failed on a runner, after merge.
#   2. `repo.spelling` ran `codespell src tests docs scripts` from inside
#      `backend/` in `make gate` and the whole repository in pre-commit, so a
#      typo in `specs/` or `.claude/` passed a green gate.
#   3. `repo.spelling` then shipped as a bare `codespell` whose directory walk
#      skips dot-entries, so `.claude/` and `.github/` were never opened while
#      its own comment and §5 both said they were.
#
# Three instances of one defect class is enough. This check does mechanically
# what a reviewer was being asked to do by eye: it PARSES ship-gate.json and
# greps each command string, as a fixed string, against the workflow files. It
# does not read intent and it cannot be satisfied by a paraphrase.
#
# What it deliberately does NOT assert:
#   - that a workflow runs nothing the gate lacks. A workflow legitimately
#     carries steps that are not gate checks (checkout, SDK setup, artifact
#     upload) and jobs deliberately outside the gate (backend-ci's `image`,
#     frontend-ci's `build`) — both are documented in ship-gate.json's own note.
#   - pre-commit coverage. Some gate checks are pre-commit hooks supplied by
#     the upstream project (`gitleaks`, `codespell`) rather than an `entry:`
#     string, so there is no command to compare. §5's "Also in" column stays a
#     human claim; this check owns the column that can be mechanised.

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

gate=".claude/ship-gate.json"
workflow_dir=".github/workflows"

# Malformed JSON is a failure, not an empty loop. jq exits non-zero and
# `set -e` carries it — but say so, because "0 entries checked" once looked
# like success in this repository.
total=$(jq -r '.required | length' "$gate")
if [ "${total:-0}" -lt 15 ]; then
  echo "repo.gate-pairs: only ${total} required entries — ship-gate.json is wrong, not the repository" >&2
  exit 1
fi

failed=0
checked=0

while IFS=$'\t' read -r id cmd; do
  checked=$((checked + 1))
  match=""
  for wf in "${workflow_dir}"/*.yaml; do
    if grep -Fq -- "$cmd" "$wf"; then
      match="${match}${match:+, }$(basename "$wf")"
    fi
  done
  if [ -z "$match" ]; then
    failed=$((failed + 1))
    echo "repo.gate-pairs: ${id} is in ship-gate.json but no workflow runs it verbatim" >&2
    echo "    ${cmd}" >&2
    echo "  fix: copy that exact string into the workflow step, or correct the gate entry." >&2
  fi
done < <(jq -r '.required[] | "\(.id)\t\(.cmd)"' "$gate")

if [ "$checked" -ne "$total" ]; then
  echo "repo.gate-pairs: read ${checked} of ${total} entries — the parse lost rows" >&2
  exit 1
fi

if [ "$failed" -gt 0 ]; then
  echo "repo.gate-pairs: ${failed} of ${checked} gate commands have drifted from their workflow" >&2
  exit 1
fi

echo "repo.gate-pairs: ${checked} gate command(s) found verbatim in ${workflow_dir}/"

# ---------------------------------------------------------------------------
# §5's third question: under what version does the command run?
# ---------------------------------------------------------------------------
# Matching command strings is not enough. GGU-94 found `frontend.format`
# byte-identical on both sides and still untrustworthy, because the *toolchain*
# was unstated: `frontend-ci.yaml` pinned `FLUTTER_VERSION: "3.47.5"` where no
# local command could read it, and `dart format` does not consult the SDK
# constraint in pubspec.yaml. A version pinned where only CI can read it is not
# a pin; it is a claim CI happens to satisfy.
#
# The fix moved the pin to `frontend/.fvmrc`. This asserts the fix stays fixed,
# because the first attempt at it added a SECOND pin file (`.flutter-version`)
# beside the `.fvmrc` that was already tracked — the same defect, one file over,
# and it took two reviewers to see it. That is exactly the point at which this
# repository stops asking reviewers to be careful and writes the check.
pin_file="frontend/.fvmrc"
pin_failed=0

if [ ! -f "$pin_file" ]; then
  echo "repo.gate-pairs: ${pin_file} is missing — the frontend SDK pin has no home" >&2
  exit 1
fi

# 1. No workflow may carry its own Flutter version.
for wf in "${workflow_dir}"/*.yaml; do
  if grep -Eq 'FLUTTER_VERSION[[:space:]]*:' "$wf"; then
    echo "repo.gate-pairs: $(basename "$wf") sets FLUTTER_VERSION" >&2
    echo "  the pin lives in ${pin_file}; read it in a step instead:" >&2
    # shellcheck disable=SC2016 # deliberate: this prints a YAML step for the
    # reader to copy, so `$(jq …)` and `$GITHUB_OUTPUT` must survive verbatim.
    echo '    run: echo "version=$(jq -r .flutter .fvmrc)" >> "$GITHUB_OUTPUT"' >&2
    pin_failed=$(( pin_failed + 1 ))
  fi
done

# 2. No second tracked file may name a Flutter version for `frontend/`.
#    `frontend/pubspec.yaml` and `frontend/app/pubspec.yaml` mention 3.47.5 in
#    prose beside their Dart floor, which is documentation rather than a pin, so
#    only machine-readable pin files are searched.
while IFS= read -r candidate; do
  [ -n "$candidate" ] || continue
  [ "$candidate" = "$pin_file" ] && continue
  echo "repo.gate-pairs: ${candidate} is a second machine-readable Flutter pin" >&2
  echo "  ${pin_file} is the one home; a pin file that disagrees with it is" >&2
  echo "  the defect GGU-94 removed, recreated one file over." >&2
  pin_failed=$(( pin_failed + 1 ))
done < <(git ls-files -- 'frontend/.fvmrc' 'frontend/.flutter-version' 'frontend/.fvm/*' 'frontend/.tool-versions')

if [ "$pin_failed" -gt 0 ]; then
  echo "repo.gate-pairs: the frontend SDK pin has ${pin_failed} home(s) too many" >&2
  exit 1
fi

echo "repo.gate-pairs: the frontend SDK pin lives only in ${pin_file}"
