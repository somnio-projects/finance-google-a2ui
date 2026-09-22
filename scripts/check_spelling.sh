#!/usr/bin/env bash
#
# repo.spelling — codespell over every tracked file, including the dot-directories.
#
# This exists in a script rather than as a bare `codespell` because the bare
# form does not scan what it claims to. codespell's directory walk skips
# entries whose name begins with a dot, so `codespell .` never opens
# `.claude/` or `.github/` — and naming them on the command line does not help,
# because the same walk applies once it descends. The gate that shipped in
# PR #54 therefore advertised a scope it did not have: its own configuration
# comment and `ship-gate.json`'s `_note` both said it closed the gap for
# `.claude/`, while a misspelling of `unparsable` sat in
# `.claude/harness-log.md` and the gate stayed green.
#
# `git ls-files` removes the walk from the question entirely: codespell is
# handed an explicit list and opens exactly the files the repository tracks.
# No hidden-entry rule, no ordering surprise, and an untracked build artefact
# cannot fail the build.
#
# The exclusions are the trees this repository does not own:
#   .claude/skills, .agents, .claude/rules/python, .claude/rules/flutter
#     synced from somnio-ai-tools by the Somnio CLI; CLAUDE.md's "Do not touch"
#     list covers them, and a typo there is fixed upstream, not here.
#   *.lock
#     generated, and a hash is not prose.
#   *.pdf
#     a PDF is compressed binary, not prose. Decoded as latin-1 — which is
#     what codespell falls back to — it yields dozens of "findings" per file
#     out of the compression stream: two-letter fragments of deflated bytes
#     that no word list can be taught. The prose it was made
#     from IS scanned: docs/guides/feeding-charts-and-schema-mutations.pdf is
#     generated from docs/guides/*.md, and those are tracked, opened here and
#     checked. Excluding the derived file loses no coverage of the source.
#
# Word-list exceptions live in .codespellrc so this command stays short enough
# to appear byte-identically in .claude/ship-gate.json, repo-ci.yaml and
# .pre-commit-config.yaml (.claude/rules/ci-conventions.md §5).

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

files=$(
  git ls-files -z -- . \
    ':!:.claude/skills' \
    ':!:.agents' \
    ':!:.claude/rules/python' \
    ':!:.claude/rules/flutter' \
    ':!:*.lock' \
    ':!:*.pdf' |
    tr '\0' '\n'
)

# A check that silently matches nothing is worse than no check. This one has
# been wrong in exactly that way once already, so it refuses to report success
# on an empty or implausibly small file list rather than printing a green line.
count=$(printf '%s\n' "$files" | grep -c . || true)
if [ "${count:-0}" -lt 100 ]; then
  echo "repo.spelling: only ${count} file(s) to scan — the list is wrong, not the repository" >&2
  echo "  expected several hundred tracked files; check the git ls-files pathspecs above" >&2
  exit 1
fi

# The dot-directories are the whole reason this script exists, so assert they
# are actually in the list rather than trusting that they are.
#
# A here-string, NOT `printf ... | grep -q`. That pipeline failed on the runner
# with "printf: write error: Broken pipe", and `pipefail` turned the broken
# pipe into a failed test — so the script reported "nothing under .claude/
# reached codespell" about a list that began with `.claude/`. `grep -q` exits
# at the first match, and `.claude/` sorts first, so it closed the pipe while
# printf still had a thousand paths to write. The larger the repository, the
# more reliably this check failed, and it failed CLOSED, which is why it read
# as a real finding: `develop` was red for it before this branch existed.
# A here-string has no reader to close the pipe early.
for required in ".claude/" ".github/"; do
  if ! grep -q "^${required}" <<<"$files"; then
    echo "repo.spelling: nothing under ${required} reached codespell" >&2
    echo "  that is the gap this check was written to close — see the header" >&2
    exit 1
  fi
done

printf '%s\0' "$files" |
  tr '\n' '\0' |
  xargs -0 uv run --project backend codespell

echo "repo.spelling: ${count} tracked file(s) scanned, including .claude/ and .github/"
