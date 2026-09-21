#!/usr/bin/env bash
#
# Proves frontend/tool/check_toolchain.sh rejects, and rejects for the right
# reason (GGU-94).
#
# It needs a suite more than most checks in this repository, for two reasons a
# reviewer named:
#
#   1. It is the FIRST step of `cd frontend && make gate`, so a false failure
#      blocks every other frontend check behind it.
#   2. On a runner it can never be observed rejecting, because CI installs
#      exactly the pinned SDK. The only place its failure paths can be exercised
#      is here.
#
# The SDK is stubbed, not installed: a fake `flutter` and a fake `dart` on PATH,
# the same shape `infra/scripts/tests/test_deploy_cloud_run.sh` uses for
# `gcloud`. So this runs in about a second on a machine with no Flutter at all —
# which is the machine the ticket was filed from.
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRONTEND="$(cd "${HERE}/../.." && pwd)"
cd "$FRONTEND"

CHECK="tool/check_toolchain.sh"
# Identical to the `frontend.toolchain-test` entry in ../.claude/ship-gate.json,
# the pre-commit hook and the frontend-ci step (ci-conventions §5 — copied,
# never paraphrased).
FIX="bash tool/tests/test_check_toolchain.sh"

PASSED=0
FAILED=0
pass() { echo "  PASS  $1"; PASSED=$(( PASSED + 1 )); }
fail() { echo "  FAIL  $1"; FAILED=$(( FAILED + 1 )); }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/toolchain.XXXXXX")"
trap 'rm -rf "${WORK}"' EXIT

# Builds a stub SDK in $WORK/bin: `flutter --version --machine` prints the JSON
# the real tool prints, `dart --version` prints what the real one prints.
# $1 flutter version, $2 dart version. Either may be the literal "crash".
stub_sdk() {
  local flutter_version="$1" dart_version="$2"
  # `${WORK:?}`, not `${WORK}`: an unset or empty WORK would make this
  # `rm -rf /bin`. SC2115, and the one shellcheck finding worth obeying rather
  # than annotating.
  rm -rf "${WORK:?}/bin"
  mkdir -p "${WORK}/bin"

  if [ "$flutter_version" = "crash" ]; then
    printf '%s\n' '#!/bin/sh' 'echo "Unhandled exception: PathAccessException" >&2' 'exit 1' \
      >"${WORK}/bin/flutter"
  else
    {
      printf '%s\n' '#!/bin/sh'
      printf 'cat <<JSON\n'
      printf '{\n'
      printf '  "frameworkVersion": "%s",\n' "$flutter_version"
      printf '  "dartSdkVersion": "%s",\n' "$dart_version"
      printf '  "flutterRoot": "%s"\n' "${WORK}/sdk"
      printf '}\n'
      printf 'JSON\n'
    } >"${WORK}/bin/flutter"
  fi

  printf '%s\n' '#!/bin/sh' \
    "echo 'Dart SDK version: ${dart_version} (stable) on \"macos_arm64\"'" \
    >"${WORK}/bin/dart"

  chmod +x "${WORK}/bin/flutter" "${WORK}/bin/dart"
}

# Runs the check with only the stub directory (plus the system binaries the
# script itself needs) on PATH, and asserts the exit code AND the message.
# "Exited non-zero" is not enough: a red gate is not evidence that it is red for
# your reason (ci-conventions §5).
expect() {
  local label="$1" want_status="$2" want_text="$3" search_path="$4"
  local out status
  set +e
  out=$(PATH="$search_path" bash "$CHECK" 2>&1)
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

PINNED="$(sed -n 's/.*"flutter"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' .fvmrc | head -n 1)"
SYS="/usr/bin:/bin"

echo "== ${CHECK} (pin: ${PINNED})"

# 1. The stub agrees with .fvmrc and its Dart is the one it vendors.
stub_sdk "$PINNED" "3.13.4"
expect "the pinned SDK with its own Dart is accepted" \
  0 "matches .fvmrc" "${WORK}/bin:${SYS}"

# 2. The wrong Flutter entirely.
stub_sdk "3.40.0" "3.13.4"
expect "a Flutter that is not the pinned one is rejected" \
  1 "the Flutter on PATH is not the pinned one" "${WORK}/bin:${SYS}"
expect "the rejection names both versions" \
  1 "found:    Flutter 3.40.0" "${WORK}/bin:${SYS}"

# 3. THE defect: the right Flutter, a different Dart earlier on PATH. This is
#    the one that used to surface as three unformatted files and exit 65.
stub_sdk "$PINNED" "3.13.4"
mkdir -p "${WORK}/homebrew"
printf '%s\n' '#!/bin/sh' "echo 'Dart SDK version: 3.12.1 (stable) on \"macos_arm64\"'" \
  >"${WORK}/homebrew/dart"
chmod +x "${WORK}/homebrew/dart"
expect "a Dart that is not the one Flutter vendors is rejected" \
  1 "not the one Flutter ${PINNED} vendors" "${WORK}/homebrew:${WORK}/bin:${SYS}"
expect "the rejection names the Dart found and the Dart required" \
  1 "found:    Dart 3.12.1" "${WORK}/homebrew:${WORK}/bin:${SYS}"

# 4. No Flutter at all — the message the ticket asked for by name.
expect "no Flutter on PATH says so, rather than failing at a format diff" \
  1 "no Flutter SDK found on PATH" "$SYS"

# 5. A `flutter` that crashes. Plain `flutter --version` throws an unhandled
#    PathAccessException in an agent sandbox when it cannot delete its own
#    telemetry log — and does it INSIDE its error handler, hiding the first
#    failure. The check must report that, not die with `set -e` and no message.
stub_sdk "crash" "3.13.4"
expect "a flutter that cannot report itself is a named failure, not a crash" \
  1 "returned no version" "${WORK}/bin:${SYS}"

# 6. Anti-vacuity. Every assertion above holds of a script that always exits 1,
#    except the first — so this asserts the suite really ran them all.
if [ "$PASSED" -lt 7 ]; then
  fail "the suite ran ${PASSED} assertion(s) — fewer than it contains"
fi

echo
echo "  ${PASSED} passed, ${FAILED} failed"
if [ "$FAILED" -gt 0 ]; then
  echo "  fix: ${FIX}" >&2
  exit 1
fi
