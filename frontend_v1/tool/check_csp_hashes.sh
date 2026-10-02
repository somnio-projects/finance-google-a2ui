#!/usr/bin/env bash
# frontend.csp — the two Content-Security-Policy headers this client is served
# under must authorise the one inline script it genuinely needs.
#
# WHY THIS EXISTS. `firebase_core_web` loads the Firebase JS SDK by appending a
# <script> element whose *text* it sets — an inline script — that defines
# `window.ff_trigger_<service>` and then dynamic-`import()`s the SDK bundle
# from gstatic. A strict `script-src` blocks it, `Firebase.initializeApp`
# throws, and the app renders a white page. That is not hypothetical: it is
# what https://finance-a2ui.web.app served on 2026-09-22, and nothing caught it
# because every local run is served without a CSP and every test runs in a
# widget harness that has no browser policy at all.
#
# WHY HASHES AND NOT 'unsafe-inline'. The alternatives were weighed:
#   * 'unsafe-inline' — authorises every inline script in the document, which
#     is the whole point of the directive. Refused (security.md).
#   * a nonce — needs the server to mint one per response. Firebase Hosting
#     serves static files; there is no response to mint into.
#   * pre-loading the SDK so the plugin's own skip condition
#     (`window.firebase_core != null`, firebase_core_web.dart `_initializeCore`)
#     fires — a race against `main()`, which is worse than a hash.
# A hash authorises exactly one byte sequence, which is the tightest of the
# four and the only one with no runtime moving part.
#
# WHY IT IS A GATE. A hash is a copy of somebody else's source. Bump
# `firebase_core_web`, or add a FlutterFire plugin, and the snippet changes and
# the app dies again — silently, on the deployed origin only. So the hash is
# never written by hand: this script derives it from the resolved package and
# fails with the value to paste. Same shape as the catalog artefacts — a
# generated value is gated by regeneration, never by trust
# (.claude/rules/ci-conventions.md §4).
set -euo pipefail

cd "$(dirname "$0")/.."

readonly LOCK="pubspec.lock"
# frontend_v1 ships to its own Hosting site, so it reads its own
# firebase.json — a copy of the root one's headers (same CSP).
readonly POLICIES=("firebase.json" "docker/nginx.conf.template")

fail() {
  echo "frontend.csp: $*" >&2
  exit 1
}

# The services whose loader snippets we authorise. Deliberately a literal:
# `_initializeCore` injects one script per registered FlutterFire plugin, so a
# plugin added tomorrow needs a fifth and a sixth hash. The guard below turns
# that into a failing gate instead of a white page.
readonly SERVICES=("firebase_core:app" "firebase_auth:auth")
readonly EXPECTED_PLUGINS=("firebase_auth_web" "firebase_core_web")

pub_cache="${PUB_CACHE:-$HOME/.pub-cache}"

[ -f "$LOCK" ] || fail "no $LOCK here — run this from frontend_v1/"

# 1. The plugin set must be the one the literal above covers.
found="$(grep -oE '^  firebase_[a-z_]+_web:' "$LOCK" | tr -d ' :' | sort -u | tr '\n' ' ')"
found="${found% }"
if [ "$found" != "${EXPECTED_PLUGINS[*]}" ]; then
  fail "the FlutterFire web plugins in $LOCK are [${found:-none}], but this
  check only authorises [${EXPECTED_PLUGINS[*]}]. Each plugin injects its own
  loader script, so add it to SERVICES here and re-run to get its hash."
fi

# 2. The SDK version is the plugin's, read from the resolved package.
version_of() {
  awk -v want="$1" '
    $1 == want":" { found = 1 }
    found && $1 == "version:" { gsub(/"/, "", $2); print $2; exit }
  ' "$LOCK"
}
plugin_version="$(version_of firebase_core_web)"
[ -n "$plugin_version" ] || fail "could not read firebase_core_web's version from $LOCK"

sdk_source="$pub_cache/hosted/pub.dev/firebase_core_web-$plugin_version/lib/src/firebase_sdk_version.dart"
[ -f "$sdk_source" ] || fail "$sdk_source is missing — run 'flutter pub get' first"

sdk_version="$(grep -oE "supportedFirebaseJsSdkVersion = '[^']+'" "$sdk_source" | cut -d"'" -f2)"
[ -n "$sdk_version" ] || fail "could not read supportedFirebaseJsSdkVersion from $sdk_source"

# 3. Rebuild both snippets byte for byte. The indentation is not cosmetic: the
# two branches of `injectSrcScript` are written with different leading
# whitespace, so a browser with Trusted Types (Chrome, Edge) and one without
# (Safari, Firefox) execute different bytes and need different hashes.
sha() { printf '%s' "$1" | openssl dgst -sha256 -binary | openssl base64 -A; }

trusted_types_snippet() {
  printf '            window.ff_trigger_%s = async (callback) => {\n' "$1"
  printf '              console.debug("Initializing Firebase %s");\n' "$1"
  printf '              callback(await import("%s"));\n' "$2"
  printf '            };\n          '
}

plain_snippet() {
  printf '      window.ff_trigger_%s = async (callback) => {\n' "$1"
  printf '        console.debug("Initializing Firebase %s");\n' "$1"
  printf '        callback(await import("%s"));\n' "$2"
  printf '      };\n    '
}

missing=0
checked=0
for entry in "${SERVICES[@]}"; do
  window_var="${entry%%:*}"
  bundle="${entry##*:}"
  url="https://www.gstatic.com/firebasejs/$sdk_version/firebase-$bundle.js"
  for shape in trusted_types plain; do
    digest="sha256-$(sha "$("${shape}_snippet" "$window_var" "$url")")"
    for policy in "${POLICIES[@]}"; do
      [ -f "$policy" ] || fail "$policy is missing"
      checked=$((checked + 1))
      if ! grep -qF "'$digest'" "$policy"; then
        echo "frontend.csp: $policy does not authorise $window_var ($shape)" >&2
        echo "  add to script-src: '$digest'" >&2
        missing=$((missing + 1))
      fi
    done
  done
done

# 4. Anti-vacuity: a check that silently examined nothing would pass.
[ "$checked" -eq 8 ] || fail "examined $checked policy/hash pairs, expected 8 — the loop is wrong"
[ "$missing" -eq 0 ] || fail "$missing authorisation(s) missing (Firebase JS SDK $sdk_version)"

echo "frontend.csp: ${#POLICIES[@]} policies authorise the Firebase JS SDK $sdk_version loader (${#SERVICES[@]} services × 2 shapes)"
