#!/usr/bin/env bash
#
# repo.spec-numbers — every spec has a well-formed number, a unique one, and a row.
#
# `specs/README.md` says: "Numbers are per area, zero-padded, never reused" and
# "One row per file, ordered by area then number — so a missing spec and a
# duplicated one are both visible at a glance." Both halves of that sentence
# were false when this check was written, which is the whole argument for it
# (GGU-105):
#
#   specs/frontend/0002-a2ui-agent-path.md
#   specs/frontend/0002-chart-primitives-and-waterfall.md
#
# Two specs, one number, on `develop` — and nine spec files with no row in the
# index at all, including both of those. So neither the duplicate nor the
# missing spec was visible at a glance; the sentence that promised it was doing
# the work of a check. Then GGU-57 and GGU-59 both wrote `specs/frontend/0003-*`
# in parallel branches and GGU-59 renumbered after the fact, at a cost of a
# rename plus twenty-one citations.
#
# The cause is structural rather than careless: `.claude/rules/backend/sdd.md`
# says `NNNN` is "the next free number", and *free* is evaluated against the
# branch point. Two branches cut from the same commit always pick the same
# number and nothing notices until a human reads a directory listing. A number
# cannot be allocated without a shared authority, so this check does not try to
# allocate one — it makes the collision fail the build instead of surviving the
# merge.
#
# THREE rules, and the reason each is here rather than left to a reader:
#
#   1. Shape.  `NNNN-lowercase-kebab-slug.md`. A five-digit or unpadded number
#      sorts wrong and breaks the prefix comparison rule 2 depends on.
#   2. Uniqueness, per area. The defect above. The failure names BOTH files,
#      because "0002 is duplicated" sends the reader to a directory listing.
#   3. The index. Every tracked spec has exactly one row in `specs/README.md`,
#      and every row resolves to a tracked file. This is the half that makes
#      rule 2 hard to reintroduce: a spec that reaches the index has been
#      compared with every other number by whoever added the row.
#
# What this check deliberately does NOT assert, with the reason (this is §5's
# second question — does the command cover what its name claims):
#
#   * "Never reused" is not machine-checked. In git history a renumbering is a
#     delete plus an add, which is byte-for-byte what a reuse looks like; the
#     check would have failed on GGU-59's own legitimate rename. What protects
#     the property instead is rule 3 plus the README's rule that a superseded
#     spec keeps its file and its row — a number in use stays visible.
#   * Ordering is not asserted. The README used to claim the index was "ordered
#     by area then number" and it was not; the claim has been removed rather
#     than enforced, because an unenforced claim is this ticket's own subject
#     and reordering seventy rows is not what makes a collision fail.
#   * Contiguity is not asserted. A gap is not a defect — `docs/diagrams/`
#     keeps `11` free on purpose — and a check that demanded contiguity would
#     forbid the renumbering that resolves a collision.
#
# An optional first argument is the directory to treat as the repository root.
# It exists for `scripts/tests/test_check_spec_numbers.sh`, which builds fixture
# trees; the default is this script's own parent and nothing in the repository
# passes it.

set -Eeuo pipefail

ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT"

INDEX="specs/README.md"
# The smallest plausible corpus. A check that silently matches nothing is worse
# than no check — `repo.spelling` shipped in exactly that shape — so this one
# refuses to report success on a file list it cannot believe.
MIN_SPECS=40

failed=0

note() { echo "repo.spec-numbers: $1" >&2; }

if [ ! -f "$INDEX" ]; then
  note "${INDEX} is missing — the index is half of this check"
  exit 1
fi

# Tracked files only, and only the numbered ones: README.md, TEMPLATE.md and any
# asset directory are prose about specs rather than specs.
specs=$(git ls-files -- 'specs/*/[0-9]*.md' | sed 's|^specs/||' | sort)
count=$(printf '%s\n' "$specs" | grep -c . || true)

if [ "${count:-0}" -lt "$MIN_SPECS" ]; then
  note "only ${count} spec file(s) found — the list is wrong, not the repository"
  note "  expected at least ${MIN_SPECS}; check the git ls-files pathspec above"
  exit 1
fi

