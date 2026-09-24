#!/usr/bin/env bash
#
# Proves scripts/check_manual_run.sh REJECTS, which is the only interesting
# thing about a check. GGU-93: "give it a manual run with a sha from another
# branch and confirm it is rejected, naming the sha."
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
{"status":"ok","version":"local+${release}"}
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
  0 "it exercised this branch" "${WORK}/head.md" "HEAD"

# 1b. The rule says a deployed run that is behind is pasted "as well, never
#     instead". A body carrying BOTH must therefore pass. The first version of
#     this check looped over every identity and failed on the context one, so
#     it punished exactly what the rule requires — caught in review, and this
#     is the case that keeps it fixed.
{
  cat "${WORK}/head.md"
  echo
  echo "For context, the deployed dev environment is behind:"
  echo '{"status":"ok","version":"0.1.0+'"${old_sha}"'"}'
} >"${WORK}/head-plus-context.md"
expect "a body naming the head AND an older deployed build is accepted" \
  0 "it exercised this branch" "${WORK}/head-plus-context.md" "HEAD"
expect "the older build is reported as context, not as a failure" \
  0 "context, not evidence" "${WORK}/head-plus-context.md" "HEAD"

# 1c. Hex-shaped things that are not build identities must be ignored. Semver
#     build metadata is the realistic case: an earlier form of this check
#     matched any `+<hex>` anywhere in the body and rejected a good one.
{
  cat "${WORK}/head.md"
  echo
  echo "Bumped the widget library to v1.2.3+abc1234 in this PR."
} >"${WORK}/head-plus-semver.md"
expect "semver build metadata elsewhere in the body is not read as a build" \
  0 "it exercised this branch" "${WORK}/head-plus-semver.md" "HEAD"

# 2. The incident itself. An ancestor is NOT good enough: the branch in PR #69
#    was cut from the stale commit, so a literal ancestry test would have
#    passed it. This is the case that check exists for.
body_with "$old_sha" "${WORK}/behind.md"
expect "a run served only by an ancestor is rejected" \
  1 "commit(s) behind the head" "${WORK}/behind.md" "HEAD"
expect "the rejection names the stale build" \
  1 "$old_sha" "${WORK}/behind.md" "HEAD"

# 3. A build from outside this line of history. HEAD is not an ancestor of
#    HEAD~2, so passing HEAD~2 as the head ref produces the foreign case
#    without writing a commit.
body_with "$head_sha" "${WORK}/foreign.md"
expect "a run served by a commit outside the branch is rejected" \
  1 "not in this branch at all" "${WORK}/foreign.md" "HEAD~2"
expect "the rejection names the foreign sha" \
  1 "$head_sha" "${WORK}/foreign.md" "HEAD~2"

# 4. A commit nobody has ever seen.
body_with "0123456789abcdef0123456789abcdef01234567" "${WORK}/unknown.md"
expect "a run naming an unknown commit is rejected" \
  1 "not a commit in this repository" "${WORK}/unknown.md" "HEAD"

# 5. The status quo ante: a transcript with real commands, real responses and
#    no build identity at all. This is what every PR body in this repository
#    looked like before GGU-93. Exit 3, not 1 — `sdd.md` allows a PR to declare
#    that a manual run was not possible, with the reason and the consequence,
#    and that judgement belongs to a reviewer rather than to a grep. repo-ci
#    reports 3 and fails on 1.
cat >"${WORK}/silent.md" <<'EOF'
## Manual run

$ curl -s -H "Authorization: Bearer $TOKEN" localhost:8000/v1/views | jq '.views[0] | keys'
[ "actions", "endpoints", "example", "id", "options_schema", "summary" ]
EOF
expect "a run that names no build exits 3, distinct from a wrong build" \
  3 "names no build identity" "${WORK}/silent.md" "HEAD"

# 5b. The trap the documented bring-up used to fall into: `core/release.py`
#     reports APP_RELEASE verbatim, so `APP_RELEASE="$(git rev-parse --short
#     HEAD)"` yields a bare sha with no `+` and no identity is read at all.
#     The docs now say `local+$(…)`; this keeps the failure legible if they
#     ever drift back.
cat >"${WORK}/bare-sha.md" <<EOF
## Manual run

\$ curl -s localhost:8000/health
{"status":"ok","version":"${head_sha}"}
EOF
expect "a bare sha with no version prefix is not read as an identity" \
  3 "names no build identity" "${WORK}/bare-sha.md" "HEAD"

# 6. Anti-vacuity. Every assertion above would also hold of a script that
#    always exits 1, except the first — so the first is the one that matters,
#    and this asserts the suite actually ran it.
if [ "$PASSED" -lt 11 ]; then
  fail "the suite ran ${PASSED} assertion(s) — fewer than it contains"
fi

echo
echo "  ${PASSED} passed, ${FAILED} failed"
if [ "$FAILED" -gt 0 ]; then
  echo "  fix: ${FIX}" >&2
  exit 1
fi
