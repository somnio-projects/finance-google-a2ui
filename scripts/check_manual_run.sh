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
# So the verdicts are three, not two:
#
#   sha == head        PASS   — the build that answered is the code being reviewed
#   sha is an ancestor FAIL   — it ran, and it did not exercise this branch
#   anything else      FAIL   — the build is not in this branch at all
#
# A run against a long-lived deployed environment is legitimately behind. That
# is not an exception to this check: paste it as context AND paste a run
# against the branch, because only the second is evidence about the diff.

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

FIX="bash scripts/check_manual_run.sh <pr-body-file>"

if [ "$#" -lt 1 ]; then
  echo "usage: ${FIX} [<head-ref>]" >&2
  exit 2
fi

body="$1"
head_ref="${2:-HEAD}"

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
      $ APP_RELEASE="$(git rev-parse --short HEAD)" docker compose up --build -d
      $ curl -s localhost:8000/health
      {"status":"ok","version":"0.1.0+c6dd5b2"}

  Then the commands the change is actually about. The identity is not decoration:
  it is the only thing in the transcript that says which build answered.
  See .claude/rules/backend/sdd.md, "The manual run".
EOF
}

# The identity is `<version>+<short sha>`, so the sha is what follows a `+`.
# Anchored on the `+` rather than on bare hex, because a PR body is full of
# hex-shaped things — ETags, digests, tokens — and a check that matches the
# wrong token is worse than one that matches nothing (the lesson `repo.spelling`
# left in .claude/rules/ci-conventions.md §5).
shas=$(grep -oE '\+[0-9a-f]{7,40}' "$body" | cut -c2- | sort -u || true)

if [ -z "$shas" ]; then
  echo "repo.manual-run: the manual run names no build identity" >&2
  echo "  searched: ${body}" >&2
  echo "  expected: a <version>+<short sha> from GET /health, e.g. 0.1.0+c6dd5b2" >&2
  template
  exit 1
fi

failed=0
checked=0

while IFS= read -r sha; do
  [ -n "$sha" ] || continue
  checked=$(( checked + 1 ))

  if ! full=$(git rev-parse --verify --quiet "${sha}^{commit}"); then
    echo "repo.manual-run: the manual run names ${sha}, which is not a commit in this repository" >&2
    echo "  head: ${head_sha}" >&2
    failed=$(( failed + 1 ))
    continue
  fi

  if [ "$full" = "$head_sha" ]; then
    echo "repo.manual-run: ${sha} is the head of ${head_ref} — the run exercised this branch"
    continue
  fi

  if ! git merge-base --is-ancestor "$full" "$head_sha"; then
    echo "repo.manual-run: the manual run was served by ${sha}, which is NOT in this branch" >&2
    echo "  build: ${full}" >&2
    echo "  head:  ${head_sha} (${head_ref})" >&2
    echo "  A transcript from another branch is not evidence about this one." >&2
    failed=$(( failed + 1 ))
    continue
  fi

  behind=$(git rev-list --count "${full}..${head_sha}")
  echo "repo.manual-run: the manual run was served by ${sha}, ${behind} commit(s) behind the head" >&2
  echo "  build: ${full}" >&2
  echo "  head:  ${head_sha} (${head_ref})" >&2
  echo "  It is an ancestor, so it is this line of history — but it does not" >&2
  echo "  contain the change under review, so it says nothing about the diff." >&2
  echo "  Rebuild at the head and re-run. A deployed environment that is behind" >&2
  echo "  is context, not evidence: paste it as well, never instead." >&2
  failed=$(( failed + 1 ))
done <<<"$shas"

# A check that silently examines nothing is the failure mode this repository
# has now hit three times (ci-conventions §5). The loop above cannot run zero
# times given the emptiness guard, so this asserts the guarantee rather than
# hoping for it.
if [ "$checked" -eq 0 ]; then
  echo "repo.manual-run: parsed ${body} and examined no build identity — the parse lost rows" >&2
  exit 1
fi

if [ "$failed" -gt 0 ]; then
  echo "repo.manual-run: ${failed} of ${checked} build identit(ies) do not name this branch's head" >&2
  exit 1
fi

echo "repo.manual-run: ${checked} build identit(ies) checked against ${head_ref}"
