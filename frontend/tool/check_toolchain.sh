#!/usr/bin/env bash
#
# frontend.toolchain — the gate refuses to run under an unstated toolchain.
#
# GGU-94. `cd frontend && make gate` used to open with `dart format`, so a
# machine carrying the WRONG Dart failed at a formatting diff:
#
#     Formatted 138 files (3 changed) in 0.10 seconds.
#     make: *** [format-check] Error 65
#
# which reads exactly like a red gate on the integration branch and is nothing
# of the sort. `frontend/pubspec.yaml` declares `sdk: ^3.13.0`, but
# `dart format` does not read the SDK constraint, so Homebrew's dart-sdk 3.12.1
# — BELOW the declared floor — formatted three tracked files differently and
# exited 65. Measured on develop at c6dd5b2: 3 changed / exit 65 under 3.12.1,
# 0 changed / exit 0 under the pinned 3.47.5. `develop` was fine; the toolchain
# was not, and the gate had no way to say so.
#
# The required version has ONE home, `frontend/.fvmrc`, read here and by every
# `Set up the pinned Flutter SDK` step in .github/workflows/frontend-ci.yaml.
# It used to ALSO live in that workflow, as `FLUTTER_VERSION`, where no local
# command could reach it — the SDK half of "change one, change its pair"
# (.claude/rules/ci-conventions.md §5).
#
# `.fvmrc` rather than a new `.flutter-version`, because `.fvmrc` was already
# tracked and already cited as THE pin by frontend/README.md and
# docs/DEV_HARNESS.md. A second machine-readable pin file would have recreated
# the exact defect this check exists to remove, one file over. Using fvm is
# optional — nothing here shells out to it; the file is read as plain JSON.
#
# Why bash and not Dart: this check's whole job is to run BEFORE any conclusion
# drawn from `dart` or `flutter` can be trusted, and a Dart script would have to
# be launched by the very binary under suspicion.
#
# Why `--machine --suppress-analytics` and not `flutter --version`: plain
# `flutter --version` throws an unhandled PathAccessException when the tool
# cannot delete its own telemetry log (~/.dart-tool/dart-flutter-telemetry.log),
# which is the normal case inside an agent sandbox. A preflight that crashes is
# worse than no preflight. `--machine` also returns the vendored Dart version
# and the SDK root as JSON, which is what the `dart` comparison below needs.

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

PIN_FILE=".fvmrc"
# The command that fixes a red run, copied verbatim into .claude/ship-gate.json
# (`frontend.toolchain`), frontend/Makefile and frontend-ci.yaml — never
# paraphrased (.claude/rules/ci-conventions.md §5).
FIX="bash tool/check_toolchain.sh"

if [ ! -f "$PIN_FILE" ]; then
  echo "frontend.toolchain: ${PIN_FILE} is missing — the pinned version has no home" >&2
  exit 1
fi

# `{"flutter": "3.47.5"}` — the one key fvm defines. Read with sed, not jq:
# this check runs before anything in the workspace is trusted, and it must work
# on a laptop that has installed nothing yet.
required=$(
  sed -n 's/.*"flutter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$PIN_FILE" \
    | head -n 1
)

if [ -z "$required" ]; then
  echo "frontend.toolchain: ${PIN_FILE} names no Flutter version" >&2
  echo "  expected a \"flutter\": \"<version>\" key, e.g. {\"flutter\": \"3.47.5\"}" >&2
  exit 1
fi

