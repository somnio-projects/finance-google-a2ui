#!/usr/bin/env bash
#
# repo.shell-lint — shellcheck over every tracked shell script in the repository.
#
# This replaces `infra.shell-lint`, which named two globs under `infra/scripts/`
# and therefore proved nothing about the shell this repository ships anywhere
# else. Two scripts sat outside it and had never been linted by any gate that
# runs on a pull request:
#
#   client_flutter/docker/entrypoint.sh  validates BACKEND_BASE_URL against an
#     origin regex and substitutes it into the CSP `connect-src` directive — the
#     highest-consequence shell in the repository, and linted by nothing.
#   backend/docker/entrypoint.sh         the API container's entry point.
#
# Both were red the first time this check was pointed at them (SC2016 and
# SC2086, each a deliberate construct that now carries a justified `disable`
# directive at its own line). That is the argument for repository scope in one
# sentence: a per-stack list is a list somebody has to remember to extend, and
# for these two nobody did.
#
# `client_flutter/` was retired on 2026-09-22 (spec `repo/0002`) and its
# entry point went with it. The history above stays because it is the argument
# for this check's scope, and the assertion below now names
# `frontend/docker/entrypoint.sh` — the surviving app's entry point, which does
# the same CSP substitution and is the file the assertion exists to reach. The
# named list moved with the repository rather than quietly emptying: an
# assertion over a file that no longer exists passes for the wrong reason.
#
# The scope is discovered, not enumerated: `git ls-files` for the `*.sh`
# extension, plus any tracked file whose first line is a `sh`/`bash` shebang,
# so an extensionless script cannot slip in unlinted. A hand-maintained file
# list is exactly the drift .claude/rules/ci-conventions.md §5 is about.
#
# No `--severity` flag, deliberately. Lowering severity to make a finding go
# away would give this repository two shellcheck configurations for one check,
# which §5 calls the same drift as two command strings. A false positive is
# annotated at its own line, with a reason, where a reader meets it.

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# `*.sh` by name, plus anything carrying a shell shebang regardless of name.
# Newline-separated rather than an array, matching scripts/check_spelling.sh —
# no path in this repository contains whitespace, and the two scripts stay
# readable side by side.
# No `case` inside this command substitution, deliberately: bash 3.2 — which is
# what macOS still ships as /bin/bash, and what a developer on this team runs —
# fails to parse one there, while the ubuntu-latest bash 5 in CI parses it
# happily. A gate that only runs on the runner is half a gate.
#
# One regex, not four patterns: `sh`, `bash` and `env bash` all end in `sh`, and
# spelling them out separately made two of them unreachable — which this check
# caught when first pointed at itself (SC2221/SC2222).
files=$(
  {
    git ls-files -- '*.sh'
    git ls-files | grep -v '\.sh$' | while IFS= read -r f; do
      [ -f "$f" ] || continue
      if head -n 1 "$f" 2>/dev/null | grep -aEq '^#!.*sh$'; then
        printf '%s\n' "$f"
      fi
    done
  } | sort -u
)

count=$(printf '%s\n' "$files" | grep -c . || true)

# A check that silently matches nothing is worse than no check — the lesson of
# `repo.spelling`, which advertised a scope its directory walk never had. This
# one refuses to report success on an implausible file list.
if [ "${count:-0}" -lt 8 ]; then
  echo "repo.shell-lint: only ${count} script(s) found — the list is wrong, not the repository" >&2
  echo "  expected every tracked *.sh plus every shell shebang; check the pathspecs above" >&2
  exit 1
fi

# The two scripts this check was written to reach, asserted by name: "shellcheck
# ran and was happy" is the same sentence whether it opened them or not.
#
# The list is REQUIRED to exist. This used to open with
# `[ -f "$required" ] || continue`, commented "the tree is allowed to lose a
# file; it is not allowed to skip one" — which sounds right and made the whole
# assertion vacuous the moment a name went stale. Measured on 2026-09-22 while
# retiring `client_flutter/` (spec `repo/0002`): `git mv`-ing an entry point
# out from under the list left this check **green**, reporting the same
# "19 scripts linted" it reports when the file is there. That is the shape
# ci-conventions §5 warns about one level down — the two halves agreed, and the
# check's subject had quietly emptied.
#
# So a name that no longer resolves is a failure, and the fix is to edit this
# list in the pull request that moves the file. That is the whole cost, and it
# is paid by the person who already has both files open.
for required in "frontend/docker/entrypoint.sh" "backend/docker/entrypoint.sh"; do
  if [ ! -f "$required" ]; then
    echo "repo.shell-lint: ${required} is named here but is not in the tree" >&2
    echo "  if it moved or was deleted, update this list in the same commit —" >&2
    echo "  an assertion over a file that does not exist passes for the wrong" >&2
    echo "  reason, which is how this check lost its teeth once already." >&2
    exit 1
  fi
  # A here-string, not `printf ... | grep -qx`. `grep -q` exits at the first
  # match and `pipefail` then reports the SIGPIPE'd printf as a failed test —
  # so the assertion fails on a list that does contain the file. It is latent
  # at this scale (twelve scripts fit in one write) and certain at
  # check_spelling.sh's (a thousand paths), where it was turning `develop` red.
  # Same idiom, same bug; fixed in both rather than only where it bit.
  if ! grep -qx "$required" <<<"$files"; then
    echo "repo.shell-lint: ${required} is tracked but never reached shellcheck" >&2
    echo "  that is the gap this check was written to close — see the header" >&2
    exit 1
  fi
done

# shellcheck disable=SC2086 # deliberate: the list is newline-separated and must
# split into one argument per script. No path in this repository has whitespace,
# and the count assertion above fails long before an empty expansion could.
shellcheck $files

echo "repo.shell-lint: ${count} tracked shell script(s) linted"
