#!/usr/bin/env bash
#
# frontend.verify-release-test — prove verify_release.sh REJECTS.
#
# `.claude/rules/ci-conventions.md` records the rule this suite exists for:
# "a check that has never been shown to reject is the same defect one level
# up". `verify_release.sh` is the last thing standing between a green deploy
# job and a claim that the live origin serves this commit, and on a runner it
# can only ever be seen accepting — the deploy just succeeded. Its rejection
# paths have nowhere else to be exercised.
#
# `curl` is stubbed through the script's own CURL hook, so nothing here
# touches the network and every case is deterministic.

set -Eeuo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="${here}/../verify_release.sh"
# An explicit template, not a bare `mktemp -d`: BSD mktemp (macOS) resolves
# the bare form through confstr and IGNORES TMPDIR, so a developer whose
# temporary directory is elsewhere gets "Operation not permitted" from a
# suite that has nothing to do with temporary directories.
workdir="$(mktemp -d "${TMPDIR:-/tmp}/verify_release.XXXXXX")"
trap 'rm -rf "${workdir}"' EXIT

pass=0
fail=0

# A stub curl that prints $STUB_BODY and exits $STUB_CODE. It ignores its
# arguments on purpose: what is under test is how the script reads an answer,
# not how it spells a request.
cat > "${workdir}/curl" <<'STUB'
#!/usr/bin/env bash
[ "${STUB_CODE:-0}" -eq 0 ] || exit "${STUB_CODE}"
printf '%s' "${STUB_BODY:-}"
STUB
chmod +x "${workdir}/curl"

# One attempt and no delay: the retry loop is correct behaviour against a
# propagating CDN and would only make this suite slow.
run() {
  URL="https://example.test" \
  RELEASE="${1}" \
  CURL="${workdir}/curl" \
  ATTEMPTS=1 \
  RETRY_DELAY_SECONDS=0 \
  STUB_BODY="${2}" \
  STUB_CODE="${3}" \
    bash "${script}" >"${workdir}/out" 2>&1
}

check() {
  local name="${1}" expected="${2}" actual="${3}"
  if [ "${expected}" -eq "${actual}" ]; then
    pass=$((pass + 1))
    echo "  ok   ${name} (exit ${actual})"
  else
    fail=$((fail + 1))
    echo "  FAIL ${name}: expected exit ${expected}, got ${actual}" >&2
    sed 's/^/       /' "${workdir}/out" >&2
  fi
}

echo "test_verify_release: the rejections"

# 1. A DIFFERENT build is serving. The case GGU-93 is about: the deploy step
#    exited 0 and the origin is on something else.
set +e; run "0.1.0+aaaaaaa" '{"release":"0.1.0+bbbbbbb"}' 0; code=$?; set -e
check "a stale release is rejected" 1 "${code}"

# 2. The origin does not answer at all.
set +e; run "0.1.0+aaaaaaa" '' 22; code=$?; set -e
check "an origin that does not answer is rejected" 1 "${code}"

# 3. /release.json exists but is not the document this expects — e.g. the SPA
#    rewrite served index.html for a missing file, which is a 200.
set +e; run "0.1.0+aaaaaaa" '<!DOCTYPE html><html></html>' 0; code=$?; set -e
check "a non-JSON body is rejected" 1 "${code}"

# 4. Valid JSON with no release field — a bundle built by something that did
#    not go through build_web.sh.
set +e; run "0.1.0+aaaaaaa" '{"backendBaseUrl":"https://api.test"}' 0; code=$?; set -e
check "JSON without a release field is rejected" 1 "${code}"

# 5. A PREFIX of the expected release. Guards against a substring comparison
#    ever creeping in: `0.1.0+aaaaaa` must not satisfy `0.1.0+aaaaaaa`.
set +e; run "0.1.0+aaaaaaa" '{"release":"0.1.0+aaaaaa"}' 0; code=$?; set -e
check "a prefix of the release is rejected" 1 "${code}"

# 6. Missing inputs. A check invoked wrongly must stop, not pass vacuously.
set +e
URL="" RELEASE="0.1.0+aaaaaaa" CURL="${workdir}/curl" ATTEMPTS=1 \
  bash "${script}" >"${workdir}/out" 2>&1
code=$?
set -e
check "an empty URL is rejected" 1 "${code}"

set +e
URL="https://example.test" RELEASE="" CURL="${workdir}/curl" ATTEMPTS=1 \
  bash "${script}" >"${workdir}/out" 2>&1
code=$?
set -e
check "an empty RELEASE is rejected" 1 "${code}"

echo "test_verify_release: the one acceptance"

# 7. The only shape that may pass.
set +e; run "0.1.0+aaaaaaa" '{"release":"0.1.0+aaaaaaa","backendBaseUrl":"https://api.test"}' 0; code=$?; set -e
check "the matching release is accepted" 0 "${code}"

# The anti-vacuity guard `infra/scripts/tests/` uses: a suite that ran no
# cases is not a green suite.
if [ "$((pass + fail))" -lt 8 ]; then
  echo "test_verify_release: only $((pass + fail)) cases ran — the suite lost rows" >&2
  exit 1
fi

if [ "${fail}" -gt 0 ]; then
  echo "test_verify_release: ${fail} of $((pass + fail)) cases failed" >&2
  exit 1
fi

echo "test_verify_release: ${pass} cases, all green"