install_hint() {
  cat >&2 <<EOF

  Install the pinned SDK. With fvm, if you already use it:

      fvm install ${required} && fvm use ${required}

  Without it — nothing in this gate requires fvm:

      git clone --depth 1 --branch ${required} https://github.com/flutter/flutter.git "\$HOME/flutter-${required}"
      export PATH="\$HOME/flutter-${required}/bin:\$PATH"

  Put that PATH line in your shell profile so \`dart\` resolves to the SDK
  Flutter vendors, not to a Homebrew or system copy. Then re-run: ${FIX}
EOF
}

if ! command -v flutter >/dev/null 2>&1; then
  echo "frontend.toolchain: no Flutter SDK found on PATH" >&2
  echo "  required: Flutter ${required} (${PIN_FILE})" >&2
  echo "  found:    nothing — \`command -v flutter\` resolved to no binary" >&2
  install_hint
  exit 1
fi

flutter_path=$(command -v flutter)

# `|| true` so a crashing tool becomes an empty payload and the explicit error
# below, rather than `set -e` killing the script with no message at all.
machine=$(flutter --version --machine --suppress-analytics 2>/dev/null || true)

# Field extraction without jq: `frontend/` has no jq dependency and the gate
# must run before anything in this workspace is trusted. One key, one line.
json_field() {
  printf '%s\n' "$machine" \
    | sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" \
    | head -n 1
}

found_flutter=$(json_field frameworkVersion)
vendored_dart=$(json_field dartSdkVersion)
flutter_root=$(json_field flutterRoot)

if [ -z "$found_flutter" ]; then
  echo "frontend.toolchain: \`flutter --version --machine\` returned no version" >&2
  echo "  required: Flutter ${required} (${PIN_FILE})" >&2
  echo "  flutter:  ${flutter_path}" >&2
  echo "  The SDK is on PATH but could not report itself. Run it directly to see why:" >&2
  echo "      flutter --version --machine --suppress-analytics" >&2
  exit 1
fi

if [ "$found_flutter" != "$required" ]; then
  echo "frontend.toolchain: the Flutter on PATH is not the pinned one" >&2
  echo "  required: Flutter ${required} (${PIN_FILE})" >&2
  echo "  found:    Flutter ${found_flutter} (${flutter_path})" >&2
  install_hint
  exit 1
fi

if ! command -v dart >/dev/null 2>&1; then
  echo "frontend.toolchain: no Dart SDK found on PATH" >&2
  echo "  required: Dart ${vendored_dart}, the SDK Flutter ${required} vendors" >&2
  echo "  found:    nothing — \`command -v dart\` resolved to no binary" >&2
  echo "  fix:      export PATH=\"${flutter_root}/bin:\$PATH\"" >&2
  exit 1
fi

dart_path=$(command -v dart)
found_dart=$(dart --version 2>&1 | sed -n 's/.*version:[[:space:]]*\([0-9][^ ]*\).*/\1/p' | head -n 1)

if [ -z "$found_dart" ]; then
  echo "frontend.toolchain: \`dart --version\` returned no version" >&2
  echo "  required: Dart ${vendored_dart} (vendored by Flutter ${required})" >&2
  echo "  dart:     ${dart_path}" >&2
  exit 1
fi

# The defect this check exists for: a correct `flutter` and a DIFFERENT `dart`
# earlier on PATH. `dart format`, `dart analyze` and `dart test` all run from
# that one, and none of them reads the SDK constraint in pubspec.yaml.
if [ "$found_dart" != "$vendored_dart" ]; then
  echo "frontend.toolchain: the Dart on PATH is not the one Flutter ${required} vendors" >&2
  echo "  required: Dart ${vendored_dart} (vendored by Flutter ${required}, ${flutter_root})" >&2
  echo "  found:    Dart ${found_dart} (${dart_path})" >&2
  echo "  This is the one that fails as a formatting diff: \`dart format\` does not" >&2
  echo "  read the SDK constraint, so the wrong Dart reformats tracked files and" >&2
  echo "  exits 65 while the branch is perfectly formatted." >&2
  echo "  fix:      export PATH=\"${flutter_root}/bin:\$PATH\"" >&2
  exit 1
fi

echo "frontend.toolchain: Flutter ${found_flutter} · Dart ${found_dart} · ${flutter_root} — matches ${PIN_FILE}"
