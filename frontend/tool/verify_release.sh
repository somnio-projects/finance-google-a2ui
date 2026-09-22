#!/usr/bin/env bash
#
# Ask an origin which build it is serving, and fail if it is not this one.
#
# This is GGU-93's rule applied to a static bundle. The backend has `/health`,
# which reports `<version>+<sha>` verbatim, and `scripts/check_manual_run.sh`
# exists because without it a transcript from a tree six commits behind
# `develop` read exactly like a correct one. A Hosting release has no process
# to ask, so `tool/build_web.sh` writes `/release.json` beside the bundle and
# this script reads it back over HTTP.
#
# `frontend-cd.yaml` runs it twice: once against the preview channel, before
# anything is live, and once against the live origin afterwards. The second
# call is the one that turns "the deploy step exited 0" into "the origin is
# serving this commit" — two claims that look like one until they disagree.
#
#   URL      the origin to ask, with no trailing path (e.g. https://x.web.app)
#   RELEASE  the identifier it must report (e.g. 0.1.0+a1b2c3d)
#   CURL     optional; the curl to use. Exists so tests/ can stub it — this
#            script's whole job is to reject, and a rejection path that has
#            never run is not one.
#
# Hosting serves a new release within a second or two, but "within" is not
# "immediately", so a miss is retried before it is believed. A mismatch that
# survives every attempt is reported with both values, because "verification
# failed" without them sends people to the wrong file.

set -Eeuo pipefail

: "${URL:?verify_release: URL is required — the origin to ask}"
: "${RELEASE:?verify_release: RELEASE is required — the identifier it must report}"

curl_bin="${CURL:-curl}"
attempts="${ATTEMPTS:-6}"
delay="${RETRY_DELAY_SECONDS:-5}"

endpoint="${URL%/}/release.json"
body=""
reported=""

for attempt in $(seq 1 "${attempts}"); do
  if body="$("${curl_bin}" -fsS --max-time 20 "${endpoint}" 2>/dev/null)"; then
    reported="$(printf '%s' "${body}" | jq -r '.release // empty' 2>/dev/null || true)"
    if [ "${reported}" = "${RELEASE}" ]; then
      echo "verify_release: ${endpoint} reports ${reported} — this commit."
      exit 0
    fi
    echo "verify_release: attempt ${attempt}/${attempts} — ${endpoint} reports '${reported:-<unparsable>}', expected '${RELEASE}'"
  else
    echo "verify_release: attempt ${attempt}/${attempts} — ${endpoint} did not answer"
  fi
  [ "${attempt}" -lt "${attempts}" ] && sleep "${delay}"
done

echo "verify_release: ${endpoint} never reported ${RELEASE}." >&2
echo "verify_release: last answer: ${body:-<none>}" >&2
echo "verify_release: the origin is NOT serving the build this run produced." >&2
echo "verify_release: do not read a green deploy step as a released build —" >&2
echo "verify_release: that is the gap this check exists to close (GGU-93)." >&2
exit 1
