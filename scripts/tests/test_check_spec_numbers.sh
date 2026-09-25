#!/usr/bin/env bash
#
# Proves scripts/check_spec_numbers.sh REJECTS, which is the only interesting
# thing about a check (GGU-105 AC-4).
#
# The defect that ticket describes is a property nothing enforces. A check that
# has only ever been seen passing reproduces it one level up: "spec numbers are
# unique" reads exactly the same whether the check can tell or not. So every
# rule has a case here, planted into a fixture tree, and the pass case is last
# rather than first — a suite whose only green line is "the real repository is
# fine" would also be green for a script that always exits 0.
#
# Fixtures are real throwaway git repositories, because the check reads
# `git ls-files`: tracked files only, so an untracked scratch file cannot fail
# somebody's build. `git add` is enough — nothing here commits.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../.." && pwd)"
cd "$ROOT"

CHECK="scripts/check_spec_numbers.sh"
# Identical to the `repo.spec-numbers` entry in .claude/ship-gate.json, the
# pre-commit hook and the repo-ci step (ci-conventions §5 — copied, never
# paraphrased).
FIX="bash scripts/tests/test_check_spec_numbers.sh"

PASSED=0
FAILED=0

pass() { echo "  PASS  $1"; PASSED=$(( PASSED + 1 )); }
fail() { echo "  FAIL  $1"; FAILED=$(( FAILED + 1 )); }

# An explicit template, not a bare `mktemp -d`: macOS's mktemp ignores TMPDIR
# when given no template and uses the confstr temp directory instead, which is
# outside the agent sandbox's write set. Same command, two behaviours, one of
# them red only on a laptop. Copied from test_check_manual_run.sh.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/spec-numbers.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

# Builds a tree that PASSES, so every case below is one planted defect away
# from green. Forty-one specs, because the check refuses to believe a corpus
# smaller than forty — the fixture has to clear the bar the real repository
# clears, or the suite would only ever exercise the vacuity guard.
fixture() {
  local dir="$1"
  mkdir -p "${dir}/specs"/{backend,frontend,infra,repo,client}
  : >"${dir}/specs/README.md"
  {
    echo "# Specs"
    echo
    echo "| Spec | Status | Ticket |"
    echo "|---|---|---|"
  } >>"${dir}/specs/README.md"
  local area number slug
  for spec in $(seq -f 'backend/%04.0f-a-backend-spec' 1 37) \
    'frontend/0001-a-frontend-spec' 'infra/0001-an-infra-spec' \
    'repo/0001-a-repo-spec' 'client/0001-a-client-spec'; do
    area="${spec%%/*}"
    slug="${spec#*/}"
    echo "# ${slug}" >"${dir}/specs/${area}/${slug}.md"
    echo "| [${area}/${slug}.md](${area}/${slug}.md) | Draft | — |" >>"${dir}/specs/README.md"
  done
  ( cd "$dir" && git init --quiet . && git add -A >/dev/null )
  # `number` is assigned nowhere above; naming it keeps shellcheck honest about
  # the loop's locals rather than leaving one to leak from the caller's scope.
  : "${number:=}"
}

# Adds a spec file AND its index row — the shape a well-behaved change has.
add_spec() {
  local dir="$1" area="$2" name="$3"
  echo "# ${name}" >"${dir}/specs/${area}/${name}.md"
  echo "| [${area}/${name}.md](${area}/${name}.md) | Draft | — |" >>"${dir}/specs/README.md"
  ( cd "$dir" && git add -A >/dev/null )
}

# Runs the check against a fixture and reports whether it exited as expected
# AND said the right thing. "Exited non-zero" is not enough: a red gate is not
# evidence that it is red for your reason (ci-conventions §5).
expect() {
  local label="$1" want_status="$2" want_text="$3" dir="$4"
  local out status
  set +e
  out=$(bash "$CHECK" "$dir" 2>&1)
  status=$?
  set -e
  if [ "$status" -ne "$want_status" ]; then
    fail "${label} — exit ${status}, expected ${want_status}"
    printf '%s\n' "$out" | sed 's/^/          /'
    return
  fi
  if ! printf '%s\n' "$out" | grep -Fq -- "$want_text"; then
    fail "${label} — exit ${want_status} as expected, but never said: ${want_text}"
    printf '%s\n' "$out" | sed 's/^/          /'
    return
  fi
  pass "${label}"
}

echo "== ${CHECK}"

# 0. The fixture itself passes. Without this line every assertion below would
#    also hold of a check that always exits 1.
fixture "${WORK}/clean"
expect "a tree with unique, well-formed, indexed specs is accepted" \
  0 "each numbered once and indexed once" "${WORK}/clean"

# 1. The defect GGU-105 was cut for: two files, one number, in one area. This is
#    `specs/frontend/0002` on `develop`, reproduced.
fixture "${WORK}/dup"
add_spec "${WORK}/dup" frontend 0002-the-first-one
add_spec "${WORK}/dup" frontend 0002-the-second-one
expect "two specs sharing a number in one area are rejected" \
  1 "two specs share specs/frontend/0002" "${WORK}/dup"
