#!/usr/bin/env bash
# Guards that the rules index in CLAUDE.md matches the rules on disk (GGU-86).
#
# The index table lives INSIDE the block `/harness-init` regenerates, and
# `/harness-init` is not in this repository — it is the Somnio CLI recorded in
# .claude/harness.json. So the table is rewritten by a tool we cannot read, and
# the failure mode is silent in both directions:
#
#   1. A rule file with NO ROW never loads. Every property that rule carries
#      stops applying and nothing goes red — the harness is disabled rather
#      than broken, which is why no existing check catches it.
#
#   2. A ROW WITH NO FILE points at nothing. Harmless today, but it is the
#      evidence that the table and the directory have drifted apart, and it is
#      free to catch while we are looking.
#
# This is the seam between a Markdown table and a directory listing: `make
# gate` cannot see CLAUDE.md and no Markdown tool reads .claude/rules/, so the
# assertion lives here, beside test_dev_environment.sh, which guards the other
# cross-stack seams the same way.
#
# The table is located by its HEADER rather than by grepping the file for
# `.claude/rules/`: that string also appears in prose and in the folder table
# at the top of CLAUDE.md, and a check that quietly matches the wrong thing —
# or nothing at all — is worse than no check. Hence the explicit guards below:
# an unreadable table is a FAILURE, never an empty set that trivially agrees.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA="$(cd "${HERE}/../.." && pwd)"
ROOT="$(cd "${INFRA}/.." && pwd)"

INDEX="CLAUDE.md"
RULES_DIR=".claude/rules"
# The command that fixes a red run. Identical to the `infra.rules-index` entry
# in .claude/ship-gate.json, the pre-commit hook and the infra-ci step
# (.claude/rules/ci-conventions.md §5 — copied, never paraphrased).
FIX="bash infra/scripts/tests/test_rules_index.sh"

PASSED=0
FAILED=0

fail() {
  echo "  FAIL  $1"
  FAILED=$(( FAILED + 1 ))
}

pass() {
  echo "  PASS  $1"
  PASSED=$(( PASSED + 1 ))
}

# Reads the first column of the rules index table out of CLAUDE.md.
#
# Finds the table by its header cells (path | stack | loads when), skips the
# alignment row, then emits the first cell of every row until the table ends.
# Cells are trimmed of whitespace and backticks, so a row written `| `x.md` |`
# is read exactly like `| x.md |`.
index_paths() {
  awk '
    function norm(s) {
      gsub(/^[ \t`]+/, "", s)
      gsub(/[ \t`]+$/, "", s)
      return s
    }
    {
      line = $0
      sub(/^[ \t]+/, "", line)
      # A non-row line ends the table (but is skipped while still looking).
      if (line !~ /^\|/) { if (intable) exit; next }
      n = split(line, cell, /\|/)
      if (n < 4) { if (intable) exit; next }
      first = norm(cell[2]); second = norm(cell[3]); third = norm(cell[4])
      if (!intable) {
        if (tolower(first) == "path" && tolower(second) == "stack" &&
            tolower(third) == "loads when") intable = 1
        next
      }
      if (first ~ /^:?-+:?$/) next        # the |:--|:--|:--| alignment row
      if (first == "") first = "(empty path cell)"
      print first
    }
  ' "${ROOT}/${INDEX}"
}

DECLARED="$(index_paths | sort -u)"
ACTUAL="$(cd "${ROOT}" && find "${RULES_DIR}" -type f -name '*.md' | sort -u)"

echo "the rules index in ${INDEX} is readable"

# Guard 1: the table must be found. If /harness-init ever renames the columns
# this goes red and someone updates the parser — the loud failure is the point.
if [[ -z "${DECLARED}" ]]; then
  fail "no rules index table found in ${INDEX}"
  echo "        looked for a table with the header: | path | stack | loads when |" >&2
  echo "        the check cannot run until it parses; fix the table or this script:" >&2
  echo "          ${FIX}" >&2
else
  pass "$(wc -l <<< "${DECLARED}" | tr -d ' ') row(s) parsed from the index table"
fi

# Guard 2: the directory must be non-empty, for the same reason.
if [[ -z "${ACTUAL}" ]]; then
  fail "no rule files found under ${RULES_DIR}"
  echo "        expected at least one *.md; the comparison below would be vacuous" >&2
else
  pass "$(wc -l <<< "${ACTUAL}" | tr -d ' ') rule file(s) found under ${RULES_DIR}"
fi

if [[ -n "${DECLARED}" && -n "${ACTUAL}" ]]; then
  echo
  echo "every rule file has a row, and every row has a rule file"

  # On disk but not in the table: the rule will not load (the silent failure).
  UNLISTED="$(comm -23 <(printf '%s\n' "${ACTUAL}") <(printf '%s\n' "${DECLARED}"))"
  if [[ -n "${UNLISTED}" ]]; then
    fail "$(wc -l <<< "${UNLISTED}" | tr -d ' ') rule file(s) have no row in ${INDEX} — they will not load:"
    awk '{ print "          " $0 }' <<< "${UNLISTED}" >&2
    echo "        add a row to the '## Rules' table in ${INDEX} for each, then re-run:" >&2
    echo "          ${FIX}" >&2
  else
    pass "every rule file under ${RULES_DIR} has a row"
  fi

  # In the table but not on disk: the row points at nothing.
  STALE="$(comm -13 <(printf '%s\n' "${ACTUAL}") <(printf '%s\n' "${DECLARED}"))"
  if [[ -n "${STALE}" ]]; then
    fail "$(wc -l <<< "${STALE}" | tr -d ' ') row(s) in ${INDEX} point at a file that does not exist:"
    awk '{ print "          " $0 }' <<< "${STALE}" >&2
    echo "        remove the row from ${INDEX} (or restore the file), then re-run:" >&2
    echo "          ${FIX}" >&2
  else
    pass "every row in the index table points at a rule file that exists"
  fi
fi

echo
echo "${PASSED} passed, ${FAILED} failed"
[[ "${FAILED}" -eq 0 ]]
