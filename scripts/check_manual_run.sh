#!/usr/bin/env bash
#
# repo.manual-run — the manual run in a PR body names the build that served it,
# and that build is this branch's head.
#
#     bash scripts/check_manual_run.sh <pr-body-file> [<head-ref>]
#
# GGU-93. `.claude/rules/backend/sdd.md` requires every pull request to carry
# "a manual run against the running stack with the real commands and their real
# responses pasted in". On 2026-09-21 one was performed, pasted, and entirely
# false: the container had been built from a working tree six commits behind
# `develop`, and the two "defects" it reported had been fixed in #61 and #66.
#
# Nothing about the transcript looked wrong. Correct commands, real HTTP
# responses, real JSON, real status codes. **There was no field in it, and none
# required by the rule, that said which build answered** — so the one form of
# evidence the process treats as unfalsifiable, a human watched it work, was
# silently parameterised by a variable nobody recorded.
#
# The identity itself already existed and nobody read it. `GET /health` returns
# `{"status":"ok","version":"<version>+<short sha>"}` (spec backend/0007 AC-5,
# `APP_RELEASE` → `Settings.app_release` → `core/release.py`). Measured on the
# deployed dev service the same morning:
#
#     $ curl -s https://<dev>/health
#     {"status":"ok","version":"0.1.0+9a94346"}
#     $ git rev-list --count 9a94346..develop
#     26
#
# Twenty-six commits behind, on the environment the Flutter client was being
# built against — the thesis demonstrated on live infrastructure rather than on
# a laptop.
#
# ---------------------------------------------------------------------------
# Why this fails a run that is merely BEHIND, not only one that is FOREIGN
# ---------------------------------------------------------------------------
# GGU-93 AC-3 asks that the sha be "an ancestor of the PR's head". Implemented
# literally, that check would have PASSED the pull request that produced the
# ticket: the branch was cut from a3e6f93, so a3e6f93 was a perfectly good
# ancestor of its head. Ancestry proves the build is from this line of history;
# it does not prove the build contains the change under review, which is the
# property the evidence is claiming.
#
# So the question is not "is every identity in this body the head" but "is ANY
# of them":
#
#   some identity == head   PASS   — the build that answered is the code under
#                                    review. Every other identity is printed as
#                                    context and none of them can fail the run.
#   none == head            FAIL   — each one diagnosed: an ancestor (it ran,
#                                    and it did not exercise this branch), a
#                                    commit from elsewhere, or one nobody has.
#   no identity at all      EXIT 3 — a different finding; see below.
#
# A run against a long-lived deployed environment is legitimately behind, and
# `sdd.md` says to paste it "as well, never instead". The first version of this
# script looped over every identity and failed the body for the context one, so
# it punished exactly what the rule requires. Caught in review; the suite now
# has a case for it.

set -Eeuo pipefail

FIX="bash scripts/check_manual_run.sh <pr-body-file>"

if [ "$#" -lt 1 ]; then
  echo "usage: ${FIX} [<head-ref>]" >&2
  exit 2
fi