# The areas this repository actually keeps specs in, asserted by name for the
# reason `scripts/check_shell.sh` asserts its two entry points: "the walk ran
# and was happy" is the same sentence whether it opened them or not. A name that
# stops resolving is a failure, and the fix is to edit this list in the pull
# request that moves the directory.
for area in backend frontend infra repo client; do
  if ! grep -q "^${area}/" <<<"$specs"; then
    note "nothing under specs/${area}/ reached this check"
    note "  if that area moved or closed, update the list in this script"
    failed=$((failed + 1))
  fi
done

# ---------------------------------------------------------------- 1. shape
while IFS= read -r spec; do
  [ -n "$spec" ] || continue
  base="${spec#*/}"
  if ! grep -Eq '^[0-9]{4}-[a-z0-9]+(-[a-z0-9]+)*\.md$' <<<"$base"; then
    note "specs/${spec} is not NNNN-lowercase-kebab-slug.md"
    failed=$((failed + 1))
  fi
done <<<"$specs"

# ----------------------------------------------------- 2. uniqueness per area
# `<area>/<NNNN>` for every spec, then the numbers that appear twice. The
# failure names both files rather than the number, because a number sends the
# reader back to a directory listing — which is what nobody did for `0002`.
duplicates=$(sed -E 's|^([a-z]+)/([0-9]{4})-.*|\1/\2|' <<<"$specs" | sort | uniq -d || true)
while IFS= read -r dup; do
  [ -n "$dup" ] || continue
  area="${dup%/*}"
  number="${dup#*/}"
  note "two specs share specs/${area}/${number}:"
  grep "^${area}/${number}-" <<<"$specs" | sed 's|^|    specs/|' >&2
  note "  renumber one of them to a free number in that area, follow every"
  note "  citation, and move its index row with it."
  failed=$((failed + 1))
done <<<"$duplicates"

# ------------------------------------------------------------------ 3. index
# Only table rows: a line that opens `| [` and carries a link. Prose elsewhere
# in the README links to specs too, and counting those would let a spec be
# "indexed" by a sentence about it.
#
# `/` as the sed delimiter, not `|`. With `|` the expression still parses and
# still matches nothing, because the `\|` inside it is then a delimiter escape
# rather than a literal pipe — so every row came through unsubstituted and the
# check reported seventy-two rows "over a file that does not exist". A
# substitution that silently does nothing is the vacuity failure one line down.
rows=$(grep -E '^\| \[' "$INDEX" | sed -E 's/^\| \[[^]]*\]\(([^)]+)\).*/\1/' | sort)
row_count=$(printf '%s\n' "$rows" | grep -c . || true)

if [ "${row_count:-0}" -lt "$MIN_SPECS" ]; then
  note "the index table has only ${row_count} row(s) — the parse lost rows"
  note "  a row is a line opening '| [' with a link to <area>/NNNN-….md"
  exit 1
fi

while IFS= read -r spec; do
  [ -n "$spec" ] || continue
  # -F: a spec path is data, not a pattern. Without it the `[` in an index row
  # made grep report "invalid character range" and the comparison never ran.
  hits=$(grep -Fcx -- "$spec" <<<"$rows" || true)
  if [ "$hits" -eq 0 ]; then
    note "specs/${spec} has no row in ${INDEX}"
    note "  the index is what makes a number visible before it collides"
    failed=$((failed + 1))
  elif [ "$hits" -gt 1 ]; then
    note "specs/${spec} has ${hits} rows in ${INDEX} — one spec, one row"
    failed=$((failed + 1))
  fi
done <<<"$specs"

while IFS= read -r row; do
  [ -n "$row" ] || continue
  if ! grep -Fqx -- "$row" <<<"$specs"; then
    note "${INDEX} has a row for specs/${row}, which is not a tracked spec"
    note "  a row over a file that does not exist passes for the wrong reason"
    failed=$((failed + 1))
  fi
done <<<"$(sort -u <<<"$rows")"

if [ "$failed" -gt 0 ]; then
  note "${failed} problem(s) found"
  note "fix: bash scripts/check_spec_numbers.sh"
  exit 1
fi

echo "repo.spec-numbers: ${count} spec(s) in 5 area(s), each numbered once and indexed once"
