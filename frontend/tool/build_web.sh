#!/usr/bin/env bash
#
# Build the release web bundle — the ONE place the build flags live.
#
# Two things compile this app for real: `frontend/Dockerfile` (the local stack
# and anything container-shaped) and `.github/workflows/frontend-cd.yaml` (the
# bundle that reaches Firebase Hosting). If each carried its own flag list,
# the container would be a rehearsal of something slightly different from what
# ships, and the difference would be invisible until it mattered — the exact
# "change one, change its pair" drift `.claude/rules/ci-conventions.md` §5 was
# written about, in a place §5's machine check cannot see because neither half
# is a ship-gate command.
#
# So both call this. The flags below are the whole contract.
#
# Configuration arrives as environment variables rather than arguments because
# the Dockerfile has them as build args and the workflow has them as job env,
# and `env:` is the shape both already speak. None of them is a credential:
# the Firebase web config is public by design (ADR-B D-10) and ships inside
# the bundle regardless.
#
#   BACKEND_BASE_URL               required — the API origin, as the BROWSER
#                                  sees it
#   APP_RELEASE                    required — `<version>+<short sha>`, served
#                                  at /release.json (GGU-93)
#   FIREBASE_API_KEY               optional — absent means "this build has no
#   FIREBASE_APP_ID                           Firebase", which is a declared
#   FIREBASE_PROJECT_ID                       state, not a degraded one: the
#   FIREBASE_AUTH_DOMAIN                      Google button says so and the
#   FIREBASE_MESSAGING_SENDER_ID              e-mail path is the backend's
#                                             preview sign-in
#
# Partial Firebase configuration is refused rather than compiled. `AppConfig`
# keys the whole block off FIREBASE_API_KEY alone, so four values with a fifth
# missing would produce a build that believes it can sign in and cannot — a
# failure that first appears in a browser, on a deployed origin.

set -Eeuo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

: "${BACKEND_BASE_URL:?build_web: BACKEND_BASE_URL is required — the API origin this bundle talks to}"
: "${APP_RELEASE:?build_web: APP_RELEASE is required — the <version>+<sha> this bundle reports at /release.json}"

firebase_keys=(
  FIREBASE_API_KEY
  FIREBASE_APP_ID
  FIREBASE_PROJECT_ID
  FIREBASE_AUTH_DOMAIN
  FIREBASE_MESSAGING_SENDER_ID
)

set_count=0
for key in "${firebase_keys[@]}"; do
  [ -n "${!key:-}" ] && set_count=$((set_count + 1))
done

if [ "$set_count" -ne 0 ] && [ "$set_count" -ne ${#firebase_keys[@]} ]; then
  echo "build_web: Firebase is configured by halves — ${set_count} of ${#firebase_keys[@]} values are set." >&2
  for key in "${firebase_keys[@]}"; do
    [ -n "${!key:-}" ] || echo "build_web:   missing ${key}" >&2
  done
  echo "build_web: set all five or none. AppConfig keys the whole block off" >&2
  echo "build_web: FIREBASE_API_KEY, so a partial set compiles an app that" >&2
  echo "build_web: believes it can sign in and cannot." >&2
  exit 1
fi

if [ "$set_count" -eq 0 ]; then
  echo "build_web: no Firebase config — the Google button will say so and the e-mail path is the backend's preview sign-in."
else
  echo "build_web: Firebase project ${FIREBASE_PROJECT_ID}, auth domain ${FIREBASE_AUTH_DOMAIN}."
fi
echo "build_web: API origin ${BACKEND_BASE_URL}, release ${APP_RELEASE}."

# --csp                  no dynamically generated code. This is what lets the
#                        container's Content-Security-Policy stay off
#                        'unsafe-eval'; the flag and that header are a pair,
#                        and dropping it makes the header wrong rather than
#                        making the app fail visibly.
# --no-web-resources-cdn bundle CanvasKit instead of fetching it from
#                        gstatic.com at run time. The Firebase JS SDK is then
#                        the ONLY remote script the page loads, which is what
#                        makes that one CSP exception reviewable.
# --no-source-maps       a .map file republishes the Dart source; the bundle
#                        is public, so do not put more in it than has to be.
# --pwa-strategy=none    no service worker. An offline-first worker caches the
#                        app shell and would keep serving it after a deploy —
#                        on Hosting that means a release that looks live and
#                        is not.
cd app
flutter build web \
  --release \
  --csp \
  --no-web-resources-cdn \
  --no-source-maps \
  --pwa-strategy=none \
  --dart-define=BACKEND_BASE_URL="${BACKEND_BASE_URL}" \
  --dart-define=FIREBASE_API_KEY="${FIREBASE_API_KEY:-}" \
  --dart-define=FIREBASE_APP_ID="${FIREBASE_APP_ID:-}" \
  --dart-define=FIREBASE_PROJECT_ID="${FIREBASE_PROJECT_ID:-}" \
  --dart-define=FIREBASE_AUTH_DOMAIN="${FIREBASE_AUTH_DOMAIN:-}" \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID="${FIREBASE_MESSAGING_SENDER_ID:-}"

# Written as a FILE rather than a sixth --dart-define, because
# `app/test/architecture/layering_test.dart` allows exactly one
# `String.fromEnvironment` call site and a build identifier is not worth
# spending it: nothing in the app reads this. The pipeline that deployed the
# bundle reads it back over HTTP to prove the release it published is the one
# the origin is serving — which is what /health does for the API, moved to a
# thing that has no process to ask.
printf '{"release":"%s","backendBaseUrl":"%s"}\n' \
  "${APP_RELEASE}" "${BACKEND_BASE_URL%/}" \
  > build/web/release.json

echo "build_web: built app/build/web, /release.json reports ${APP_RELEASE}"