expect "the rejection names the first file" \
  1 "specs/frontend/0002-the-first-one.md" "${WORK}/dup"
expect "the rejection names the second file" \
  1 "specs/frontend/0002-the-second-one.md" "${WORK}/dup"

# 1b. The same number in two DIFFERENT areas is legitimate — numbers are per
#     area — and `backend/0001` beside `frontend/0001` is the status quo. A
#     check that failed here would be unusable, so the fixture already contains
#     the case and case 0 covers it; this asserts it explicitly.
fixture "${WORK}/cross-area"
add_spec "${WORK}/cross-area" infra 0002-same-number-elsewhere
add_spec "${WORK}/cross-area" repo 0002-same-number-elsewhere
expect "the same number in two areas is not a collision" \
  0 "each numbered once and indexed once" "${WORK}/cross-area"

# 2. Shape. An unpadded number sorts wrong and defeats the prefix comparison
#    case 1 relies on, so it is a failure rather than a style note.
fixture "${WORK}/shape"
add_spec "${WORK}/shape" backend 038-not-padded
expect "an unpadded number is rejected" \
  1 "is not NNNN-lowercase-kebab-slug.md" "${WORK}/shape"

fixture "${WORK}/shape-case"
add_spec "${WORK}/shape-case" backend 0038-Not-Kebab-Case
expect "a capitalised slug is rejected" \
  1 "is not NNNN-lowercase-kebab-slug.md" "${WORK}/shape-case"

# 3. The index, in both directions. A spec with no row is the state nine files
#    were in on `develop` — including both halves of the `0002` collision, which
#    is why "visible at a glance" was not true of either.
fixture "${WORK}/unindexed"
echo '# orphan' >"${WORK}/unindexed/specs/backend/0038-no-row-for-me.md"
( cd "${WORK}/unindexed" && git add -A >/dev/null )
expect "a spec with no index row is rejected" \
  1 "specs/backend/0038-no-row-for-me.md has no row" "${WORK}/unindexed"

fixture "${WORK}/orphan-row"
echo '| [backend/0039-never-written.md](backend/0039-never-written.md) | Draft | — |' \
  >>"${WORK}/orphan-row/specs/README.md"
expect "an index row over a file that does not exist is rejected" \
  1 "which is not a tracked spec" "${WORK}/orphan-row"

fixture "${WORK}/twice-indexed"
add_spec "${WORK}/twice-indexed" backend 0038-listed-twice
echo '| [backend/0038-listed-twice.md](backend/0038-listed-twice.md) | Draft | — |' \
  >>"${WORK}/twice-indexed/specs/README.md"
expect "a spec listed twice in the index is rejected" \
  1 "one spec, one row" "${WORK}/twice-indexed"

# 4. Anti-vacuity, the failure mode `repo.spelling` shipped with: every rule
#    above is universally quantified over the files the walk found, so an empty
#    walk satisfies all of them. The check must refuse to report success on a
#    corpus it cannot believe.
fixture "${WORK}/tiny"
rm -f "${WORK}/tiny"/specs/backend/00[12]*.md
( cd "${WORK}/tiny" && git add -A >/dev/null )
expect "an implausibly small corpus fails instead of passing vacuously" \
  1 "the list is wrong, not the repository" "${WORK}/tiny"

# 4b. And an area that has quietly emptied. `scripts/check_shell.sh` learned
#     this the hard way: `git mv`-ing a named file out from under an assertion
#     left the check green, reporting the same count it reports when the file is
#     there.
fixture "${WORK}/no-area"
rm -f "${WORK}/no-area"/specs/client/*.md
( cd "${WORK}/no-area" && git add -A >/dev/null )
expect "an area that has emptied is rejected, not silently skipped" \
  1 "nothing under specs/client/ reached this check" "${WORK}/no-area"

# 4c. A missing index is a failure, not an empty row list.
fixture "${WORK}/no-index"
rm -f "${WORK}/no-index/specs/README.md"
expect "a missing index is rejected" \
  1 "the index is half of this check" "${WORK}/no-index"

# 5. The real repository. This is the line that makes the check a gate rather
#    than a fixture exercise, and it is last because on its own it proves
#    nothing about rejection.
expect "this repository passes" \
  0 "each numbered once and indexed once" "$ROOT"

# 6. Anti-vacuity for the suite itself, the idiom test_check_manual_run.sh uses:
#    assert the assertions ran.
if [ "$PASSED" -lt 13 ]; then
  fail "the suite ran ${PASSED} assertion(s) — fewer than it contains"
fi

echo
echo "  ${PASSED} passed, ${FAILED} failed"
if [ "$FAILED" -gt 0 ]; then
  echo "  fix: ${FIX}" >&2
  exit 1
fi
