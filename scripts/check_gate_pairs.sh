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
#
# `pin_apps` is a LIST rather than the single word `frontend`, because this
# repository shipped two Flutter apps for a while and the rule is one pin per
# APP, not one per repository. `client_flutter/` was retired on 2026-09-22
# (spec `repo/0002`) and left the list with it; the loop shape stays, so a
# second app arriving is one word here instead of a rewrite. What is forbidden
# is a SECOND home for the same app's pin, in either direction — GGU-1 added
# `client-ci.yaml` carrying `FLUTTER_VERSION: "3.47.3"` beside an
# already-tracked `client_flutter/.fvmrc`, with a comment reading "Bump both
# together or the two disagree silently", which is the GGU-94 defect rebuilt in
# the second app. Rule 1 below is repository-wide for that reason and does not
# need the app to still exist to keep catching it.
pin_apps="frontend frontend_v1"
pin_failed=0

for app in $pin_apps; do
  if [ ! -f "${app}/.fvmrc" ]; then
    echo "repo.gate-pairs: ${app}/.fvmrc is missing — that app's SDK pin has no home" >&2
    exit 1
  fi
done

# 1. No workflow may carry its own Flutter version.
for wf in "${workflow_dir}"/*.yaml; do
  if grep -Eq 'FLUTTER_VERSION[[:space:]]*:' "$wf"; then
    echo "repo.gate-pairs: $(basename "$wf") sets FLUTTER_VERSION" >&2
    echo "  the pin lives in that app's .fvmrc; read it in a step instead:" >&2
    # shellcheck disable=SC2016 # deliberate: this prints a YAML step for the
    # reader to copy, so `$(jq …)` and `$GITHUB_OUTPUT` must survive verbatim.
    echo '    run: echo "version=$(jq -r .flutter .fvmrc)" >> "$GITHUB_OUTPUT"' >&2
    pin_failed=$(( pin_failed + 1 ))
  fi
done

# 2. No second tracked file may name a Flutter version for the same app.
#    Each app's `pubspec.yaml` mentions its version in prose beside the Dart
#    floor, which is documentation rather than a pin, so only machine-readable
#    pin files are searched.
for app in $pin_apps; do
  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    [ "$candidate" = "${app}/.fvmrc" ] && continue
    echo "repo.gate-pairs: ${candidate} is a second machine-readable Flutter pin" >&2
    echo "  ${app}/.fvmrc is that app's one home; a pin file that disagrees with" >&2
    echo "  it is the defect GGU-94 removed, recreated one file over." >&2
    pin_failed=$(( pin_failed + 1 ))
  done < <(git ls-files -- "${app}/.fvmrc" "${app}/.flutter-version" "${app}/.fvm/*" "${app}/.tool-versions")
done

# 3. No app's Dockerfile may name its own Flutter version either.
#
#    This is the fourth instance of GGU-94's defect and the first one found in
#    a file the check was not reading. On 2026-09-22, while the same builder
#    stage was written for `frontend/`, `client_flutter/Dockerfile` was found
#    carrying `ARG FLUTTER_VERSION=3.47.5` beside a `.fvmrc` pinning 3.47.3 —
#    so the image shipped a bundle compiled by an SDK the gate never proved
#    the app against, and both halves looked fine on their own. Rules 1 and 2
#    above could not see it: it is not a workflow, and a Dockerfile is not a
#    pin file. That app has since been retired (spec `repo/0002`) and the
#    Dockerfile went with it; the rule stays because it is about Dockerfiles,
#    not about that one, and `frontend/Dockerfile` is held to it today.
#
#    Two assertions, because either alone is satisfiable by the wrong file: the
#    Dockerfile must not carry a version, AND it must be shown to read the one
#    that exists. Comments are stripped first — these files argue at length
#    about which version was chosen and why, and prose about a past mistake is
#    not a pin.
for app in $pin_apps; do
  dockerfile="${app}/Dockerfile"
  [ -f "$dockerfile" ] || continue

  code="$(sed 's/[[:space:]]*#.*$//' "$dockerfile")"

  if printf '%s' "$code" | grep -Eq 'FLUTTER_VERSION[[:space:]]*[=:]'; then
    echo "repo.gate-pairs: ${dockerfile} sets FLUTTER_VERSION" >&2
    echo "  the pin lives in ${app}/.fvmrc; read it in the build instead:" >&2
    # shellcheck disable=SC2016 # deliberate: this prints a RUN line for the
    # reader to copy, so `$(jq …)` must survive verbatim.
    echo '    RUN version="$(jq -r .flutter /tmp/pin/.fvmrc)"' >&2
    pin_failed=$(( pin_failed + 1 ))
  fi

  # A COPY of the file, not a MENTION of it. The first draft of this rule
  # grepped for the string `.fvmrc` and was satisfied by an error message that
  # merely named it — mutation-tested on 2026-09-22: the pin was removed from
  # the build and the check stayed green, because one `echo` still contained
  # the word. A check a comment can satisfy is not a check.
  if ! printf '%s' "$code" | grep -Eq '^[[:space:]]*COPY([[:space:]]+--[^[:space:]]+)*[[:space:]]+\.fvmrc([[:space:]]|$)'; then
    echo "repo.gate-pairs: ${dockerfile} has no COPY of ${app}/.fvmrc" >&2
    echo "  an image built by an unstated SDK is not the app the gate proved;" >&2
    echo "  copy the pin in and read it, do not restate the version here." >&2
    pin_failed=$(( pin_failed + 1 ))
  fi
done

if [ "$pin_failed" -gt 0 ]; then
  echo "repo.gate-pairs: a Flutter SDK pin has ${pin_failed} home(s) too many" >&2
  exit 1
fi

for app in $pin_apps; do
  echo "repo.gate-pairs: ${app} pins Flutter $(jq -r .flutter "${app}/.fvmrc") in ${app}/.fvmrc, and nowhere else"
done

# ---------------------------------------------------------------------------
# §5's third question again, in the other language: Python (GGU-125)
# ---------------------------------------------------------------------------
# Everything above this line was written for Flutter, and the identical defect
# sat in the Python half of the repository the whole time with nothing watching
# it. Until 2026-09-25 `backend-ci.yaml` and `repo-ci.yaml` each carried
# `PYTHON_VERSION: "3.12"` in an `env:` block, handed to `astral-sh/setup-uv`,
# while `backend/.python-version`, `backend/pyproject.toml` (twice) and
# `backend/Dockerfile` (twice) declared the same fact separately. Six
# declarations, one of them unreadable by any local command — GGU-94's defect,
# one language over. It was found by hand while upgrading to 3.14 (#130),
# which is where this repository stops trusting reviewers and writes the check.
#
# The drift is REMOVED rather than policed, which is why rule 1 forbids the
# workflow pin outright instead of comparing its value: `uv sync` and `uv run`
# read `.python-version` from the project directory on their own and install the
# interpreter it names, so `setup-uv` needs no `python-version:` input at all.
# Measured from the repository root with no env var: `uv python find --project
# backend` answers 3.14, and the same command in a directory with no pin file
# answers something else entirely.
#
# Forbidding it outright rather than comparing it is deliberate, and the reason
# is the sharpest part of GGU-125: which of the two declarations wins is not
# stable. `python-version` sets `UV_PYTHON`, and on uv 0.11.19 the tracked file
# beats it — so the CI-only pin was *inert* while reading as authoritative, and
# a uv bump or a stray `--python` flag turns it back on. A value that agrees
# today is still a second home, so rule 1 fails on the LINE, not on the value.
#
# `py_pin_dirs` is a LIST for the reason `pin_apps` is: one pin per SOLUTION,
# not one per repository. A second Python service is one word here.
py_pin_dirs="backend"
py_failed=0
py_checked=0

for dir in $py_pin_dirs; do
  pin_file="${dir}/.python-version"

  if [ ! -f "$pin_file" ]; then
    echo "repo.gate-pairs: ${pin_file} is missing — that solution's interpreter pin has no home" >&2
    exit 1
  fi

  pin="$(tr -d '[:space:]' < "$pin_file")"
  case "$pin" in
    [0-9]*.[0-9]*) ;;
    *)
      echo "repo.gate-pairs: ${pin_file} reads '${pin}', which is not an X.Y interpreter version" >&2
      exit 1
      ;;
  esac
  pin_next="${pin%.*}.$(( ${pin#*.} + 1 ))"

  # 1. No workflow may name a Python version. Comments are stripped first: the
  #    workflows explain at length why the `env:` var is gone, and prose about
  #    a removed pin is not a pin. `python-version-file:` is deliberately NOT
  #    matched — a step that READS the pin is the fix, not the defect.
  for wf in "${workflow_dir}"/*.yaml; do
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      echo "repo.gate-pairs: $(basename "$wf") names an interpreter version of its own:" >&2
      echo "    ${line#"${line%%[![:space:]]*}"}" >&2
      echo "  ${pin_file} says ${pin} and is the one home. Delete the line: uv reads" >&2
      echo "  that file from the project directory. If a step truly needs the value," >&2
      echo "  read it (\`python-version-file: ${pin_file}\`), never restate it." >&2
      py_failed=$(( py_failed + 1 ))
    done < <(sed 's/[[:space:]]*#.*$//' "$wf" |
      grep -E '(PYTHON_VERSION|UV_PYTHON)[[:space:]]*[:=]|(^|[^-[:alnum:]_])python-version[[:space:]]*:' || true)
  done

  # 2. No second machine-readable pin file for the same solution. The prose in
  #    `CLAUDE.md` and `README.md` names the version as documentation, the way
  #    each app's `pubspec.yaml` does for Flutter, so only pin files are read.
  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    [ "$candidate" = "$pin_file" ] && continue
    echo "repo.gate-pairs: ${candidate} is a second machine-readable Python pin" >&2
    echo "  ${pin_file} is that solution's one home; a pin file that disagrees with" >&2
    echo "  it is the defect this rule removed, recreated one file over." >&2
    py_failed=$(( py_failed + 1 ))
  done < <(git ls-files -- "${dir}/.python-version" "${dir}/.python-versions" \
    "${dir}/.tool-versions" "${dir}/runtime.txt")

  # 3. `pyproject.toml` restates the fact twice and cannot stop: `requires-python`
  #    is the package metadata every resolver reads, and basedpyright's
  #    `pythonVersion` is what decides which syntax type-checks. Neither can be
  #    deleted, so these two are COMPARED rather than forbidden — a mismatch
  #    means the gate type-checks against an interpreter it does not run.
  pyproject="${dir}/pyproject.toml"
  if [ -f "$pyproject" ]; then
    requires="$(sed -n 's/^requires-python[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' "$pyproject" | head -1)"
    py_checked=$(( py_checked + 1 ))
    if [ "$requires" != ">=${pin},<${pin_next}" ]; then
      echo "repo.gate-pairs: ${pyproject} requires-python = \"${requires:-<absent>}\"" >&2
      echo "  ${pin_file} says ${pin}, so this must read \">=${pin},<${pin_next}\"" >&2
      py_failed=$(( py_failed + 1 ))
    fi

    pyright="$(sed -n 's/^pythonVersion[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' "$pyproject" | head -1)"
    py_checked=$(( py_checked + 1 ))
    if [ "$pyright" != "$pin" ]; then
      echo "repo.gate-pairs: ${pyproject} pythonVersion = \"${pyright:-<absent>}\"" >&2
      echo "  ${pin_file} says ${pin}; the type-checker's target and the interpreter" >&2
      echo "  that runs the tests are the same fact and must read the same value." >&2
      py_failed=$(( py_failed + 1 ))
    fi
  fi

  # 4. The Dockerfile's base images are the fourth and fifth declarations, and
  #    the ones a laptop never exercises. `FROM` cannot read a file — an `ARG`
  #    would just be the CI-only pin again — and the builder sets
  #    `UV_PYTHON_DOWNLOADS=never`, so the base tag IS the interpreter the
  #    image ships. Compared, therefore, and both values printed.
  dockerfile="${dir}/Dockerfile"
  if [ -f "$dockerfile" ]; then
    docker_code="$(sed 's/[[:space:]]*#.*$//' "$dockerfile")"
    from_count=0
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      from_count=$(( from_count + 1 ))
      py_checked=$(( py_checked + 1 ))
      version="$(printf '%s\n' "$line" |
        sed -E 's|.*[Ff][Rr][Oo][Mm][[:space:]]+python:([0-9]+\.[0-9]+).*|\1|')"
      if [ "$version" != "$pin" ]; then
        echo "repo.gate-pairs: ${dockerfile} builds on python:${version}" >&2
        echo "    ${line#"${line%%[![:space:]]*}"}" >&2
        echo "  ${pin_file} says ${pin}. An image built on another interpreter is" >&2
        echo "  not the service the gate proved; bump both in the same commit." >&2
        py_failed=$(( py_failed + 1 ))
      fi
    done < <(printf '%s\n' "$docker_code" |
      grep -E '^[[:space:]]*[Ff][Rr][Oo][Mm][[:space:]]+python:[0-9]+\.[0-9]+' || true)

    # Anti-vacuity, the idiom `infra/scripts/tests/` and `check_spelling.sh`
    # already use: a Dockerfile whose base names no interpreter makes rule 4
    # pass by finding nothing, which is the shape of every defect above.
    if [ "$from_count" -lt 1 ]; then
      echo "repo.gate-pairs: ${dockerfile} has no \`FROM python:X.Y\` line" >&2
      echo "  the base image is where that solution's shipped interpreter is named;" >&2
      echo "  if it moved, this rule must be taught the new home, not left green." >&2
      py_failed=$(( py_failed + 1 ))
    fi
  fi
done

# Three is the floor a single solution cannot fall below while still declaring
# the fact anywhere: `requires-python`, `pythonVersion`, and at least one base
# image. Fewer means the comparison found nothing to compare.
if [ "$py_checked" -lt 3 ]; then
  echo "repo.gate-pairs: only ${py_checked} derived Python declaration(s) compared — the search found nothing, which is not the same as agreement" >&2
  exit 1
fi

if [ "$py_failed" -gt 0 ]; then
  echo "repo.gate-pairs: ${py_failed} Python interpreter declaration(s) disagree with their pin" >&2
  exit 1
fi

for dir in $py_pin_dirs; do
  echo "repo.gate-pairs: ${dir} pins Python $(tr -d '[:space:]' < "${dir}/.python-version") in ${dir}/.python-version, no workflow restates it, and ${py_checked} derived declaration(s) agree"
done

# ---------------------------------------------------------------------------
# Rule 4 — a workflow that can be CALLED needs a per-caller concurrency key.
#
# A reusable workflow evaluates `concurrency` in the **caller's** context, so a
# group keyed by `github.ref` alone puts every caller of it on one branch into
# one group. With `cancel-in-progress: true` the second caller then cancels the
# first one's gate.
#
# Measured, not theorised (GGU-130): on 2026-09-25 `frontend-cd` started 23 s
# after `backend-cd` on `develop`. Both call `repo-ci`, whose key was
# `repo-ci-${{ github.ref }}`. The later run cancelled the earlier run's `repo`
# job; `publish` and `deploy` declare `needs: [ci, repo, settings]` and were
# therefore **skipped**, so the client shipped to Hosting and the API did not —
# leaving a new bundle bound to `holding`, `delta_label` and
# `realized.direction` talking to a revision that serves none of them.
#
# `backend-ci` and `frontend-ci` are called the same way and both already
# carried `github.workflow`. Only the repository-wide one did not, which is why
# the failure message read `gate=success`: it prints `needs.ci.result`, and
# `ci` was the gate whose key happened to be right.
conc_checked=0
conc_failed=0
for workflow in .github/workflows/*.yaml; do
  grep -q "workflow_call:" "$workflow" || continue
  conc_checked=$(( conc_checked + 1 ))
  group="$(grep -A1 '^concurrency:' "$workflow" | tail -1 | sed 's/^ *//')"
  case "$group" in
    *'github.workflow'*) ;;
    *)
      echo "repo.gate-pairs: ${workflow} is callable and its concurrency group is not per-caller" >&2
      echo "  ${group}" >&2
      echo "  add \${{ github.workflow }} to the key, as backend-ci and frontend-ci do." >&2
      echo "  without it, two workflows that call this one on the same branch" >&2
      echo "  share a group, and cancel-in-progress makes the second kill the first." >&2
      conc_failed=$(( conc_failed + 1 ))
      ;;
  esac
done

# Anti-vacuity: three workflows are callable today. A run that finds none has
# stopped reading workflows, not proved them correct.
if [ "$conc_checked" -lt 3 ]; then
  echo "repo.gate-pairs: only ${conc_checked} callable workflow(s) found — the search is wrong, not the repository" >&2
  exit 1
fi

if [ "$conc_failed" -gt 0 ]; then
  echo "repo.gate-pairs: ${conc_failed} callable workflow(s) can cancel another caller's gate" >&2
  exit 1
fi

echo "repo.gate-pairs: ${conc_checked} callable workflow(s) key concurrency per caller"