# Resolve the body BEFORE the cd, or a relative path given from the repository
# root — the obvious way to call this — resolves against scripts/ and fails
# with a confusing "not a readable file".
body="$1"
case "$body" in
  /*) ;;
  *) body="${PWD}/${body}" ;;
esac
head_ref="${2:-HEAD}"

cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [ ! -f "$body" ]; then
  echo "repo.manual-run: ${body} is not a readable file" >&2
  exit 2
fi

if ! head_sha=$(git rev-parse --verify --quiet "${head_ref}^{commit}"); then
  echo "repo.manual-run: ${head_ref} is not a commit in this repository" >&2
  exit 2
fi

template() {
  cat >&2 <<'EOF'

  The manual run must OPEN with the build identity, fetched live:

      $ git rev-parse --short HEAD
      c6dd5b2
      $ APP_RELEASE="local+$(git rev-parse --short HEAD)" docker compose up --build -d
      $ curl -s localhost:8000/health
      {"status":"ok","version":"local+c6dd5b2"}

  The `local+` prefix is not decoration: `core/release.py` reports APP_RELEASE
  VERBATIM, so a bare sha produces `"version":"c6dd5b2"` with no `+` and this
  check reads no identity at all. Deployed revisions carry `<version>+<sha>`,
  composed by infra/scripts/deploy_cloud_run.sh; only the part after the `+`
  is read here.

  Then the commands the change is actually about. The identity is not decoration:
  it is the only thing in the transcript that says which build answered.
  See .claude/rules/backend/sdd.md, "The manual run".
EOF
}

# Scoped to the `"version"` field of a /health payload, NOT to any `+<hex>` in
# the body. A PR body is full of hex-shaped things — ETags, image digests,
# semver build metadata like `v1.2.3+abc1234` — and the first form of this check
# rejected a perfectly good body because it found one. A check that matches the
# wrong token is worse than one that matches nothing (the lesson `repo.spelling`
# left in .claude/rules/ci-conventions.md §5).
shas=$(
  grep -oE '"version"[[:space:]]*:[[:space:]]*"[^"]*\+[0-9a-f]{7,40}"' "$body" \
    | grep -oE '\+[0-9a-f]{7,40}"$' \
    | tr -d '+"' \
    | sort -u || true
)

# Exit 3, distinct from 1: "this body names no build" is a different finding
# from "this body names the wrong build", and a caller needs to tell them apart.
# `sdd.md` allows a PR to declare a manual run was NOT possible, with the reason
# and the consequence — that is a judgement for a reviewer, not for a grep — so
# repo-ci treats 3 as a note and 1 as a failure.
if [ -z "$shas" ]; then
  echo "repo.manual-run: the manual run names no build identity" >&2
  echo "  searched: ${body}" >&2
  echo "  expected: \"version\":\"<version>+<short sha>\" from GET /health," >&2
  echo "            e.g. {\"status\":\"ok\",\"version\":\"local+c6dd5b2\"}" >&2
  template
  exit 3
fi

# One identity must BE the head. The others are context, which is what the rule
# asks for in so many words: a run against a long-lived deployed environment is
# legitimately behind, and `sdd.md` says to paste it "as well, never instead".
# The first version of this loop failed such a body, so the check contradicted
# the rule it enforces — it insisted on exactly what the rule forbids omitting
# and then punished including it.
context=()
head_found=0
checked=0

while IFS= read -r sha; do
  [ -n "$sha" ] || continue
  checked=$(( checked + 1 ))

  if ! full=$(git rev-parse --verify --quiet "${sha}^{commit}"); then
    context+=("${sha} — not a commit in this repository")
    continue
  fi

  if [ "$full" = "$head_sha" ]; then
    head_found=1
    continue
  fi

  if ! git merge-base --is-ancestor "$full" "$head_sha"; then
    context+=("${sha} — not in this branch at all (${full})")
    continue
  fi

  behind=$(git rev-list --count "${full}..${head_sha}")
  context+=("${sha} — an ancestor, ${behind} commit(s) behind the head")
done <<<"$shas"

# A check that silently examines nothing is the failure mode this repository
# has now hit three times (ci-conventions §5). The loop above cannot run zero
# times given the emptiness guard, so this asserts the guarantee rather than
# hoping for it.
if [ "$checked" -eq 0 ]; then
  echo "repo.manual-run: parsed ${body} and examined no build identity — the parse lost rows" >&2
  exit 1
fi

if [ "$head_found" -eq 1 ]; then
  echo "repo.manual-run: a manual run names ${head_sha}, the head of ${head_ref} — it exercised this branch"
  for line in ${context[@]+"${context[@]}"}; do
    echo "  also mentioned (context, not evidence): ${line}"
  done
  echo "repo.manual-run: ${checked} build identit(ies) checked against ${head_ref}"
  exit 0
fi

echo "repo.manual-run: no manual run in this body was served by the head of ${head_ref}" >&2
echo "  head: ${head_sha} (${head_ref})" >&2
for line in ${context[@]+"${context[@]}"}; do
  echo "  found: ${line}" >&2
done
echo "  An ancestor is this line of history but does not contain the change" >&2
echo "  under review, so it says nothing about the diff. A commit from another" >&2
echo "  branch says nothing about this one. Rebuild at the head and re-run." >&2
echo "  A deployed environment that is behind is context, not evidence: paste" >&2
echo "  it as well, never instead." >&2
exit 1
