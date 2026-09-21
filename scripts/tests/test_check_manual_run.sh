#!/usr/bin/env bash
#
# Proves scripts/check_manual_run.sh REJECTS, which is the only interesting
# thing about a check (GGU-93 AC-4).
#
# The defect both GGU-93 and GGU-94 describe is evidence that cannot be
# distinguished from real evidence. A reviewer instruction that has never been
# shown to bite reproduces that defect one level up: "the reviewer checks the
# manual run" reads exactly the same whether the reviewer does or not. So the
# check is a script, and the script has a suite, and the suite asserts the
# failures rather than the success.
#
# No commits are created. The "not an ancestor" case is produced by passing an
# EARLIER commit as the head ref — HEAD is not an ancestor of HEAD~2 — so this
# suite writes nothing into the object database and can be run from any
# checkout deep enough to have a few commits.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../.." && pwd)"
cd "$ROOT"

CHECK="scripts/check_manual_run.sh"
# Identical to the `repo.manual-run` entry in .claude/ship-gate.json, the
# pre-commit hook and the repo-ci step (ci-conventions §5 — copied, never
# paraphrased).
FIX="bash scripts/tests/test_check_manual_run.sh"

PASSED=0
FAILED=0

pass() { echo "  PASS  $1"; PASSED=$(( PASSED + 1 )); }
fail() { echo "  FAIL  $1"; FAILED=$(( FAILED + 1 )); }

# An explicit template, not a bare `mktemp -d`: macOS's mktemp ignores TMPDIR
# when given no template and uses the confstr temp directory instead, which is
# outside the agent sandbox's write set. Same command, two behaviours, one of
# them red only on a laptop.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/manual-run.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

# This suite needs real history — `HEAD~2` is both the "stale build" fixture
# and, used as a head ref, the "foreign build" one. A shallow checkout has
# neither, so repo-ci gives this job `fetch-depth: 0`. Say so rather than
# failing three commits deep into someone else's pull request.
if ! git rev-parse --verify --quiet 'HEAD~2^{commit}' >/dev/null; then
  echo "  SKIPPED-AS-FAILURE  this suite needs at least 3 commits of history" >&2
  echo "  a shallow checkout has none; use fetch-depth: 0" >&2
  exit 1
fi

head_sha="$(git rev-parse --short HEAD)"
old_sha="$(git rev-parse --short HEAD~2)"

# Writes a PR body carrying a manual run whose /health reports $1.
body_with() {
  local release="$1" path="$2"
  cat >"$path" <<EOF
## Manual run

\$ curl -s localhost:8000/health
{"status":"ok","version":"0.1.0+${release}"}
\$ curl -s -H "Authorization: Bearer \$TOKEN" localhost:8000/v1/views | jq '.views | length'
6
EOF
}

# Runs the check and reports whether it exited as expected and said the right
# thing. "Exited non-zero" is not enough: a red gate is not evidence that it is
# red for your reason (ci-conventions §5).
expect() {
  local label="$1" want_status="$2" want_text="$3" body="$4" head="$5"
  local out status
  set +e
  out=$(bash "$CHECK" "$body" "$head" 2>&1)
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

# 1. The only shape that passes: the build that answered IS the head.
body_with "$head_sha" "${WORK}/head.md"
expect "a run served by the head is accepted" \
  0 "the run exercised this branch" "${WORK}/head.md" "HEAD"

# 2. The incident itself. An ancestor is NOT good enough: the branch in PR #69
#    was cut from the stale commit, so a literal ancestry test would have
#    passed it. This is the case that check exists for.
body_with "$old_sha" "${WORK}/behind.md"
expect "a run served by an ancestor is rejected" \
  1 "commit(s) behind the head" "${WORK}/behind.md" "HEAD"
expect "the rejection names the stale build" \
  1 "$old_sha" "${WORK}/behind.md" "HEAD"

# 3. A build from outside this line of history. HEAD is not an ancestor of
#    HEAD~2, so passing HEAD~2 as the head ref produces the foreign case
#    without writing a commit.
body_with "$head_sha" "${WORK}/foreign.md"
expect "a run served by a commit outside the branch is rejected" \
  1 "which is NOT in this branch" "${WORK}/foreign.md" "HEAD~2"
expect "the rejection names the foreign sha" \
  1 "$head_sha" "${WORK}/foreign.md" "HEAD~2"

# 4. A commit nobody has ever seen.
body_with "0123456789abcdef0123456789abcdef01234567" "${WORK}/unknown.md"
expect "a run naming an unknown commit is rejected" \
  1 "not a commit in this repository" "${WORK}/unknown.md" "HEAD"

# 5. The status quo ante: a transcript with real commands, real responses and
#    no build identity at all. This is what every PR body in this repository
#    looked like before GGU-93.
cat >"${WORK}/silent.md" <<'EOF'
## Manual run

$ curl -s -H "Authorization: Bearer $TOKEN" localhost:8000/v1/views | jq '.views[0] | keys'
[ "actions", "endpoints", "example", "id", "options_schema", "summary" ]
EOF
expect "a run that names no build is rejected" \
  1 "names no build identity" "${WORK}/silent.md" "HEAD"

# 6. Anti-vacuity. Every assertion above would also hold of a script that
#    always exits 1, except the first — so the first is the one that matters,
#    and this asserts the suite actually ran it.
if [ "$PASSED" -lt 7 ]; then
  fail "the suite ran ${PASSED} assertion(s) — fewer than it contains"
fi

echo
echo "  ${PASSED} passed, ${FAILED} failed"
if [ "$FAILED" -gt 0 ]; then
  echo "  fix: ${FIX}" >&2
  exit 1
fi
